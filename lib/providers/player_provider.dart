import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/providers/player/managers/history_manager.dart';
import 'package:utopia_music/providers/player/managers/recommendation_manager.dart';
import 'package:utopia_music/providers/player/managers/sleep_timer_manager.dart';

const String _tag = "PLAYER_PROVIDER";

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DatabaseService _databaseService = DatabaseService();
  late final HistoryManager _historyManager;
  late final RecommendationManager _recommendationManager;
  late final SleepTimerManager _sleepTimerManager;
  List<Song> _playlist = [];
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isBuffering = false;
  int _currentPlayingQuality = 30280;
  bool _isPlayerExpanded = false;
  bool _showFullPlayer = false;
  Timer? _expandTimer;
  PlayMode _playMode = PlayMode.sequence;
  bool _saveProgress = true;
  bool _autoPlay = false;
  bool _autoSkipInvalid = true;

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

  int get currentPlayingQuality => _currentPlayingQuality;

  AudioPlayer get player => _audioPlayerService.player;

  bool get recommendationAutoPlay => _recommendationManager.isEnabled;

  bool get isRecommendationLoading => _recommendationManager.isLoading;

  bool get isTimerActive => _sleepTimerManager.isActive;

  DateTime? get stopTime => _sleepTimerManager.stopTime;

  bool get stopAfterCurrent => _sleepTimerManager.stopAfterCurrent;

  static const String _playModeKey = 'play_mode';
  static const String _saveProgressKey = 'save_progress';
  static const String _autoPlayKey = 'auto_play';
  static const String _autoSkipInvalidKey = 'auto_skip_invalid';
  static const String _lastPlayedIndexKey = 'last_played_index';
  static const String _lastPlayedBvidKey = 'last_played_bvid';
  static const String _lastPlayedCidKey = 'last_played_cid';
  static const String _lastPlayedPositionKey = 'last_played_position';
  static const String _defaultAudioQualityKey = 'default_audio_quality';

  static String get autoSkipInvalidKey => _autoSkipInvalidKey;

  PlayerProvider() {
    _initManagers();
    _init();
    _bindPlayerEvents();
  }

  void _initManagers() {
    Log.v(_tag, "_initManagers");
    _historyManager = HistoryManager(
      getCurrentPositionSeconds: () =>
          _audioPlayerService.player.position.inSeconds,
      getCurrentPositionMilliseconds: () =>
          _audioPlayerService.player.position.inMilliseconds,
    );
    _recommendationManager = RecommendationManager(
      onPlaylistUpdate: (newPlaylist) async {
        Log.i(
          _tag,
          "onPlaylistUpdate: newPlaylist length = ${newPlaylist.length}",
        );
        await _databaseService.replacePlaylist(newPlaylist);
        await _reloadPlaylistFromDb();
        if (_currentSong != null) {
          int currentIndex = _playlist.indexWhere(
            (s) =>
                s.bvid == _currentSong!.bvid &&
                (s.cid == _currentSong!.cid ||
                    s.cid == 0 ||
                    _currentSong!.cid == 0),
          );
          if (currentIndex == -1) currentIndex = 0;
          await _audioPlayerService.updateQueueKeepPlaying(
            _playlist,
            currentIndex,
          );
        }
      },
    );

    _sleepTimerManager = SleepTimerManager(
      audioPlayerService: _audioPlayerService,
      notifyListeners: notifyListeners,
    );
  }

  void _bindPlayerEvents() {
    Log.v(_tag, "_bindPlayerEvents");
    player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;

      bool newIsPlaying =
          playing && processingState != ProcessingState.completed;
      bool newIsBuffering =
          processingState == ProcessingState.buffering ||
          processingState == ProcessingState.loading;

      if (_isPlaying != newIsPlaying || _isBuffering != newIsBuffering) {
        _isPlaying = newIsPlaying;
        _isBuffering = newIsBuffering;
        notifyListeners();
        _historyManager.updateState(
          isPlaying: _isPlaying,
          currentSong: _currentSong,
          saveProgress: _saveProgress,
        );
      }
      if (processingState == ProcessingState.completed) {
        _sleepTimerManager.onPlaybackCompleted();
      }
    });
    _audioPlayerService.currentIndexStream.listen((index) {
      Log.d(_tag, "_bindPlayerEvents, index: $index");
      if (index >= 0 && index < _playlist.length) {
        final newSong = _playlist[index];
        if (_currentSong?.bvid != newSong.bvid ||
            _currentSong?.cid != newSong.cid) {
          _onSongChanged(newSong);
        }
      }
    });
    _audioPlayerService.playbackErrorStream.listen((error) {
      Log.e(_tag, "Playback Error", error);
      _handlePlaybackError(error);
    });
    _audioPlayerService.actualQualityStream.listen((quality) {
      // Log.d(_tag, "actualQualityStream, quality: $quality");
      if (_currentPlayingQuality != quality) {
        _currentPlayingQuality = quality;
        notifyListeners();
        Log.i(_tag, "Updated actual playing quality to: $quality");
      }
    });
  }

  Future<void> _init() async {
    Log.v(_tag, "_init");
    await DownloadManager().init();
    await _loadSettings();
    await _reloadPlaylistFromDb();
    await _restoreLastPlaybackState();
  }

  Future<void> _loadSettings() async {
    Log.v(_tag, "_loadSettings");
    final prefs = await SharedPreferences.getInstance();
    int modeIndex = prefs.getInt(_playModeKey) ?? 0;
    if (modeIndex >= 0 && modeIndex < PlayMode.values.length) {
      _playMode = PlayMode.values[modeIndex];
    }
    _saveProgress = prefs.getBool(_saveProgressKey) ?? true;
    _autoPlay = prefs.getBool(_autoPlayKey) ?? false;
    _autoSkipInvalid = prefs.getBool(_autoSkipInvalidKey) ?? true;
    await _recommendationManager.loadSettings();
    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    int quality = prefs.getInt(_defaultAudioQualityKey) ?? 30280;
    _audioPlayerService.setPreferredQuality(quality);
    notifyListeners();
  }

  Future<void> _onSongChanged(Song newSong) async {
    Log.v(_tag, "_onSongChanged: ${newSong.title}");
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
    _historyManager.updateState(
      isPlaying: _isPlaying,
      currentSong: newSong,
      saveProgress: _saveProgress,
    );

    _recommendationManager.checkAndLoad(
      currentSong: newSong,
      currentPlaylist: _playlist,
      notifyLoading: notifyListeners,
      notifyLoaded: notifyListeners,
    );
  }

  Future<void> _reloadPlaylistFromDb() async {
    Log.v(_tag, "_reloadPlaylistFromDb");
    bool shuffle = _playMode == PlayMode.shuffle;
    _playlist = await _databaseService.getPlaylist(isShuffleMode: shuffle);
    Log.i(_tag, "_reloadPlaylistFromDb: loaded ${_playlist.length} songs");
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    Log.v(_tag, "playSong, song: ${song.title}");
    int index = _playlist.indexWhere(
      (s) => s.bvid == song.bvid && s.cid == song.cid,
    );
    if (index != -1) {
      if (_currentSong?.bvid == song.bvid &&
          _currentSong?.cid == song.cid &&
          _isPlaying) {
        return;
      }
      await _startPlay(index);
    } else {
      await setPlaylistAndPlay([song], song);
    }
  }

  Future<void> setPlaylistAndPlay(List<Song> songs, Song initialSong) async {
    Log.v(
      _tag,
      "setPlaylistAndPlay, songs: ${songs.length}, initialSong: ${initialSong.title}",
    );

    try {
      // Save the recommendation state at the start for consistency
      final shouldTriggerRecommendation = recommendationAutoPlay;

      List<Song> newSongs;
      if (shouldTriggerRecommendation) {
        newSongs = [initialSong];
      } else {
        newSongs = List.from(songs);
        int existingIndex = newSongs.indexWhere(
          (s) => s.bvid == initialSong.bvid && s.cid == initialSong.cid,
        );

        if (existingIndex == -1) {
          existingIndex = newSongs.indexWhere(
            (s) =>
                s.bvid == initialSong.bvid &&
                (s.cid == 0 || initialSong.cid == 0),
          );
        }

        if (existingIndex != -1) {
          newSongs[existingIndex] = initialSong;
        } else {
          newSongs.insert(0, initialSong);
        }
      }

      await _databaseService.replacePlaylist(newSongs);
      await _reloadPlaylistFromDb();

      int index = _playlist.indexWhere(
        (s) =>
            s.bvid == initialSong.bvid &&
            (s.cid == 0 || initialSong.cid == 0 || s.cid == initialSong.cid),
      );
      if (index == -1) index = 0;

      // Start playback immediately
      await _startPlay(index);
      expandPlayer();

      // Trigger recommendation load immediately (non-blocking)
      // Use the saved state to ensure consistency
      if (shouldTriggerRecommendation) {
        Log.i(
          _tag,
          "Triggering immediate recommendation check after setPlaylistAndPlay",
        );
        // Don't await - let it run in parallel
        _recommendationManager.checkAndLoad(
          currentSong: initialSong,
          currentPlaylist: _playlist,
          notifyLoading: notifyListeners,
          notifyLoaded: notifyListeners,
        );
      }
    } catch (e) {
      Log.e(_tag, "setPlaylistAndPlay error", e);
    }
  }

  Future<void> insertNext(Song song) async {
    Log.v(_tag, "insertNext, song: ${song.title}");
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: _currentSong);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> insertNextAndPlay(Song song) async {
    Log.v(_tag, "insertNextAndPlay, song: ${song.title}");
    await insertNext(song);
    if (hasNext) await playNext();
  }

  Future<void> addToEnd(Song song) async {
    Log.v(_tag, "addToEnd, song: ${song.title}");
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: null);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> replacePlaylistWithSong(Song song) async {
    Log.v(_tag, "replacePlaylistWithSong, song: ${song.title}");
    await setPlaylistAndPlay([song], song);
  }

  Future<void> removeSong(int index) async {
    Log.v(_tag, "removeSong, index: $index");
    if (index < 0 || index >= _playlist.length) return;
    Song songToRemove = _playlist[index];

    await _databaseService.removeSong(songToRemove.bvid, songToRemove.cid);
    await _reloadPlaylistFromDb();

    bool isCurrent =
        _currentSong != null &&
        _currentSong!.bvid == songToRemove.bvid &&
        (_currentSong!.cid == 0 ||
            songToRemove.cid == 0 ||
            _currentSong!.cid == songToRemove.cid);

    if (isCurrent) {
      if (_playlist.isEmpty) {
        await closePlayer();
      } else {
        int nextIndex = index >= _playlist.length ? 0 : index;
        await _audioPlayerService.playWithQueue(
          _playlist,
          nextIndex,
          autoPlay: true,
        );
      }
    } else {
      await _syncPlayerQueue();
    }
  }

  Future<void> reorderPlaylist(int oldIndex, int newIndex) async {
    Log.v(_tag, "reorderPlaylist, oldIndex: $oldIndex, newIndex: $newIndex");
    if (oldIndex < newIndex) newIndex -= 1;
    bool shuffle = _playMode == PlayMode.shuffle;
    await _databaseService.reorderPlaylist(oldIndex, newIndex, shuffle);
    await _reloadPlaylistFromDb();
    if (_currentSong != null) {
      int newCurrentIndex = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      if (newCurrentIndex != -1) {
        await _audioPlayerService.updateQueueKeepPlaying(
          _playlist,
          newCurrentIndex,
        );
      }
    }
  }

  Future<void> clearPlaylist() async {
    Log.v(_tag, "clearPlaylist");
    await _databaseService.clearPlaylist();
    await closePlayer();
  }

  Future<void> _startPlay(int index) async {
    Log.v(_tag, "_startPlay, index: $index");
    _currentSong = _playlist[index];
    _historyManager.updateState(
      isPlaying: true,
      currentSong: _currentSong,
      saveProgress: _saveProgress,
    );
    await _audioPlayerService.playWithQueue(_playlist, index, autoPlay: true);
    await _setPlayerLoopMode();
  }

  Future<void> _syncPlayerQueue() async {
    Log.v(_tag, "_syncPlayerQueue");
    if (_currentSong == null) return;
    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
    );
    if (currentIndex != -1) {
      await _audioPlayerService.updateQueueKeepPlaying(_playlist, currentIndex);
    } else if (_playlist.isNotEmpty) {
      await _audioPlayerService.playWithQueue(_playlist, 0);
    }
  }

  Future<void> _handlePlaybackError(Map<String, dynamic> error) async {
    Log.e(_tag, "Playback Error", error);
    if (!_autoSkipInvalid) return;
    await Future.delayed(const Duration(milliseconds: 300));
    final String bvid = error['bvid'] ?? '';
    final int cid = error['cid'] ?? 0;

    int index = _playlist.indexWhere(
      (s) => s.bvid == bvid && (cid == 0 || s.cid == 0 || s.cid == cid),
    );

    if (index != -1) {
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

  Future<void> togglePlayMode() async {
    Log.v(_tag, "togglePlayMode");
    if (recommendationAutoPlay) {
      return;
    }

    int nextIndex = (_playMode.index + 1) % PlayMode.values.length;
    PlayMode newMode = PlayMode.values[nextIndex];
    bool isOrderChanged =
        (_playMode == PlayMode.shuffle) || (newMode == PlayMode.shuffle);
    _playMode = newMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);

    if (isOrderChanged) {
      await _reloadPlaylistFromDb();
      if (_currentSong != null) {
        int newIndex = _playlist.indexWhere(
          (s) =>
              s.bvid == _currentSong!.bvid &&
              (s.cid == _currentSong!.cid ||
                  s.cid == 0 ||
                  _currentSong!.cid == 0),
        );

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
    Log.v(_tag, "_setPlayerLoopMode");
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

  Future<void> _restoreLastPlaybackState() async {
    Log.v(_tag, "_restoreLastPlaybackState");
    if (_playlist.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lastBvid = prefs.getString(_lastPlayedBvidKey);
    final lastCid = prefs.getInt(_lastPlayedCidKey);
    final lastPosition = prefs.getInt(_lastPlayedPositionKey) ?? 0;

    int initialIndex = 0;
    if (lastBvid != null) {
      initialIndex = _playlist.indexWhere(
        (s) => s.bvid == lastBvid && s.cid == lastCid,
      );
    }
    if (initialIndex == -1) {
      initialIndex = prefs.getInt(_lastPlayedIndexKey) ?? 0;
      if (initialIndex < 0 || initialIndex >= _playlist.length) {
        initialIndex = 0;
      }
    }

    _currentSong = _playlist[initialIndex];
    _showFullPlayer = true;

    try {
      await _audioPlayerService.playWithQueue(
        _playlist,
        initialIndex,
        autoPlay: _autoPlay,
      );
      if (_saveProgress && lastPosition > 0) {
        await player.seek(Duration(milliseconds: lastPosition));
      }
      await _setPlayerLoopMode();
    } catch (e) {
      Log.e(_tag, "Restore playback error", e);
    }
  }

  Future<void> setSaveProgress(bool value) async {
    Log.v(_tag, "setSaveProgress, value: $value");
    _saveProgress = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveProgressKey, value);
    notifyListeners();
    _historyManager.updateState(
      isPlaying: _isPlaying,
      currentSong: _currentSong,
      saveProgress: _saveProgress,
    );
  }

  Future<void> setRecommendationAutoPlay(bool value) async {
    Log.v(_tag, "setRecommendationAutoPlay, value: $value");

    if (value && _playMode == PlayMode.shuffle) {
      Log.i(
        _tag,
        "Recommendation mode enabled, switching from Shuffle to Sequence",
      );
      _playMode = PlayMode.sequence;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_playModeKey, _playMode.index);
      notifyListeners();
      await _setPlayerLoopMode();
    }

    await _recommendationManager.setEnabled(value);
    notifyListeners();
    if (value && _currentSong != null) {
      _recommendationManager.checkAndLoad(
        currentSong: _currentSong!,
        currentPlaylist: _playlist,
        notifyLoading: notifyListeners,
        notifyLoaded: notifyListeners,
      );
    }
  }

  Future<void> setAutoPlay(bool value) async {
    Log.v(_tag, "setAutoPlay, value: $value");
    _autoPlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, value);
    notifyListeners();
  }

  Future<void> setAutoSkipInvalid(bool value) async {
    Log.v(_tag, "setAutoSkipInvalid, value: $value");
    _autoSkipInvalid = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSkipInvalidKey, value);
    _audioPlayerService.setAutoSkipInvalid(value);
    notifyListeners();
  }

  void setStopTimer(Duration duration, {bool stopAfterCurrent = false}) {
    Log.v(
      _tag,
      "setStopTimer, duration: $duration, stopAfterCurrent: $stopAfterCurrent",
    );
    _sleepTimerManager.setTimer(duration, stopAfterCurrent: stopAfterCurrent);
  }

  void setStopTime(DateTime time, {bool stopAfterCurrent = false}) {
    Log.v(
      _tag,
      "setStopTime, time: $time, stopAfterCurrent: $stopAfterCurrent",
    );
    _sleepTimerManager.setStopTime(time, stopAfterCurrent: stopAfterCurrent);
  }

  void cancelTimer() => _sleepTimerManager.cancel();

  void cancelStopTimer() => _sleepTimerManager.cancel();

  Future<void> playNext() async => await _audioPlayerService.playNext();

  Future<void> playPrevious() async => await _audioPlayerService.playPrevious();

  Future<void> togglePlayPause() async =>
      await _audioPlayerService.togglePlayPause();

  Future<void> seek(Duration position) async => await player.seek(position);

  Future<void> closePlayer() async {
    Log.v(_tag, "closePlayer");
    await _audioPlayerService.resetState();
    _currentSong = null;
    _playlist = [];
    await _databaseService.clearPlaylist();
    _isPlaying = false;
    _showFullPlayer = false;
    _isPlayerExpanded = false;
    _historyManager.updateState(
      isPlaying: false,
      currentSong: null,
      saveProgress: false,
    );
    _sleepTimerManager.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPlayedBvidKey);
    await prefs.remove(_lastPlayedPositionKey);

    notifyListeners();
  }

  void expandPlayer() {
    Log.v(_tag, "expandPlayer");
    _expandTimer?.cancel();
    _showFullPlayer = true;
    notifyListeners();
    _expandTimer = Timer(const Duration(milliseconds: 50), () {
      _isPlayerExpanded = true;
      notifyListeners();
    });
  }

  void collapsePlayer() {
    Log.v(_tag, "collapsePlayer");
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
    Log.v(_tag, "togglePlayerExpansion");
    if (_isPlayerExpanded) {
      collapsePlayer();
    } else {
      expandPlayer();
    }
  }

  Future<void> clearAllCache() async {
    Log.v(_tag, "clearAllCache");
    await _audioPlayerService.clearCache();
  }

  Future<void> resetToDefaults() async {
    Log.v(_tag, "resetToDefaults");
    _playMode = PlayMode.sequence;
    _saveProgress = true;
    _autoPlay = false;
    _autoSkipInvalid = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
    await prefs.setBool(_saveProgressKey, _saveProgress);
    await prefs.setBool(_autoPlayKey, _autoPlay);
    await prefs.setBool(_autoSkipInvalidKey, _autoSkipInvalid);
    await _recommendationManager.resetToDefault();
    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    _audioPlayerService.setPreferredQuality(30280);
    notifyListeners();
  }

  bool get hasNext {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.loop || _playMode == PlayMode.shuffle) {
      return true;
    }
    int index = _playlist.indexOf(_currentSong!);
    return index < _playlist.length - 1;
  }

  bool get hasPrevious {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.loop || _playMode == PlayMode.shuffle) {
      return true;
    }
    int index = _playlist.indexOf(_currentSong!);
    return index > 0;
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _historyManager.dispose();
    _sleepTimerManager.dispose();
    _expandTimer?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}
