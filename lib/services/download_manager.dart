import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "DOWNLOAD_MANAGER";

enum CacheStatus {
  localStored(0),
  staticCached(1),
  promoting(4);

  final int code;

  const CacheStatus(this.code);
}

class ResourceException implements Exception {
  final String message;

  ResourceException(this.message);

  @override
  String toString() => "ResourceException: $message";
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  NetworkException(this.message, {this.statusCode});

  @override
  String toString() => "NetworkException: $message (Code: $statusCode)";
}

class ResourceResponse {
  final File? file;
  final String? directUrl;

  ResourceResponse({this.file, this.directUrl});
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
  String? _downloadDir;

  static const String _maxCacheSizeKey = 'max_cache_size_mb';
  static const String _concurrentDownloadsKey = 'max_concurrent_downloads';
  static const String _defaultDownloadQualityKey = 'default_download_quality';

  int _maxCacheSize = 500 * 1024 * 1024;
  int _maxConcurrentDownloads = 3;
  bool get isCacheEnabled => _maxCacheSize > 0;

  final List<_DownloadTask> _queue = [];
  int _activeDownloads = 0;
  final Map<String, bool> _activeTaskIds = {};
  final StreamController<DownloadUpdate> _progressController =
      StreamController.broadcast();

  Stream<DownloadUpdate> get downloadUpdateStream => _progressController.stream;

  Future<void> init() async {
    Log.v(_tag, "init");
    await _initDirs();
    final prefs = await SharedPreferences.getInstance();
    int mb = prefs.getInt(_maxCacheSizeKey) ?? 200;
    _maxCacheSize = mb * 1024 * 1024;
    _maxConcurrentDownloads = prefs.getInt(_concurrentDownloadsKey) ?? 3;

    await _performSmartCleanup();
    await _cleanTempFiles();
    await _resumePendingDownloads();
  }

  Future<void> _initDirs() async {
    Log.v(_tag, "_initDirs");
    if (_cacheDir != null && _downloadDir != null) return;

    final tempDir = await getTemporaryDirectory();
    final cacheRoot = Directory('${tempDir.path}/MusicCache');
    final staticDir = Directory('${cacheRoot.path}/Static');
    if (!await staticDir.exists()) await staticDir.create(recursive: true);

    _cacheDir = staticDir.path;

    final docDir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${docDir.path}/MusicDownload');
    if (!await dlDir.exists()) await dlDir.create(recursive: true);
    _downloadDir = dlDir.path;
  }

