import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class AudioStreamApi {
  Future<String?> getAudioStream(String bvid, int cid, {int qn = 80}) async {
    final params = {
      'bvid': bvid,
      'cid': cid,
      'qn': qn,
      'fnval': 16,
      'fnver': 0,
      'fourk': 1,
    };

    try {
      // Pass a flag to suppress global error dialogs for this request
      final data = await Request().get(
        Api.urlPlayUrlWbi,
        params: params,
        useWbi: true,
        suppressErrorDialog: true, 
      );

      if (data != null && data['code'] == 0) {
        final dash = data['data']['dash'];
        if (dash != null) {
          final audioList = dash['audio'];
          if (audioList != null && audioList is List && audioList.isNotEmpty) {
            // Sort by quality (id) descending
            audioList.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
            
            // TODO: Implement quality selection logic here based on user preference or fallback
            // For now, we just pick the highest quality available
            
            String url = audioList.first['baseUrl'];
            if (url.startsWith('http://')) {
              url = url.replaceFirst('http://', 'https://');
            }
            return url;
          }
        }
      }
      // If code is not 0, it might be a permission issue or other error.
      // The caller (AudioProxyService) should handle null return.
      return null;
    } catch (e) {
      print('Error fetching audio stream: $e');
      return null;
    }
  }
}
