import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/services/download_manager.dart';
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
  bool _isDisposed = false;
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
        return StreamAudioResponse(
          sourceLength: fileLen,
          contentLength: end != null
              ? (end - startOffset)
              : (fileLen - startOffset),
          offset: startOffset,
          stream: file.openRead(startOffset, end),
          contentType: 'audio/mp4',
        );
      }

      final bool enableCache = (startOffset == 0 && targetCid != 0);

      final response = await _downloadManager.getNetworkStream(
        bvid,
        targetCid,
        quality,
        start: startOffset,
      );

      int contentLength = response.contentLength;
      int? sourceLength;
      if (response.statusCode == 206) {
        final rangeHeader = response.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        if (rangeHeader != null) {
          // bytes 0-1023/10000
          final parts = rangeHeader.split('/');
          if (parts.length == 2 && parts[1] != '*') {
            sourceLength = int.tryParse(parts[1]);
          }
        }
      }

      if (sourceLength == null) {
        if (startOffset == 0 && contentLength > 0) {
          sourceLength = contentLength;
        } else {
          sourceLength = contentLength > 0
              ? (contentLength + startOffset)
              : null;
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
        );
      } else {
        return StreamAudioResponse(
          sourceLength: sourceLength,
          contentLength: contentLength,
          offset: startOffset,
          stream: stream,
          contentType: 'audio/mp4',
        );
      }
    } catch (e) {
      Log.e(_tag, "BiliAudioSource Request Failed: $e");
      if (e.toString().contains("403") || e.toString().contains("404")) {
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
  ) {
    final tempPath = _downloadManager.getTempCachePath(bvid, cid);
    final tempFile = File(tempPath);
    final StreamController<List<int>> outputController = StreamController();
    IOSink? fileSink;
    bool isWriting = false;
    Future.microtask(() async {
      try {
        if (!await tempFile.parent.exists()) {
          await tempFile.parent.create(recursive: true);
        }
        fileSink = tempFile.openWrite();
        isWriting = true;
      } catch (e) {
        Log.w(
          _tag,
          "Failed to open temp file for writing, falling back to direct stream: $e",
        );
        isWriting = false;
      }
    });

    _currentSubscription = input.listen(
      (data) {
        if (_isDisposed) return;
        outputController.add(data);
        if (isWriting && fileSink != null) {
          try {
            fileSink!.add(data);
          } catch (e) {
            Log.w(
              _tag,
              "Cache write error, stopping cache but continuing play: $e",
            );
            isWriting = false;
            fileSink?.close();
            fileSink = null;
            _cleanupTempFile(tempFile);
          }
        }
      },
      onDone: () async {
        await outputController.close();
        if (isWriting && fileSink != null) {
          try {
            await fileSink!.flush();
            await fileSink!.close();
            if (_downloadManager.isCacheEnabled) {
              _promoteTempFile(tempFile, cid, sourceLength);
            } else {
              Log.v(_tag, "Cache limit is 0, cleaning up temp file.");
              _cleanupTempFile(tempFile);
            }
          } catch (_) {
            _cleanupTempFile(tempFile);
          }
        }
      },
      onError: (e) {
        outputController.addError(e);
        if (isWriting) {
          fileSink?.close();
          _cleanupTempFile(tempFile);
        }
      },
      cancelOnError: true,
    );

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: contentLength,
      offset: offset,
      stream: outputController.stream,
      contentType: 'audio/mp4',
    );
  }

  Future<void> _promoteTempFile(File tempFile, int cid, int totalSize) async {
    Log.v(_tag, "_promoteTempFile, path: ${tempFile.path}");

    try {
      final staticPath = _downloadManager.getStaticCachePath(
        bvid,
        cid,
        quality,
      );
      final staticFile = File(staticPath);
      if (!await staticFile.parent.exists())
        await staticFile.parent.create(recursive: true);
      if (await staticFile.exists()) await staticFile.delete();

      await tempFile.copy(staticPath);
      await tempFile.delete();

      await _dbService.recordCacheAccess(
        bvid,
        cid,
        quality,
        status: 1,
        fileSize: totalSize,
        totalSize: totalSize,
      );
    } catch (e) {
      Log.w(_tag, "Promote failed: $e");
      await _cleanupTempFile(tempFile);
    }
  }

  Future<void> _cleanupTempFile(File file) async {
    Log.v(_tag, "_cleanupTempFile, path: ${file.path}");
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
