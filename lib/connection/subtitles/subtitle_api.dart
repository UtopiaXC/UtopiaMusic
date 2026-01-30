import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/subtitle.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SUBTITLE_API";

class SubtitleApi {
  int _cachedUpMid = 0;

  Future<SubtitleResult> getSubtitleResult(String bvid, int cid) async {
    Log.v(_tag, "Fetching subtitles for $bvid / $cid");
    _cachedUpMid = 0;

    List<SubtitleTrack> tracks = await _fetchTracksFromViewApi(bvid, cid);

    if (tracks.isEmpty) {
      Log.d(_tag, "View API failed, trying Player API");
      tracks = await _fetchTracksFromPlayerApi(bvid, cid);
    }

    if (tracks.isNotEmpty) {
      await _loadTrackContent(tracks[0]);
      return SubtitleResult(tracks: tracks, selectedIndex: 0);
    }

    Log.d(_tag, "No subtitle tracks found, trying AI conclusion");
    final aiItems = await _fetchAiConclusion(bvid, cid, _cachedUpMid);
    if (aiItems.isNotEmpty) {
      return SubtitleResult(
        tracks: [],
        hasAiConclusion: true,
        aiConclusionItems: aiItems,
      );
    }

    return SubtitleResult(tracks: []);
  }

  Future<List<SubtitleItem>> getSubtitles(String bvid, int cid) async {
    final result = await getSubtitleResult(bvid, cid);
    return result.currentItems ?? [];
  }

  Future<void> loadTrackContent(SubtitleTrack track) async {
    await _loadTrackContent(track);
  }

