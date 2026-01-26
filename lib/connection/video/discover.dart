import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class VideoApi {
  static const String _kFreshIdxKey = 'video_api_fresh_idx';
  final HtmlUnescape _unescape = HtmlUnescape();

  Future<List<Song>> getRecommentVideos(BuildContext context, {int recursionDepth = 0}) async {
    if (recursionDepth > 10) {
      print('VideoApi: Max recursion depth reached ($recursionDepth), stopping retry.');
      return [];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      int currentIdx = prefs.getInt(_kFreshIdxKey) ?? 1;
      currentIdx++;
      await prefs.setInt(_kFreshIdxKey, currentIdx);

      final params = {
        'feed_version': 'V10',
        'fresh_type': 4,
        'y_num': 4,
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

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data']['item'] ?? [];
        return list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(context, item))
            .toList();
      } else if (data != null && data['code'] == 62011) {
        print('Feed exhausted (62011), resetting fresh_idx to 0...');
        await prefs.setInt(_kFreshIdxKey, 0);
        return getRecommentVideos(context, recursionDepth: recursionDepth + 1);
      } else {
        print(
          'Failed to load recommend videos: ${data?['message']} (${data?['code']})',
        );
        return [];
      }
    } catch (e) {
      print('Error fetching recommend videos: $e');
      return [];
    }
  }

  Future<List<Song>> getRankingVideos(BuildContext context, {int rid = 0}) async {
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
        print('Failed to load ranking videos: ${data?['message']} (${data?['code']})');
      }
    } catch (e) {
      print('Error fetching ranking videos: $e');
    }
    return [];
  }

  Future<List<Song>> getRegionRankingVideos(BuildContext context, {required int rid}) async {
    try {
      final data = await Request().get(
        Api.urlRankingRegion,
        baseUrl: Api.urlBase,
        params: {'rid': rid, 'day': 3, 'original': 0},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data'] ?? [];
        return list
            .map((item) => _mapToSong(context, item))
            .toList();
      } else {
        print('Failed to load region ranking videos: ${data?['message']} (${data?['code']})');
      }
    } catch (e) {
      print('Error fetching region ranking videos: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getFeed(BuildContext context, String offset) async {
    try {
      final data = await Request().get(
        Api.urlDynamicFeed,
        baseUrl: Api.urlBase,
        params: {
          'timezone_offset': '-480',
          'type': 'video',
          'offset': offset,
        },
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

              songs.add(Song(
                title: _unescape.convert(archive['title'] ?? S.of(context).common_no_title),
                artist: _unescape.convert(author['name'] ?? S.of(context).common_unknown),
                coverUrl: archive['cover'],
                lyrics: '',
                colorValue: 0xFF2196F3,
                bvid: archive['bvid'],
                cid: 0,
              ));
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
      print('Error fetching feed: $e');
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
    return Song(
      title: _unescape.convert(item['title'] ?? S.of(context).common_no_title),
      artist: _unescape.convert(artist),
      coverUrl: cover,
      lyrics: S.of(context).common_no_lyrics,
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
    );
  }
}
