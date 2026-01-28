import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "IOS_NOW_PLAYING_SERVICE";

class IosNowPlayingService {
  static final IosNowPlayingService _instance = IosNowPlayingService._internal();
  factory IosNowPlayingService() => _instance;
  IosNowPlayingService._internal();

  static const MethodChannel _channel = MethodChannel('com.utopiaxc.utopia.music/now_playing');

  bool _isInitialized = false;
  Song? _currentSong;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;
  bool _isPlaying = false;

  Function()? onPlay;
  Function()? onPause;
  Function()? onPlayPause;
  Function()? onNext;
  Function()? onPrevious;
  Function(Duration)? onSeek;

  Future<void> init() async {
    if (!Platform.isIOS || _isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      await _channel.invokeMethod('initialize');

      _isInitialized = true;
      Log.i(_tag, "iOS NowPlaying service initialized");
    } catch (e) {
      Log.e(_tag, "Failed to initialize iOS NowPlaying service", e);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlay':
        onPlay?.call();
        break;
      case 'onPause':
        onPause?.call();
        break;
      case 'onPlayPause':
        onPlayPause?.call();
        break;
      case 'onNext':
        onNext?.call();
        break;
      case 'onPrevious':
        onPrevious?.call();
        break;
      case 'onSeek':
        final position = call.arguments as double;
        onSeek?.call(Duration(milliseconds: (position * 1000).round()));
        break;
    }
    return null;
  }

  Future<void> updateNowPlaying({
    required Song song,
    required Duration duration,
    required Duration position,
    required bool isPlaying,
    double playbackRate = 1.0,
  }) async {
    if (!Platform.isIOS || !_isInitialized) return;

    _currentSong = song;
    _duration = duration;
    _position = position;
    _isPlaying = isPlaying;
    _playbackRate = playbackRate;

    try {
      await _channel.invokeMethod('updateNowPlaying', {
        'title': song.title,
        'artist': song.artist,
        'albumArt': song.coverUrl,
        'duration': duration.inSeconds.toDouble(),
        'position': position.inSeconds.toDouble(),
        'playbackRate': isPlaying ? playbackRate : 0.0,
        'isPlaying': isPlaying,
      });
    } catch (e) {
      Log.e(_tag, "Failed to update NowPlaying", e);
    }
  }

  Future<void> updatePosition(Duration position) async {
    if (!Platform.isIOS || !_isInitialized || _currentSong == null) return;

    _position = position;

    try {
      await _channel.invokeMethod('updatePosition', {
        'position': position.inSeconds.toDouble(),
        'playbackRate': _isPlaying ? _playbackRate : 0.0,
      });
    } catch (e) {}
  }

  Future<void> updatePlaybackState(bool isPlaying) async {
    if (!Platform.isIOS || !_isInitialized) return;

    _isPlaying = isPlaying;

    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'playbackRate': isPlaying ? _playbackRate : 0.0,
        'position': _position.inSeconds.toDouble(),
      });
    } catch (e) {
      Log.e(_tag, "Failed to update playback state", e);
    }
  }

  Future<void> updateCommandState({
    required bool hasNext,
    required bool hasPrevious,
  }) async {
    if (!Platform.isIOS || !_isInitialized) return;

    try {
      await _channel.invokeMethod('updateCommandState', {
        'hasNext': hasNext,
        'hasPrevious': hasPrevious,
      });
    } catch (e) {
      Log.e(_tag, "Failed to update command state", e);
    }
  }

  Future<void> clearNowPlaying() async {
    if (!Platform.isIOS || !_isInitialized) return;

    _currentSong = null;
    _duration = Duration.zero;
    _position = Duration.zero;
    _isPlaying = false;

    try {
      await _channel.invokeMethod('clearNowPlaying');
    } catch (e) {
      Log.e(_tag, "Failed to clear NowPlaying", e);
    }
  }

  void bindToPlayer(AudioPlayer player, {
    required Function() onPlayCallback,
    required Function() onPauseCallback,
    required Function() onNextCallback,
    required Function() onPreviousCallback,
    required Function(Duration) onSeekCallback,
  }) {
    onPlay = onPlayCallback;
    onPause = onPauseCallback;
    onPlayPause = () {
      if (_isPlaying) {
        onPauseCallback();
      } else {
        onPlayCallback();
      }
    };
    onNext = onNextCallback;
    onPrevious = onPreviousCallback;
    onSeek = onSeekCallback;
  }

  void dispose() {
    onPlay = null;
    onPause = null;
    onPlayPause = null;
    onNext = null;
    onPrevious = null;
    onSeek = null;
  }
}