  Future<List<SubtitleTrack>> _fetchTracksFromViewApi(
    String bvid,
    int cid,
  ) async {
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

        final subtitleData = data['data']?['subtitle'];
        if (subtitleData != null) {
          return _parseViewApiTracks(subtitleData['list']);
        }
      }
    } catch (e) {
      Log.w(_tag, "View API error: $e");
    }
    return [];
  }

  Future<List<SubtitleTrack>> _fetchTracksFromPlayerApi(
    String bvid,
    int cid,
  ) async {
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
          return _parsePlayerApiTracks(subData['subtitles']);
        }
      }
    } catch (e) {
      Log.w(_tag, "Player API error: $e");
    }
    return [];
  }

  List<SubtitleTrack> _parseViewApiTracks(dynamic list) {
    if (list is! List || list.isEmpty) return [];

    Log.d(_tag, "Found ${list.length} subtitle tracks from View API");

    final tracks = <SubtitleTrack>[];

    for (var item in list) {
      if (item['subtitle_url'] == null ||
          item['subtitle_url'].toString().isEmpty) {
        continue;
      }

      String url = item['subtitle_url'];
      if (url.startsWith('//')) url = 'https:$url';
      final bool isAi = _isAiSubtitle(item, url);
      final String lan = item['lan'] ?? '';

      final track = SubtitleTrack(
        id: (item['id'] ?? '').toString(),
        displayName: item['lan_doc'] ?? item['lan'] ?? 'Unknown',
        languageCode: lan.startsWith('ai-') ? lan.substring(3) : lan,
        lanDoc: item['lan_doc'] ?? item['lan'] ?? 'Unknown',
        type: isAi ? SubtitleType.ai : SubtitleType.manual,
        subtitleUrl: url,
      );

      tracks.add(track);
      Log.v(
        _tag,
        "Track: ${track.shortName} (${track.typeLabel}) - lan: $lan - URL: $url",
      );
    }

    return tracks;
  }

  bool _isAiSubtitle(dynamic item, String url) {
    final String lan = item['lan'] ?? '';
    if (lan.startsWith('ai-')) {
      return true;
    }

    final int type = item['type'] ?? 0;
    if (type == 1) {
      return true;
    }

    if (url.contains('/ai_subtitle/')) {
      return true;
    }

    return false;
  }

  List<SubtitleTrack> _parsePlayerApiTracks(dynamic list) {
    if (list is! List || list.isEmpty) return [];

    Log.d(_tag, "Found ${list.length} subtitle tracks from Player API");

    final tracks = <SubtitleTrack>[];

    for (var item in list) {
      if (item['subtitle_url'] == null ||
          item['subtitle_url'].toString().isEmpty) {
        continue;
      }

      String url = item['subtitle_url'];
      if (url.startsWith('//')) url = 'https:$url';

      final bool isAi = _isAiSubtitle(item, url);
      final String lan = item['lan'] ?? '';

      final track = SubtitleTrack(
        id: (item['id'] ?? item['id_str'] ?? '').toString(),
        displayName: item['lan_doc'] ?? item['lan'] ?? 'Unknown',
        // Remove "ai-" prefix from language code for display
        languageCode: lan.startsWith('ai-') ? lan.substring(3) : lan,
        lanDoc: item['lan_doc'] ?? item['lan'] ?? 'Unknown',
        type: isAi ? SubtitleType.ai : SubtitleType.manual,
        subtitleUrl: url,
      );

      tracks.add(track);
      Log.v(
        _tag,
        "Track: ${track.shortName} (${track.typeLabel}) - lan: $lan - URL: $url",
      );
    }

    return tracks;
  }

  Future<void> _loadTrackContent(SubtitleTrack track) async {
    if (track.cachedItems != null) return;

    try {
      Log.v(_tag, "Loading content for track: ${track.shortName}");
      final dio = Dio();
      final response = await dio.get(track.subtitleUrl);

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
          Log.v(_tag, "Loaded ${bodyData.length} subtitle lines");
          track.cachedItems = bodyData.map((item) {
            return SubtitleItem(
              from: (item['from'] ?? 0.0).toDouble(),
              to: (item['to'] ?? 0.0).toDouble(),
              content: item['content'] ?? '',
            );
          }).toList();
        }
      }
    } catch (e) {
      Log.w(_tag, "Error loading track content: $e");
      track.cachedItems = [];
    }
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
        if (modelResult != null && (modelResult['result_type'] ?? 0) > 0) {
          Log.v(_tag, "AI Result Type: ${modelResult['result_type']}");

          final aiSubtitle = modelResult['subtitle'];
          if (aiSubtitle is List && aiSubtitle.isNotEmpty) {
            final List<SubtitleItem> items = [];

            for (var subtitleGroup in aiSubtitle) {
              final partSubtitle = subtitleGroup['part_subtitle'];
              if (partSubtitle is List) {
                for (var item in partSubtitle) {
                  items.add(
                    SubtitleItem(
                      from: (item['start_timestamp'] ?? 0.0).toDouble(),
                      to: (item['end_timestamp'] ?? 0.0).toDouble(),
                      content: item['content'] ?? '',
                    ),
                  );
                }
              }
            }

            if (items.isNotEmpty) {
              Log.d(
                _tag,
                "Using AI Time-synced Subtitles (${items.length} items)",
              );
              return items;
            }
          }

          // Try AI outline
          final outline = modelResult['outline'];
          if (outline is List && outline.isNotEmpty) {
            Log.d(_tag, "Using AI Outline.");
            return outline.map<SubtitleItem>((item) {
              double timestamp = (item['timestamp'] ?? 0).toDouble();
              String content = item['title'] ?? '';

              final partOutline = item['part_outline'];
              if (partOutline is List && partOutline.isNotEmpty) {
                final details = partOutline
                    .map((p) => '• ${p['content'] ?? ''}')
                    .join('\n');
                if (details.isNotEmpty) {
                  content += '\n$details';
                }
              }

              return SubtitleItem(
                from: timestamp,
                to: timestamp + 30.0,
                content: "[AI] $content",
              );
            }).toList();
          }

          final String summary = modelResult['summary'] ?? '';
          if (summary.isNotEmpty) {
            Log.d(_tag, "Using AI Summary as fallback.");
            return [
              SubtitleItem(from: 0.0, to: 9999.0, content: "[AI]\n$summary"),
            ];
          }
        } else {
          Log.w(
            _tag,
            "No AI model result found (result_type: ${modelResult?['result_type']})",
          );
        }
      } else {
        Log.w(
          _tag,
          "Cannot access AI API (code: ${data?['code']}), this interface needs login",
        );
      }
    } catch (e) {
      Log.e(_tag, "Error fetching AI conclusion", e);
    }
    return [];
  }
}
