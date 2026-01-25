import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/connection/utils/constants.dart';

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
  static const String _concurrentDownloadsKey = 'max_concurrent_downloads'; // [New]

  int _maxCacheSize = 500 * 1024 * 1024;
  int _maxConcurrentDownloads = 3;
  final List<_DownloadTask> _queue = [];
  int _activeDownloads = 0;
  final StreamController<DownloadUpdate> _progressController = StreamController.broadcast();
  Stream<DownloadUpdate> get downloadUpdateStream => _progressController.stream;

  Future<void> init() async {
    await _initDirs();
    final prefs = await SharedPreferences.getInstance();
    int mb = prefs.getInt(_maxCacheSizeKey) ?? 500;
    _maxCacheSize = mb * 1024 * 1024;
    _maxConcurrentDownloads = prefs.getInt(_concurrentDownloadsKey) ?? 3;
    _performSmartCleanup();
  }

  Future<void> setMaxCacheSize(int mb) async {
    _maxCacheSize = mb * 1024 * 1024;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxCacheSizeKey, mb);
    _performSmartCleanup();
  }

  Future<int> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxCacheSizeKey) ?? 500;
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    if (count < 1) count = 1;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrentDownloadsKey, count);
    _processQueue();
  }

  Future<int> getMaxConcurrentDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_concurrentDownloadsKey) ?? 3;
  }

  Future<void> _initDirs() async {
    if (_cacheDir != null && _downloadDir != null) return;

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/MusicCache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    _cacheDir = cacheDir.path;

    final docDir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${docDir.path}/MusicDownload');
    if (!await dlDir.exists()) await dlDir.create(recursive: true);
    _downloadDir = dlDir.path;
  }

  Future<bool> isDownloaded(String bvid, int cid) async {
    return await _dbService.isDownloaded(bvid, cid);
  }

  Future<Set<String>> getDownloadedIds(List<Song> songs) async {
    final ids = songs.map((s) => '${s.bvid}_${s.cid}').toList();
    final downloadedList = await _dbService.getDownloadedIds(ids);
    return downloadedList.toSet();
  }

  Future<({File file, int quality})?> getPlayableFile(String bvid, int cid, int requestedQuality) async {
    if (_downloadDir == null) await _initDirs();

    final downloadRecord = await _dbService.getCompletedDownload(bvid, cid);
    if (downloadRecord != null) {
      final path = downloadRecord['save_path'] as String;
      final quality = downloadRecord['quality'] as int;
      final file = File(path);

      if (await file.exists()) {
        print("DownloadManager: Hit DOWNLOAD (Quality: $quality) for $bvid");
        return (file: file, quality: quality);
      } else {
        _dbService.updateDownloadStatus(bvid, cid, 4);
      }
    }

    final cacheName = _getCacheFileName(bvid, cid, requestedQuality);
    final cacheFile = File('$_cacheDir/$cacheName');

    if (await cacheFile.exists()) {
      print("DownloadManager: Hit CACHE (Quality: $requestedQuality) for $bvid");
      _dbService.recordCacheAccess(bvid, cid, requestedQuality);
      return (file: cacheFile, quality: requestedQuality);
    }

    return null;
  }

  Future<void> startDownload(Song song, {int quality = 30280}) async {
    await _initDirs();
    if (await isDownloaded(song.bvid, song.cid)) {
      return;
    }

    final id = '${song.bvid}_${song.cid}';
    if (_queue.any((task) => '${task.song.bvid}_${task.song.cid}' == id)) {
      return;
    }
    final fileName = '${song.bvid}_${song.cid}_$quality.audio';
    final savePath = '$_downloadDir/$fileName';
    await _dbService.insertDownload(song, savePath, quality);
    _progressController.add(DownloadUpdate(id, 0.0, 0));
    _queue.add(_DownloadTask(song: song, savePath: savePath, quality: quality));
    _processQueue();
  }

  void _processQueue() {
    while (_activeDownloads < _maxConcurrentDownloads && _queue.isNotEmpty) {
      _activeDownloads++;
      final task = _queue.removeAt(0);
      _executeDownload(task).whenComplete(() {
        _activeDownloads--;
        _processQueue();
      });
    }
  }

  Future<void> _executeDownload(_DownloadTask task) async {
    final id = '${task.song.bvid}_${task.song.cid}';

    try {
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 1);
      _progressController.add(DownloadUpdate(id, 0.0, 1));
      int cid = task.song.cid;
      if (cid == 0) {
        cid = await _searchApi.fetchCid(task.song.bvid);
      }
      final info = await _audioStreamApi.getAudioStream(task.song.bvid, cid, preferredQuality: task.quality);
      if (info == null) throw Exception("Failed to get audio stream");
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(info.url));
      request.headers.set('User-Agent', HttpConstants.userAgent);
      request.headers.set('Referer', HttpConstants.referer);

      final response = await request.close();
      final totalBytes = response.contentLength;

      final file = File(task.savePath);
      final sink = file.openWrite();

      int receivedBytes = 0;
      int lastProgressUpdate = 0;

      await for (var chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          final percent = (progress * 100).toInt();
          if (percent > lastProgressUpdate) {
            lastProgressUpdate = percent;
            _progressController.add(DownloadUpdate(id, progress, 1));
          }
        }
      }

      await sink.flush();
      await sink.close();
      client.close();
      await _dbService.updateDownloadStatus(task.song.bvid, cid, 3, progress: 1.0);
      _progressController.add(DownloadUpdate(id, 1.0, 3));
      print("Download completed: ${task.song.title}");

    } catch (e) {
      print("Download failed: $e");
      await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 4);
      _progressController.add(DownloadUpdate(id, 0.0, 4));

      final file = File(task.savePath);
      if (await file.exists()) await file.delete();
    }
  }
  String _getCacheFileName(String bvid, int cid, int quality) {
    return 'song_${bvid}_${cid}_$quality.audio';
  }

  Future<File> getTempCacheFile(String bvid, int cid, int quality) async {
    if (_cacheDir == null) await _initDirs();
    final fileName = '${_getCacheFileName(bvid, cid, quality)}.tmp';
    return File('$_cacheDir/$fileName');
  }

  Future<File?> commitCacheFile(File tempFile, String bvid, int cid, int quality) async {
    if (_cacheDir == null) await _initDirs();
    try {
      if (!await tempFile.exists()) return null;
      final fileName = _getCacheFileName(bvid, cid, quality);
      final targetFile = File('$_cacheDir/$fileName');
      if (await targetFile.exists()) await targetFile.delete();
      await tempFile.rename(targetFile.path);

      final size = await targetFile.length();
      await _dbService.recordCacheAccess(
          bvid, cid, quality, fileSize: size, status: 'completed'
      );
      _performSmartCleanup();
      return targetFile;
    } catch (e) {
      try { await tempFile.delete(); } catch (_) {}
      return null;
    }
  }

  Future<void> _performSmartCleanup() async {
    if (_cacheDir == null) return;
    try {
      final metas = await _dbService.getCompletedCacheMeta();
      if (metas.isEmpty) return;
      int totalSize = 0;
      for (var m in metas) {
        totalSize += (m['file_size'] as int? ?? 0);
      }
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
        final fileName = 'song_$key.audio';
        final file = File('$_cacheDir/$fileName');
        try {
          if (await file.exists()) await file.delete();
          await _dbService.removeCacheMeta(key as String);
          totalSize -= (meta['file_size'] as int? ?? 0);
        } catch (e) {}
      }
    } catch (e) {
      print("Cleanup error: $e");
    }
  }

  double _calculateScore(Map<String, dynamic> meta, int now) {
    int hits = meta['hit_count'] ?? 0;
    int lastAccess = meta['last_access_time'] ?? 0;
    double hoursDiff = (now - lastAccess) / (1000 * 3600);
    if (hoursDiff < 0.1) hoursDiff = 0.1;
    double recencyScore = 1000 / hoursDiff;
    double frequencyScore = hits * 100.0;
    return recencyScore + frequencyScore;
  }

  Future<void> clearAllCache() async {
    if (_cacheDir == null) await _initDirs();
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
        await dir.create();
      } catch (e) {}
    }
    await _dbService.clearCacheMetaTable();
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
}