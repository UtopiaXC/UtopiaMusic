import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class VideoDetailApi {
  Future<Map<String, dynamic>?> getVideoDetail(String bvid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(SettingsProvider.requestDelayKey) ?? 100;
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }

      final data = await Request().get(
        Api.urlVideoDetail,
        baseUrl: Api.urlBase,
        params: {'bvid': bvid},
        useWbi: true,
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching video detail: $e');
    }
    return null;
  }
}
