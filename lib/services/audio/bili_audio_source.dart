import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/services/download_manager.dart';

class BiliAudioSource extends StreamAudioSource {
  final String bvid;
  final int initCid;
  final String title;
  final String artist;
  final String coverUrl;
  final int quality;

  AudioStreamInfo? _cachedStreamInfo;
  String _mimeType = 'audio/mp4';
  File? _tempCacheFile;
  StreamSubscription<List<int>>? _downloadSubscription;
  IOSink? _fileSink;
  bool _isDownloading = false;
  bool _isDisposed = false;
  bool _isCommittedToManager = false;

  final StreamController<void> _dataWriteController = StreamController.broadcast();

  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();

  static const String _bufferDirName = 'utopia_stream_buffer';

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

  static Future<void> clearBufferCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/$_bufferDirName');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print("🧹 Cleaned up orphaned stream buffers.");
      }
    } catch (e) {
      print("Failed to clean buffer cache: $e");
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    int startOffset = start ?? 0;

    try {
      if (_isDisposed) throw Exception("Source disposed");

      if (_cachedStreamInfo == null) {
        await _resolveStreamInfo();
      }
      if (_cachedStreamInfo == null) {
        throw Exception("Failed to resolve audio stream info");
      }

      final playable = await DownloadManager().getPlayableFile(bvid, initCid, quality);
      if (playable != null && await playable.file.exists()) {
        print("BiliAudioSource: Hit local file for $bvid ($_mimeType)");
        return _streamFromFile(playable.file, startOffset, end);
      }


      if (_isCommittedToManager) {
        _isCommittedToManager = false;
        _isDownloading = false;
      }

      if (!_isDownloading) {
        if (_tempCacheFile == null || !(await _tempCacheFile!.exists())) {
          await _startDynamicCaching();
        }
      }

      await _waitForFirstByte();

      if (_tempCacheFile == null || !await _tempCacheFile!.exists()) {
        if (_isDisposed) throw Exception("Disposed during wait");
        throw Exception("Temp file missing after wait");
      }

      return _streamFromTempFile(startOffset, end);

    } catch (e) {
      print("Audio request failed: $e");
      throw Exception("Audio request failed: $e");
    }
  }

  Future<void> _startDynamicCaching() async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      final bufferDir = await _getBufferDir();
      _tempCacheFile = File('${bufferDir.path}/${bvid}_${initCid}_$_sessionId.tmp');

      if (await _tempCacheFile!.exists()) {
        await _tempCacheFile!.delete();
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_cachedStreamInfo!.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);

      final response = await request.close();

      _fileSink = _tempCacheFile!.openWrite(mode: FileMode.append);

      _downloadSubscription = response.listen(
            (chunk) {
          if (_isDisposed) return;
          _fileSink?.add(chunk);
          _dataWriteController.add(null);
        },
        onDone: () async {
          await _onDownloadComplete();
        },
        onError: (e) {
          print("Dynamic caching error: $e");
          _cleanupTempResources();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("Start dynamic caching failed: $e");
      _cleanupTempResources();
    }
  }

  Future<Directory> _getBufferDir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$_bufferDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _onDownloadComplete() async {
    _isDownloading = false;
    try {
      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;
    } catch (_) {}

    _dataWriteController.add(null);

    if (_isDisposed) {
      _deleteTempFile();
      return;
    }

    await _commitToManager();
  }

  Future<void> _commitToManager() async {
    try {
      if (_tempCacheFile == null || !(await _tempCacheFile!.exists())) return;
      if (await _tempCacheFile!.length() < 1024) {
        _deleteTempFile();
        return;
      }

      print("Committing cache to DownloadManager...");
      final committed = await DownloadManager().commitCacheFile(
          _tempCacheFile!,
          bvid,
          initCid,
          quality
      );

      if (committed != null) {
        print("Cache committed successfully");
        _isCommittedToManager = true;
        _tempCacheFile = null;
      } else {
        _deleteTempFile();
      }
    } catch (e) {
      print("Commit failed: $e");
      _deleteTempFile();
    }
  }

  StreamAudioResponse _streamFromTempFile(int start, int? end) {
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: start,
      stream: _createTailingStream(start, end),
      contentType: _mimeType,
    );
  }

  Stream<List<int>> _createTailingStream(int start, int? end) async* {
    int currentOffset = start;
    if (_tempCacheFile == null) { yield []; return; }

    RandomAccessFile? raf;
    try {
      if (await _tempCacheFile!.exists()) {
        raf = await _tempCacheFile!.open();
      } else {
        yield [];
        return;
      }

      while (!_isDisposed) {
        int fileLen = 0;
        try {
          fileLen = await raf.length();
        } catch (e) {
          break;
        }

        if (currentOffset < fileLen) {
          int readLen = fileLen - currentOffset;
          if (readLen > 64 * 1024) readLen = 64 * 1024;

          try {
            await raf.setPosition(currentOffset);
            final chunk = await raf.read(readLen);
            if (chunk.isNotEmpty) {
              yield chunk;
              currentOffset += chunk.length;
            }
          } catch (e) {
            break;
          }
        }
        else if (_isDownloading) {
          await Future.any([
            _dataWriteController.stream.first,
            Future.delayed(const Duration(milliseconds: 200))
          ]);
        }
        else {
          break;
        }

        if (end != null && currentOffset >= end) break;
      }
    } catch (e) {
      print("Tailing stream error: $e");
    } finally {
      try { await raf?.close(); } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _dataWriteController.close();
    await _downloadSubscription?.cancel();
    _isDownloading = false;
    try { await _fileSink?.close(); } catch (_) {}

    if (!_isCommittedToManager) {
      _deleteTempFile();
    }
  }

  void _cleanupTempResources() {
    _isDownloading = false;
    _downloadSubscription?.cancel();
    try { _fileSink?.close(); } catch (_) {}
    _deleteTempFile();
  }

  Future<void> _deleteTempFile() async {
    try {
      if (_tempCacheFile != null && await _tempCacheFile!.exists()) {
        await _tempCacheFile!.delete();
      }
    } catch (_) {}
  }

  Future<void> _waitForFirstByte() async {
    int retries = 0;
    while (retries < 50) {
      if (_tempCacheFile != null && await _tempCacheFile!.exists()) {
        try {
          final len = await _tempCacheFile!.length();
          if (len > 0) return;
        } catch (_) {}
      }
      if (!_isDownloading && (_tempCacheFile == null || !(await _tempCacheFile!.exists()))) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
  }

  Future<StreamAudioResponse> _streamFromFile(File file, int start, int? end) async {
    final fileLen = await file.length();
    int endOffset = end ?? fileLen;
    int contentLength = endOffset - start;
    if (contentLength < 0) contentLength = 0;

    return StreamAudioResponse(
      sourceLength: fileLen,
      contentLength: contentLength,
      offset: start,
      stream: file.openRead(start, end),
      contentType: _mimeType,
    );
  }

  Future<void> _resolveStreamInfo() async {
    int cid = initCid;
    if (cid == 0) {
      cid = await SearchApi().fetchCid(bvid);
    }
    _cachedStreamInfo = await AudioStreamApi().getAudioStream(
        bvid, cid, preferredQuality: quality
    );

    if (_cachedStreamInfo != null) {
      final url = _cachedStreamInfo!.url.toLowerCase();
      final path = url.split('?').first;

      if (path.endsWith('.flac')) {
        _mimeType = 'audio/flac';
      } else {
        _mimeType = 'audio/mp4';
      }
    }
  }
}