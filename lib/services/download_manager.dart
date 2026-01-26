import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/utils/quality_utils.dart';

enum CacheStatus {
  localStored(0),
  staticCached(1),
  buffering(2),
  paused(3),
  promoting(4);

  final int code;
  const CacheStatus(this.code);
}

class ResourceResponse {
  final File? file;
  final String? directUrl;
  final String mimeType;
  final bool isComplete;
  final String sessionId;
  final int? totalSize;

  ResourceResponse({
    this.file,
    this.directUrl,
    required this.mimeType,
    required this.isComplete,
    required this.sessionId,
    this.totalSize,
  });
}

          class DownloadUpdate {
  final String id;
  final double progress;
  final int status;

  DownloadUpdate(this.id, this.progress, this.status);
}

class _DownloadTask {
  final Song song;
  final String savePath;
  final int quality;

  _DownloadTask({
    required this.song,
    required this.savePath,
    required this.quality,
  });
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  final DatabaseService _dbService = DatabaseService();
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();

  factory DownloadManager() => _instance;

  DownloadManager._internal();

  String? _cacheDir;
  String? _bufferDir;
  String? _downloadDir;

  static const String _maxCacheSizeKey = 'max_cache_size_mb';
  static const String _concurrentDownloadsKey = 'max_concurrent_downloads';
  static const String _defaultDownloadQualityKey = 'default_download_quality';

  int _maxCacheSize = 500 * 1024 * 1024;
  int _maxConcurrentDownloads = 3;

  final List<_DownloadTask> _queue = [];
  int _activeDownloads = 0;
  final Map<String, bool> _activeTaskIds = {};
  final StreamController<DownloadUpdate> _progressController = StreamController.broadcast();
  Stream<DownloadUpdate> get downloadUpdateStream => _progressController.stream;

  final Map<String, StreamController<void>> _bufferNotifiers = {};
  final Map<String, String> _activeSessions = {};
  final Map<String, int?> _bufferTotalSizeHints = {};

  Future<void> init() async {
    await _initDirs();
    final prefs = await SharedPreferences.getInstance();
    int mb = prefs.getInt(_maxCacheSizeKey) ?? 500;
    _maxCacheSize = mb * 1024 * 1024;
    _maxConcurrentDownloads = prefs.getInt(_concurrentDownloadsKey) ?? 3;

    await _performSmartCleanup();
    await _cleanOrphanedBuffers();
    await _resumePendingDownloads();
  }

  Future<void> _initDirs() async {
    if (_cacheDir != null && _downloadDir != null) return;

    final tempDir = await getTemporaryDirectory();
    final cacheRoot = Directory('${tempDir.path}/MusicCache');
    final staticDir = Directory('${cacheRoot.path}/Static');
    final bufferDir = Directory('${cacheRoot.path}/Buffer');

    if (!await staticDir.exists()) await staticDir.create(recursive: true);
    if (!await bufferDir.exists()) await bufferDir.create(recursive: true);

    _cacheDir = staticDir.path;
    _bufferDir = bufferDir.path;

    final docDir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${docDir.path}/MusicDownload');
    if (!await dlDir.exists()) await dlDir.create(recursive: true);
    _downloadDir = dlDir.path;
  }

