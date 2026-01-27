import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/audio/report_history.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "PLAYER_PROVIDER";

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DatabaseService _databaseService = DatabaseService();
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  final ReportHistoryApi _reportHistoryApi = ReportHistoryApi();

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
  int _historyReportCounter = 12;

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

        if (_isPlaying) {
          _startProgressTimer();
        } else {
          _stopProgressTimer();
          _saveCurrentProgress();
        }
      }

      if (processingState == ProcessingState.completed) {
        if (_stopAfterCurrent &&
            isTimerActive &&
            _stopTime != null &&
            DateTime.now().isAfter(_stopTime!)) {
          cancelStopTimer();
          _audioPlayerService.stop();
        }
      }
    });

    _audioPlayerService.currentIndexStream.listen((index) {
      if (index >= 0 && index < _playlist.length) {
        final newSong = _playlist[index];
        if (_currentSong?.bvid != newSong.bvid ||
            _currentSong?.cid != newSong.cid) {
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
    _recommendationAutoPlay =
        prefs.getBool(_recommendationAutoPlayKey) ?? false;

    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    int quality = prefs.getInt(_defaultAudioQualityKey) ?? 30280;
    _audioPlayerService.setPreferredQuality(quality);

    notifyListeners();
  }

  Future<void> _onSongChanged(Song newSong) async {
    Log.v(_tag, "_onSongChanged, newSong: ${newSong.toString()}");
    _currentSong = newSong;
    final context = navigatorKey.currentContext;
    if (context != null) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _historyReportCounter = 15 - settings.historyReportDelay;
    } else {
      _historyReportCounter = 12;
    }

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
    Log.v(_tag, "_handlePlaybackError, error: $error");
    if (!_autoSkipInvalid) return;
    await Future.delayed(const Duration(milliseconds: 300));
    final String bvid = error['bvid'] ?? '';
    final int cid = error['cid'] ?? 0;

    int index = _playlist.indexWhere(
      (s) => s.bvid == bvid && (cid == 0 || s.cid == 0 || s.cid == cid),
    );

    if (index != -1) {
      print(
        "PlayerProvider: Removing invalid song from playlist: $bvid / $cid",
      );
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
    Log.v(_tag, "_handleRecommendationAutoPlay, currentSong: ${currentSong.toString()}");
    if (_isRecommendationLoading) return;
    if (_playlist.isEmpty) return;

    _isRecommendationLoading = true;
    notifyListeners();

    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final related = await _videoDetailApi.getRelatedVideos(
        context,
        currentSong.bvid,
      );

      if (_currentSong?.bvid != currentSong.bvid) return;

      if (related.isNotEmpty) {
        List<Song> newPlaylist = [currentSong, ...related];
        final Set<String> seen = {'${currentSong.bvid}_${currentSong.cid}'};
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

        int newIndex = _playlist.indexWhere(
          (s) => s.bvid == currentSong.bvid && s.cid == currentSong.cid,
        );
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
    Log.v(_tag, "_reloadPlaylistFromDb");
    bool shuffle = _playMode == PlayMode.shuffle;
    _playlist = await _databaseService.getPlaylist(isShuffleMode: shuffle);
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    Log.v(_tag, "playSong, song: ${song.toString()}");
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
    Log.v(_tag, "setPlaylistAndPlay, songs: ${songs.toString()}, initialSong: ${initialSong.toString()}");
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
    Log.v(_tag, "insertNext, song: ${song.toString()}");
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: _currentSong);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> insertNextAndPlay(Song song) async {
    Log.v(_tag, "insertNextAndPlay, song: ${song.toString()}");
    await insertNext(song);
    if (hasNext) {
      await playNext();
    }
  }

  Future<void> addToEnd(Song song) async {
    Log.v(_tag, "addToEnd, song: ${song.toString()}");
    if (_playlist.isEmpty) {
      await setPlaylistAndPlay([song], song);
      return;
    }
    await _databaseService.insertSong(song, afterSong: null);
    await _reloadPlaylistFromDb();
    await _syncPlayerQueue();
  }

  Future<void> replacePlaylistWithSong(Song song) async {
    Log.v(_tag, "replacePlaylistWithSong, song: ${song.toString()}");
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
        int nextIndex = index;
        if (nextIndex >= _playlist.length) nextIndex = 0;

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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
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

  Future<void> _startPlay(int index) async {
    Log.v(_tag, "_startPlay, index: $index");
    _currentSong = _playlist[index];

    final context = navigatorKey.currentContext;
    if (context != null) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _historyReportCounter = 15 - settings.historyReportDelay;
    } else {
      _historyReportCounter = 12;
    }

    await _audioPlayerService.playWithQueue(_playlist, index, autoPlay: true);
    await _setPlayerLoopMode();
  }

  Future<void> togglePlayMode() async {
    Log.v(_tag, "togglePlayMode");
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
    bool isOrderChanged =
        (oldMode == PlayMode.shuffle) || (newMode == PlayMode.shuffle);

    if (isOrderChanged) {
      await _reloadPlaylistFromDb();

      if (_currentSong != null) {
        int newIndex = _playlist.indexWhere(
          (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
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

  Future<void> setRecommendationAutoPlay(bool value) async {
    Log.v(_tag, "setRecommendationAutoPlay, value: $value");
    _recommendationAutoPlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationAutoPlayKey, value);
    notifyListeners();
    if (value && _currentSong != null) {
      _handleRecommendationAutoPlay(_currentSong!);
    }
  }

  void _startProgressTimer() {
    Log.v(_tag, "_startProgressTimer");
    _stopProgressTimer();

    _progressSaveTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (_isPlaying) {
        if (_saveProgress) {
          _saveCurrentProgress();
        }

        final context = navigatorKey.currentContext;
        if (context != null && _currentSong != null) {
          final settings = Provider.of<SettingsProvider>(
            context,
            listen: false,
          );
          final auth = Provider.of<AuthProvider>(context, listen: false);

          if (settings.enableHistoryReport && auth.isLoggedIn) {
            _historyReportCounter++;

            if (_historyReportCounter >= 15) {
              _reportHistoryApi.reportHistory(
                bvid: _currentSong!.bvid,
                cid: _currentSong!.cid,
                playedTime: player.position.inSeconds,
              );
              _historyReportCounter = 0;
            }
          }
        }
      }
    });
  }

  void _stopProgressTimer() {
    Log.v(_tag, "_stopProgressTimer");
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  Future<void> setSaveProgress(bool value) async {
    Log.v(_tag, "setSaveProgress, value: $value");
    _saveProgress = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveProgressKey, value);
    notifyListeners();
    if (_isPlaying) {
      _startProgressTimer();
    } else {
      _stopProgressTimer();
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

  void setDecoderType(int type) {
    Log.v(_tag, "setDecoderType, type: ${type}");
    notifyListeners();
  }

  Future<void> _saveCurrentProgress() async {
    Log.v(_tag, "_saveCurrentProgress");
    if (_currentSong == null) return;
    final position = player.position.inMilliseconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPlayedPositionKey, position);
  }

  Future<void> _restoreLastPlaybackState() async {
    Log.v(_tag, "_restoreLastPlaybackState");
    if (_playlist.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastBvid = prefs.getString(_lastPlayedBvidKey);
    final lastCid = prefs.getInt(_lastPlayedCidKey);
    final lastPosition = prefs.getInt(_lastPlayedPositionKey) ?? 0;

    int initialIndex = 0;
    Log.v(
      _tag,
      "_restoreLastPlaybackState, lastBvid: $lastBvid, lastCid: $lastCid",
    );
    if (lastBvid != null) {
      initialIndex = _playlist.indexWhere(
        (s) => s.bvid == lastBvid && s.cid == lastCid,
      );
    }
    Log.v(_tag, "_restoreLastPlaybackState, initialIndex: $initialIndex");
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
      print("Restore playback error: $e");
    }
  }

  Future<void> playNext() async => await _audioPlayerService.playNext();

  Future<void> playPrevious() async => await _audioPlayerService.playPrevious();

  Future<void> togglePlayPause() async =>
      await _audioPlayerService.togglePlayPause();

  Future<void> seek(Duration position) async => await player.seek(position);

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

  Future<void> closePlayer() async {
    Log.v(_tag, "closePlayer");
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
    Log.v(_tag, "setStopTimer, duration: $duration");
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
    Log.v(_tag, "cancelStopTimer");
    _stopTimer?.cancel();
    _stopTimer = null;
    _stopTime = null;
    _stopAfterCurrent = false;
    notifyListeners();
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
    _recommendationAutoPlay = false;

    Log.i(_tag, "Reset for shared preferences");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
    await prefs.setBool(_saveProgressKey, _saveProgress);
    await prefs.setBool(_autoPlayKey, _autoPlay);
    await prefs.setBool(_autoSkipInvalidKey, _autoSkipInvalid);
    await prefs.setBool(_recommendationAutoPlayKey, _recommendationAutoPlay);

    Log.i(_tag, "Reset for audio player");
    _audioPlayerService.setAutoSkipInvalid(_autoSkipInvalid);
    _audioPlayerService.setPreferredQuality(30280);

    notifyListeners();
  }

  bool get hasNext {
    Log.v(_tag, "get hasNext");
    if (_playlist.isEmpty || _currentSong == null) return false;
    int index = _playlist.indexOf(_currentSong!);
    return index < _playlist.length - 1;
  }

  bool get hasPrevious {
    Log.v(_tag, "get hasPrevious");
    if (_playlist.isEmpty || _currentSong == null) return false;
    int index = _playlist.indexOf(_currentSong!);
    return index > 0;
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _stopProgressTimer();
    _stopTimer?.cancel();
    _expandTimer?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}
