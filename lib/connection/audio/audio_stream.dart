import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "AUDIO_STREAM";

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

  String get mimeType {
    if (quality == QualityUtils.qualityHiRes) {
      Log.i(_tag, "quality is hires, return flac");
      return 'audio/flac';
    }
    switch (extension) {
      case 'flac':
        Log.i(_tag, "getMimeType return flac");
        return 'audio/flac';
      case 'mp3':
        Log.i(_tag, "getMimeType extension is mp3, return mp3");
        return 'audio/mpeg';
      case 'mp4':
        Log.i(_tag, "getMimeType extension is mp4, return mp4");
        return 'audio/mp4';
      case 'm4s':
        Log.i(_tag, "getMimeType extension is m4s, return mp4");
        return 'audio/mp4';
      default:
        Log.i(_tag, "getMimeType extension unknow, return mp4");
        return 'audio/mp4';
    }
  }
}

class AudioStreamApi {
  Future<AudioStreamInfo?> getAudioStream(
    String bvid,
    int cid, {
    int qn = 16,
    int preferredQuality = QualityUtils.quality192k,
  }) async {
    return await _getAudioStreamInternal(
      bvid,
      cid,
      qn,
      preferredQuality,
      isRetry: false,
    );
  }

  Future<AudioStreamInfo?> _getAudioStreamInternal(
    String bvid,
    int cid,
    int qn,
    int preferredQuality, {
    required bool isRetry,
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

      if (data != null) {
        if (data['code'] == 0) {
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

              Log.i(_tag, "availableQualities: $availableQualities");

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
                Log.i(_tag, "selectedAudio: $selectedAudio");
              } else {
                allAudio.sort(
                  (a, b) => getScore(a['id']).compareTo(getScore(b['id'])),
                );
                selectedAudio = allAudio.first;
                Log.i(_tag, "no best match, selectedAudio: $selectedAudio");
              }

              String url = selectedAudio['baseUrl'];
              if (url.startsWith('http://')) {
                url = url.replaceFirst('http://', 'https://');
              }

              // 简单的后缀判断，仅用于 extension 字段，MIME 判断交给了 AudioStreamInfo getter
              String extension = 'm4s';
              if (url.contains('.m4s')) {
                extension = 'm4s';
              } else if (url.contains('.mp4')) {
                extension = 'mp4';
              } else if (url.contains('.flac')) {
                extension = 'flac';
              } else if (url.contains('.mp3')) {
                extension = 'mp3';
              }

              return AudioStreamInfo(
                url: url,
                quality: selectedAudio['id'] as int,
                extension: extension,
                availableQualities: availableQualities,
              );
            }
          }
        } else {
          // 错误处理逻辑
          print(
            'GetAudioStream Error Code: ${data['code']}, Message: ${data['message']}',
          );
          if (!isRetry &&
              (data['code'] == -403 ||
                  data['code'] == -412 ||
                  data['code'] == -400)) {
            print(
              "WBI signature might be invalid. Refreshing keys and retrying...",
            );
            await WbiUtil.invalidateKeys();
            return await _getAudioStreamInternal(
              bvid,
              cid,
              qn,
              preferredQuality,
              isRetry: true,
            );
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching audio stream: $e');
      if (!isRetry) {
        return await _getAudioStreamInternal(
          bvid,
          cid,
          qn,
          preferredQuality,
          isRetry: true,
        );
      }
      return null;
    }
  }

  Future<List<int>> fetchAvailableQualities(String bvid, int cid) async {
    final params = {
      'bvid': bvid,
      'cid': cid,
      'qn': 16,
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

      Log.v(_tag, "fetchAvailableQualities, code is ${data['code']}");

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
            Log.i(_tag, "all available qualities are $availableQualities");
            return availableQualities.toSet().toList();
          }
        }
      }
      Log.e(_tag, "No available qualities found");
      return [];
    } catch (e) {
      Log.e(_tag, "Error fetching available qualities", e);
      return [];
    }
  }

  int getScore(int id) {
    return QualityUtils.getScore(id);
  }
}