  Future<ResourceResponse> requestResource(String bvid, int initCid, int quality, String sessionId) async {
    await _initDirs();


    int cid = initCid;
    if (cid == 0) {
      cid = await _searchApi.fetchCid(bvid);
    }

    final downloadRecord = await _dbService.getCompletedDownload(bvid, cid);
    if (downloadRecord != null) {
      final path = downloadRecord['save_path'] as String;
      final file = File(path);
      if (await file.exists()) {
        _dbService.updateDownloadStatus(bvid, cid, 4);
        return ResourceResponse(
          file: file,
          mimeType: 'audio/mp4',
          isComplete: true,
          sessionId: 'local',
          totalSize: await file.length(),
        );
      }
    }

    final cacheMeta = await _dbService.getCacheMeta(bvid, cid, quality);
    if (cacheMeta != null && cacheMeta['status'] == CacheStatus.staticCached.code) {
      final fileName = _getStaticCacheFileName(bvid, cid, quality);
      final file = File('$_cacheDir/$fileName');
      if (await file.exists()) {
        await _dbService.recordCacheAccess(bvid, cid, quality, status: CacheStatus.staticCached.code);
        return ResourceResponse(
          file: file,
          mimeType: 'audio/mp4',
          isComplete: true,
          sessionId: 'static',
          totalSize: await file.length(),
        );
      }
    }

    if (Platform.isWindows) {
      final streamInfo = await _audioStreamApi.getAudioStream(bvid, cid, preferredQuality: quality);
      if (streamInfo == null) throw Exception("Failed to resolve stream");

      String mimeType = streamInfo.url.contains('.flac') ? 'audio/flac' : 'audio/mp4';

      return ResourceResponse(
        file: null,
        directUrl: streamInfo.url,
        mimeType: mimeType,
        isComplete: false,
        sessionId: sessionId,
        totalSize: null,
      );
    }

    return await _startBufferingTask(bvid, cid, quality, sessionId);
  }

  Future<ResourceResponse> _startBufferingTask(String bvid, int cid, int quality, String sessionId) async {
    final fileName = '${bvid}_${cid}_${quality}_$sessionId.tmp';
    final file = File('$_bufferDir/$fileName');

    _activeSessions[sessionId] = file.path;
    _bufferNotifiers[sessionId] = StreamController<void>.broadcast();

    final Completer<String> readyCompleter = Completer();
    _runBufferDownload(bvid, cid, quality, sessionId, file, readyCompleter);

    try {
      final mimeType = await readyCompleter.future;
      final fileLen = await file.exists() ? await file.length() : 0;

      return ResourceResponse(
        file: file,
        mimeType: mimeType,
        isComplete: false,
        sessionId: sessionId,
        totalSize: _bufferTotalSizeHints[sessionId] ?? fileLen,
      );
    } catch (e) {
      cancelSession(sessionId);
      throw e;
    }
  }

  Future<void> _runBufferDownload(
      String bvid,
      int cid,
      int quality,
      String sessionId,
      File file,
      Completer<String> readyCompleter
      ) async {
    IOSink? sink;
    try {
      final streamInfo = await _audioStreamApi.getAudioStream(bvid, cid, preferredQuality: quality);
      if (streamInfo == null) {
        readyCompleter.completeError(Exception("Stream info null"));
        return;
      }
      String mimeType = streamInfo.url.contains('.flac') ? 'audio/flac' : 'audio/mp4';

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamInfo.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);

      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 206) {
        readyCompleter.completeError(Exception("HTTP Error ${response.statusCode}"));
        return;
      }

      final totalSize = response.contentLength > 0 ? response.contentLength : null;
      _bufferTotalSizeHints[sessionId] = totalSize;

      await _dbService.recordCacheAccess(
          bvid, cid, quality,
          status: CacheStatus.buffering.code,
          totalSize: (totalSize ?? 0),
          sessionId: sessionId
      );

      sink = file.openWrite();
      if (!readyCompleter.isCompleted) {
        readyCompleter.complete(mimeType);
      }

      int downloaded = 0;
      int lastFlushBytes = 0;

      await for (var chunk in response) {
        if (!_activeSessions.containsKey(sessionId)) {
          await sink.flush();
          await sink.close();
          client.close();
          return;
        }

        sink.add(chunk);
        downloaded += chunk.length;
        if (downloaded - lastFlushBytes > 32 * 1024) {
          await sink.flush();
          lastFlushBytes = downloaded;
        }

        _bufferNotifiers[sessionId]?.add(null);

        if (downloaded % (100 * 1024) == 0) {
          await _dbService.recordCacheAccess(bvid, cid, quality, fileSize: downloaded, sessionId: sessionId);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      await _promoteToStatic(file, bvid, cid, quality, sessionId, (totalSize ?? downloaded));
      _endSession(sessionId);

    } catch (e) {
      print("Buffer failed: $e");
      if (!readyCompleter.isCompleted) {
        readyCompleter.completeError(e);
      }
      try { await sink?.close(); } catch (_) {}

      if (_activeSessions.containsKey(sessionId)) {
        _endSession(sessionId);
      }
    }
  }

