import 'dart:async';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SLEEP_TIMER_MANAGER";

class SleepTimerManager {
  final AudioPlayerService _audioPlayerService;
  final Function() notifyListeners;

  Timer? _timer;
  DateTime? _stopTime;
  bool _stopAfterCurrent = false;

  SleepTimerManager({
    required AudioPlayerService audioPlayerService,
    required this.notifyListeners,
  }) : _audioPlayerService = audioPlayerService;

  bool get isActive => _timer != null;

  DateTime? get stopTime => _stopTime;

  bool get stopAfterCurrent => _stopAfterCurrent;

  void setTimer(Duration duration, {bool stopAfterCurrent = false}) {
    Log.v(
      _tag,
      "setTimer, duration: $duration, stopAfterCurrent: $stopAfterCurrent",
    );
    cancel();
    _stopTime = DateTime.now().add(duration);
    _stopAfterCurrent = stopAfterCurrent;

    _timer = Timer(duration, () {
      if (!_stopAfterCurrent) {
        _audioPlayerService.stop();
        cancel();
      }
    });
    notifyListeners();
  }

  void setStopTime(DateTime time, {bool stopAfterCurrent = false}) {
    Log.v(
      _tag,
      "setStopTime, time: $time, stopAfterCurrent: $stopAfterCurrent",
    );
    final now = DateTime.now();
    final duration = time.difference(now);
    if (duration.isNegative) {
      cancel();
      return;
    }
    setTimer(duration, stopAfterCurrent: stopAfterCurrent);
  }

  void onPlaybackCompleted() {
    Log.v(_tag, "onPlaybackCompleted");
    if (_stopAfterCurrent && isActive && _stopTime != null) {
      if (DateTime.now().isAfter(_stopTime!)) {
        cancel();
        _audioPlayerService.stop();
      }
    }
  }

  void cancel() {
    Log.v(_tag, "cancel");
    _timer?.cancel();
    _timer = null;
    _stopTime = null;
    _stopAfterCurrent = false;
    notifyListeners();
  }

  void dispose() {
    Log.v(_tag, "dispose");
    _timer?.cancel();
  }
}
