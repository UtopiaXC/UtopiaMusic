import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/services/download_manager.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DatabaseService _databaseService = DatabaseService();
  final VideoDetailApi _videoDetailApi = VideoDetailApi();


  List<Song> _playlist = [];
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isBuffering = false;

  bool _isPlayerExpanded = false;
  bool _showFullPlayer = false;

  PlayMode _playMode = PlayMode.sequence;
  bool _saveProgress = true;
  bool _autoPlay = false;
  bool _autoSkipInvalid = true;

  bool _recommendationAutoPlay = false;
  bool _isRecommendationLoading = false;

  Timer? _progressSaveTimer;
  Timer? _stopTimer;
  Timer? _expandTimer;
  DateTime? _stopTime;
  bool _stopAfterCurrent = false;

  int _currentPlayingQuality = 30280;
  int get currentPlayingQuality => _currentPlayingQuality;

  static const String _playModeKey = 'play_mode';
  static const String _lastPlayedIndexKey = 'last_played_index';
  static const String _lastPlayedBvidKey = 'last_played_bvid';
  static const String _lastPlayedCidKey = 'last_played_cid';
  static const String _lastPlayedPositionKey = 'last_played_position';
  static const String _saveProgressKey = 'save_progress';
  static const String _autoPlayKey = 'auto_play';
  static const String _autoSkipInvalidKey = 'auto_skip_invalid';
  static const String _recommendationAutoPlayKey = 'recommendation_auto_play';
  static const String _defaultAudioQualityKey = 'default_audio_quality';

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get showFullPlayer => _showFullPlayer;
  PlayMode get playMode => _playMode;
  bool get saveProgress => _saveProgress;
  bool get autoPlay => _autoPlay;
  bool get autoSkipInvalid => _autoSkipInvalid;
  bool get recommendationAutoPlay => _recommendationAutoPlay;
  bool get isRecommendationLoading => _isRecommendationLoading;
  bool get isTimerActive => _stopTimer != null;
  DateTime? get stopTime => _stopTime;
  bool get stopAfterCurrent => _stopAfterCurrent;

  int get decoderType => 0;

  static String get autoSkipInvalidKey => _autoSkipInvalidKey;
  AudioPlayer get player => _audioPlayerService.player;

  PlayerProvider() {
    _init();
    _bindPlayerEvents();
  }

  void _bindPlayerEvents() {
    player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;

      bool newIsPlaying = playing && processingState != ProcessingState.completed;
      bool newIsBuffering = processingState == ProcessingState.buffering || processingState == ProcessingState.loading;

      if (_isPlaying != newIsPlaying || _isBuffering != newIsBuffering) {
        _isPlaying = newIsPlaying;
        _isBuffering = newIsBuffering;
        notifyListeners();

        if (_isPlaying) {
          _startProgressTimer();
        } else {
          _stopProgressTimer();
          _saveCurrentProgress();
        }
      }

      if (processingState == ProcessingState.completed) {
        if (_stopAfterCurrent && isTimerActive && _stopTime != null && DateTime.now().isAfter(_stopTime!)) {
          cancelStopTimer();
          _audioPlayerService.stop();
        }
      }
    });

    _audioPlayerService.currentIndexStream.listen((index) {
      if (index >= 0 && index < _playlist.length) {
        final newSong = _playlist[index];
        if (_currentSong?.bvid != newSong.bvid || _currentSong?.cid != newSong.cid) {
          _onSongChanged(newSong);
        }
      }
    });

    _audioPlayerService.playbackErrorStream.listen((error) {
      _handlePlaybackError(error);
    });

    _audioPlayerService.actualQualityStream.listen((quality) {
      if (_currentPlayingQuality != quality) {
        _currentPlayingQuality = quality;
        notifyListeners();
      }
    });
  }

  Future<void> _init() async {
    await DownloadManager().init();
    await _loadSettings();
    await _reloadPlaylistFromDb();
    await _restoreLastPlaybackState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    int modeIndex = prefs.getInt(_playModeKey) ?? 0;
    if (modeIndex >= 0 && modeIndex < PlayMode.values.length) {
      _playMode = PlayMode.values[modeIndex];
    }

    _saveProgress = prefs.getBool(_saveProgressKey) ?? true;
    _autoPlay = prefs.getBool(_autoPlayKey) ?? false;
    _autoSkipInvalid = prefs.getBool(_autoSkipInvalidKey) ?? true;
    _recommendationAutoPlay = prefs.getBool(_recommendationAutoPlayKey) ?? false;

    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    int quality = prefs.getInt(_defaultAudioQualityKey) ?? 30280;
    _audioPlayerService.setPreferredQuality(quality);

    notifyListeners();
  }

  Future<void> _onSongChanged(Song newSong) async {
    _currentSong = newSong;
    notifyListeners();
    _databaseService.recordCacheAccess(newSong.bvid, newSong.cid, 30280);

    final prefs = await SharedPreferences.getInstance();
    int index = _playlist.indexOf(newSong);
    if (index != -1) {
      await prefs.setInt(_lastPlayedIndexKey, index);
    }
    await prefs.setString(_lastPlayedBvidKey, newSong.bvid);
    await prefs.setInt(_lastPlayedCidKey, newSong.cid);

    if (_recommendationAutoPlay) {
      _handleRecommendationAutoPlay(newSong);
    }
  }

  Future<void> _handlePlaybackError(Map<String, dynamic> error) async {
    if (!_autoSkipInvalid) return;

    final String bvid = error['bvid'] ?? '';
    final int cid = error['cid'] ?? 0;

    int index = _playlist.indexWhere((s) => s.bvid == bvid && (cid == 0 || s.cid == 0 || s.cid == cid));

    if (index != -1) {
      print("PlayerProvider: Removing invalid song from playlist: $bvid / $cid");
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发现无效资源，可能是网络问题、版权视频或充电视频，已自动跳过并清理。'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await removeSong(index);
    }
  }

  Future<void> _handleRecommendationAutoPlay(Song currentSong) async {
    if (_isRecommendationLoading) return;
    if (_playlist.isEmpty) return;

    _isRecommendationLoading = true;
    notifyListeners();

    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final related = await _videoDetailApi.getRelatedVideos(context, currentSong.bvid);

      if (_currentSong?.bvid != currentSong.bvid) return;

      if (related.isNotEmpty) {
        List<Song> newPlaylist = [currentSong, ...related];
        final Set<String> seen = { '${currentSong.bvid}_${currentSong.cid}' };
        List<Song> deduped = [currentSong];
        for (var s in related) {
          final key = '${s.bvid}_${s.cid}';
          if (!seen.contains(key)) {
            seen.add(key);
            deduped.add(s);
          }
        }
        newPlaylist = deduped;

        await _databaseService.replacePlaylist(newPlaylist);
        await _reloadPlaylistFromDb();

        int newIndex = _playlist.indexWhere((s) => s.bvid == currentSong.bvid && s.cid == currentSong.cid);
        if (newIndex == -1) newIndex = 0;

        await _audioPlayerService.updateQueueKeepPlaying(_playlist, newIndex);
      }
    } catch (e) {
      print("Recommendation AutoPlay Error: $e");
    } finally {
      _isRecommendationLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadPlaylistFromDb() async {
    bool shuffle = _playMode == PlayMode.shuffle;
    _playlist = await _databaseService.getPlaylist(isShuffleMode: shuffle);
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    int index = _playlist.indexWhere((s) => s.bvid == song.bvid && s.cid == song.cid);
    if (index != -1) {
      if (_currentSong?.bvid == song.bvid && _currentSong?.cid == song.cid && _isPlaying) {
        return;
      }
      await _startPlay(index);
    } else {
      await setPlaylistAndPlay([song], song);
    }
  }

  Future<void> setPlaylistAndPlay(List<Song> songs, Song initialSong) async {
    try {
      List<Song> newSongs = List.from(songs);

      int existingIndex = newSongs.indexWhere((s) {
        if (s.bvid != initialSong.bvid) return false;
        if (s.cid == 0 || initialSong.cid == 0) return true;
        return s.cid == initialSong.cid;
      });

      if (existingIndex != -1) {
        newSongs[existingIndex] = initialSong;
      } else {
        newSongs.insert(0, initialSong);
      }

      await _databaseService.replacePlaylist(newSongs);
      await _reloadPlaylistFromDb();

      int index = _playlist.indexWhere((s) {
        if (s.bvid != initialSong.bvid) return false;
        if (s.cid == 0 || initialSong.cid == 0) return true;
        return s.cid == initialSong.cid;
      });

      if (index == -1) index = 0;

      await _startPlay(index);
      expandPlayer();
      notifyListeners();
    } catch (e) {
      print("setPlaylistAndPlay error: $e");
    }
  }

  Future<void> insertNext(Song song) async {
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: _currentSong);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> insertNextAndPlay(Song song) async {
    await insertNext(song);
    if (hasNext) {
      await playNext();
    }
  }

  Future<void> addToEnd(Song song) async {
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: null);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> replacePlaylistWithSong(Song song) async {
    await setPlaylistAndPlay([song], song);
  }

  Future<void> removeSong(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    Song songToRemove = _playlist[index];

    await _databaseService.removeSong(songToRemove.bvid, songToRemove.cid);
    await _reloadPlaylistFromDb();

    bool isCurrent = _currentSong != null &&
        _currentSong!.bvid == songToRemove.bvid &&
        (_currentSong!.cid == 0 || songToRemove.cid == 0 || _currentSong!.cid == songToRemove.cid);

    if (isCurrent) {
      if (_playlist.isEmpty) {
        await closePlayer();
      } else {
        int nextIndex = index;
        if (nextIndex >= _playlist.length) nextIndex = 0;

        await _audioPlayerService.playWithQueue(_playlist, nextIndex, autoPlay: true);
      }
    } else {
      await _syncPlayerQueue();
    }
  }

  Future<void> reorderPlaylist(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    bool shuffle = _playMode == PlayMode.shuffle;
    await _databaseService.reorderPlaylist(oldIndex, newIndex, shuffle);
    await _reloadPlaylistFromDb();

    if (_currentSong != null) {
      int newCurrentIndex = _playlist.indexWhere((s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid);
      if (newCurrentIndex != -1) {
        await _audioPlayerService.updateQueueKeepPlaying(_playlist, newCurrentIndex);
      }
    }
  }

  Future<void> clearPlaylist() async {
    await _databaseService.clearPlaylist();
    await closePlayer();
  }

  Future<void> _syncPlayerQueue() async {
    if (_currentSong == null) return;
    int currentIndex = _playlist.indexWhere((s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid);
    if (currentIndex != -1) {
      await _audioPlayerService.updateQueueKeepPlaying(_playlist, currentIndex);
    } else if (_playlist.isNotEmpty) {
      await _audioPlayerService.playWithQueue(_playlist, 0);
    }
  }

  Future<void> _startPlay(int index) async {
    _currentSong = _playlist[index];
    await _audioPlayerService.playWithQueue(_playlist, index, autoPlay: true);
    await _setPlayerLoopMode();
  }

  Future<void> togglePlayMode() async {
    if (_recommendationAutoPlay) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前处于随机连播，无法切换模式。请先关闭连播。')),
        );
      }
      return;
    }
    final oldMode = _playMode;
    int nextIndex = (_playMode.index + 1) % PlayMode.values.length;
    final newMode = PlayMode.values[nextIndex];
    _playMode = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
    bool isOrderChanged = (oldMode == PlayMode.shuffle) || (newMode == PlayMode.shuffle);

    if (isOrderChanged) {
      await _reloadPlaylistFromDb();

      if (_currentSong != null) {
        int newIndex = _playlist.indexWhere((s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid);
        if (newIndex != -1) {
          await _audioPlayerService.updateQueueKeepPlaying(_playlist, newIndex);
        } else if (_playlist.isNotEmpty) {
          await _startPlay(0);
        }
      }
    } else {
      notifyListeners();
    }

    await _setPlayerLoopMode();
  }

  Future<void> _setPlayerLoopMode() async {
    await player.setShuffleModeEnabled(false);
    switch (_playMode) {
      case PlayMode.single:
        await player.setLoopMode(LoopMode.one);
        break;
      case PlayMode.sequence:
        await player.setLoopMode(LoopMode.off);
        break;
      case PlayMode.loop:
      case PlayMode.shuffle:
        await player.setLoopMode(LoopMode.all);
        break;
    }
  }

  Future<void> setRecommendationAutoPlay(bool value) async {
    _recommendationAutoPlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationAutoPlayKey, value);
    notifyListeners();
    if (value && _currentSong != null) {
      _handleRecommendationAutoPlay(_currentSong!);
    }
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    if (!_saveProgress) return;
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        _saveCurrentProgress();
      }
    });
  }

  void _stopProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  Future<void> setSaveProgress(bool value) async {
    _saveProgress = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveProgressKey, value);
    notifyListeners();
    if (value && _isPlaying) {
      _startProgressTimer();
    } else {
      _stopProgressTimer();
    }
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, value);
    notifyListeners();
  }

  Future<void> setAutoSkipInvalid(bool value) async {
    _autoSkipInvalid = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSkipInvalidKey, value);
    _audioPlayerService.setAutoSkipInvalid(value);
    notifyListeners();
  }

  void setDecoderType(int type) {
    notifyListeners();
  }

  Future<void> _saveCurrentProgress() async {
    if (_currentSong == null) return;
    final position = player.position.inMilliseconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPlayedPositionKey, position);
  }

  Future<void> _restoreLastPlaybackState() async {
    if (_playlist.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastBvid = prefs.getString(_lastPlayedBvidKey);
    final lastCid = prefs.getInt(_lastPlayedCidKey);
    final lastPosition = prefs.getInt(_lastPlayedPositionKey) ?? 0;

    int initialIndex = 0;
    if (lastBvid != null) {
      initialIndex = _playlist.indexWhere((s) => s.bvid == lastBvid && s.cid == lastCid);
    }

    if (initialIndex == -1) {
      int savedIndex = prefs.getInt(_lastPlayedIndexKey) ?? 0;
      if (savedIndex >= 0 && savedIndex < _playlist.length) {
        initialIndex = savedIndex;
      } else {
        initialIndex = 0;
      }
    }

    _currentSong = _playlist[initialIndex];
    _showFullPlayer = true;

    try {
      await _audioPlayerService.playWithQueue(_playlist, initialIndex, autoPlay: _autoPlay);
      if (_saveProgress && lastPosition > 0) {
        await player.seek(Duration(milliseconds: lastPosition));
      }
      await _setPlayerLoopMode();
    } catch (e) {
      print("Restore playback error: $e");
    }
  }

  Future<void> playNext() async => await _audioPlayerService.playNext();
  Future<void> playPrevious() async => await _audioPlayerService.playPrevious();
  Future<void> togglePlayPause() async => await _audioPlayerService.togglePlayPause();
  Future<void> seek(Duration position) async => await player.seek(position);

  void expandPlayer() {
    _expandTimer?.cancel();
    _showFullPlayer = true;
    notifyListeners();
    _expandTimer = Timer(const Duration(milliseconds: 50), () {
      _isPlayerExpanded = true;
      notifyListeners();
    });
  }

  void collapsePlayer() {
    _expandTimer?.cancel();
    _isPlayerExpanded = false;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isPlayerExpanded) {
        _showFullPlayer = false;
        notifyListeners();
      }
    });
  }

  void togglePlayerExpansion() {
    if (_isPlayerExpanded) {
      collapsePlayer();
    } else {
      expandPlayer();
    }
  }

  Future<void> closePlayer() async {
    await _audioPlayerService.stop();
    _currentSong = null;
    _playlist = [];
    await _databaseService.clearPlaylist();
    _isPlaying = false;
    _showFullPlayer = false;
    _isPlayerExpanded = false;

    _stopProgressTimer();
    cancelStopTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPlayedBvidKey);
    await prefs.remove(_lastPlayedPositionKey);

    notifyListeners();
  }

  void setStopTimer(Duration duration, {bool stopAfterCurrent = false}) {
    cancelStopTimer();
    _stopTime = DateTime.now().add(duration);
    _stopAfterCurrent = stopAfterCurrent;

    _stopTimer = Timer(duration, () {
      if (!_stopAfterCurrent) {
        _audioPlayerService.stop();
        cancelStopTimer();
      }
    });
    notifyListeners();
  }

  void setStopTime(DateTime time, {bool stopAfterCurrent = false}) {
    final now = DateTime.now();
    final duration = time.difference(now);
    if (duration.isNegative) {
      cancelStopTimer();
      return;
    }
    setStopTimer(duration, stopAfterCurrent: stopAfterCurrent);
  }

  void cancelTimer() => cancelStopTimer();

  void cancelStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _stopTime = null;
    _stopAfterCurrent = false;
    notifyListeners();
  }

  Future<void> clearAllCache() async {
    await _audioPlayerService.clearCache();
  }

  Future<void> resetToDefaults() async {
    _playMode = PlayMode.sequence;
    _saveProgress = true;
    _autoPlay = false;
    _autoSkipInvalid = true;
    _recommendationAutoPlay = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
    await prefs.setBool(_saveProgressKey, _saveProgress);
    await prefs.setBool(_autoPlayKey, _autoPlay);
    await prefs.setBool(_autoSkipInvalidKey, _autoSkipInvalid);
    await prefs.setBool(_recommendationAutoPlayKey, _recommendationAutoPlay);

    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    _audioPlayerService.setPreferredQuality(30280);

    notifyListeners();
  }

  bool get hasNext {
    if (_playlist.isEmpty || _currentSong == null) return false;
    int index = _playlist.indexOf(_currentSong!);
    return index < _playlist.length - 1;
  }

  bool get hasPrevious {
    if (_playlist.isEmpty || _currentSong == null) return false;
    int index = _playlist.indexOf(_currentSong!);
    return index > 0;
  }

  @override
  void dispose() {
    _stopProgressTimer();
    _stopTimer?.cancel();
    _expandTimer?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}