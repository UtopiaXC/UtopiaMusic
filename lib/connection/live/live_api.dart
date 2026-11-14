import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = 'LIVE_API';

class LiveApi {
  final HtmlUnescape _unescape = HtmlUnescape();
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  static Options _liveOptions() => Options(
    headers: const {
      'Referer': 'https://live.bilibili.com/',
      'Origin': 'https://live.bilibili.com',
    },
  );

  String _cleanText(dynamic raw) {
    if (raw == null) return '';
    return _unescape.convert(raw.toString().replaceAll(_htmlTagRegex, '')).trim();
  }

  /// Fetches currently streaming rooms of followed anchors.
  Future<List<LiveRoom>> getFollowedLiveRooms({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await Request().get(
        Api.urlLiveFollowed,
        baseUrl: Api.urlLiveBase,
        params: {
          'page': page,
          'page_size': pageSize,
          'ignoreRecord': 1,
          'hit_ab': true,
        },
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (data is Map && data['code'] == 0) {
        final list = data['data']?['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (item) => LiveRoom.fromFollowedJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((room) => room.roomId > 0 && room.isLive)
              .toList();
        }
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching followed live rooms: $e');
    }
    return [];
  }

  /// Fetches recommended live rooms from Bilibili live web index feed,
  /// falling back to area recommendation when needed.
  Future<List<LiveRoom>> getRecommendedLiveRooms({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final indexData = await Request().get(
        Api.urlLiveIndexList,
        baseUrl: Api.urlLiveBase,
        params: {'platform': 'web', 'page': page},
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      final parsedIndex = parseIndexListResponse(indexData);
      if (parsedIndex.isNotEmpty) {
        return parsedIndex;
      }

      // Secondary fallback with WBI signing + live Referer.
      await Request().ensureBuvidCookies();
      final areaData = await Request().get(
        Api.urlLiveRecommend,
        baseUrl: Api.urlLiveBase,
        params: {
          'platform': 'web',
          'parent_area_id': 0,
          'area_id': 0,
          'sort_type': 'online',
          'page': page,
          'page_size': pageSize,
        },
        useWbi: true,
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (areaData is Map && areaData['code'] == 0) {
        final list = areaData['data']?['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (item) => _parseRecommendEntry(Map<String, dynamic>.from(item)),
              )
              .where((room) => room.roomId > 0)
              .toList();
        }
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching recommended live rooms: $e');
    }
    return [];
  }

  LiveRoom _parseRecommendEntry(Map<String, dynamic> map) {
    final parsed = LiveRoom.fromRecommendJson(map);
    return parsed.copyWith(
      title: _cleanText(parsed.title),
      uname: _cleanText(parsed.uname),
    );
  }

  /// Parses `/xlive/web-interface/v1/index/getList` payloads into deduplicated rooms.
  List<LiveRoom> parseIndexListResponse(dynamic response) {
    if (response is! Map || response['code'] != 0) return const [];
    final data = response['data'];
    if (data is! Map) return const [];

    final rooms = <LiveRoom>[];
    final seenIds = <int>{};

    void addItem(dynamic raw) {
      if (raw is! Map) return;
      final room = _parseRecommendEntry(Map<String, dynamic>.from(raw));
      if (room.roomId > 0 && seenIds.add(room.roomId)) {
        rooms.add(room);
      }
    }

    final recommendList = data['recommend_room_list'];
    if (recommendList is List) {
      for (final item in recommendList) {
        addItem(item);
      }
    }

    final roomCategories = data['room_list'];
    if (roomCategories is List) {
      for (final category in roomCategories) {
        if (category is! Map) continue;
        final list = category['list'];
        if (list is List) {
          for (final item in list) {
            addItem(item);
          }
        }
      }
    }

    return rooms;
  }

  /// Queries live room status for a given user UID. Returns null when offline.
  Future<LiveRoom?> getUserLiveRoom(
    int mid, {
    String uname = '',
    String face = '',
  }) async {
    if (mid <= 0) return null;
    try {
      final data = await Request().get(
        Api.urlLiveRoomByMid,
        baseUrl: Api.urlLiveBase,
        params: {'mid': mid},
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (data is Map && data['code'] == 0 && data['data'] is Map) {
        final d = Map<String, dynamic>.from(data['data'] as Map);
        final int liveStatus = d['liveStatus'] is int
            ? d['liveStatus'] as int
            : int.tryParse('${d['liveStatus']}') ?? 0;
        final int roomId = d['roomid'] is int
            ? d['roomid'] as int
            : int.tryParse('${d['roomid']}') ?? 0;
        if (liveStatus != 1 || roomId <= 0) {
          return null;
        }
        return LiveRoom(
          roomId: roomId,
          uid: mid,
          uname: uname,
          face: LiveRoom.normalizeImageUrl(face),
          title: _cleanText(d['title']),
          cover: LiveRoom.normalizeImageUrl(d['cover']?.toString()),
          online: d['online'] is int
              ? d['online'] as int
              : int.tryParse('${d['online']}') ?? 0,
          isLive: true,
        );
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user live room: $e');
    }
    return null;
  }

  /// Fetches live room metadata (title, area, online count).
  Future<LiveRoom?> getRoomInfo(int roomId, {LiveRoom? fallback}) async {
    try {
      final data = await Request().get(
        Api.urlLiveRoomInfo,
        baseUrl: Api.urlLiveBase,
        params: {'room_id': roomId},
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (data is Map && data['code'] == 0 && data['data'] is Map) {
        final d = Map<String, dynamic>.from(data['data'] as Map);
        final int liveStatus = d['live_status'] is int
            ? d['live_status'] as int
            : int.tryParse('${d['live_status']}') ?? 0;
        return LiveRoom(
          roomId: d['room_id'] is int ? d['room_id'] as int : roomId,
          uid: d['uid'] is int ? d['uid'] as int : (fallback?.uid ?? 0),
          uname: fallback?.uname ?? '',
          face: fallback?.face ?? '',
          title: _cleanText(d['title'] ?? fallback?.title),
          cover: LiveRoom.normalizeImageUrl(
            (d['user_cover'] ?? d['keyframe'] ?? fallback?.cover)?.toString(),
          ),
          areaName: (d['area_name'] ?? fallback?.areaName ?? '').toString(),
          online: d['online'] is int
              ? d['online'] as int
              : (fallback?.online ?? 0),
          isLive: liveStatus == 1,
          isFollowed: fallback?.isFollowed ?? false,
        );
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching room info: $e');
    }
    return fallback;
  }

  /// Searches Bilibili live rooms by keyword.
  Future<List<LiveRoom>> searchLiveRooms(
    String keyword, {
    int page = 1,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];
    try {
      await Request().ensureBuvidCookies();
      final params = {
        'search_type': 'live_room',
        'keyword': trimmed,
        'page': page,
        'platform': 'pc',
        'web_location': 1430654,
      };
      final options = Options(
        headers: {
          'Origin': 'https://search.bilibili.com',
          'Referer':
              'https://search.bilibili.com/live?keyword=${Uri.encodeComponent(trimmed)}',
        },
      );
      var data = await Request().get(
        Api.urlSearch,
        baseUrl: Api.urlBase,
        params: params,
        options: options,
        suppressErrorDialog: true,
      );
      final bool hasVoucher =
          data is Map &&
          data['data'] is Map &&
          data['data']['v_voucher'] != null;
      if (data is! Map || data['code'] != 0 || hasVoucher) {
        await Request().ensureBuvidCookies(forceRefresh: true);
        data = await Request().get(
          Api.urlSearchWbi,
          baseUrl: Api.urlBase,
          params: params,
          useWbi: true,
          options: options,
          suppressErrorDialog: true,
        );
      }
      if (data is Map && data['code'] == 0) {
        final dynamic result = data['data']?['result'];
        List<dynamic> rawList = const [];
        if (result is List) {
          rawList = result;
        } else if (result is Map && result['live_room'] is List) {
          rawList = result['live_room'] as List<dynamic>;
        }
        return rawList
            .whereType<Map>()
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              return LiveRoom.fromSearchJson(
                map,
                cleanedTitle: _cleanText(map['title']),
                cleanedUname: _cleanText(map['uname']),
              );
            })
            .where((room) => room.roomId > 0)
            .toList();
      }
    } catch (e) {
      Log.w(_tag, 'Error searching live rooms: $e');
    }
    return [];
  }

  /// Filters candidate stream URLs for the target runtime playback backend.
  /// Android ExoPlayer plays HLS (`fmp4`/`ts`), while `just_audio_media_kit`
  /// audio-only `libmpv` builds omit FFmpeg's `hls` demuxer and require `.flv`.
  @visibleForTesting
  static List<String> filterUrlsForPlatform(
    List<String> urls, {
    required bool isAndroid,
    bool usesMediaKit = false,
  }) {
    if (isAndroid) {
      final hlsUrls = urls.where((url) {
        final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
        return !path.endsWith('.flv');
      }).toList();
      return hlsUrls.isNotEmpty ? hlsUrls : urls;
    }
    if (usesMediaKit) {
      final flvUrls = urls.where((url) {
        final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
        return path.endsWith('.flv');
      }).toList();
      return flvUrls.isNotEmpty ? flvUrls : urls;
    }
    return urls;
  }

  /// Extracts candidate stream URLs modeled after PiliPlus:
  /// ensures guest buvid cookies, requests WBI-signed `getRoomPlayInfo` with `only_audio: 1`,
  /// falls back to full stream `getRoomPlayInfo` (retrying once on risk control) and legacy `playUrl`,
  /// and filters candidates to the formats supported by the current backend.
  Future<List<String>> getLiveStreamUrls(int roomId) async {
    try {
      await Request().ensureBuvidCookies();
      final bool isAndroid = !kIsWeb && Platform.isAndroid;
      final bool usesMediaKit = !kIsWeb && !isAndroid;

      Future<List<String>> fetchPlayInfo({required bool onlyAudio}) async {
        final params = <String, dynamic>{
          'room_id': roomId,
          'protocol': '0,1',
          'format': '0,1,2',
          'codec': '0,1,2',
          'qn': onlyAudio ? 10000 : 80,
          'platform': 'web',
          'ptype': 8,
          'dolby': 5,
          'panorama': 1,
          'web_location': '444.8',
        };
        if (onlyAudio) {
          params['only_audio'] = 1;
        }
        final resp = await Request().get(
          Api.urlLivePlayInfo,
          baseUrl: Api.urlLiveBase,
          params: params,
          useWbi: true,
          options: _liveOptions(),
          suppressErrorDialog: true,
        );
        return extractPlayInfoUrls(resp);
      }

      var urls = await fetchPlayInfo(onlyAudio: true);
      if (urls.isEmpty) {
        urls = await fetchPlayInfo(onlyAudio: false);
      }
      if (urls.isEmpty) {
        await Request().ensureBuvidCookies(forceRefresh: true);
        urls = await fetchPlayInfo(onlyAudio: false);
      }
      if (urls.isNotEmpty) {
        return filterUrlsForPlatform(
          urls,
          isAndroid: isAndroid,
          usesMediaKit: usesMediaKit,
        );
      }

      final legacyResp = await Request().get(
        Api.urlLivePlayUrl,
        baseUrl: Api.urlLiveBase,
        params: {'cid': roomId, 'platform': 'web', 'qn': 80},
        options: _liveOptions(),
        suppressErrorDialog: true,
      );
      if (legacyResp is Map && legacyResp['code'] == 0) {
        final durl = legacyResp['data']?['durl'];
        if (durl is List) {
          final legacyUrls = durl
              .whereType<Map>()
              .map((entry) => entry['url']?.toString() ?? '')
              .where((url) => url.isNotEmpty)
              .toList();
          return filterUrlsForPlatform(
            legacyUrls,
            isAndroid: isAndroid,
            usesMediaKit: usesMediaKit,
          );
        }
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching live stream urls: $e');
    }
    return [];
  }

  /// Parses `getRoomPlayInfo` JSON into ordered playback URLs:
  /// `http_hls` (fmp4) -> `http_hls` (ts) -> `http_stream` (flv).
  List<String> extractPlayInfoUrls(dynamic response) {
    if (response is! Map || response['code'] != 0) return const [];
    final streams = response['data']?['playurl_info']?['playurl']?['stream'];
    if (streams is! List) return const [];

    final fmp4HlsUrls = <String>[];
    final tsHlsUrls = <String>[];
    final otherHlsUrls = <String>[];
    final flvUrls = <String>[];

    for (final stream in streams) {
      if (stream is! Map) continue;
      final protocolName = stream['protocol_name']?.toString() ?? '';
      final formats = stream['format'];
      if (formats is! List) continue;

      for (final format in formats) {
        if (format is! Map) continue;
        final formatName = format['format_name']?.toString() ?? '';
        final codecs = format['codec'];
        if (codecs is! List) continue;

        for (final codec in codecs) {
          if (codec is! Map) continue;
          final baseUrl = codec['base_url']?.toString() ?? '';
          final urlInfo = codec['url_info'];
          if (baseUrl.isEmpty || urlInfo is! List) continue;

          for (final info in urlInfo) {
            if (info is! Map) continue;
            final host = info['host']?.toString() ?? '';
            final extra = info['extra']?.toString() ?? '';
            if (host.isEmpty) continue;
            final fullUrl = '$host$baseUrl$extra';
            if (protocolName == 'http_hls') {
              if (formatName == 'fmp4') {
                fmp4HlsUrls.add(fullUrl);
              } else if (formatName == 'ts') {
                tsHlsUrls.add(fullUrl);
              } else {
                otherHlsUrls.add(fullUrl);
              }
            } else {
              flvUrls.add(fullUrl);
            }
          }
        }
      }
    }

    return <String>{
      ...fmp4HlsUrls,
      ...tsHlsUrls,
      ...otherHlsUrls,
      ...flvUrls,
    }.toList();
  }
}
