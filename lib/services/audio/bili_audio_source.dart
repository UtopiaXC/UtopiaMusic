import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/connection/video/search.dart';

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
  HttpClientResponse? _currentResponse;
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
    _isDisposed = false;
    final startOffset = start ?? 0;

    try {
      if (_realCid == 0) {
        try {
          print("BiliAudioSource: CID is 0, fetching...");
          _realCid = await _searchApi.fetchCid(bvid);
          print("BiliAudioSource: Resolved CID: $_realCid");
        } catch (e) {
          print("BiliAudioSource: Failed to resolve CID: $e");
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
        int? contentLength;
        if (end != null) {
          contentLength = end - startOffset;
        } else {
          contentLength = fileLen - startOffset;
        }
        return StreamAudioResponse(
          sourceLength: fileLen,
          contentLength: contentLength,
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
      _currentResponse = response;
      int contentLength = response.contentLength;
      int? totalLength;
      if (response.statusCode == 206) {
        final rangeHeader = response.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        if (rangeHeader != null) {
          final parts = rangeHeader.split('/');
          if (parts.length == 2 && parts[1] != '*') {
            totalLength = int.tryParse(parts[1]);
          }
        }
      } else {
        totalLength = contentLength;
      }
      if (totalLength == null) totalLength = contentLength + startOffset;

      Stream<List<int>> stream = response;
      if (enableCache) {
        bool isCachePromoting = false;
        final tempPath = _downloadManager.getTempCachePath(bvid, targetCid);
        final tempFile = File(tempPath);
        if (!await tempFile.parent.exists()) {
          await tempFile.parent.create(recursive: true);
        }

        final IOSink fileSink = tempFile.openWrite();

        final controller = StreamController<List<int>>(
          onCancel: () async {
            if (isCachePromoting) return;
            await fileSink.close();
            await _cleanupTempFile(tempFile);
            _currentSubscription?.cancel();
          },
        );

        _currentSubscription = stream.listen(
          (data) {
            if (!_isDisposed) {
              fileSink.add(data);
              controller.add(data);
            }
          },
          onDone: () async {
            isCachePromoting = true;
            try {
              await fileSink.flush();
              await fileSink.close();
              await controller.close();
              await _promoteTempFile(tempFile, targetCid, totalLength ?? 0);
            } catch (e) {
              print("Cache promotion failed: $e");
              await _cleanupTempFile(tempFile);
            } finally {
              isCachePromoting = false;
            }
          },
          onError: (e) async {
            isCachePromoting = false;
            await fileSink.close();
            controller.addError(e);
            await _cleanupTempFile(tempFile);
          },
          cancelOnError: true,
        );

        return StreamAudioResponse(
          sourceLength: totalLength,
          contentLength: contentLength,
          offset: startOffset,
          stream: controller.stream,
          contentType: 'audio/mp4',
        );
      } else {
        return StreamAudioResponse(
          sourceLength: totalLength,
          contentLength: contentLength,
          offset: startOffset,
          stream: stream,
          contentType: 'audio/mp4',
        );
      }
    } catch (e) {
      print("BiliAudioSource Request Failed: $e");
      if (e.toString().contains("Fatal Resource")) {
        onFatalError?.call(bvid, _realCid, e.toString());
      }
      throw e;
    }
  }

  Future<void> _promoteTempFile(File tempFile, int cid, int totalSize) async {
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

      if (await staticFile.exists()) {
        await staticFile.delete();
      }

      print("Promoting cache: ${tempFile.path} -> $staticPath");
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
      print("Cache Promoted Successfully!");
    } catch (e) {
      print("Failed to promote cache: $e");
      await _cleanupTempFile(tempFile);
    }
  }

  Future<void> _cleanupTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
