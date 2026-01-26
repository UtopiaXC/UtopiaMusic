import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/audio/bili_audio_source.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static const String _defaultAudioQualityKey = 'default_audio_quality';
  final StreamController<int> _actualQualityController =
      StreamController<int>.broadcast();

  Stream<int> get actualQualityStream => _actualQualityController.stream;

  int _preferredQuality = 30280;

  factory AudioPlayerService() => _instance;

  final DatabaseService _dbService = DatabaseService();
  final DownloadManager _downloadManager = DownloadManager();
  final AudioPlayer _player = AudioPlayer();

  List<Song> _globalQueue = [];
  int _currentIndex = 0;
  bool _autoSkipInvalid = true;
  bool _isHandlingError = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final StreamController<int> _indexController =
      StreamController<int>.broadcast();

  Stream<int> get currentIndexStream => _indexController.stream;

  final StreamController<Map<String, dynamic>> _playbackErrorController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get playbackErrorStream =>
      _playbackErrorController.stream;

  List<Song> get queue => List.unmodifiable(_globalQueue);

  AudioPlayerService._internal() {
    _init();

    _player.currentIndexStream.listen((index) {
      if (!_isDesktop && index != null) {
        _currentIndex = index;
        _indexController.add(index);
      }
    });

    _player.playerStateStream.listen((state) {
      if (_isDesktop && state.processingState == ProcessingState.completed) {
        _handleDesktopAutoNext();
      }
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        print('AudioPlayerService: 捕获到播放器底层错误: $e');
        _handleInvalidResourceAndPlayNext();
      },
    );
  }

  void _handleDesktopAutoNext() {
    if (_player.loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      if (_currentIndex < _globalQueue.length - 1) {
        playNext();
      } else if (_player.loopMode == LoopMode.all) {
        playWithQueue(_globalQueue, 0);
      }
    }
  }

  void setAutoSkipInvalid(bool enable) {
    _autoSkipInvalid = enable;
  }

  void notifyPlaybackError(String bvid, int cid) {
    print("AudioPlayerService: 报告资源无效 ($bvid)");
    _playbackErrorController.add({'bvid': bvid, 'cid': cid});
    Future.microtask(() => _handleInvalidResourceAndPlayNext());
  }

  Future<void> _handleInvalidResourceAndPlayNext() async {
    if (_isHandlingError) return;

    final prefs = await SharedPreferences.getInstance();
    _autoSkipInvalid = prefs.getBool(PlayerProvider.autoSkipInvalidKey) ?? true;

    if (!_autoSkipInvalid) {
      await stop();
      final context = navigatorKey.currentContext;
      if (context != null) {
        Future.delayed(Duration.zero, () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('资源无效'),
              content: const Text(
                '当前请求的资源由于网络、版权原因或充电视频等无法播放，已停止播放。\n\n此后是否自动跳过并清理无效资源？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    await prefs.setBool(
                      PlayerProvider.autoSkipInvalidKey,
                      true,
                    );
                    _autoSkipInvalid = true;
                    try {
                      Provider.of<PlayerProvider>(
                        context,
                        listen: false,
                      ).setAutoSkipInvalid(true);
                    } catch (e) {
                      print("Failed to sync provider state: $e");
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('确认'),
                ),
              ],
            ),
          );
        });
      }
      return;
    }

    _isHandlingError = true;
    try {
      print("AudioPlayerService: 等待 PlayerProvider 处理失效资源...");
    } catch (e) {
      print("Error during auto-skip: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      _isHandlingError = false;
    }
  }

  Future<void> _init() async {
    await _loadSettings();
    await _downloadManager.init();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _preferredQuality = prefs.getInt(_defaultAudioQualityKey) ?? 30280;
  }

  Future<int> getMaxCacheSize() async {
    return await _downloadManager.getMaxCacheSize();
  }

  Future<void> setMaxCacheSize(int sizeMb) async {
    await _downloadManager.setMaxCacheSize(sizeMb);
  }

  void setPreferredQuality(int quality) {
    _preferredQuality = quality;
  }

  AudioPlayer get player => _player;

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _globalQueue.length)
      ? _globalQueue[_currentIndex]
      : null;

  AudioSource _createAudioSource(Song song) {
    return BiliAudioSource(
      bvid: song.bvid,
      initCid: song.cid,
      title: song.title,
      artist: song.artist,
      coverUrl: song.coverUrl,
      quality: _preferredQuality,
    );
  }

  Future<void> playSong(Song song) async {
    await playWithQueue([song], 0);
  }

  Future<void> playWithQueue(
    List<Song> queue,
    int index, {
    bool autoPlay = true,
    Duration? initialPosition,
  }) async {
    try {
      _globalQueue = queue;
      _currentIndex = index;
      _indexController.add(index);

      if (_isDesktop) {
        await _playSingleDesktop(
          index,
          autoPlay: autoPlay,
          initialPosition: initialPosition,
        );
      } else {
        await _playListMobile(
          queue,
          index,
          autoPlay: autoPlay,
          initialPosition: initialPosition,
        );
      }
    } catch (e) {
      print("Error setting audio source: $e");
    }
  }

  Future<void> _playListMobile(
    List<Song> queue,
    int index, {
    bool autoPlay = true,
    Duration? initialPosition,
  }) async {
    final List<AudioSource> sources = queue
        .map((s) => _createAudioSource(s))
        .toList();

    final playlist = ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );

    try {
      await _player.setAudioSource(
        playlist,
        initialIndex: index,
        initialPosition: initialPosition,
      );
      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      print("Set Audio Source Error (Mobile): $e");
      await _handleInvalidResourceAndPlayNext();
    }
  }

  Future<void> _playSingleDesktop(
    int index, {
    bool autoPlay = true,
    Duration? initialPosition,
  }) async {
    if (index < 0 || index >= _globalQueue.length) return;

    final song = _globalQueue[index];
    final source = _createAudioSource(song);

    try {
      await _player.setAudioSource(source, initialPosition: initialPosition);
      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      print("Set Audio Source Error (Desktop): $e");
      await _handleInvalidResourceAndPlayNext();
    }
  }

  Future<void> updateQueueKeepPlaying(List<Song> newQueue, int newIndex) async {
    if (newQueue.isEmpty) {
      _globalQueue = [];
      await stop();
      return;
    }

    if (_isDesktop) {
      bool wasPlaying = _player.playing;
      _globalQueue = newQueue;
      _currentIndex = newIndex;
      _indexController.add(newIndex);
      return;
    }

    try {
      final playlist = _player.audioSource as ConcatenatingAudioSource?;
      final currentSong = this.currentSong;
      if (playlist == null || currentSong == null) {
        await playWithQueue(
            newQueue,
            newIndex,
            autoPlay: _player.playing,
            initialPosition: _player.position
        );
        return;
      }

      final targetSong = newQueue[newIndex];
      if (targetSong.bvid != currentSong.bvid || targetSong.cid != currentSong.cid) {
        await playWithQueue(
            newQueue,
            newIndex,
            autoPlay: _player.playing,
            initialPosition: _player.position
        );
        return;
      }
      final songsBefore = newQueue.sublist(0, newIndex);
      final songsAfter = newQueue.sublist(newIndex + 1);

      final sourcesBefore = songsBefore.map((s) => _createAudioSource(s)).toList();
      final sourcesAfter = songsAfter.map((s) => _createAudioSource(s)).toList();
      final playerIndex = _player.currentIndex;
      if (playerIndex == null) throw Exception("Player index is null");
      if (playerIndex < playlist.length - 1) {
        await playlist.removeRange(playerIndex + 1, playlist.length);
      }
      if (playerIndex > 0) {
        await playlist.removeRange(0, playerIndex);
      }
      if (sourcesBefore.isNotEmpty) {
        await playlist.insertAll(0, sourcesBefore);
      }
      if (sourcesAfter.isNotEmpty) {
        await playlist.addAll(sourcesAfter);
      }

      _globalQueue = newQueue;
      _currentIndex = newIndex;

      print("Hot swap playlist completed successfully.");

    } catch (e) {
      print("Hot swap failed, falling back to reload: $e");
      await playWithQueue(
          newQueue,
          newIndex,
          autoPlay: _player.playing,
          initialPosition: _player.position
      );
    }
  }

  Future<void> pause() async => await _player.pause();

  Future<void> resume() async => await _player.play();

  Future<void> stop() async => await _player.stop();

  Future<void> playNext() async {
    if (_isDesktop) {
      if (_currentIndex < _globalQueue.length - 1) {
        _currentIndex++;
        _indexController.add(_currentIndex);
        await _playSingleDesktop(_currentIndex);
      } else {
        if (_player.loopMode == LoopMode.all) {
          _currentIndex = 0;
          _indexController.add(0);
          await _playSingleDesktop(0);
        }
      }
    } else {
      if (_player.hasNext) {
        await _player.seekToNext();
      }
    }
  }

  Future<void> playPrevious() async {
    if (_isDesktop) {
      if (_currentIndex > 0) {
        _currentIndex--;
        _indexController.add(_currentIndex);
        await _playSingleDesktop(_currentIndex);
      }
    } else {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<int> getUsedCacheSize() async {
    return await _downloadManager.getUsedCacheSize();
  }

  Future<void> clearCache() async {
    await stop();
    await _downloadManager.clearAllCache();
    print("All audio cache and metadata cleared via DownloadManager.");
  }

  void notifyActualQuality(int quality) {
    _actualQualityController.add(quality);
  }

  Future<void> switchQuality(int newQuality) async {
    if (_preferredQuality == newQuality) return;

    print("AudioPlayerService: Switching quality to $newQuality...");
    _preferredQuality = newQuality;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultAudioQualityKey, newQuality);

    if (_globalQueue.isEmpty) return;
    final currentPos = _player.position;
    final wasPlaying = _player.playing;
    final currentIndex = _currentIndex;

    try {
      if (_isDesktop) {
        await _player.stop();

        final song = _globalQueue[currentIndex];
        final source = _createAudioSource(song);

        await _player.setAudioSource(source, initialPosition: currentPos);

        if (wasPlaying) {
          await _player.play();
        }
      } else {
        await _player.stop();

        final List<AudioSource> sources = _globalQueue
            .map((s) => _createAudioSource(s))
            .toList();

        final playlist = ConcatenatingAudioSource(
          children: sources,
          useLazyPreparation: true,
        );

        await _player.setAudioSource(
          playlist,
          initialIndex: currentIndex,
          initialPosition: currentPos,
        );

        if (wasPlaying) {
          await _player.play();
        }
      }
      print("Quality switched successfully.");
    } catch (e) {
      print("Switch quality failed: $e");
    }
  }

  void dispose() {
    _player.dispose();
    _indexController.close();
    _playbackErrorController.close();
    _actualQualityController.close();
  }
}
