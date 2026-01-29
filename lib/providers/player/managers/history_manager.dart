import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/audio/report_history.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "HISTORY_MANAGER";

class HistoryManager {
  final ReportHistoryApi _reportHistoryApi = ReportHistoryApi();
  final int Function() getCurrentPositionSeconds;
  final int Function() getCurrentPositionMilliseconds;

  Timer? _timer;
  int _reportCounter = 0;
  bool _saveProgress = true;
  Song? _trackingSong;

  HistoryManager({
    required this.getCurrentPositionSeconds,
    required this.getCurrentPositionMilliseconds,
  });

  void updateState({
    required bool isPlaying,
    required Song? currentSong,
    required bool saveProgress,
  }) {
    Log.v(_tag, "updateState");
    _saveProgress = saveProgress;
    if (_trackingSong != currentSong) {
      _trackingSong = currentSong;
      _resetCounter();
    }

    if (isPlaying && currentSong != null) {
      _startTimer(currentSong);
    } else {
      _stopTimer();
      if (currentSong != null) {
        _saveCurrentProgress();
      }
    }
  }

  void _startTimer(Song song) {
    Log.v(_tag, "_startTimer, song: ${song.title}");
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(song));
  }

  void _stopTimer() {
    Log.v(_tag, "_stopTimer");
    _timer?.cancel();
    _timer = null;
  }

  void _resetCounter() {
    Log.v(_tag, "_resetCounter");
    final context = navigatorKey.currentContext;
    if (context != null) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _reportCounter = 15 - settings.historyReportDelay;
    } else {
      _reportCounter = 12;
    }
  }

  Future<void> _tick(Song song) async {
    // Log.v(_tag, "_tick, song: ${song.title}");
    if (_saveProgress) {
      _saveCurrentProgress();
    }

    final context = navigatorKey.currentContext;
    if (context != null) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (settings.enableHistoryReport && auth.isLoggedIn) {
        _reportCounter++;
        if (_reportCounter >= 15) {
          try {
            await _reportHistoryApi.reportHistory(
              bvid: song.bvid,
              cid: song.cid,
              playedTime: getCurrentPositionSeconds(),
            );
          } catch (e) {
            Log.e(_tag, "Report failed", e);
          }
          _reportCounter = 0;
        }
      }
    }
  }

  Future<void> _saveCurrentProgress() async {
    // Log.v(_tag, "_saveCurrentProgress");
    final position = getCurrentPositionMilliseconds();
    if (position > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_played_position', position);
    }
  }

  Future<int> getSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_played_position') ?? 0;
  }

  void dispose() {
    Log.v(_tag, "dispose");
    _stopTimer();
  }
}
