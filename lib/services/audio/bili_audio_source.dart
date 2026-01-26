import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/services/download_manager.dart';

class BiliAudioSource extends StreamAudioSource {
  final String bvid;
  final int initCid;
  final String title;
  final String artist;
  final String coverUrl;
  final int quality;

  String? _currentSessionId;

  final DownloadManager _downloadManager = DownloadManager();

  bool _isDisposed = false;
  File? _readingFile;

  BiliAudioSource({
    required this.bvid,
    required this.initCid,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.quality,
  }) : super(
    tag: MediaItem(
      id: '${bvid}_$initCid',
      title: title,
      artist: artist,
      artUri: Uri.tryParse(coverUrl),
    ),
  );

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      _isDisposed = false;
      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
      _currentSessionId = newSessionId;

      final response = await _downloadManager.requestResource(bvid, initCid, quality, newSessionId);
      final int? expectedLength = response.totalSize;

      if (response.directUrl != null) {
        return await _streamFromNetwork(response.directUrl!, start, end, expectedLength: expectedLength);
      }

      if (response.file != null) {
        _readingFile = response.file;

        if (!await _readingFile!.exists()) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        final fileLen = await _readingFile!.length();
        final int? sourceLength = response.isComplete
            ? fileLen
            : (expectedLength ?? fileLen);

        int startOffset = start ?? 0;
        if (response.isComplete && startOffset > fileLen) {
          startOffset = fileLen;
        }

        int? contentLength;
        if (end != null) {
          contentLength = end - startOffset;
        } else if (response.isComplete) {
          contentLength = fileLen - startOffset;
        } else if (sourceLength != null) {
          contentLength = sourceLength - startOffset;
        }
        if (contentLength != null && contentLength < 0) contentLength = 0;

        if (response.isComplete && startOffset >= fileLen) {
          return StreamAudioResponse(
            sourceLength: sourceLength ?? fileLen,
            contentLength: 0,
            offset: startOffset,
            stream: Stream.value(List<int>.empty()),
            contentType: response.mimeType,
          );
        }

        if (response.isComplete) {
          return StreamAudioResponse(
            sourceLength: sourceLength ?? fileLen,
            contentLength: contentLength,
            offset: startOffset,
            stream: _readingFile!.openRead(startOffset, end),
            contentType: response.mimeType,
          );
        } else {
          return StreamAudioResponse(
            sourceLength: sourceLength ?? startOffset,
            contentLength: contentLength,
            offset: startOffset,
            stream: _createTailingStream(startOffset, end, newSessionId, sourceLength),
            contentType: response.mimeType,
          );
        }
      }

      throw Exception("No file or url provided");

    } catch (e) {
      print("Audio Request Failed: $e");
      throw Exception("Audio Request Failed: $e");
    }
  }

  Future<StreamAudioResponse> _streamFromNetwork(String url, int? start, int? end, {int? expectedLength}) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);

      int startOffset = start ?? 0;
      if (startOffset > 0 || end != null) {
        String rangeHeader = 'bytes=$startOffset-';
        if (end != null) rangeHeader += '${end - 1}';
        request.headers.set('Range', rangeHeader);
      }

      final response = await request.close();

      int? totalLength = response.contentLength > 0 ? response.contentLength : expectedLength;
      int? contentLength;
      if (end != null) {
        contentLength = end - startOffset;
      } else {
        contentLength = totalLength;
      }
      if (contentLength != null && contentLength < 0) contentLength = 0;

      final int safeSourceLength = (totalLength ?? end ?? startOffset);

      return StreamAudioResponse(
        sourceLength: safeSourceLength,
        contentLength: contentLength,
        offset: startOffset,
        stream: response,
        contentType: response.headers.contentType?.mimeType ?? 'audio/mp4',
      );
    } catch (e) {
      print("Network Stream Failed: $e");
      throw Exception("Network Stream Failed: $e");
    }
  }

  Stream<List<int>> _createTailingStream(int start, int? end, String sessionId, int? totalSize) async* {
    if (_readingFile == null) return;

    RandomAccessFile? raf;
    try {
      raf = await _readingFile!.open();
      int currentOffset = start;
      Stream<void>? notifier = _downloadManager.getBufferNotifier(sessionId);

      while (!_isDisposed && _currentSessionId == sessionId) {
        int fileLen = await raf.length();

        final bool sessionActive = _downloadManager.isSessionActive(sessionId);
        final bool reachedExpectedEnd = totalSize != null && currentOffset >= totalSize;
        if (currentOffset >= fileLen) {
          if (!sessionActive || reachedExpectedEnd) {
            int finalLen = await raf.length();
            if (currentOffset >= finalLen && (totalSize == null || currentOffset >= (totalSize))) {
              break;
            }
          }
          if (notifier != null) {
            await Future.any([
              notifier.first,
              Future.delayed(const Duration(milliseconds: 200))
            ]);
          } else {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          continue;
        }

        int readLen = fileLen - currentOffset;
        if (readLen > 64 * 1024) readLen = 64 * 1024;
        if (end != null && currentOffset + readLen > end) {
          readLen = end - currentOffset;
        }

        if (readLen > 0) {
          await raf.setPosition(currentOffset);
          final chunk = await raf.read(readLen);

          if (chunk.isNotEmpty) {
            yield chunk;
            currentOffset += chunk.length;
          }
        }

        if ((end != null && currentOffset >= end) || (totalSize != null && currentOffset >= totalSize)) break;
      }
    } catch (e) {
      print("Stream error: $e");
    } finally {
      try { await raf?.close(); } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    if (_currentSessionId != null) {
      _downloadManager.cancelSession(_currentSessionId!);
      _currentSessionId = null;
    }
  }
}