  Future<ResourceResponse?> checkLocalResource(
    String bvid,
    int initCid,
    int quality,
  ) async {
    Log.v(
      _tag,
      "checkLocalResource, bvid: $bvid, cid: $initCid, quality: $quality",
    );
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
        return ResourceResponse(file: file);
      }
    }

    final cacheMeta = await _dbService.getCacheMeta(bvid, cid, quality);
    if (cacheMeta != null &&
        cacheMeta['status'] == CacheStatus.staticCached.code) {
      final fileName = _getStaticCacheFileName(bvid, cid, quality);
      final file = File('$_cacheDir/$fileName');
      if (await file.exists()) {
        await _dbService.recordCacheAccess(
          bvid,
          cid,
          quality,
          status: CacheStatus.staticCached.code,
        );
        return ResourceResponse(file: file);
      }
    }

    return null;
  }

  Future<HttpClientResponse> getNetworkStream(
    String bvid,
    int initCid,
    int quality, {
    int start = 0,
  }) async {
    Log.v(
      _tag,
      "getNetworkStream, bvid: $bvid, cid: $initCid, quality: $quality",
    );
    int cid = initCid;
    if (cid == 0) {
      try {
        cid = await _searchApi.fetchCid(bvid);
        Log.i(_tag, "Resolved CID: $cid");
      } catch (e) {
        Log.w(_tag, "Fetch cid failed, source may be invalid");
      }
    }

    if (cid == 0) {
      throw ResourceException("Fetch CID failed");
    }

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final streamInfo = await _audioStreamApi.getAudioStream(
          bvid,
          cid,
          preferredQuality: quality,
        );

        if (streamInfo == null) {
          throw ResourceException("Can't resolve stream info");
        }

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);

        final request = await client.getUrl(Uri.parse(streamInfo.url));

        request.headers.set('User-Agent', HttpConstants.userAgent);
        request.headers.set('Referer', HttpConstants.referer);
        if (start > 0) {
          request.headers.set('Range', 'bytes=$start-');
        }

        final response = await request.close();
        if (response.statusCode >= 400) {
          if (response.statusCode == 403 ||
              response.statusCode == 404 ||
              response.statusCode == 410) {
            throw ResourceException("HTTP ${response.statusCode}: 资源无效或无权访问");
          }
          throw NetworkException(
            "HTTP Server Error",
            statusCode: response.statusCode,
          );
        }

        return response;
      } catch (e) {
        retryCount++;
        Log.w(_tag, "getNetworkStream failed (attempt $retryCount): $e");

        if (e is ResourceException) rethrow;

        if (retryCount > maxRetries) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw ResourceException("Failed to get network stream after retries");
  }

  String getStaticCachePath(String bvid, int cid, int quality) {
    final fileName = _getStaticCacheFileName(bvid, cid, quality);
    return '$_cacheDir/$fileName';
  }

  String getTempCachePath(String bvid, int cid) {
    return '$_cacheDir/temp_${bvid}_$cid.tmp';
  }

  Future<void> _cleanTempFiles() async {
    Log.v(_tag, "_cleanTempFiles");
    if (_cacheDir == null) return;
    try {
      final dir = Directory(_cacheDir!);
      if (await dir.exists()) {
        await for (var file in dir.list()) {
          if (file is File && file.path.endsWith('.tmp')) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  String _getStaticCacheFileName(String bvid, int cid, int quality) =>
      'song_${bvid}_${cid}_$quality.audio';

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
          if (file is File) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        Log.e(_tag, "Fail to clear static cache", e);
      }
    }
    await _dbService.clearStaticCacheMeta();
  }

  Future<void> startDownload(Song song, {int? quality}) async {
    Log.v(_tag, "startDownload, bvid: ${song.bvid}, cid: ${song.cid}");
    await _initDirs();
    int cid = song.cid;
    if (cid == 0) cid = await _searchApi.fetchCid(song.bvid);
    final songWithCid = song.copyWith(cid: cid);
    if (await isDownloaded(songWithCid.bvid, songWithCid.cid)) return;
    final id = '${songWithCid.bvid}_${songWithCid.cid}';
    if (_queue.any((task) => '${task.song.bvid}_${task.song.cid}' == id))
      return;
    if (_activeTaskIds.containsKey(id)) return;
    int targetQuality = quality ?? await _resolveBestQuality(songWithCid);
    final fileName =
        '${songWithCid.bvid}_${songWithCid.cid}_$targetQuality.audio';
    final savePath = '$_downloadDir/$fileName';
    await _dbService.insertDownload(songWithCid, savePath, targetQuality);
    _progressController.add(DownloadUpdate(id, 0.0, 0));
    _queue.add(
      _DownloadTask(
        song: songWithCid,
        savePath: savePath,
        quality: targetQuality,
      ),
    );
    _processQueue();
  }

  Future<int> _resolveBestQuality(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    int targetQuality = prefs.getInt(_defaultDownloadQualityKey) ?? 30280;
    try {
      final available = await _audioStreamApi.fetchAvailableQualities(
        song.bvid,
        song.cid,
      );
      if (available.isNotEmpty) {
        available.sort(
          (a, b) =>
              QualityUtils.getScore(b).compareTo(QualityUtils.getScore(a)),
        );
        int preferredScore = QualityUtils.getScore(targetQuality);
        int? bestMatch;
        for (var q in available) {
          if (QualityUtils.getScore(q) <= preferredScore) {
            bestMatch = q;
            break;
          }
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
    Log.v(_tag, "_executeDownload, bvid: ${task.song.bvid}");
    final id = '${task.song.bvid}_${task.song.cid}';

    try {
      if (!_activeTaskIds.containsKey(id)) return;

      final file = File(task.savePath);
      int downloadedBytes = await file.exists() ? await file.length() : 0;
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 1);
      _progressController.add(DownloadUpdate(id, 0.0, 1));

      final response = await getNetworkStream(
        task.song.bvid,
        task.song.cid,
        task.quality,
        start: downloadedBytes,
      );

      final totalBytes = response.contentLength + downloadedBytes;
      final sink = file.openWrite(mode: FileMode.append);
      int receivedBytes = downloadedBytes;
      int lastUpdate = 0;

      await for (var chunk in response) {
        if (!_activeTaskIds.containsKey(id)) {
          await sink.flush();
          await sink.close();
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          final percent = ((receivedBytes / totalBytes) * 100).toInt();
          if (percent > lastUpdate + 2) {
            lastUpdate = percent;
            _progressController.add(
              DownloadUpdate(id, receivedBytes / totalBytes, 1),
            );
          }
        }
      }

      await sink.flush();
      await sink.close();

      if (!_activeTaskIds.containsKey(id)) return;

      await _dbService.updateDownloadStatus(
        task.song.bvid,
        task.song.cid,
        3,
        progress: 1.0,
      );
      _progressController.add(DownloadUpdate(id, 1.0, 3));
    } catch (e) {
      Log.e(_tag, "Download failed: $e");
      if (_activeTaskIds.containsKey(id)) {
        await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 4);
        _progressController.add(DownloadUpdate(id, 0.0, 4));
      }
    }
  }

  Future<void> pauseDownload(String bvid, int cid) async {
    Log.v(_tag, "pauseDownload, bvid: $bvid, cid: $cid");
    final id = '${bvid}_$cid';
    if (_activeTaskIds.containsKey(id)) {
      _activeTaskIds.remove(id);
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate(id, 0.0, 0));
      _activeDownloads--;
      _processQueue();
    }
  }

  Future<void> retryDownload(String bvid, int cid) async {
    Log.v(_tag, "retryDownload, bvid: $bvid, cid: $cid");
    final record = await _dbService.getDownload(bvid, cid);
    if (record != null) {
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate('${bvid}_$cid', 0.0, 0));
      startDownload(
        Song(
          title: record['title'],
          artist: record['artist'],
          coverUrl: record['cover_url'],
          lyrics: '',
          colorValue: 0,
          bvid: bvid,
          cid: cid,
        ),
        quality: record['quality'],
      );
    }
  }

  Future<void> deleteDownload(String bvid, int cid) async {
    Log.v(_tag, "deleteDownload, bvid: $bvid, cid: $cid");
    await pauseDownload(bvid, cid);
    await _dbService.deleteDownload(bvid, cid);
    _queue.removeWhere((t) => t.song.bvid == bvid && t.song.cid == cid);
    if (_downloadDir == null) await _initDirs();
    final dir = Directory(_downloadDir!);
    if (await dir.exists()) {
      await for (var file in dir.list()) {
        if (file.path.contains('${bvid}_$cid')) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _performSmartCleanup() async {
    Log.v(_tag, "_performSmartCleanup");
    if (_cacheDir == null) return;
    try {
      final metas = await _dbService.getCompletedCacheMeta();
      if (metas.isEmpty) return;

      int totalSize = 0;
      for (var m in metas) {
        int size = (m['file_size'] as int? ?? 0);
        if (size <= 0) {
          try {
            final bvid = m['bvid'];
            final cid = m['cid'];
            final quality = m['quality'];
            final path = getStaticCachePath(bvid, cid, quality);
            final file = File(path);
            if (await file.exists()) {
              size = await file.length();
              _dbService.recordCacheAccess(bvid, cid, quality, fileSize: size);
            }
          } catch (e) {
            Log.w(_tag, "_performSmartCleanup failed, error: $e");
          }
        }
        totalSize += size;
      }

      Log.i(
        _tag,
        "Current Cache Size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB / Max: ${(_maxCacheSize / 1024 / 1024).toStringAsFixed(2)} MB",
      );

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
          if (await file.exists()) {
            int fileSize = await file.length();
            await file.delete();
            totalSize -= fileSize;
          } else {
            totalSize -= (meta['file_size'] as int? ?? 0);
          }
          await _dbService.removeCacheMeta(key as String);
          Log.i(_tag, "Cleaned up cache: $fileName");
        } catch (e) {
          Log.w(_tag, "Failed to delete cache file: $fileName");
        }
      }
    } catch (e) {
      Log.e(_tag, "Smart cleanup failed", e);
    }
  }

  double _calculateScore(Map<String, dynamic> meta, int now) {
    int hits = meta['hit_count'] ?? 0;
    int lastAccess = meta['last_access_time'] ?? 0;
    double hoursDiff = (now - lastAccess) / (1000 * 3600);
    if (hoursDiff < 0.1) hoursDiff = 0.1;
    return (hits * 100.0) + (1000 / hoursDiff);
  }

  Future<void> _resumePendingDownloads() async {
    Log.v(_tag, "_resumePendingDownloads");
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      if (d['status'] == 0 || d['status'] == 1) {
        startDownload(
          Song(
            title: d['title'],
            artist: d['artist'],
            coverUrl: d['cover_url'],
            lyrics: '',
            colorValue: 0,
            bvid: d['bvid'],
            cid: d['cid'],
          ),
          quality: d['quality'],
        );
      }
    }
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    Log.v(_tag, "setMaxConcurrentDownloads, count: $count");
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

  Future<bool> isDownloaded(String bvid, int cid) async {
    return await _dbService.isDownloaded(bvid, cid);
  }
}
