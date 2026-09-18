import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/sponsor_block/sponsor_block_service.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/connection/utils/constants.dart';
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
  final int? quality;

  ResourceResponse({this.file, this.directUrl, this.quality});
}

class NetworkStreamResponse {
  final HttpClientResponse httpResponse;
  final String mimeType;
  final int actualQuality;
  final int? lastPlayTime;

  NetworkStreamResponse({
    required this.httpResponse,
    required this.mimeType,
    required this.actualQuality,
    this.lastPlayTime,
  });
}

class DownloadUpdate {
  final String id;
  final double progress;
  final int status;

  DownloadUpdate(this.id, this.progress, this.status);
}

class _DownloadTask {
  Song song;
  String savePath;
  int quality;

  _DownloadTask({
    required this.song,
    required this.savePath,
    required this.quality,
  });

  String get id => '${song.bvid}_${song.cid}';
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

  int _maxCacheSize = 200 * 1024 * 1024;
  int _maxConcurrentDownloads = 3;
  bool get isCacheEnabled => _maxCacheSize > 0;
  bool _isCleaningUp = false;
  int _pendingCacheSize = 0;
  static const int _cleanupThreshold = 10 * 1024 * 1024;

  final List<_DownloadTask> _queue = [];
  int _activeDownloads = 0;
  final Map<String, bool> _activeTaskIds = {};
  bool _isPausedAll = false;
  bool _isProcessingQueue = false;
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

  Future<File?> getRealDownloadFile(
    String? savePath,
    String bvid,
    int cid, [
    int? quality,
  ]) async {
    await _initDirs();

    // 1. Check if the recorded savePath directly exists
    if (savePath != null && savePath.isNotEmpty) {
      final file = File(savePath);
      if (await file.exists()) {
        return file;
      }
    }

    // 2. Dynamic path resolution for iOS sandbox / LiveContainer:
    // When container UUID changes, find the file inside current _downloadDir
    if (_downloadDir != null) {
      String? fileName;
      if (savePath != null && savePath.isNotEmpty) {
        fileName = savePath.split(RegExp(r'[\\/]')).last;
      }
      if (fileName == null || fileName.isEmpty) {
        if (quality != null) {
          fileName = '${bvid}_${cid}_$quality.audio';
        }
      }

      if (fileName != null && fileName.isNotEmpty) {
        final dynFile = File('$_downloadDir/$fileName');
        if (await dynFile.exists()) {
          // Self-heal the stale path in database
          await _dbService.updateDownloadPath(bvid, cid, dynFile.path);
          return dynFile;
        }
      }

      // 3. Fallback: match by prefix '${bvid}_${cid}_' in _downloadDir
      final dir = Directory(_downloadDir!);
      if (await dir.exists()) {
        final prefix = '${bvid}_${cid}_';
        await for (final entity in dir.list()) {
          if (entity is File) {
            final name = entity.path.split(RegExp(r'[\\/]')).last;
            if (name.startsWith(prefix) && name.endsWith('.audio')) {
              await _dbService.updateDownloadPath(bvid, cid, entity.path);
              return entity;
            }
          }
        }
      }
    }

    return null;
  }

  Future<ResourceResponse?> checkLocalResource(
    String bvid,
    int initCid,
    int quality,
  ) async {
    await _initDirs();

    int cid = initCid;
    if (cid == 0) {
      cid = await _searchApi.fetchCid(bvid);
    }

    final downloadRecord = await _dbService.getCompletedDownload(bvid, cid);
    if (downloadRecord != null) {
      final file = await getRealDownloadFile(
        downloadRecord['save_path'] as String?,
        bvid,
        cid,
        quality,
      );
      if (file != null && await file.exists() && await file.length() > 0) {
        return ResourceResponse(file: file, quality: quality);
      }
    }

    final cacheMeta = await _dbService.getCacheMeta(bvid, cid, quality);
    if (cacheMeta != null &&
        cacheMeta['status'] == CacheStatus.staticCached.code) {
      final fileName = _getStaticCacheFileName(bvid, cid, quality);
      final file = File('$_cacheDir/$fileName');
      if (await file.exists()) {
        if (await file.length() > 0) {
          await _dbService.recordCacheAccess(
            bvid,
            cid,
            quality,
            status: CacheStatus.staticCached.code,
          );
          return ResourceResponse(file: file);
        } else {
          try {
            await file.delete();
          } catch (_) {}
          await _dbService.removeCacheMeta(cacheMeta['key']);
        }
      }
    }

    return null;
  }

