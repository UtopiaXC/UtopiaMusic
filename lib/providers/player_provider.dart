import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isSwitchingMode = false;

  Song? _currentSong;
  bool _isPlaying = false;
  bool _isPlayerExpanded = false;
  bool _showFullPlayer = false;

  List<Song> _playlist = [];
  PlayMode _playMode = PlayMode.sequence;
  static const String _playModeKey = 'play_mode';

  Song? get currentSong => _currentSong;

  bool get isPlaying => _isPlaying;

  bool get isPlayerExpanded => _isPlayerExpanded;

  bool get showFullPlayer => _showFullPlayer;

  AudioPlayer get player => _audioPlayerService.player;

  List<Song> get playlist => _playlist;

  PlayMode get playMode => _playMode;

  PlayerProvider() {
    _init();

    _audioPlayerService.player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayerService.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playNext(auto: true);
      }
    });

    _audioPlayerService.currentIndexStream.listen((index) {
      if (_isSwitchingMode) return;
      if (index >= 0 && index < _playlist.length) {
        final newSong = _playlist[index];
        if (_currentSong?.bvid != newSong.bvid ||
            _currentSong?.cid != newSong.cid) {
          _currentSong = newSong;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _init() async {
    await _loadPlayMode();
    await _loadPlaylist();

    if (_playlist.isNotEmpty) {
      _currentSong = _playlist.first;
      _showFullPlayer = true;
      try {
        await _audioPlayerService.playWithQueue(_playlist, 0, autoPlay: false);
        await _setPlayerLoopMode();
      } catch (e) {
        print("Init player error: $e");
      }
    }
  }

  Future<void> _loadPlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_playModeKey) ?? 0;
    if (modeIndex >= 0 && modeIndex < PlayMode.values.length) {
      _playMode = PlayMode.values[modeIndex];
      await _setPlayerLoopMode();
      notifyListeners();
    }
  }

  Future<void> _savePlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
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

    await _databaseService.savePlaylist(newPlaylist);
    await _loadPlaylist();
    await _play(initialSong);
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
    await _databaseService.savePlaylist([song]);
    await _loadPlaylist();
    await _play(song);
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
    notifyListeners();
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

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }
}