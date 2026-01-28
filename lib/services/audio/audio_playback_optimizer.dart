import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "AUDIO_PLAYBACK_OPTIMIZER";

class AudioPlaybackOptimizer {
  static final AudioPlaybackOptimizer _instance =
      AudioPlaybackOptimizer._internal();

  factory AudioPlaybackOptimizer() => _instance;

  AudioPlaybackOptimizer._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb && Platform.isIOS) {
      _applyIosOptimizations();
    }
    _isInitialized = true;
    Log.i(_tag, "Audio playback optimizer initialized");
  }

  void _applyIosOptimizations() {
    SchedulerBinding.instance.scheduleForcedFrame();

    Log.i(_tag, "iOS audio optimizations applied");
  }

  void onHeavyUiOperationStart() {
    if (!kIsWeb && Platform.isIOS) {}
  }

  void onHeavyUiOperationEnd() {
    if (!kIsWeb && Platform.isIOS) {}
  }
}
