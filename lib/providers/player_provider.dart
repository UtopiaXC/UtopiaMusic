import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'dart:async';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isSwitchingMode = false;
  bool _isSwitchingPlaylist = false;

  Song? _currentSong;
  bool _isPlaying = false;
  bool _isPlayerExpanded = false;
  bool _showFullPlayer = false;

  List<Song> _playlist = [];
  PlayMode _playMode = PlayMode.sequence;
  static const String _playModeKey = 'play_mode';
  static const String _lastPlayedIndexKey = 'last_played_index';
  static const String _lastPlayedPositionKey = 'last_played_position';
  static const String _saveProgressKey = 'save_progress';
  static const String _autoPlayKey = 'auto_play';
  static const String _decoderKey = 'decoder_type';
  static const String _autoSkipInvalidKey = 'auto_skip_invalid';

  bool _saveProgress = true;
  bool _autoPlay = false;
  int _decoderType = 1;
  bool _autoSkipInvalid = true;


  // Timer related
  Timer? _stopTimer;
  DateTime? _stopTime;
  bool _stopAfterCurrent = false;
  bool _isTimerActive = false;

  Song? get currentSong => _currentSong;

  bool get isPlaying => _isPlaying;

  bool get isPlayerExpanded => _isPlayerExpanded;

  bool get showFullPlayer => _showFullPlayer;

  AudioPlayer get player => _audioPlayerService.player;

  List<Song> get playlist => _playlist;

  PlayMode get playMode => _playMode;

  bool get saveProgress => _saveProgress;

  bool get autoPlay => _autoPlay;

  int get decoderType => _decoderType;

  bool get isTimerActive => _isTimerActive;

  DateTime? get stopTime => _stopTime;

  bool get stopAfterCurrent => _stopAfterCurrent;

  bool get autoSkipInvalid => _autoSkipInvalid;

  static String get autoSkipInvalidKey => _autoSkipInvalidKey;


  PlayerProvider() {
    _init();

    _audioPlayerService.player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayerService.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_stopAfterCurrent &&
            _isTimerActive &&
            _stopTime != null &&
            DateTime.now().isAfter(_stopTime!)) {
          cancelTimer();
          _audioPlayerService.stop();
          _isPlaying = false;
          notifyListeners();
        } else {
          playNext(auto: true);
        }
      }
    });

    _audioPlayerService.currentIndexStream.listen((index) {
      if (_isSwitchingMode) return;
      if (index >= 0 && index < _playlist.length) {
        final newSong = _playlist[index];
        if (_currentSong?.bvid != newSong.bvid ||
            _currentSong?.cid != newSong.cid) {
          _currentSong = newSong;
          _saveLastPlayedIndex(index);
          notifyListeners();
        }
      }
    });

    _audioPlayerService.player.positionStream.listen((position) {
      if (_isPlaying && position.inSeconds % 1 == 0) {
        _saveLastPlayedPosition(position.inMilliseconds);
      }
    });

    _audioPlayerService.player.playerStateStream.listen((state) {
      if (!state.playing) {
        _saveLastPlayedPosition(
          _audioPlayerService.player.position.inMilliseconds,
        );
      }
    });
    
    // Listen for playback errors from service (if we implement stream there)
    // But currently service handles it by skipping.
    // If we want to remove song, we need a way to know which song failed.
    // Since service skips, index changes.
    // We can listen to index changes, but that's normal behavior too.
    
    // Let's rely on service skipping for now as requested "play next".
    // "Remove from playlist" is tricky because we need to know WHICH song failed.
    // If we are listening to playback errors here:
    _audioPlayerService.player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace stackTrace) {
       // This catches errors from the player stream
       // If it's a 404 or similar source error
       if (e.toString().contains('404') || e.toString().contains('Source error')) {
          print('PlayerProvider: Caught playback error, removing current song and skipping.');
          _handlePlaybackError();
       }
    });
  }
  
  Future<void> _handlePlaybackError() async {
    if (_playlist.isEmpty || _currentSong == null) return;
    
    final indexToRemove = _playlist.indexWhere((s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid);
    
    if (indexToRemove != -1) {
       // Remove from DB and list
       await removeSong(indexToRemove);
       // removeSong already handles playing next if current is removed
       // But removeSong calls _play(next), which might trigger another error if next is also bad.
       // This loop should work until a good song is found or list empty.
    }
  }

  Future<void> _init() async {
    await _loadSettings();
    await _loadPlaylist();

    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt(_lastPlayedIndexKey) ?? 0;
    final lastPosition = prefs.getInt(_lastPlayedPositionKey) ?? 0;

    if (_playlist.isNotEmpty) {
      int initialIndex = 0;
      if (lastIndex >= 0 && lastIndex < _playlist.length) {
        initialIndex = lastIndex;
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
          await _audioPlayerService.player.seek(
            Duration(milliseconds: lastPosition),
          );
        }

        await _setPlayerLoopMode();
      } catch (e) {
        print("Init player error: $e");
        if (_decoderType == 1) {
          print(
            "Hard decoder failed, switching to soft decoder preference (simulated)",
          );
          await setDecoderType(0);
        }
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_playModeKey) ?? 0;
    if (modeIndex >= 0 && modeIndex < PlayMode.values.length) {
      _playMode = PlayMode.values[modeIndex];
    }
    _saveProgress = prefs.getBool(_saveProgressKey) ?? true;
    _autoPlay = prefs.getBool(_autoPlayKey) ?? false;
    _decoderType = prefs.getInt(_decoderKey) ?? 1;
    notifyListeners();
  }

  Future<void> setSaveProgress(bool value) async {
    _saveProgress = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveProgressKey, value);
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, value);
  }

  Future<void> setDecoderType(int value) async {
    _decoderType = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_decoderKey, value);
  }

  Future<void> _savePlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
  }

  Future<void> _saveLastPlayedIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPlayedIndexKey, index);
  }

  Future<void> _saveLastPlayedPosition(int positionMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPlayedPositionKey, positionMs);
  }

  Future<void> _loadPlaylist() async {
    _playlist = await _databaseService.getPlaylist(
      shuffle: _playMode == PlayMode.shuffle,
    );
    notifyListeners();
  }

  Future<void> _setPlayerLoopMode() async {
    await _audioPlayerService.player.setShuffleModeEnabled(false);

    switch (_playMode) {
      case PlayMode.single:
        await _audioPlayerService.player.setLoopMode(LoopMode.one);
        break;
      case PlayMode.sequence:
        await _audioPlayerService.player.setLoopMode(LoopMode.off);
        break;
      case PlayMode.loop:
      case PlayMode.shuffle:
        await _audioPlayerService.player.setLoopMode(LoopMode.all);
        break;
    }
  }

  Future<void> setAutoSkipInvalid(bool value) async {
    _autoSkipInvalid = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoSkipInvalidKey, value);
  }

  Future<void> togglePlayMode() async {
    _isSwitchingMode = true;
    try {
      int nextIndex = (_playMode.index + 1) % PlayMode.values.length;
      _playMode = PlayMode.values[nextIndex];
      await _savePlayMode();

      _playlist = await _databaseService.getPlaylist(
        shuffle: _playMode == PlayMode.shuffle,
      );

      if (_currentSong != null) {
        int newIndex = _playlist.indexWhere(
          (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
        );

        if (newIndex != -1) {
          await _audioPlayerService.updateQueueKeepPlaying(_playlist, newIndex);
          await _saveLastPlayedIndex(newIndex);
        } else {
          if (_playlist.isNotEmpty) {
            await _play(_playlist[0]);
          }
        }
      }

      await _setPlayerLoopMode();

      notifyListeners();
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        _isSwitchingMode = false;
      });
    }
  }

  Future<void> playSong(Song song) async {
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      await _databaseService.addSongToEnd(song);
      await _loadPlaylist();
    }
    await _play(song);
  }

  Future<void> setPlaylistAndPlay(List<Song> songs, Song initialSong) async {
    // Force reset if it was stuck
    if (_isSwitchingPlaylist) {
       print("Warning: _isSwitchingPlaylist was true, forcing reset.");
       _isSwitchingPlaylist = false;
    }
    
    _isSwitchingPlaylist = true;

    try {
      // Stop player first
      await _audioPlayerService.stop();
      
      // Clear current playlist in memory immediately to avoid race conditions
      _playlist = [];
      _currentSong = null;
      notifyListeners();

      List<Song> newPlaylist = [];
      final seen = <String>{};
      for (var song in songs) {
        if (song.bvid.isNotEmpty && !seen.contains(song.bvid)) {
          seen.add(song.bvid);
          newPlaylist.add(song);
        }
      }

      if (initialSong.bvid.isNotEmpty &&
          !newPlaylist.any((s) => s.bvid == initialSong.bvid)) {
        newPlaylist.insert(0, initialSong);
      }
      
      await _databaseService.clearPlaylist();
      await _databaseService.savePlaylist(newPlaylist);
      await _loadPlaylist();
      await _play(initialSong);
    } catch (e) {
      print("setPlaylistAndPlay error: $e");
    } finally {
      _isSwitchingPlaylist = false;
    }
  }

  Future<void> insertNext(Song song) async {
    if (_playlist.isEmpty) {
      await playSong(song);
      return;
    }
    await _databaseService.insertSong(
      song,
      afterSong: _currentSong,
      isShuffleMode: _playMode == PlayMode.shuffle,
    );
    await _loadPlaylist();
    notifyListeners();
  }

  Future<void> insertNextAndPlay(Song song) async {
    await insertNext(song);
    await playNext();
  }

  Future<void> addToEnd(Song song) async {
    if (_playlist.isEmpty) {
      await playSong(song);
      return;
    }
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      await _databaseService.addSongToEnd(song);
      await _loadPlaylist();
      notifyListeners();
    }
  }

  Future<void> replacePlaylistWithSong(Song song) async {
    if (_isSwitchingPlaylist) {
       _isSwitchingPlaylist = false;
    }
    _isSwitchingPlaylist = true;
    try {
      await _audioPlayerService.stop();
      
      _playlist = [];
      _currentSong = null;
      notifyListeners();
      
      await _databaseService.clearPlaylist();
      await _databaseService.savePlaylist([song]);
      await _loadPlaylist();
      await _play(song);
    } catch (e) {
      print("replacePlaylistWithSong error: $e");
    } finally {
      _isSwitchingPlaylist = false;
    }
  }

  Future<void> _play(Song song) async {
    _currentSong = song;
    _isPlaying = true;
    _showFullPlayer = true;

    int index = _playlist.indexWhere(
      (s) => s.bvid == song.bvid && s.cid == song.cid,
    );
    if (index == -1) {
      index = 0;
    }

    notifyListeners();

    try {
      await _audioPlayerService.playWithQueue(_playlist, index);
      await _saveLastPlayedIndex(index);
      await _setPlayerLoopMode();
    } catch (e) {
      print("Play error: $e");
    }
  }

  Future<void> playNext({bool auto = false}) async {
    if (_playlist.isEmpty || _currentSong == null) return;

    if (_playMode == PlayMode.single && auto) {
      await _audioPlayerService.player.seek(Duration.zero);
      await _audioPlayerService.resume();
      return;
    }

    if (hasNext) {
      await _audioPlayerService.playNext();
    } else {
      if (_playMode == PlayMode.loop || _playMode == PlayMode.shuffle) {
        await _audioPlayerService.playWithQueue(_playlist, 0);
      } else {
        await _audioPlayerService.stop();
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentSong == null) return;

    if (hasPrevious) {
      await _audioPlayerService.playPrevious();
    } else {
      if (_playMode == PlayMode.loop || _playMode == PlayMode.shuffle) {
        await _audioPlayerService.playWithQueue(
          _playlist,
          _playlist.length - 1,
        );
      }
    }
  }

  void expandPlayer() {
    _showFullPlayer = true;
    Future.delayed(const Duration(milliseconds: 50), () {
      _isPlayerExpanded = true;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayerService.pause();
    } else {
      if (_audioPlayerService.player.processingState ==
          ProcessingState.completed) {
        await _audioPlayerService.player.seek(Duration.zero);
      }
      await _audioPlayerService.resume();
    }
  }

  void togglePlayerExpansion() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    _isPlayerExpanded = false;
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await _audioPlayerService.stop();
    _currentSong = null;
    _playlist = [];
    await _databaseService.clearPlaylist();
    _isPlaying = false;
    _isPlayerExpanded = false;
    _showFullPlayer = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPlayedIndexKey);
    await prefs.remove(_lastPlayedPositionKey);

    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _saveProgress = false;
    _autoPlay = false;
    _decoderType = 1;
    _autoSkipInvalid = true;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveProgressKey);
    await prefs.remove(_autoPlayKey);
    await prefs.remove(_decoderKey);
    await prefs.remove(autoSkipInvalidKey);
  }

  bool get hasNext {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.sequence) {
      int index = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      return index < _playlist.length - 1;
    }
    return true;
  }

  bool get hasPrevious {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.sequence) {
      int index = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      return index > 0;
    }
    return true;
  }

  void setStopTimer(Duration duration, {bool stopAfterCurrent = false}) {
    _stopTimer?.cancel();
    _stopTime = DateTime.now().add(duration);
    _stopAfterCurrent = stopAfterCurrent;
    _isTimerActive = true;

    _stopTimer = Timer(duration, () {
      if (!_stopAfterCurrent) {
        _audioPlayerService.stop();
        _isPlaying = false;
        cancelTimer();
      }
    });

    notifyListeners();
  }

  void setStopTime(DateTime time, {bool stopAfterCurrent = false}) {
    final now = DateTime.now();
    if (time.isBefore(now)) return;
    final duration = time.difference(now);
    setStopTimer(duration, stopAfterCurrent: stopAfterCurrent);
  }

  void cancelTimer() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _stopTime = null;
    _isTimerActive = false;
    _stopAfterCurrent = false;
    notifyListeners();
  }

  Future<void> reorderPlaylist(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);

    await _databaseService.savePlaylist(_playlist);

    if (_currentSong != null) {
      final currentIndex = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      if (currentIndex != -1) {
        await _saveLastPlayedIndex(currentIndex);
        await _audioPlayerService.updateQueueKeepPlaying(
          _playlist,
          currentIndex,
        );
      }
    }

    notifyListeners();
  }

  Future<void> removeSong(int index) async {
    if (index >= 0 && index < _playlist.length) {
      final songToRemove = _playlist[index];
      _playlist.removeAt(index);
      await _databaseService.savePlaylist(_playlist);

      if (_currentSong?.bvid == songToRemove.bvid &&
          _currentSong?.cid == songToRemove.cid) {
        if (_playlist.isNotEmpty) {
          int nextIndex = index;
          if (nextIndex >= _playlist.length) nextIndex = 0;
          await _play(_playlist[nextIndex]);
        } else {
          await closePlayer();
        }
      } else {
        if (_currentSong != null) {
          final currentIndex = _playlist.indexWhere(
            (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
          );
          if (currentIndex != -1) {
            await _audioPlayerService.updateQueueKeepPlaying(
              _playlist,
              currentIndex,
            );
            await _saveLastPlayedIndex(currentIndex);
          }
        }
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}
