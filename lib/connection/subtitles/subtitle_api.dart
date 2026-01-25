import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/subtitle.dart';

class SubtitleApi {
  int _cachedUpMid = 0;
  Future<List<SubtitleItem>> getSubtitles(String bvid, int cid) async {
    print('[SubtitleDebug] Fetching for $bvid / $cid');
    _cachedUpMid = 0;
    List<SubtitleItem> subtitles = await _fetchFromViewApi(bvid, cid);
    if (subtitles.isNotEmpty) return subtitles;
    print('[SubtitleDebug] View API failed to get subs, trying Player API...');
    subtitles = await _fetchFromPlayerApi(bvid, cid);
    if (subtitles.isNotEmpty) return subtitles;
    print('[SubtitleDebug] Standard subtitles empty, trying AI conclusion with mid: $_cachedUpMid');
    return await _fetchAiConclusion(bvid, cid, _cachedUpMid);
  }
  Future<List<SubtitleItem>> _fetchFromViewApi(String bvid, int cid) async {
    try {
      final data = await Request().get(
        Api.urlVideoDetail,
        baseUrl: Api.urlBase,
        params: {'bvid': bvid, 'cid': cid},
        useWbi: true,
      );
      if (data != null && data['data'] != null) {
        final owner = data['data']['owner'];
        if (owner != null) {
          _cachedUpMid = owner['mid'] ?? 0;
          print('[SubtitleDebug] Captured UpMid: $_cachedUpMid');
        }
      }

      return await _parseSubtitleData(data);
    } catch (e) {
      print('[SubtitleDebug] View API error: $e');
    }
    return [];
  }

  Future<List<SubtitleItem>> _fetchFromPlayerApi(String bvid, int cid) async {
    try {
      final data = await Request().get(
        '/x/player/wbi/v2',
        baseUrl: Api.urlBase,
        params: {'bvid': bvid, 'cid': cid},
        useWbi: true,
      );
      if (data != null && data['data'] != null) {
        final subData = data['data']['subtitle'];
        if (subData != null) {
          return await _processSubtitleList(subData['subtitles']);
        }
      }
    } catch (e) {
      print('[SubtitleDebug] Player API error: $e');
    }
    return [];
  }

  Future<List<SubtitleItem>> _parseSubtitleData(dynamic data) async {
    if (data != null && data['code'] == 0) {
      final subtitleData = data['data']?['subtitle'];
      if (subtitleData != null) {
        return await _processSubtitleList(subtitleData['list']);
      }
    }
    return [];
  }

  Future<List<SubtitleItem>> _processSubtitleList(dynamic list) async {
    if (list is List && list.isNotEmpty) {
      print('[SubtitleDebug] Found ${list.length} subtitle tracks.');
      var target = list.firstWhere(
              (s) => s['subtitle_url'] != null && s['subtitle_url'].toString().isNotEmpty,
          orElse: () => null
      );

      if (target != null) {
        String url = target['subtitle_url'];
        if (url.startsWith('//')) url = 'https:$url';
        print('[SubtitleDebug] Selected subtitle URL: $url');
        return await _fetchAndParseSubtitle(url);
      }
    }
    return [];
  }

  Future<List<SubtitleItem>> _fetchAiConclusion(String bvid, int cid, int upMid) async {
    try {
      final params = {'bvid': bvid, 'cid': cid, 'up_mid': upMid};

      final data = await Request().get(
        '/x/web-interface/view/conclusion/get',
        baseUrl: Api.urlBase,
        params: params,
        useWbi: true,
      );

      if (data != null && data['code'] == 0) {
        final modelResult = data['data']?['model_result'];
        if (modelResult != null && modelResult['result_type'] > 0) {
          print('[SubtitleDebug] AI Result Type: ${modelResult['result_type']}');
          final aiSubtitles = modelResult['subtitle'];
          if (aiSubtitles is List && aiSubtitles.isNotEmpty) {
            print('[SubtitleDebug] Using AI Time-synced Subtitles.');
            return aiSubtitles.map<SubtitleItem>((item) {
              return SubtitleItem(
                from: (item['from'] ?? 0.0).toDouble(),
                to: (item['to'] ?? 0.0).toDouble(),
                content: item['content'] ?? '',
              );
            }).toList();
          }

          final outline = modelResult['outline'];
          if (outline is List && outline.isNotEmpty) {
            print('[SubtitleDebug] Using AI Outline.');
            return outline.map<SubtitleItem>((item) {
              double timestamp = (item['timestamp'] ?? 0).toDouble();
              String content = item['title'] ?? '';
              if (item['part_summary'] != null) {
                content += "\n${item['part_summary']}";
              }
              return SubtitleItem(
                from: timestamp,
                to: timestamp + 10.0,
                content: "【AI 提纲】 $content",
              );
            }).toList();
          }
          final String summary = modelResult['summary'] ?? '';
          if (summary.isNotEmpty) {
            print('[SubtitleDebug] Using AI Summary as fallback.');
            return [
              SubtitleItem(
                  from: 0.0,
                  to: 9999.0,
                  content: "【AI 视频摘要】\n$summary"
              )
            ];
          }
        } else {
          print('[SubtitleDebug] No AI model result found.');
        }
      } else {
        print('[SubtitleDebug] AI API Error: ${data?['code']} ${data?['message']}');
      }
    } catch (e) {
      print('[SubtitleDebug] Error fetching AI conclusion: $e');
    }
    return [];
  }

  Future<List<SubtitleItem>> _fetchAndParseSubtitle(String url) async {
    try {
      print('[SubtitleDebug] Downloading subtitle JSON...');
      final dio = Dio();
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        dynamic bodyData;
        if (response.data is String) {
          try {
            bodyData = jsonDecode(response.data)['body'];
          } catch (_) {}
        } else if (response.data is Map) {
          bodyData = response.data['body'];
        }

        if (bodyData is List) {
          print('[SubtitleDebug] Parsed ${bodyData.length} lines.');
          return bodyData.map((item) {
            return SubtitleItem(
              from: (item['from'] ?? 0.0).toDouble(),
              to: (item['to'] ?? 0.0).toDouble(),
              content: item['content'] ?? '',
            );
          }).toList();
        }
      }
    } catch (e) {
      print('[SubtitleDebug] Error parsing subtitle content: $e');
    }
    return [];
  }
}