import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "BILI_AUDIO_SOURCE";

typedef FatalErrorCallback =
void Function(String bvid, int cid, String message);

class BiliAudioSource extends StreamAudioSource {
  final String bvid;
  final int initCid;
  final String title;
  final String artist;
  final String coverUrl;
  final int quality;
  final FatalErrorCallback? onFatalError;

  final DownloadManager _downloadManager = DownloadManager();
  final DatabaseService _dbService = DatabaseService();
  final SearchApi _searchApi = SearchApi();
  StreamSubscription? _currentSubscription;
  int _realCid = 0;

  BiliAudioSource({
    required this.bvid,
    required this.initCid,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.quality,
    this.onFatalError,
  }) : super(
    tag: MediaItem(
      id: '${bvid}_$initCid',
      title: title,
      artist: artist,
      artUri: Uri.tryParse(coverUrl),
    ),
  ) {
    _realCid = initCid;
  }

  String _getMimeType(String? extension) {
    if (quality == 30251) return 'audio/flac';
    if (extension != null) {
      switch (extension.toLowerCase()) {
        case 'flac':
          return 'audio/flac';
        case 'mp3':
          return 'audio/mpeg';
        case 'aac':
          return 'audio/aac';
        case 'm4a':
          return 'audio/mp4';
      }
    }
    return 'audio/mp4';
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    Log.v(_tag, "request range: $start - $end");
    final startOffset = start ?? 0;

    try {
      if (_realCid == 0) {
        try {
          _realCid = await _searchApi.fetchCid(bvid);
        } catch (e) {
          Log.e(_tag, "Failed to resolve CID", e);
        }
      }
      final targetCid = _realCid == 0 ? initCid : _realCid;
      final localRes = await _downloadManager.checkLocalResource(
        bvid,
        targetCid,
        quality,
      );
      if (localRes != null && localRes.file != null) {
        final file = localRes.file!;
        final fileLen = await file.length();

        if (startOffset == 0) {
          AudioPlayerService().notifyActualQuality(localRes.quality ?? quality);
        }

        return StreamAudioResponse(
          sourceLength: fileLen,
          contentLength: end != null
              ? (end - startOffset + 1)
              : (fileLen - startOffset),
          offset: startOffset,
          stream: file.openRead(startOffset, end),
          contentType: _getMimeType(null),
        );
      }

      final bool enableCache = (startOffset == 0 && targetCid != 0);

      final netResponse = await _downloadManager.getNetworkStream(
        bvid,
        targetCid,
        quality,
        start: startOffset,
      );

      final response = netResponse.httpResponse;
      final contentType = netResponse.mimeType;

      if (startOffset == 0) {
        AudioPlayerService().notifyActualQuality(netResponse.actualQuality);
      }

      int contentLength = response.contentLength;
      int? sourceLength;

      if (response.statusCode == 206) {
        final rangeHeader = response.headers.value(HttpHeaders.contentRangeHeader);
        if (rangeHeader != null) {
          final parts = rangeHeader.split('/');
          if (parts.length == 2 && parts[1] != '*') {
            sourceLength = int.tryParse(parts[1]);
          }
        }
      }

      if (sourceLength == null) {
        if (startOffset == 0 && contentLength > 0) {
          sourceLength = contentLength;
        } else if (contentLength > 0) {
          sourceLength = contentLength + startOffset;
        }
      }

      Stream<List<int>> stream = response;

      if (enableCache && sourceLength != null && sourceLength > 0) {
        return _handleCacheStream(
          stream,
          targetCid,
          startOffset,
          contentLength,
          sourceLength,
          bvid,
          contentType,
        );
      } else {
        return StreamAudioResponse(
          sourceLength: sourceLength,
          contentLength: contentLength,
          offset: startOffset,
          stream: stream,
          contentType: contentType,
        );
      }
    } catch (e) {
      Log.e(_tag, "BiliAudioSource Request Failed: $e");
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains("403") ||
          errorStr.contains("404") ||
          errorStr.contains("resource") ||
          errorStr.contains("unavailable")) {
        onFatalError?.call(bvid, _realCid, e.toString());
      }
      rethrow;
    }
  }

  StreamAudioResponse _handleCacheStream(
      Stream<List<int>> input,
      int cid,
      int offset,
      int contentLength,
      int sourceLength,
      String bvid,
      String contentType,
      ) {
    final tempPath = _downloadManager.getTempCachePath(bvid, cid);
    final tempFile = File(tempPath);

    StreamController<List<int>>? outputController;
    StreamSubscription? inputSubscription;
    IOSink? fileSink;
    bool isWriting = false;
    int writtenBytes = 0;

    outputController = StreamController<List<int>>.broadcast(
      onCancel: () async {
        await inputSubscription?.cancel();
        if (isWriting && fileSink != null) {
          try {
            await fileSink!.flush();
            await fileSink!.close();
            if (writtenBytes > sourceLength * 0.8) {
              Log.v(_tag, "Keeping partial cache ($writtenBytes/$sourceLength) for resume");
              await _dbService.recordCacheAccess(
                bvid,
                cid,
                quality,
                status: CacheStatus.promoting.code,
                fileSize: writtenBytes,
                totalSize: sourceLength,
              );
            } else if (await tempFile.exists()) {
              await tempFile.delete();
              Log.v(_tag, "Download cancelled (Probe/Seek), temp file cleaned");
            }
          } catch (_) {}
        }
      },
    );

    Future.microtask(() async {
      try {
        if (!await tempFile.parent.exists()) {
          await tempFile.parent.create(recursive: true);
        }
        if (await tempFile.exists()) {
          final existingSize = await tempFile.length();
          if (existingSize > 0 && existingSize < sourceLength) {
            Log.v(_tag, "Found incomplete cache, will overwrite");
          }
          await tempFile.delete();
        }

        fileSink = tempFile.openWrite();
        isWriting = true;
      } catch (e) {
        Log.w(_tag, "Failed to open temp file: $e");
        isWriting = false;
      }
    });

    inputSubscription = input.listen(
          (data) {
        if (!outputController!.isClosed) {
          outputController.add(data);
        }
        if (isWriting && fileSink != null) {
          try {
            fileSink!.add(data);
            writtenBytes += data.length;
          } catch (e) {
            isWriting = false;
            try { fileSink?.close(); } catch (_) {}
            fileSink = null;
            _cleanupTempFile(tempFile);
          }
        }
      },
      onDone: () async {
        await outputController?.close();
        if (isWriting && fileSink != null) {
          try {
            await fileSink!.flush();
            await fileSink!.close();

            if (_downloadManager.isCacheEnabled) {
              int finalSize = await tempFile.length();
              if (finalSize == sourceLength) {
                _promoteTempFile(tempFile, cid, sourceLength);
              } else {
                Log.v(_tag, "Partial download ($finalSize/$sourceLength), skip cache.");
                _cleanupTempFile(tempFile);
              }
            } else {
              _cleanupTempFile(tempFile);
            }
          } catch (_) {
            _cleanupTempFile(tempFile);
          }
        }
      },
      onError: (e) {
        if (!outputController!.isClosed) outputController?.addError(e);
        if (isWriting) {
          try { fileSink?.close(); } catch (_) {}
          _cleanupTempFile(tempFile);
        }
      },
      cancelOnError: true,
    );

    _currentSubscription = inputSubscription;

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: contentLength,
      offset: offset,
      stream: outputController.stream,
      contentType: contentType,
    );
  }

  Future<void> _promoteTempFile(File tempFile, int cid, int totalSize) async {
    Log.v(_tag, "_promoteTempFile");
    try {
      final staticPath = _downloadManager.getStaticCachePath(
        bvid,
        cid,
        quality,
      );
      final staticFile = File(staticPath);
      if (!await staticFile.parent.exists()) {
        await staticFile.parent.create(recursive: true);
      }

      if (await staticFile.exists()) await staticFile.delete();

      await tempFile.rename(staticPath);

      await _dbService.recordCacheAccess(
        bvid,
        cid,
        quality,
        status: 1,
        fileSize: totalSize,
        totalSize: totalSize,
      );

      await _downloadManager.onCacheFileAdded(totalSize);

    } catch (e) {
      Log.w(_tag, "Promote failed: $e");
      _cleanupTempFile(tempFile);
    }
  }

  Future<void> _cleanupTempFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}