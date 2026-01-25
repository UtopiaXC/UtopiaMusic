import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/audio/bili_audio_source.dart';
import 'package:utopia_music/services/download_manager.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static const String _defaultAudioQualityKey = 'default_audio_quality';

  int _preferredQuality = 30280;

  factory AudioPlayerService() => _instance;

  final DatabaseService _dbService = DatabaseService();
  final DownloadManager _downloadManager = DownloadManager();
  final AudioPlayer _player = AudioPlayer();

  List<Song> _globalQueue = [];
  int _currentIndex = 0;
  bool _autoSkipInvalid = true;
  bool _isHandlingError = false;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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
      } else {
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
      return;
    }

    _isHandlingError = true;
    try {
      print("AudioPlayerService: 自动跳过失效资源...");
      await playNext();
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
      }) async {
    try {
      _globalQueue = queue;
      _currentIndex = index;
      _indexController.add(index);

      if (_isDesktop) {
        await _playSingleDesktop(index, autoPlay: autoPlay);
      } else {
        await _playListMobile(queue, index, autoPlay: autoPlay);
      }

    } catch (e) {
      print("Error setting audio source: $e");
    }
  }

  Future<void> _playListMobile(List<Song> queue, int index, {bool autoPlay = true}) async {
    final List<AudioSource> sources = queue
        .map((s) => _createAudioSource(s))
        .toList();

    final playlist = ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );

    try {
      await _player.setAudioSource(playlist, initialIndex: index);
      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      print("Set Audio Source Error (Mobile): $e");
      await _handleInvalidResourceAndPlayNext();
    }
  }

  Future<void> _playSingleDesktop(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= _globalQueue.length) return;

    final song = _globalQueue[index];
    final source = _createAudioSource(song);

    try {
      await _player.setAudioSource(source);
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

    bool wasPlaying = _player.playing;
    _globalQueue = newQueue;
    _currentIndex = newIndex;

    if (_isDesktop) {
      _indexController.add(newIndex);
    } else {
      await playWithQueue(newQueue, newIndex, autoPlay: wasPlaying);
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

  void dispose() {
    _player.dispose();
    _indexController.close();
    _playbackErrorController.close();
  }

  Future<int> getMaxCacheSize() async {
    return await _downloadManager.getMaxCacheSize();
  }

  Future<void> setMaxCacheSize(int sizeMb) async {
    await _downloadManager.setMaxCacheSize(sizeMb);
  }
}