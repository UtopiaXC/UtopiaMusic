import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/services/audio_proxy_service.dart';
import 'package:utopia_music/services/database_service.dart';

class _CacheItem {
  final File file;
  final String key;
  final int size;
  int hitCount;
  int dbLastAccess;

  _CacheItem({
    required this.file,
    required this.key,
    required this.size,
    this.hitCount = 0,
    this.dbLastAccess = 0,
  });

  double get retentionScore {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffHours = (now - dbLastAccess) / (1000 * 3600) + 0.1;
    double recencyScore = 1000 / diffHours;
    double frequencyScore = (hitCount > 0) ? (hitCount * 100.0) : 0.0;

    if (hitCount <= 1 && diffHours > 24) {
      return 0.0;
    }

    return recencyScore + frequencyScore;
  }
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static const String _cacheSizeKey = 'max_cache_size_mb';
  int _maxCacheSize = 200 * 1024 * 1024;

  factory AudioPlayerService() => _instance;

  final AudioProxyService _proxy = AudioProxyService();
  final DatabaseService _dbService = DatabaseService();
  final AudioPlayer _player = AudioPlayer();

  String? _cacheDir;
  List<Song> _globalQueue = [];
  int _currentIndex = 0;
  bool _autoSkipInvalid = true;
  bool _isHandlingError = false;

  final StreamController<int> _indexController =
      StreamController<int>.broadcast();

  Stream<int> get currentIndexStream => _indexController.stream;

  final StreamController<Map<String, dynamic>> _playbackErrorController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get playbackErrorStream =>
      _playbackErrorController.stream;

