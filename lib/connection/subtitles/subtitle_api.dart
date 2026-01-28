import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/subtitle.dart';
import 'package:utopia_music/utils/log.dart';

final String _tag = "SUBTITLE_API";

class SubtitleApi {
  int _cachedUpMid = 0;

  Future<List<SubtitleItem>> getSubtitles(String bvid, int cid) async {
    Log.v(_tag, "Fetching for $bvid / $cid");
    _cachedUpMid = 0;
    List<SubtitleItem> subtitles = await _fetchFromViewApi(bvid, cid);
    if (subtitles.isNotEmpty) return subtitles;
    Log.d(_tag, "View API failed to get subs, trying Player API");
    subtitles = await _fetchFromPlayerApi(bvid, cid);
    if (subtitles.isNotEmpty) return subtitles;
    Log.d(
      _tag,
      "Standard subtitles empty, trying AI conclusion with mid: $_cachedUpMid",
    );
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
          Log.v(_tag, "Captured UpMid: $_cachedUpMid");
        }
      }

      return await _parseSubtitleData(data);
    } catch (e) {
      Log.w(_tag, "View API error, might no subtitles or not login");
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
      Log.w(_tag, "Player API error, might no subtitles or not login");
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
      Log.d(_tag, "Found ${list.length} subtitle tracks.");
      var target = list.firstWhere(
        (s) =>
            s['subtitle_url'] != null &&
            s['subtitle_url'].toString().isNotEmpty,
        orElse: () => null,
      );

      if (target != null) {
        String url = target['subtitle_url'];
        if (url.startsWith('//')) url = 'https:$url';
        Log.d(_tag, "Selected subtitle URL: $url");
        return await _fetchAndParseSubtitle(url);
      }
    }
    return [];
  }

  Future<List<SubtitleItem>> _fetchAiConclusion(
    String bvid,
    int cid,
    int upMid,
  ) async {
    try {
      final params = {'bvid': bvid, 'cid': cid, 'up_mid': upMid};

      final data = await Request().get(
        '/x/web-interface/view/conclusion/get',
        baseUrl: Api.urlBase,
        params: params,
        useWbi: true,
        suppressErrorDialog: true,
      );

      if (data != null && data['code'] == 0) {
        final modelResult = data['data']?['model_result'];
        if (modelResult != null && modelResult['result_type'] > 0) {
          Log.v(_tag, "AI Result Type: ${modelResult['result_type']}");
          final aiSubtitles = modelResult['subtitle'];
          if (aiSubtitles is List && aiSubtitles.isNotEmpty) {
            Log.d(_tag, "Using AI Time-synced Subtitles.");
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
            Log.d(_tag, "Using AI Outline.");
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
            Log.d(_tag, "Using AI Summary as fallback.");
            return [
              SubtitleItem(
                from: 0.0,
                to: 9999.0,
                content: "【AI 视频摘要】\n$summary",
              ),
            ];
          }
        } else {
          Log.w(_tag, "No AI model result found.");
        }
      } else {
        Log.w(_tag, "Cannot access AI API, this interface needs login");
      }
    } catch (e) {
      Log.e(_tag, "Error fetching AI conclusion", e);
    }
    return [];
  }

  Future<List<SubtitleItem>> _fetchAndParseSubtitle(String url) async {
    try {
      Log.v(_tag, "Downloading subtitle JSON");
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
          Log.v(_tag, "Parsed ${bodyData.length} lines.");
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
      Log.w(_tag, "Error parsing subtitle content: $e");
    }
    return [];
  }
}
