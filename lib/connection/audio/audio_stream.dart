import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class AudioStreamApi {
  Future<String?> getAudioStream(String bvid, int cid) async {
    final params = {
      'bvid': bvid,
      'cid': cid,
      'qn': 80,
      'fnval': 16,
      'fnver': 0,
      'fourk': 1,
    };

    try {
      final data = await Request().get(
        Api.urlPlayUrlWbi,
        params: params,
        useWbi: true,
      );

      if (data != null && data['code'] == 0) {
        final dash = data['data']['dash'];
        if (dash != null) {
          final audioList = dash['audio'];
          if (audioList != null && audioList is List && audioList.isNotEmpty) {
            audioList.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
            String url = audioList.first['baseUrl'];
            if (url.startsWith('http://')) {
              url = url.replaceFirst('http://', 'https://');
            }
            return url;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching audio stream: $e');
      return null;
    }
  }
}
