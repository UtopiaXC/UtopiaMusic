import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class AudioStreamInfo {
  final String url;
  final int quality;
  final String extension;
  final List<int> availableQualities;

  AudioStreamInfo({
    required this.url,
    required this.quality,
    required this.extension,
    required this.availableQualities,
  });
}

class AudioStreamApi {
  Future<AudioStreamInfo?> getAudioStream(
    String bvid,
    int cid, {
    int qn = 16,
    int preferredQuality = 30280,
  }) async {
    final params = {
      'bvid': bvid,
      'cid': cid,
      'qn': qn,
      'fnval': 4048,
      'fnver': 0,
      'fourk': 0,
    };

    try {
      final data = await Request().get(
        Api.urlPlayUrlWbi,
        params: params,
        useWbi: true,
        suppressErrorDialog: true,
      );

      if (data != null && data['code'] == 0) {
        final dash = data['data']['dash'];
        if (dash != null) {
          List<dynamic> allAudio = [];

          if (dash['audio'] != null && dash['audio'] is List) {
            allAudio.addAll(dash['audio']);
          }

          if (dash['dolby'] != null &&
              dash['dolby']['audio'] != null &&
              dash['dolby']['audio'] is List) {
            allAudio.addAll(dash['dolby']['audio']);
          }

          if (dash['flac'] != null && dash['flac']['audio'] != null) {
            if (dash['flac']['audio'] is List) {
              allAudio.addAll(dash['flac']['audio']);
            } else if (dash['flac']['audio'] is Map) {
              allAudio.add(dash['flac']['audio']);
            }
          }

          if (allAudio.isNotEmpty) {
            List<int> availableQualities = [];
            for (var a in allAudio) {
              if (a['id'] != null) {
                availableQualities.add(a['id'] as int);
              }
            }
            availableQualities = availableQualities.toSet().toList();
            availableQualities.sort(
              (a, b) => getScore(b).compareTo(getScore(a)),
            );

            int preferredScore = getScore(preferredQuality);

            var candidates = allAudio.where((a) {
              int id = a['id'] as int;
              return getScore(id) <= preferredScore;
            }).toList();

            Map<String, dynamic> selectedAudio;

            if (candidates.isNotEmpty) {
              candidates.sort(
                (a, b) => getScore(b['id']).compareTo(getScore(a['id'])),
              );
              selectedAudio = candidates.first;
            } else {
              allAudio.sort(
                (a, b) => getScore(a['id']).compareTo(getScore(b['id'])),
              );
              selectedAudio = allAudio.first;
            }

            String url = selectedAudio['baseUrl'];
            if (url.startsWith('http://')) {
              url = url.replaceFirst('http://', 'https://');
            }

            String extension = 'm4s';
            if (url.contains('.m4s')) {
              extension = 'm4s';
            } else if (url.contains('.mp4')) {
              extension = 'mp4';
            } else if (url.contains('.flac')) {
              extension = 'flac';
            }

            return AudioStreamInfo(
              url: url,
              quality: selectedAudio['id'] as int,
              extension: extension,
              availableQualities: availableQualities,
            );
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching audio stream: $e');
      return null;
    }
  }

  int getScore(int id) {
    switch (id) {
      case 30251:
        return 5; // Hi-Res
      case 30250:
        return 4; // Dolby
      case 30280:
        return 3; // 192K
      case 30232:
        return 2; // 132K
      case 30216:
        return 1; // 64K
      default:
        return 0;
    }
  }
}