  Future<void> _promoteToStatic(File bufferFile, String bvid, int cid, int quality, String sessionId, int totalSize) async {
    try {
      await _dbService.recordCacheAccess(bvid, cid, quality, status: CacheStatus.promoting.code, sessionId: sessionId);
      final staticName = _getStaticCacheFileName(bvid, cid, quality);
      final staticFile = File('$_cacheDir/$staticName');
      if (await staticFile.exists()) await staticFile.delete();
      await bufferFile.copy(staticFile.path);
      await _dbService.recordCacheAccess(bvid, cid, quality, status: CacheStatus.staticCached.code, fileSize: totalSize, totalSize: totalSize, sessionId: null);
      _performSmartCleanup();
    } catch (e) { print("Promotion failed: $e"); }
  }

  void _endSession(String sessionId) {
    if (_activeSessions.containsKey(sessionId)) {
      _activeSessions.remove(sessionId);
    }
    _bufferNotifiers[sessionId]?.close();
    _bufferNotifiers.remove(sessionId);
    _bufferTotalSizeHints.remove(sessionId);
  }

  void cancelSession(String sessionId) {
    if (_activeSessions.containsKey(sessionId)) {
      final path = _activeSessions.remove(sessionId);
      _bufferNotifiers[sessionId]?.close();
      _bufferNotifiers.remove(sessionId);
    }
  }

  Stream<void>? getBufferNotifier(String sessionId) => _bufferNotifiers[sessionId]?.stream;
  bool isSessionActive(String sessionId) => _activeSessions.containsKey(sessionId);
  String _getStaticCacheFileName(String bvid, int cid, int quality) => 'song_${bvid}_${cid}_$quality.audio';

