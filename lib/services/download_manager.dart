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
  final List<_DownloadTask> _queue = [];
  int _activeDownloads = 0;
  final StreamController<DownloadUpdate> _progressController = StreamController.broadcast();
  Stream<DownloadUpdate> get downloadUpdateStream => _progressController.stream;

  final Map<String, bool> _activeTaskIds = {};

  Future<void> init() async {
    await _initDirs();
    final prefs = await SharedPreferences.getInstance();
    int mb = prefs.getInt(_maxCacheSizeKey) ?? 500;
    _maxCacheSize = mb * 1024 * 1024;
    _maxConcurrentDownloads = prefs.getInt(_concurrentDownloadsKey) ?? 3;
    _performSmartCleanup();
    _resumePendingDownloads();
  }

  Future<void> _resumePendingDownloads() async {
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      if (d['status'] == 0 || d['status'] == 1) {
        final song = Song(
          title: d['title'],
          artist: d['artist'],
          coverUrl: d['cover_url'],
          lyrics: '',
          colorValue: 0,
          bvid: d['bvid'],
          cid: d['cid'],
        );
        final quality = d['quality'] as int;
        if (d['status'] == 1) {
          await _dbService.updateDownloadStatus(song.bvid, song.cid, 0);
        }
        startDownload(song, quality: quality);
      }
    }
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
    if (count < 0) count = 0;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrentDownloadsKey, count);
    
    if (count == 0) {
      final activeIds = List<String>.from(_activeTaskIds.keys);
      for (var id in activeIds) {
        _activeTaskIds.remove(id);
      }
      for (var id in activeIds) {
        final parts = id.split('_');
        if (parts.length >= 2) {
          final bvid = parts[0];
          final cid = int.tryParse(parts[1]) ?? 0;
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

  Future<void> startDownload(Song song, {int? quality}) async {
    await _initDirs();
    
    int cid = song.cid;
    if (cid == 0) {
      try {
        cid = await _searchApi.fetchCid(song.bvid);
      } catch (e) {
        print("Failed to fetch CID for download: $e");
        return;
      }
    }
    
    final songWithCid = song.copyWith(cid: cid);

    if (await isDownloaded(songWithCid.bvid, songWithCid.cid)) {
      return;
    }

    final id = '${songWithCid.bvid}_${songWithCid.cid}';
    if (_queue.any((task) => '${task.song.bvid}_${task.song.cid}' == id)) {
      return;
    }

    if (_activeTaskIds.containsKey(id)) {
      return;
    }

    int targetQuality = quality ?? 30280;
    if (quality == null) {
      final prefs = await SharedPreferences.getInstance();
      targetQuality = prefs.getInt(_defaultDownloadQualityKey) ?? 30280;

      try {
        final available = await _audioStreamApi.fetchAvailableQualities(songWithCid.bvid, songWithCid.cid);
        if (available.isNotEmpty) {
          available.sort((a, b) => QualityUtils.getScore(b).compareTo(QualityUtils.getScore(a)));
          
          int preferredScore = QualityUtils.getScore(targetQuality);

          int? bestMatch;
          for (var q in available) {
            if (QualityUtils.getScore(q) <= preferredScore) {
              bestMatch = q;
              break;
            }
          }

          bestMatch ??= available.last;
          
          targetQuality = bestMatch;
        }
      } catch (e) {
        print("Failed to fetch available qualities for download: $e");
      }
    }

    final fileName = '${songWithCid.bvid}_${songWithCid.cid}_$targetQuality.audio';
    final savePath = '$_downloadDir/$fileName';

    await _dbService.insertDownload(songWithCid, savePath, targetQuality);
    _progressController.add(DownloadUpdate(id, 0.0, 0));
    
    _queue.add(_DownloadTask(song: songWithCid, savePath: savePath, quality: targetQuality));
    _processQueue();
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

  Future<void> prioritizeDownload(String bvid, int cid) async {
    final id = '${bvid}_${cid}';
    if (_activeTaskIds.containsKey(id)) return;
    final index = _queue.indexWhere((t) => '${t.song.bvid}_${t.song.cid}' == id);
    _DownloadTask? task;
    if (index != -1) {
      task = _queue.removeAt(index);
    } else {
      final record = await _dbService.getDownload(bvid, cid);
      if (record != null) {
        final song = Song(
          title: record['title'],
          artist: record['artist'],
          coverUrl: record['cover_url'],
          lyrics: '',
          colorValue: 0,
          bvid: bvid,
          cid: cid,
        );
        final quality = record['quality'] as int;
        final savePath = record['save_path'] as String;
        task = _DownloadTask(song: song, savePath: savePath, quality: quality);
      }
    }

    if (task != null) {
      _queue.insert(0, task);
      if (_activeDownloads >= _maxConcurrentDownloads && _maxConcurrentDownloads > 0) {
        if (_activeTaskIds.isNotEmpty) {
          final idToPause = _activeTaskIds.keys.last;
          final parts = idToPause.split('_');
          if (parts.length >= 2) {
             await pauseDownload(parts[0], int.parse(parts[1]));
          }
        }
      }
      _processQueue();
    }
  }

  Future<void> retryDownload(String bvid, int cid) async {
    final record = await _dbService.getDownload(bvid, cid);
    if (record != null) {
      final song = Song(
        title: record['title'],
        artist: record['artist'],
        coverUrl: record['cover_url'],
        lyrics: '',
        colorValue: 0,
        bvid: bvid,
        cid: cid,
      );
      final quality = record['quality'] as int;
      await _dbService.updateDownloadStatus(bvid, cid, 0);
      _progressController.add(DownloadUpdate('${bvid}_${cid}', 0.0, 0));
      startDownload(song, quality: quality);
    }
  }

  Future<void> deleteDownload(String bvid, int cid) async {
    final id = '${bvid}_${cid}';
    _activeTaskIds.remove(id);
    
    await _dbService.deleteDownload(bvid, cid);
    
    if (_downloadDir == null) await _initDirs();
    final dir = Directory(_downloadDir!);
    if (await dir.exists()) {
      try {
        await for (var file in dir.list()) {
          if (file is File) {
            final name = file.uri.pathSegments.last;
            if (name.startsWith('${bvid}_${cid}_')) {
              await file.delete();
            }
          }
        }
      } catch (e) {
        print("Error deleting download file: $e");
      }
    }
    
    _queue.removeWhere((task) => task.song.bvid == bvid && task.song.cid == cid);
  }

  Future<void> deleteAllDownloads() async {
    final downloads = await _dbService.getAllDownloads();
    for (var d in downloads) {
      final bvid = d['bvid'] as String;
      final cid = d['cid'] as int;
      await deleteDownload(bvid, cid);
    }
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
      
      final record = await _dbService.getDownload(task.song.bvid, task.song.cid);
      if (record == null) return;
      final file = File(task.savePath);
      int downloadedBytes = 0;
      if (await file.exists()) {
        downloadedBytes = await file.length();
      }

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
      
      if (downloadedBytes > 0) {
        request.headers.set('Range', 'bytes=$downloadedBytes-');
      }

      final response = await request.close();
      
      if (response.statusCode == HttpStatus.partialContent || response.statusCode == HttpStatus.ok) {
         final totalBytes = response.contentLength + downloadedBytes;
         final isPartial = response.statusCode == HttpStatus.partialContent;
         
         final sink = file.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
         
         int receivedBytes = isPartial ? downloadedBytes : 0;
         int lastProgressUpdate = 0;

         await for (var chunk in response) {
           if (!_activeTaskIds.containsKey(id)) {
             await sink.flush();
             await sink.close();
             client.close();
             return;
           }
           
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
      } else {
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
           await file.delete();
           throw Exception("Range not satisfiable, restarting...");
        }
        throw Exception("HTTP Error: ${response.statusCode}");
      }
      
      client.close();

      if (!_activeTaskIds.containsKey(id)) return;
      
      final check = await _dbService.getDownload(task.song.bvid, task.song.cid);
      if (check == null) {
        if (await file.exists()) await file.delete();
        return;
      }

      await _dbService.updateDownloadStatus(task.song.bvid, cid, 3, progress: 1.0);
      _progressController.add(DownloadUpdate(id, 1.0, 3));
      print("Download completed: ${task.song.title}");

    } catch (e) {
      print("Download failed: $e");
      if (_activeTaskIds.containsKey(id)) {
        final check = await _dbService.getDownload(task.song.bvid, task.song.cid);
        if (check != null) {
          await _dbService.updateDownloadStatus(task.song.bvid, task.song.cid, 4);
          _progressController.add(DownloadUpdate(id, 0.0, 4));
        }
      }
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