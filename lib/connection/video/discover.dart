import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/bili_id.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "VIDEO_API";

class VideoApi {
  static const String _kFreshIdxKey = 'video_api_fresh_idx';
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<List<Song>> getRecommentVideos(
    BuildContext context, {
    int recursionDepth = 0,
  }) async {
    if (recursionDepth > 10) {
      Log.w(
        _tag,
        'Max recursion depth reached ($recursionDepth), stopping retry.',
      );
      return [];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      int currentIdx = prefs.getInt(_kFreshIdxKey) ?? 1;
      currentIdx++;
      await prefs.setInt(_kFreshIdxKey, currentIdx);

      final params = {
        'feed_version': 'V8',
        'version': 1,
        'homepage_ver': 1,
        'fresh_type': 4,
        'y_num': 5,
        'fresh_idx': currentIdx,
        'fresh_idx_1h': currentIdx,
        'ps': 20,
        'plat': 1,
        'web_location': 1430650,
      };

      final data = await Request().get(
        Api.urlRecommentList,
        baseUrl: Api.urlBase,
        params: params,
        useWbi: true,
      );

      if (data != null && data is Map && data['code'] == 0) {
        final List<dynamic> list = data['data']?['item'] ?? [];
        final songs = list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(context, item))
            .toList();
        if (songs.isNotEmpty) return songs;
      } else if (data != null && data is Map && data['code'] == 62011) {
        Log.d(_tag, 'Feed exhausted (62011), resetting fresh_idx to 0...');
        await prefs.setInt(_kFreshIdxKey, 0);
        if (!context.mounted) return [];
        return getRecommentVideos(context, recursionDepth: recursionDepth + 1);
      }

      if (context.mounted) {
        return _getRecommendVideosApp(context, currentIdx);
      }
      return [];
    } catch (e) {
      Log.w(_tag, 'Error fetching recommend videos: $e');
      if (context.mounted) {
        return _getRecommendVideosApp(context, 0);
      }
      return [];
    }
  }

  Future<List<Song>> _getRecommendVideosApp(
    BuildContext context,
    int idx,
  ) async {
    try {
      final data = await Request().get(
        Api.urlAppRcmd,
        baseUrl: Api.urlAppBase,
        params: {
          'idx': idx,
          'pull': 'true',
          'column': 4,
          'flush': 0,
        },
        useAppSign: true,
        suppressErrorDialog: true,
      );
      if (data != null && data is Map && data['code'] == 0 && context.mounted) {
        return mapAppFeedItems(context, data['data']?['items']);
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching app recommend videos: $e');
    }
    return [];
  }

  /// Normalizes `/x/v2/feed/index` items into [Song] entries for fallback feed.
  @visibleForTesting
  List<Song> mapAppFeedItems(BuildContext context, dynamic rawItems) {
    if (rawItems is! List) return [];
    final songs = <Song>[];
    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final item = Map<String, dynamic>.from(entry);
      if (item['goto'] != null && item['goto'] != 'av') continue;
      final args = item['args'] is Map ? item['args'] as Map : null;
      final playerArgs = item['player_args'] is Map
          ? item['player_args'] as Map
          : null;
      final int aid =
          int.tryParse('${playerArgs?['aid'] ?? args?['aid'] ?? item['param'] ?? 0}') ??
          0;
      String bvid = item['bvid']?.toString() ?? '';
      if (bvid.isEmpty && aid > 0) {
        bvid = BiliIdUtils.av2bv(aid);
      }
      if (bvid.isEmpty) continue;
      String cover = item['cover']?.toString() ?? '';
      if (cover.startsWith('http://')) {
        cover = cover.replaceFirst('http://', 'https://');
      } else if (cover.startsWith('//')) {
        cover = 'https:$cover';
      }
      final String artist =
          args?['up_name']?.toString() ?? S.of(context).common_unknown;
      final int? duration = playerArgs?['duration'] is int
          ? playerArgs!['duration'] as int
          : _parseDuration(playerArgs?['duration']?.toString());
      final int cid = playerArgs?['cid'] is int
          ? playerArgs!['cid'] as int
          : int.tryParse('${playerArgs?['cid'] ?? 0}') ?? 0;
      songs.add(
        Song(
          title: _unescape.convert(
            item['title']?.toString() ?? S.of(context).common_no_title,
          ),
          artist: _unescape.convert(artist),
          coverUrl: cover,
          lyrics: S.of(context).common_no_lyrics,
          colorValue: 0xFF2196F3,
          bvid: bvid,
          cid: cid,
          durationSeconds: duration,
        ),
      );
    }
    return songs;
  }

  Future<List<Song>> getRankingVideos(
    BuildContext context, {
    int rid = 0,
  }) async {
    try {
      final data = await Request().get(
        Api.urlRanking,
        baseUrl: Api.urlBase,
        params: {'rid': rid, 'type': 'all'},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data']['list'] ?? [];
        return list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(context, item))
            .toList();
      } else {
        Log.w(
          _tag,
          'Failed to load ranking videos: ${data?['message']} (${data?['code']})',
        );
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching ranking videos: $e');
    }
    return [];
  }

  Future<List<Song>> getRegionRankingVideos(
    BuildContext context, {
    required int rid,
  }) async {
    try {
      final data = await Request().get(
        Api.urlRankingRegion,
        baseUrl: Api.urlBase,
        params: {'rid': rid, 'day': 3, 'original': 0},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data'] ?? [];
        return list.map((item) => _mapToSong(context, item)).toList();
      } else {
        Log.w(
          _tag,
          'Failed to load region ranking videos: ${data?['message']} (${data?['code']})',
        );
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching region ranking videos: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getFeed(
    BuildContext context,
    String offset,
  ) async {
    try {
      final data = await Request().get(
        Api.urlDynamicFeed,
        baseUrl: Api.urlBase,
        params: {'timezone_offset': '-480', 'type': 'video', 'offset': offset},
      );

      if (data != null) {
        if (data['code'] == 0) {
          final items = data['data']['items'] as List;
          final songs = <Song>[];
          for (var item in items) {
            if (item['type'] == 'DYNAMIC_TYPE_AV') {
              final modules = item['modules'];
              final moduleDynamic = modules['module_dynamic'];
              final major = moduleDynamic['major'];
              final archive = major['archive'];
              final author = modules['module_author'];

              final stat = archive['stat'] as Map<String, dynamic>?;
              songs.add(
                Song(
                  title: _unescape.convert(
                    archive['title'] ?? S.of(context).common_no_title,
                  ),
                  artist: _unescape.convert(
                    author['name'] ?? S.of(context).common_unknown,
                  ),
                  coverUrl: archive['cover'],
                  lyrics: '',
                  colorValue: 0xFF2196F3,
                  bvid: archive['bvid'],
                  cid: 0,
                  durationSeconds: _parseDuration(archive['duration_text']),
                  viewCount: _parseCount(stat?['play']),
                  danmakuCount: _parseCount(stat?['danmaku']),
                  isFollowed: true,
                ),
              );
            }
          }
          return {
            'code': 0,
            'songs': songs,
            'offset': data['data']['offset'] ?? '',
            'has_more': data['data']['has_more'] ?? false,
          };
        } else {
          return {'code': data['code'], 'message': data['message']};
        }
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching feed: $e');
      return {'code': -1, 'message': e.toString()};
    }
    return {'code': -1, 'message': 'Unknown error'};
  }

  Song _mapToSong(BuildContext context, dynamic item) {
    String artist = S.of(context).common_unknown;
    if (item['owner'] != null) {
      artist = item['owner']['name'];
    } else if (item['author'] != null) {
      artist = item['author'];
    } else if (item['upper'] != null) {
      artist = item['upper']['name'];
    }

    String cover = item['pic'] ?? item['cover'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    final stat = item['stat'] as Map<String, dynamic>?;
    final int? duration = item['duration'] is int
        ? item['duration'] as int
        : _parseDuration(item['duration']?.toString());
    final int? viewCount =
        _parseCount(stat?['view']) ?? _parseCount(item['play']);
    final int? danmakuCount =
        _parseCount(stat?['danmaku']) ?? _parseCount(item['video_review']);
    final bool isFollowed = (item['is_followed'] == 1 || item['is_followed'] == true);

    return Song(
      title: _unescape.convert(item['title'] ?? S.of(context).common_no_title),
      artist: _unescape.convert(artist),
      coverUrl: cover,
      lyrics: S.of(context).common_no_lyrics,
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
      durationSeconds: duration,
      viewCount: viewCount,
      danmakuCount: danmakuCount,
      isFollowed: isFollowed,
    );
  }

  int? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final numeric = int.tryParse(raw);
    if (numeric != null) return numeric;
    final parts = raw.split(':').map(int.tryParse).toList();
    if (parts.any((e) => e == null)) return null;
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    return null;
  }

  int? _parseCount(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    if (str.endsWith('万')) {
      final numVal = double.tryParse(str.substring(0, str.length - 1));
      if (numVal != null) return (numVal * 10000).round();
    }
    if (str.endsWith('亿')) {
      final numVal = double.tryParse(str.substring(0, str.length - 1));
      if (numVal != null) return (numVal * 100000000).round();
    }
    return int.tryParse(str);
  }
}