  Future<int> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxCacheSizeKey) ?? 500;
  }

  Future<void> setMaxCacheSize(int mb) async {
    _maxCacheSize = mb * 1024 * 1024;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxCacheSizeKey, mb);
    _performSmartCleanup();
  }

  Future<int> getUsedCacheSize() async {
    if (_cacheDir == null) await _initDirs();
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) return 0;
    int size = 0;
    try {
      await for (var file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) size += await file.length();
      }
    } catch (_) {}
    return size;
  }

  Future<void> clearAllCache() async {
    if (_cacheDir == null) await _initDirs();
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      try {
        await for (var file in dir.list()) {
          if (file is File) { try { await file.delete(); } catch (_) {} }
        }
      } catch (e) { print("Clear static cache error: $e"); }
    }
    await _dbService.clearStaticCacheMeta();
    await _cleanOrphanedBuffers();
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    if (count < 0) count = 0;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrentDownloadsKey, count);
    if (count == 0) {
      final activeIds = List<String>.from(_activeTaskIds.keys);
      for (var id in activeIds) {
        final parts = id.split('_');
        if (parts.length >= 2) {
          final bvid = parts[0];
          final cid = int.tryParse(parts[1]) ?? 0;
          _activeTaskIds.remove(id);
          await _dbService.updateDownloadStatus(bvid, cid, 0);
          _progressController.add(DownloadUpdate(id, 0.0, 0));
        }
      }
      _activeDownloads = 0;
    } else {
      _processQueue();
    }
  }

  Future<int> getMaxConcurrentDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_concurrentDownloadsKey) ?? 3;
  }

  Future<int> getUsedDownloadSize() async {
    if (_downloadDir == null) await _initDirs();
    final dir = Directory(_downloadDir!);
    if (!await dir.exists()) return 0;
    int size = 0;
    try {
      await for (var file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) size += await file.length();
      }
    } catch (_) {}
    return size;
  }

  Future<void> deleteAllDownloads() async {
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      final bvid = d['bvid'] as String;
      final cid = d['cid'] as int;
      await deleteDownload(bvid, cid);
    }
  }

  Future<void> _performSmartCleanup() async {
    if (_cacheDir == null) return;
    try {
      final metas = await _dbService.getCompletedCacheMeta();
      if (metas.isEmpty) return;
      int totalSize = 0;
      for (var m in metas) { totalSize += (m['file_size'] as int? ?? 0); }
      if (totalSize <= _maxCacheSize) return;
      List<Map<String, dynamic>> sortedMetas = List.from(metas);
      final now = DateTime.now().millisecondsSinceEpoch;
      sortedMetas.sort((a, b) {
        double scoreA = _calculateScore(a, now);
        double scoreB = _calculateScore(b, now);
        return scoreA.compareTo(scoreB);
      });
      int targetSize = (_maxCacheSize * 0.8).toInt();
      for (var meta in sortedMetas) {
        if (totalSize <= targetSize) break;
        final key = meta['key'];
        final bvid = meta['bvid'];
        final cid = meta['cid'];
        final quality = meta['quality'];
        final fileName = _getStaticCacheFileName(bvid, cid, quality);
        final file = File('$_cacheDir/$fileName');
        try {
          if (await file.exists()) await file.delete();
          await _dbService.removeCacheMeta(key as String);
          totalSize -= (meta['file_size'] as int? ?? 0);
        } catch (e) {}
      }
    } catch (e) {}
  }

  double _calculateScore(Map<String, dynamic> meta, int now) {
    int hits = meta['hit_count'] ?? 0;
    int lastAccess = meta['last_access_time'] ?? 0;
    double hoursDiff = (now - lastAccess) / (1000 * 3600);
    if (hoursDiff < 0.1) hoursDiff = 0.1;
    return (hits * 100.0) + (1000 / hoursDiff);
  }

  Future<void> _cleanOrphanedBuffers() async {
    if (_bufferDir == null) return;
    try {
      final dir = Directory(_bufferDir!);
      if (!await dir.exists()) return;
      await _dbService.clearBufferingCacheMeta();
      await for (var file in dir.list()) {
        if (file is File) {
          bool isActive = false;
          for (var path in _activeSessions.values) {
            if (path == file.path) { isActive = true; break; }
          }
          if (!isActive) { try { await file.delete(); } catch (_) {} }
        }
      }
    } catch (_) {}
  }

  Future<void> startDownload(Song song, {int? quality}) async {
    await _initDirs();
    int cid = song.cid;
    if (cid == 0) cid = await _searchApi.fetchCid(song.bvid);
    final songWithCid = song.copyWith(cid: cid);
    if (await isDownloaded(songWithCid.bvid, songWithCid.cid)) return;
    final id = '${songWithCid.bvid}_${songWithCid.cid}';
    if (_queue.any((task) => '${task.song.bvid}_${task.song.cid}' == id)) return;
    if (_activeTaskIds.containsKey(id)) return;
    int targetQuality = quality ?? await _resolveBestQuality(songWithCid);
    final fileName = '${songWithCid.bvid}_${songWithCid.cid}_$targetQuality.audio';
    final savePath = '$_downloadDir/$fileName';
    await _dbService.insertDownload(songWithCid, savePath, targetQuality);
    _progressController.add(DownloadUpdate(id, 0.0, 0));
    _queue.add(_DownloadTask(song: songWithCid, savePath: savePath, quality: targetQuality));
    _processQueue();
  }

  Future<int> _resolveBestQuality(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    int targetQuality = prefs.getInt(_defaultDownloadQualityKey) ?? 30280;
    try {
      final available = await _audioStreamApi.fetchAvailableQualities(song.bvid, song.cid);
      if (available.isNotEmpty) {
        available.sort((a, b) => QualityUtils.getScore(b).compareTo(QualityUtils.getScore(a)));
        int preferredScore = QualityUtils.getScore(targetQuality);
        int? bestMatch;
        for (var q in available) {
          if (QualityUtils.getScore(q) <= preferredScore) { bestMatch = q; break; }
        }
        targetQuality = bestMatch ?? available.last;
      }
    } catch (_) {}
    return targetQuality;
  }

  void _processQueue() {
    if (_maxConcurrentDownloads == 0) return;
    while (_activeDownloads < _maxConcurrentDownloads && _queue.isNotEmpty) {
      _activeDownloads++;
      final task = _queue.removeAt(0);
      final id = '${task.song.bvid}_${task.song.cid}';
      _activeTaskIds[id] = true;
      _executeDownload(task).whenComplete(() {
        _activeDownloads--;
        _activeTaskIds.remove(id);
        _processQueue();
      });
    }
  }

  Future<void> _executeDownload(_DownloadTask task) async {
    final id = '${task.song.bvid}_${task.song.cid}';
    try {
      if (!_activeTaskIds.containsKey(id)) return;
      final file = File(task.savePath);
      int downloadedBytes = await file.exists() ? await file.length() : 0;
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 1);
      _progressController.add(DownloadUpdate(id, 0.0, 1));

      final info = await _audioStreamApi.getAudioStream(task.song.bvid, task.song.cid, preferredQuality: task.quality);
      if (info == null) throw Exception("Stream info null");

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(info.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);
      if (downloadedBytes > 0) request.headers.set('Range', 'bytes=$downloadedBytes-');

      final response = await request.close();
      if (response.statusCode != HttpStatus.partialContent && response.statusCode != HttpStatus.ok) {
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
          await file.delete();
          throw Exception("Range error");
        }
        throw Exception("HTTP ${response.statusCode}");
      }
      final totalBytes = response.contentLength + downloadedBytes;
      final sink = file.openWrite(mode: FileMode.append);
      int receivedBytes = downloadedBytes;
      int lastUpdate = 0;
      await for (var chunk in response) {
        if (!_activeTaskIds.containsKey(id)) {
          await sink.flush(); await sink.close(); client.close(); return;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final percent = ((receivedBytes / totalBytes) * 100).toInt();
          if (percent > lastUpdate) {
            lastUpdate = percent;
            _progressController.add(DownloadUpdate(id, receivedBytes / totalBytes, 1));
          }
        }
      }
      await sink.flush(); await sink.close(); client.close();
      if (!_activeTaskIds.containsKey(id)) return;
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 3, progress: 1.0);
      _progressController.add(DownloadUpdate(id, 1.0, 3));
    } catch (e) {
      if (_activeTaskIds.containsKey(id)) {
        await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 4);
        _progressController.add(DownloadUpdate(id, 0.0, 4));
      }
    }
  }

  Future<void> pauseDownload(String bvid, int cid) async {
    final id = '${bvid}_${cid}';
    if (_activeTaskIds.containsKey(id)) {
      _activeTaskIds.remove(id);
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate(id, 0.0, 0));
      _activeDownloads--;
      _processQueue();
    }
  }

  Future<void> retryDownload(String bvid, int cid) async {
    final record = await _dbService.getDownload(bvid, cid);
    if (record != null) {
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate('${bvid}_${cid}', 0.0, 0));
      startDownload(Song(title: record['title'], artist: record['artist'], coverUrl: record['cover_url'], lyrics: '', colorValue: 0, bvid: bvid, cid: cid), quality: record['quality']);
    }
  }

  Future<void> deleteDownload(String bvid, int cid) async {
    await pauseDownload(bvid, cid);
    await _dbService.deleteDownload(bvid, cid);
    _queue.removeWhere((t) => t.song.bvid == bvid && t.song.cid == cid);
    if (_downloadDir == null) await _initDirs();
    final dir = Directory(_downloadDir!);
    if (await dir.exists()) {
      await for (var file in dir.list()) {
        if (file.path.contains('${bvid}_${cid}')) { try { await file.delete(); } catch (_) {} }
      }
    }
  }

  Future<void> _resumePendingDownloads() async {
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      if (d['status'] == 0 || d['status'] == 1) {
        startDownload(Song(title: d['title'], artist: d['artist'], coverUrl: d['cover_url'], lyrics: '', colorValue: 0, bvid: d['bvid'], cid: d['cid']), quality: d['quality']);
      }
    }
  }

  Future<bool> isDownloaded(String bvid, int cid) async {
    return await _dbService.isDownloaded(bvid, cid);
  }
}
