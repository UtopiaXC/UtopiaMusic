import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "BACKGROUND_PLAYBACK_SERVICE";

class BackgroundPlaybackService with WidgetsBindingObserver {
  static final BackgroundPlaybackService _instance = BackgroundPlaybackService._internal();
  factory BackgroundPlaybackService() => _instance;
  BackgroundPlaybackService._internal();

  bool _isInitialized = false;
  AudioSession? _audioSession;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _becomingNoisySubscription;

  bool _wasPlayingBeforeInterruption = false;
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      WidgetsBinding.instance.addObserver(this);
      _audioSession = await AudioSession.instance;

      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _interruptionSubscription = _audioSession!.interruptionEventStream.listen((event) {
        _handleInterruption(event);
      });

      _becomingNoisySubscription = _audioSession!.becomingNoisyEventStream.listen((_) {
        _handleBecomingNoisy();
      });

      await _audioSession!.setActive(true);

      _isInitialized = true;
      Log.i(_tag, "Background playback service initialized");

    } catch (e) {
      Log.e(_tag, "Failed to initialize background playback service", e);
    }
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    Log.i(_tag, "Audio interruption: ${event.type}, begin=${event.begin}");

    final player = AudioPlayerService().player;

    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          _wasPlayingBeforeInterruption = player.playing;
          if (_wasPlayingBeforeInterruption) {
            player.pause();
          }
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_wasPlayingBeforeInterruption) {
            player.play();
          }
          break;
      }
    }
  }

  void _handleBecomingNoisy() {
    Log.i(_tag, "Audio becoming noisy (headphones unplugged?)");
    AudioPlayerService().player.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Log.d(_tag, "App lifecycle state changed: $state");

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onAppResumed() {
    Log.d(_tag, "App resumed");
    _audioSession?.setActive(true);
  }

  void _onAppPaused() {
    Log.d(_tag, "App paused (entering background)");
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interruptionSubscription?.cancel();
    _becomingNoisySubscription?.cancel();
  }
}