  List<Song> get queue => List.unmodifiable(_globalQueue);

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  AudioPlayerService._internal() {
    _init();

    _player.currentIndexStream.listen((index) {
      if (!_isDesktop && index != null) {
        _currentIndex = index;
        _indexController.add(index);
      }
    });

    _player.playerStateStream.listen((state) {});

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        print('AudioPlayerService: 捕获到播放器底层错误: $e');
        _handleInvalidResourceAndPlayNext();
      },
    );
  }

  void setAutoSkipInvalid(bool enable) {
    _autoSkipInvalid = enable;
  }

  void notifyPlaybackError(String bvid, int cid) {
    print("AudioPlayerService: Proxy 报告资源无效 ($bvid)");
    _playbackErrorController.add({'bvid': bvid, 'cid': cid});
    Future.microtask(() => _handleInvalidResourceAndPlayNext());
  }

  Future<void> _handleInvalidResourceAndPlayNext() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSkipInvalid = prefs.getBool(PlayerProvider.autoSkipInvalidKey) ?? true;
    if (!_autoSkipInvalid) {
      if (_currentIndex < _globalQueue.length) {
        final invalidSong = _globalQueue[_currentIndex];
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('资源失效'),
              content: Text(
                ' "${invalidSong.title}" 无法播放。可能原因：网络波动、资源版权限制、资源为充电视频等。已经自动停止播放，请自行清理失效资源并重新开始播放。如果希望跳过失效资源，请在设置中播放设置启动自动清理失效资源。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      }
      await stop();
      return;
    }

    if (_globalQueue.isEmpty || _isHandlingError) return;
    _isHandlingError = true;

    try {
      if (_currentIndex >= _globalQueue.length) {
        _currentIndex = 0;
        if (_globalQueue.isEmpty) return;
      }

      final invalidSong = _globalQueue[_currentIndex];
      _globalQueue.removeAt(_currentIndex);
      if (_globalQueue.isEmpty) {
        await stop();
        _indexController.add(0);
        return;
      }
      if (_currentIndex >= _globalQueue.length) {
        _currentIndex = 0;
      }
      if (_isDesktop) {
        await playWithQueue(_globalQueue, _currentIndex);
      } else {
        try {
          final source = _player.audioSource as ConcatenatingAudioSource?;
          if (source != null && source.length > _currentIndex) {
            await source.removeAt(_currentIndex);
            if (!_player.playing) {
              await _player.play();
            }
          } else {
            await playWithQueue(_globalQueue, _currentIndex);
          }
        } catch (e) {
          print("Error removing item from playlist source: $e");
          await playWithQueue(_globalQueue, _currentIndex);
        }
      }
      _indexController.add(_currentIndex);
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isHandlingError = false;
    }
  }

  Future<void> _init() async {
    await _loadCacheSettings();
    final cachePath = await _getCacheDir();
    _proxy.setCacheDir(cachePath);
    _proxy.onCacheFinished = (bvid) {
      _performStrictCleanup();
    };
    await _proxy.start();
    _performStrictCleanup();
  }

  Future<void> _loadCacheSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sizeMb = prefs.getInt(_cacheSizeKey) ?? 200;
    _maxCacheSize = sizeMb * 1024 * 1024;
  }

  Future<void> setMaxCacheSize(int sizeMb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cacheSizeKey, sizeMb);
    _maxCacheSize = sizeMb * 1024 * 1024;
    _performStrictCleanup();
  }

  Future<int> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cacheSizeKey) ?? 200;
  }

  AudioPlayer get player => _player;

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _globalQueue.length)
      ? _globalQueue[_currentIndex]
      : null;

  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    _cacheDir = "${dir.path}/UtopiaMusicCache";
    final directory = Directory(_cacheDir!);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return _cacheDir!;
  }

  AudioSource _createAudioSource(Song song) {
    // 传递 quality 参数
    final proxyUrl = _proxy.buildUrl(
      song.bvid,
      song.cid,
      quality: _proxy.preferredQuality,
    );

    return AudioSource.uri(
      Uri.parse(proxyUrl),
      headers: {
        'User-Agent': HttpConstants.userAgent,
        'Referer': HttpConstants.referer,
      },
      tag: MediaItem(
        id: song.bvid,
        title: song.title,
        artist: song.artist,
        artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
      ),
    );
  }

  Future<void> playSong(Song song) async {
    await playWithQueue([song], 0);
  }

  Future<void> playWithQueue(
    List<Song> queue,
    int index, {
    bool autoPlay = true,
  }) async {
    try {
      if (_player.playing) {
        await _player.stop();
      }

      _globalQueue = queue;
      _currentIndex = index;
      _indexController.add(index);

      if (_isDesktop) {
        final song = queue[index];
        final source = _createAudioSource(song);
        try {
          await _player.setAudioSource(source);
          if (autoPlay) {
            await _player.play();
          }
        } catch (e) {
          print("Desktop load error (likely 403/404): $e");
          await _handleInvalidResourceAndPlayNext();
        }
      } else {
        final List<AudioSource> sources = queue
            .map((s) => _createAudioSource(s))
            .toList();
        final playlist = ConcatenatingAudioSource(
          children: sources,
          useLazyPreparation: true,
        );
        await _player.setAudioSource(playlist, initialIndex: index);
        if (autoPlay) {
          try {
            await _player.play();
          } catch (e) {
            print("Initial play error: $e");
          }
        }
      }
    } catch (e) {
      print("Error setting audio source: $e");
    }
  }

  Future<void> updateQueueKeepPlaying(List<Song> newQueue, int newIndex) async {
    bool wasPlaying = _player.playing;

    _globalQueue = newQueue;
    _currentIndex = newIndex;
    _indexController.add(newIndex);

    if (_isDesktop) {
      try {
        if (wasPlaying) {
          await playWithQueue(newQueue, newIndex, autoPlay: true);
        } else {
          await playWithQueue(newQueue, newIndex, autoPlay: false);
        }
      } catch (e) {
        print("Desktop update error: $e");
      }
      return;
    }

    try {
      final source = _player.audioSource as ConcatenatingAudioSource?;
      if (source == null) {
        await playWithQueue(newQueue, newIndex, autoPlay: wasPlaying);
        return;
      }

      final currentSourceIndex = _player.currentIndex ?? 0;

      if (currentSourceIndex < source.length - 1) {
        await source.removeRange(currentSourceIndex + 1, source.length);
      }

      if (currentSourceIndex > 0) {
        await source.removeRange(0, currentSourceIndex);
      }

      final preSongs = newQueue.sublist(0, newIndex);
      if (preSongs.isNotEmpty) {
        final preSources = preSongs.map((s) => _createAudioSource(s)).toList();
        await source.insertAll(0, preSources);
      }

      final postSongs = newQueue.sublist(newIndex + 1);
      if (postSongs.isNotEmpty) {
        final postSources = postSongs
            .map((s) => _createAudioSource(s))
            .toList();
        await source.addAll(postSources);
      }

      print("Hot loaded new play list");

      if (!wasPlaying && _player.playing) {
        await _player.pause();
      }
    } catch (e) {
      print("Error updating playlist: $e");
      await playWithQueue(newQueue, newIndex, autoPlay: wasPlaying);
    }
  }

  Future<void> pause() async => await _player.pause();

  Future<void> resume() async => await _player.play();

  Future<void> stop() async => await _player.stop();

  Future<void> playNext() async {
    if (_isDesktop) {
      if (_currentIndex < _globalQueue.length - 1) {
        await playWithQueue(_globalQueue, _currentIndex + 1);
      }
    } else {
      if (_player.hasNext) await _player.seekToNext();
    }
  }

  Future<void> playPrevious() async {
    if (_isDesktop) {
      if (_currentIndex > 0) {
        await playWithQueue(_globalQueue, _currentIndex - 1);
      }
    } else {
      if (_player.hasPrevious) await _player.seekToPrevious();
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing)
      await _player.pause();
    else
      await _player.play();
  }

  // 【核心修改】智能清理逻辑
  Future<void> _performStrictCleanup() async {
    if (_isDesktop) return;

    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      final dbMetas = await _dbService.getAllCacheMeta();
      final Map<String, Map<String, dynamic>> metaMap = {
        for (var m in dbMetas) m['key']: m,
      };
      final List<FileSystemEntity> entities = dir.listSync();
      List<_CacheItem> cacheItems = [];
      int totalSize = 0;

      for (var entity in entities) {
        if (entity is File) {
          final filename = entity.path.split(Platform.pathSeparator).last;
          if (filename.startsWith('song_')) {
            try {
              final stat = await entity.stat();
              final size = stat.size;
              totalSize += size;
              String key = filename.replaceFirst('song_', '');
              if (key.contains('.')) {
                key = key.substring(0, key.lastIndexOf('.'));
              }

              int hits = 0;
              int lastAccess = stat.modified.millisecondsSinceEpoch;

              if (metaMap.containsKey(key)) {
                hits = metaMap[key]!['hit_count'] ?? 1;
                lastAccess = metaMap[key]!['last_access_time'] ?? lastAccess;
              }

              cacheItems.add(
                _CacheItem(
                  file: entity,
                  key: key,
                  size: size,
                  hitCount: hits,
                  dbLastAccess: lastAccess,
                ),
              );
            } catch (e) {
            }
          }
        }
      }

      if (totalSize <= _maxCacheSize) return;

      print(
        "Smart Cleanup: Current usage ${(totalSize / 1024 / 1024).toStringAsFixed(2)}MB",
      );
      cacheItems.sort((a, b) => a.retentionScore.compareTo(b.retentionScore));

      final currentBvid = currentSong?.bvid;
      for (var item in cacheItems) {
        if (totalSize <= _maxCacheSize) break;
        String? bvid;
        try {
          final parts = item.key.split('_');
          if (parts.isNotEmpty) bvid = parts[0];
        } catch (_) {}
        if (bvid != null) {
          if (bvid == currentBvid) continue;
          if (_proxy.isBvidDownloading(bvid)) continue;
        }

        if (await _tryDeleteFile(item.file)) {
          totalSize -= item.size;
          await _dbService.removeCacheMeta(item.key);
          print(
            "Evicted: ${item.key} (Hits: ${item.hitCount}, Score: ${item.retentionScore.toStringAsFixed(1)})",
          );
        }
      }

      print(
        "Cleanup finished. Now: ${(totalSize / 1024 / 1024).toStringAsFixed(2)}MB",
      );
    } catch (e) {
      print("Strict cleanup error: $e");
    }
  }

  Future<bool> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<int> getUsedCacheSize() async {
    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      final List<FileSystemEntity> entities = dir.listSync();

      for (var entity in entities) {
        if (entity is File) {
          final filename = entity.path.split(Platform.pathSeparator).last;
          if (filename.startsWith('song_')) {
            try {
              totalSize += await entity.length();
            } catch (e) {}
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
  Future<void> clearCache() async {
    try {
      await stop();

      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final List<FileSystemEntity> entities = dir.listSync();
          for (var entity in entities) {
            if (entity is File) {
              await _tryDeleteFile(entity);
            }
          }
        } catch (_) {}
      }

      await _dbService.clearCacheMetaTable();
      print("All audio cache and metadata cleared.");
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  void dispose() {
    _player.dispose();
    _proxy.stop();
    _indexController.close();
    _playbackErrorController.close();
  }
}
