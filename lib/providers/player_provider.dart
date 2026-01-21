import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  
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
    _loadPlayMode();
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

  // Add a single song to playlist and play it
  Future<void> playSong(Song song) async {
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      _playlist.add(song);
    }
    await _play(song);
  }

  // Replace playlist with new list and play specific song
  Future<void> setPlaylistAndPlay(List<Song> songs, Song initialSong) async {
    _playlist = [];
    // Filter duplicates based on bvid
    final seen = <String>{};
    for (var song in songs) {
      if (song.bvid.isNotEmpty && !seen.contains(song.bvid)) {
        seen.add(song.bvid);
        _playlist.add(song);
      }
    }
    
    // Ensure initialSong is in the playlist if it has a valid bvid
    if (initialSong.bvid.isNotEmpty && !_playlist.any((s) => s.bvid == initialSong.bvid)) {
       _playlist.insert(0, initialSong);
    }

    await _play(initialSong);
  }

  // Insert song after current song
  void insertNext(Song song) {
    if (_playlist.isEmpty) {
      playSong(song);
      return;
    }
    
    // Check if song already exists
    final existingIndex = _playlist.indexWhere((s) => s.bvid == song.bvid && s.cid == song.cid);
    if (existingIndex != -1) {
      // If it exists, remove it first (to move it)
      _playlist.removeAt(existingIndex);
    }

    if (_currentSong != null) {
      final currentIndex = _playlist.indexWhere((s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid);
      if (currentIndex != -1) {
        _playlist.insert(currentIndex + 1, song);
      } else {
        _playlist.add(song);
      }
    } else {
      _playlist.add(song);
    }
    notifyListeners();
  }

  // Insert song after current song and play immediately
  Future<void> insertNextAndPlay(Song song) async {
    insertNext(song);
    await playNext();
  }

  // Add song to end of playlist
  void addToEnd(Song song) {
    if (_playlist.isEmpty) {
      playSong(song);
      return;
    }

    // Check if song already exists
    if (!_playlist.any((s) => s.bvid == song.bvid && s.cid == song.cid)) {
      _playlist.add(song);
      notifyListeners();
    }
  }

  // Replace playlist with single song
  Future<void> replacePlaylistWithSong(Song song) async {
    _playlist = [song];
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
        nextIndex = Random().nextInt(_playlist.length);
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

  void playPrevious() {
    if (_playlist.isEmpty || _currentSong == null) return;

    int currentIndex = _playlist.indexWhere(
      (s) => s.bvid == _currentSong!.bvid && s.cid == _currentSong!.cid,
    );

    if (currentIndex == -1) return;

    int prevIndex = 0;

    if (_playMode == PlayMode.shuffle) {
       prevIndex = Random().nextInt(_playlist.length);
    } else {
      // For sequence, loop, and single (manual prev), go to previous
      if (currentIndex > 0) {
        prevIndex = currentIndex - 1;
      } else {
        prevIndex = _playlist.length - 1;
      }
    }

    _play(_playlist[prevIndex]);
  }

  void togglePlayMode() {
    int nextIndex = (_playMode.index + 1) % PlayMode.values.length;
    _playMode = PlayMode.values[nextIndex];
    _savePlayMode();
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