  Future<NetworkStreamResponse> getNetworkStream(
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
      } catch (e) {
        Log.w(_tag, "Fetch cid failed, source may be invalid");
      }
    }

    if (cid == 0) throw ResourceException("Fetch CID failed");

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
          if (response.statusCode == 403 || response.statusCode == 404) {
            throw ResourceException(
              "HTTP ${response.statusCode}: Resource unavailable",
            );
          }
          throw NetworkException("HTTP Error", statusCode: response.statusCode);
        }

        return NetworkStreamResponse(
          httpResponse: response,
          mimeType: streamInfo.mimeType,
          actualQuality: streamInfo.quality,
          lastPlayTime: streamInfo.lastPlayTime,
        );
      } catch (e) {
        retryCount++;
        if (e is ResourceException) rethrow;
        if (retryCount > maxRetries) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw ResourceException("Failed to get network stream");
  }

  String getStaticCachePath(String bvid, int cid, int quality) {
    final fileName = _getStaticCacheFileName(bvid, cid, quality);
    return '$_cacheDir/$fileName';
  }

  String getTempCachePath(String bvid, int cid) {
    return '$_cacheDir/temp_${bvid}_$cid.tmp';
  }

  Future<void> _cleanTempFiles() async {
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
    return prefs.getInt(_maxCacheSizeKey) ?? 200;
  }

  Future<void> setMaxCacheSize(int mb) async {
    _maxCacheSize = mb * 1024 * 1024;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxCacheSizeKey, mb);
    await _performSmartCleanup();
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
      } catch (_) {}
    }
    await _dbService.clearStaticCacheMeta();
  }

  Future<void> onCacheFileAdded(int fileSize) async {
    _pendingCacheSize += fileSize;
    if (_pendingCacheSize >= _cleanupThreshold) {
      _pendingCacheSize = 0;
      await _performSmartCleanup();
    }
  }

  Future<void> performCleanupIfNeeded() async {
    await _performSmartCleanup();
  }

  Future<void> startDownload(Song song, {int? quality}) async {
    await _initDirs();
    _isPausedAll = false;

    // Quick check: if already completed and CID is known
    if (song.cid > 0 && await isDownloaded(song.bvid, song.cid)) return;

    final id = '${song.bvid}_${song.cid}';
    if (_queue.any((task) => task.id == id)) return;
    if (_activeTaskIds.containsKey(id)) return;

    final prefs = await SharedPreferences.getInstance();
    final targetQuality =
        quality ?? prefs.getInt(_defaultDownloadQualityKey) ?? 30280;
    final fileName = '${song.bvid}_${song.cid}_$targetQuality.audio';
    final savePath = '$_downloadDir/$fileName';

    // Insert into database with status 0 (Queued) - no network requests here!
    await _dbService.insertDownload(song, savePath, targetQuality);
    _progressController.add(DownloadUpdate(id, 0.0, 0));

    _queue.add(
      _DownloadTask(
        song: song,
        savePath: savePath,
        quality: targetQuality,
      ),
    );

    _processQueue();
  }

  void _processQueue() async {
    if (_isPausedAll) return;
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _maxConcurrentDownloads =
          prefs.getInt(_concurrentDownloadsKey) ?? _maxConcurrentDownloads;
      if (_maxConcurrentDownloads <= 0) return;

      while (_activeDownloads < _maxConcurrentDownloads && _queue.isNotEmpty) {
        if (_isPausedAll) break;

        final task = _queue.removeAt(0);
        final id = task.id;
        _activeDownloads++;
        _activeTaskIds[id] = true;

        // Pacing delay between launching concurrent tasks to avoid bursting requests
        if (_activeDownloads > 1) {
          await Future.delayed(const Duration(milliseconds: 350));
        }

        unawaited(_executeDownload(task).whenComplete(() {
          _activeDownloads--;
          _activeTaskIds.remove(id);
          _activeTaskIds.remove(task.id);
          _processQueue();
        }));
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _executeDownload(_DownloadTask task) async {
    final originalId = task.id;

    try {
      if (!_activeTaskIds.containsKey(originalId)) return;

      // Secondary CID Resolution (二次解析) strictly when the download task begins
      if (task.song.cid <= 0) {
        Log.i(_tag, "Resolving CID for ${task.song.bvid} on download start...");
        // Polite pacing delay before API call to protect against WAF
        await Future.delayed(const Duration(milliseconds: 400));

        int resolvedCid = 0;
        try {
          resolvedCid = await _searchApi.fetchCid(task.song.bvid);
        } catch (e) {
          Log.w(_tag, "Fetch CID failed for ${task.song.bvid}: $e");
        }

        if (resolvedCid <= 0) {
          Log.e(_tag, "Fetch CID failed (cid <= 0) for ${task.song.bvid}");
          await _dbService.updateDownloadStatus(task.song.bvid, 0, 4);
          _progressController.add(DownloadUpdate(originalId, 0.0, 4));
          await Future.delayed(const Duration(milliseconds: 1000));
          return;
        }

        if (!_activeTaskIds.containsKey(originalId)) return;

        task.song = task.song.copyWith(cid: resolvedCid);
        final newId = task.id;

        _activeTaskIds.remove(originalId);
        _activeTaskIds[newId] = true;

        final newSavePath =
            '$_downloadDir/${task.song.bvid}_${resolvedCid}_${task.quality}.audio';
        task.savePath = newSavePath;

        if (await isDownloaded(task.song.bvid, resolvedCid)) {
          await _dbService.updateDownloadStatus(
            task.song.bvid,
            0,
            3,
            progress: 1.0,
          );
          _progressController.add(DownloadUpdate(newId, 1.0, 3));
          return;
        }

        await _dbService.updateDownloadResolvedCid(
          task.song.bvid,
          0,
          resolvedCid,
          newSavePath,
        );
      }

      final activeId = task.id;
      if (!_activeTaskIds.containsKey(activeId)) return;

      final file = File(task.savePath);
      int downloadedBytes = await file.exists() ? await file.length() : 0;
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 1);
      _progressController.add(DownloadUpdate(activeId, 0.0, 1));

      // Polite pacing delay before audio stream URL request to respect WAF rate limits
      await Future.delayed(const Duration(milliseconds: 300));

      final netResponse = await getNetworkStream(
        task.song.bvid,
        task.song.cid,
        task.quality,
        start: downloadedBytes,
      );
      final response = netResponse.httpResponse;

      // Check if the server responded with 206 Partial Content
      final bool isPartial = response.statusCode == 206;
      final bool append = isPartial && downloadedBytes > 0;
      final int actualStartBytes = append ? downloadedBytes : 0;
      final int totalBytes =
          (response.contentLength > 0 ? response.contentLength : 0) +
          actualStartBytes;

      final sink = file.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      int receivedBytes = actualStartBytes;
      int lastUpdate = 0;

      await for (var chunk in response) {
        if (!_activeTaskIds.containsKey(activeId)) {
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
            final progressVal = (receivedBytes / totalBytes).clamp(0.0, 1.0);
            _dbService.updateDownloadStatus(
              task.song.bvid,
              task.song.cid,
              1,
              progress: progressVal,
            );
            _progressController.add(
              DownloadUpdate(activeId, progressVal, 1),
            );
          }
        }
      }

      await sink.flush();
      await sink.close();

      if (!_activeTaskIds.containsKey(activeId)) return;

      await _dbService.updateDownloadStatus(
        task.song.bvid,
        task.song.cid,
        3,
        progress: 1.0,
      );
      _progressController.add(DownloadUpdate(activeId, 1.0, 3));
      unawaited(_fetchAndSaveSponsorBlockSegments(task.song.bvid, task.song.cid));
    } catch (e) {
      Log.e(_tag, "Download failed for ${task.song.bvid}: $e");
      final failId = task.id;
      if (_activeTaskIds.containsKey(failId) ||
          _activeTaskIds.containsKey(originalId)) {
        await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 4);
        _progressController.add(DownloadUpdate(failId, 0.0, 4));
      }
      // Anti-WAF cool down delay upon error before picking up next download
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> pauseDownload(String bvid, int cid) async {
    final id = '${bvid}_$cid';

    // 1. If waiting in queue
    final queueIndex =
        _queue.indexWhere((t) => t.id == id || (cid == 0 && t.song.bvid == bvid));
    if (queueIndex != -1) {
      final removed = _queue.removeAt(queueIndex);
      await _dbService.updateDownloadStatus(removed.song.bvid, removed.song.cid, 2);
      _progressController.add(DownloadUpdate(removed.id, 0.0, 2));
      return;
    }

    // 2. If actively downloading
    if (_activeTaskIds.containsKey(id)) {
      _activeTaskIds.remove(id);
      await _dbService.updateDownloadStatus(bvid, cid, 2);
      _progressController.add(DownloadUpdate(id, 0.0, 2));
    }
  }

  Future<void> resumeDownload(String bvid, int cid) async {
    _isPausedAll = false;
    final id = '${bvid}_$cid';
    if (_activeTaskIds.containsKey(id)) return;
    if (_queue.any((t) => t.id == id)) return;

    final record = await _dbService.getDownload(bvid, cid);
    if (record != null) {
      final double progress =
          (record['progress'] as num?)?.toDouble() ?? 0.0;
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate(id, progress, 0));

      final song = Song(
        title: record['title'] ?? '',
        artist: record['artist'] ?? '',
        coverUrl: record['cover_url'] ?? '',
        lyrics: '',
        colorValue: 0,
        bvid: bvid,
        cid: cid,
      );

      final savePath = record['save_path'] ??
          '$_downloadDir/${bvid}_${cid}_${record['quality']}.audio';

      _queue.add(
        _DownloadTask(
          song: song,
          savePath: savePath,
          quality: record['quality'] ?? 30280,
        ),
      );
      _processQueue();
    }
  }

  Future<void> retryDownload(String bvid, int cid) async {
    await resumeDownload(bvid, cid);
  }

  Future<void> pauseAllDownloads() async {
    _isPausedAll = true;
    for (var task in _queue) {
      final id = task.id;
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 2);
      _progressController.add(DownloadUpdate(id, 0.0, 2));
    }
    _queue.clear();

    final activeIds = List<String>.from(_activeTaskIds.keys);
    for (var id in activeIds) {
      _activeTaskIds.remove(id);
      final parts = id.split('_');
      if (parts.length >= 2) {
        final bvid = parts[0];
        final cid = int.tryParse(parts[1]) ?? 0;
        await _dbService.updateDownloadStatus(bvid, cid, 2);
        _progressController.add(DownloadUpdate(id, 0.0, 2));
      }
    }
  }

  Future<void> resumeAllDownloads() async {
    _isPausedAll = false;
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      final status = d['status'] as int;
      if (status == 2 || status == 0 || status == 4) {
        await resumeDownload(d['bvid'] as String, d['cid'] as int);
      }
    }
  }

  Future<void> deleteDownload(String bvid, int cid) async {
    await pauseDownload(bvid, cid);
    await _dbService.deleteDownload(bvid, cid);
    await _dbService.deleteSponsorBlockSegments(bvid, cid);
    _queue.removeWhere((t) => t.song.bvid == bvid && t.song.cid == cid);
    if (_downloadDir == null) await _initDirs();
    if (_downloadDir != null) {
      final dir = Directory(_downloadDir!);
      if (await dir.exists()) {
        final prefix = '${bvid}_${cid}_';
        await for (var file in dir.list()) {
          final fileName = file.path.split(RegExp(r'[\\/]')).last;
          if (fileName.startsWith(prefix) && fileName.endsWith('.audio')) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    }
  }

  Future<void> _fetchAndSaveSponsorBlockSegments(String bvid, int cid) async {
    try {
      if (cid <= 0) {
        try {
          final resolvedCid = await SearchApi().fetchCid(bvid);
          if (resolvedCid > 0) {
            cid = resolvedCid;
          }
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('sponsor_block_server') ??
          SponsorBlockService.defaultServer;
      final segments = await SponsorBlockService().getSkipSegments(
        server: server,
        bvid: bvid,
        cid: cid,
      );
      if (segments != null && segments.isNotEmpty) {
        final jsonStr = jsonEncode(segments.map((s) => s.toJson()).toList());
        await _dbService.saveSponsorBlockSegments(bvid, cid, jsonStr);
        Log.i(_tag, 'Saved SponsorBlock segments for downloaded song ${bvid}_$cid');
      }
    } catch (e) {
      Log.w(_tag, 'Failed to fetch SponsorBlock segments for download: $e');
    }
  }

  Future<void> _performSmartCleanup() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      if (_cacheDir == null) await _initDirs();
      if (_maxCacheSize <= 0) return;

      final actualCacheSize = await getUsedCacheSize();

      Log.d(
        _tag,
        "Cache cleanup check: actual=$actualCacheSize, max=$_maxCacheSize",
      );

      if (actualCacheSize <= _maxCacheSize) return;

      Log.i(
        _tag,
        "Cache size ($actualCacheSize) exceeds limit ($_maxCacheSize), starting cleanup...",
      );

      final metas = await _dbService.getCompletedCacheMeta();
      if (metas.isEmpty) {
        await _cleanOrphanedCacheFiles();
        return;
      }

      List<Map<String, dynamic>> sortedMetas = List.from(metas);
      final now = DateTime.now().millisecondsSinceEpoch;
      sortedMetas.sort(
        (a, b) => _calculateScore(a, now).compareTo(_calculateScore(b, now)),
      );

      int currentSize = actualCacheSize;
      final targetSize = (_maxCacheSize * 0.8).toInt();

      for (var meta in sortedMetas) {
        if (currentSize <= targetSize) break;

        final fileName = _getStaticCacheFileName(
          meta['bvid'],
          meta['cid'],
          meta['quality'],
        );
        final file = File('$_cacheDir/$fileName');

        if (await file.exists()) {
          final fileSize = await file.length();
          try {
            await file.delete();
            currentSize -= fileSize;
            Log.v(_tag, "Deleted cache: $fileName ($fileSize bytes)");
          } catch (e) {
            Log.w(_tag, "Failed to delete cache file: $e");
          }
        }
        await _dbService.removeCacheMeta(meta['key']);
      }

      Log.i(
        _tag,
        "Cache cleanup completed. Size: $actualCacheSize -> $currentSize",
      );
    } catch (e) {
      Log.e(_tag, "Cache cleanup error: $e");
    } finally {
      _isCleaningUp = false;
    }
  }

  Future<void> _cleanOrphanedCacheFiles() async {
    if (_cacheDir == null) return;

    try {
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) return;

      await for (var entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.audio')) {
          final fileName = entity.path.split('/').last;
          final parts = fileName
              .replaceAll('song_', '')
              .replaceAll('.audio', '')
              .split('_');
          if (parts.length >= 3) {
            final bvid = parts[0];
            final cid = int.tryParse(parts[1]) ?? 0;
            final quality = int.tryParse(parts[2]) ?? 0;

            final meta = await _dbService.getCacheMeta(bvid, cid, quality);
            if (meta == null) {
              try {
                await entity.delete();
                Log.v(_tag, "Deleted orphaned cache file: $fileName");
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      Log.w(_tag, "Error cleaning orphaned files: $e");
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
    if (count < 0) count = 0;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrentDownloadsKey, count);
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
      await deleteDownload(d['bvid'] as String, d['cid'] as int);
    }
  }

  Future<bool> isDownloaded(String bvid, int cid) async {
    return await _dbService.isDownloaded(bvid, cid);
  }
}
