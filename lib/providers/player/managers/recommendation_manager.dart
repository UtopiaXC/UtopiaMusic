import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "RECOMMENDATION_MANAGER";

class RecommendationManager {
  final VideoDetailApi _videoDetailApi = VideoDetailApi();

  final Future<void> Function(List<Song> newPlaylist) onPlaylistUpdate;

  bool _enabled = false;
  bool _isLoading = false;
  static const String _prefKey = 'recommendation_auto_play';

  bool get isEnabled => _enabled;

  bool get isLoading => _isLoading;

  RecommendationManager({required this.onPlaylistUpdate});

  Future<void> loadSettings() async {
    Log.v(_tag, "loadSettings");
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    Log.v(_tag, "setEnabled, value: $value");
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  Future<void> checkAndLoad({
    required Song currentSong,
    required List<Song> currentPlaylist,
    required Function() notifyLoading,
    required Function() notifyLoaded,
  }) async {
    Log.v(_tag, "checkAndLoad");
    if (!_enabled) {
      Log.v(_tag, "AutoPlay disabled, skipping.");
      return;
    }
    if (_isLoading) {
      Log.v(_tag, "Already loading, skipping.");
      return;
    }

    _isLoading = true;
    notifyLoading();

    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        Log.w(_tag, "Context is null, cannot fetch related videos.");
        return;
      }

      final related = await _videoDetailApi.getRelatedVideos(
        context,
        currentSong.bvid,
      );

      if (related.isNotEmpty) {
        await _updatePlaylistResetHistory(currentSong, related);
      } else {
        Log.w(_tag, "No related videos found.");
      }
    } catch (e) {
      Log.e(_tag, "AutoPlay Error", e);
    } finally {
      _isLoading = false;
      notifyLoaded();
    }
  }

  Future<void> _updatePlaylistResetHistory(
    Song currentSong,
    List<Song> related,
  ) async {
    Log.v(
      _tag,
      "_updatePlaylistResetHistory, currentSong: ${currentSong.title}, related: ${related.length}",
    );
    List<Song> newPlaylist = [currentSong];

    final Set<String> seen = {'${currentSong.bvid}_${currentSong.cid}'};
    for (var s in related) {
      final key = '${s.bvid}_${s.cid}';
      if (!seen.contains(key)) {
        seen.add(key);
        newPlaylist.add(s);
      }
    }
    await onPlaylistUpdate(newPlaylist);
  }

  Future<void> resetToDefault() async {
    Log.v(_tag, "resetToDefault");
    await setEnabled(false);
  }
}
