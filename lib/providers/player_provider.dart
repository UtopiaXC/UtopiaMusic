import 'dart:math';
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
  
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isPlayerExpanded = false;
  bool _showFullPlayer = false;
  
  // Playlist management
  List<Song> _playlist = [];
  PlayMode _playMode = PlayMode.sequence; // Default to sequence
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
  }

  Future<void> _init() async {
    await _loadPlayMode();
    await _loadPlaylist();
  }

  Future<void> _loadPlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_playModeKey) ?? 0;
    if (modeIndex >= 0 && modeIndex < PlayMode.values.length) {
      _playMode = PlayMode.values[modeIndex];
      notifyListeners();
    }
  }

  Future<void> _savePlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
  }

  Future<void> _loadPlaylist() async {
    _playlist = await _databaseService.getPlaylist(shuffle: _playMode == PlayMode.shuffle);
    notifyListeners();
  }

  // Add a single song to playlist and play it
  Future<void> playSong(Song song) async {
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      await _databaseService.addSongToEnd(song);
      await _loadPlaylist();
    }
    await _play(song);
  }

  // Replace playlist with new list and play specific song
  Future<void> setPlaylistAndPlay(List<Song> songs, Song initialSong) async {
    List<Song> newPlaylist = [];
    // Filter duplicates based on bvid
    final seen = <String>{};
    for (var song in songs) {
      if (song.bvid.isNotEmpty && !seen.contains(song.bvid)) {
        seen.add(song.bvid);
        newPlaylist.add(song);
      }
    }
    
    // Ensure initialSong is in the playlist if it has a valid bvid
    if (initialSong.bvid.isNotEmpty && !newPlaylist.any((s) => s.bvid == initialSong.bvid)) {
       newPlaylist.insert(0, initialSong);
    }

    await _databaseService.savePlaylist(newPlaylist);
    await _loadPlaylist();
    await _play(initialSong);
  }

  // Insert song after current song
  Future<void> insertNext(Song song) async {
    if (_playlist.isEmpty) {
      await playSong(song);
      return;
    }
    
    await _databaseService.insertSong(
        song, 
        afterSong: _currentSong, 
        isShuffleMode: _playMode == PlayMode.shuffle
    );
    await _loadPlaylist();
    notifyListeners();
  }

  // Insert song after current song and play immediately
  Future<void> insertNextAndPlay(Song song) async {
    await insertNext(song);
    await playNext();
  }

  // Add song to end of playlist
  Future<void> addToEnd(Song song) async {
    if (_playlist.isEmpty) {
      await playSong(song);
      return;
    }

    // Check if song already exists
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      await _databaseService.addSongToEnd(song);
      await _loadPlaylist();
      notifyListeners();
    }
  }

  // Replace playlist with single song
  Future<void> replacePlaylistWithSong(Song song) async {
    await _databaseService.savePlaylist([song]);
    await _loadPlaylist();
    await _play(song);
  }

  Future<void> _play(Song song) async {
    _currentSong = song;
    _isPlaying = true;
    _showFullPlayer = true;
    
    notifyListeners();

    try {
      await _audioPlayerService.playSong(song);
    } catch (e) {
      print("Play error: $e");
    }
  }

  Future<void> playNext({bool auto = false}) async {
    if (_playlist.isEmpty || _currentSong == null) return;

    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
    );
    
    if (currentIndex == -1) return;

    int nextIndex = 0;

    switch (_playMode) {
      case PlayMode.single:
        if (auto) {
          // Replay current song
          _audioPlayerService.player.seek(Duration.zero);
          _audioPlayerService.resume();
          return;
        } else {
           // Manual next in single mode goes to next song
           nextIndex = (currentIndex + 1) % _playlist.length;
        }
        break;
      case PlayMode.shuffle:
        // In shuffle mode, the playlist is already shuffled in the database
        // But here _playlist is in memory.
        // If we are in shuffle mode, _playlist should be in shuffle order.
        nextIndex = (currentIndex + 1) % _playlist.length;
        break;
      case PlayMode.loop:
        nextIndex = (currentIndex + 1) % _playlist.length;
        break;
      case PlayMode.sequence:
        if (currentIndex < _playlist.length - 1) {
          nextIndex = currentIndex + 1;
        } else {
          // End of playlist
          _audioPlayerService.stop();
          _isPlaying = false;
          notifyListeners();
          return;
        }
        break;
    }

    await _play(_playlist[nextIndex]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentSong == null) return;

    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
    );

    if (currentIndex == -1) return;

    int prevIndex = 0;

    // For sequence, loop, and single (manual prev), go to previous
    // In shuffle mode, _playlist is already shuffled, so just go to previous index
    if (currentIndex > 0) {
      prevIndex = currentIndex - 1;
    } else {
      prevIndex = _playlist.length - 1;
    }

    await _play(_playlist[prevIndex]);
  }

  Future<void> togglePlayMode() async {
    int nextIndex = (_playMode.index + 1) % PlayMode.values.length;
    _playMode = PlayMode.values[nextIndex];
    await _savePlayMode();
    
    // Reload playlist based on new mode
    _playlist = await _databaseService.getPlaylist(shuffle: _playMode == PlayMode.shuffle);
    
    notifyListeners();
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
      // If finished, restart
      if (_audioPlayerService.player.processingState == ProcessingState.completed) {
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
    _playlist = []; // Clear playlist
    await _databaseService.clearPlaylist();
    _isPlaying = false;
    _isPlayerExpanded = false;
    _showFullPlayer = false;
    notifyListeners();
  }

  bool get hasNext {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.sequence) {
      int currentIndex = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      return currentIndex < _playlist.length - 1;
    }
    return true; // Loop, Single, Shuffle always have next
  }

  bool get hasPrevious {
    if (_playlist.isEmpty || _currentSong == null) return false;
    if (_playMode == PlayMode.sequence) {
      int currentIndex = _playlist.indexWhere(
        (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
      );
      return currentIndex > 0;
    }
    return true; // Loop, Single, Shuffle always have previous
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }
}
