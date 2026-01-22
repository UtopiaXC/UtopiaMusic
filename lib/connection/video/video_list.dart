import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';

class VideoApi {
  int _freshIdx = 1;

  Future<List<Song>> getRecommentVideos() async {
    _freshIdx++;

    final params = {
      'feed_version': 'V10',
      'fresh_type': 4,
      'y_num': 4,
      'fresh_idx': _freshIdx,
      'fresh_idx_1h': _freshIdx,
      'ps': 20,
      'plat': 1,
      'web_location': 1430650,
    };

    try {
      final data = await Request().get(
        Api.urlRecommentList,
        params: params,
        useWbi: true,
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data']['item'] ?? [];
        return list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(item))
            .toList();
      } else if (data != null && data['code'] == 62011) {
        print('Feed exhausted, resetting fresh_idx...');
        _freshIdx = 0;
        return getRecommentVideos();
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

  Future<List<Song>> getRankingVideos({int rid = 0}) async {
    try {
      final data = await Request().get(
        Api.urlRanking,
        params: {'rid': rid, 'type': 'all'},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data']['list'] ?? [];
        return list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(item))
            .toList();
      } else {
        print('Failed to load ranking videos: ${data?['message']} (${data?['code']})');
      }
    } catch (e) {
      print('Error fetching ranking videos: $e');
    }
    return [];
  }

  Future<List<Song>> getRegionRankingVideos({required int rid}) async {
    try {
      final data = await Request().get(
        Api.urlRankingRegion,
        params: {'rid': rid, 'day': 3, 'original': 0},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data'] ?? [];
        return list
            .map((item) => _mapToSong(item))
            .toList();
      } else {
        print('Failed to load region ranking videos: ${data?['message']} (${data?['code']})');
      }
    } catch (e) {
      print('Error fetching region ranking videos: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getFeed(String offset) async {
    try {
      final data = await Request().get(
        Api.urlDynamicFeed,
        params: {
          'timezone_offset': '-480',
          'type': 'all',
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
                  title: archive['title'],
                  artist: author['name'],
                  coverUrl: archive['cover'],
                  lyrics: '',
                  colorValue: 0xFF2196F3,
                  bvid: archive['bvid'],
                  cid: 0, // CID needs to be fetched when playing
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

  Song _mapToSong(dynamic item) {
    // Handle different response structures
    // Ranking/Region Ranking might have different field names or structures
    // For region ranking, 'owner' might be directly 'author' string or object
    
    String artist = '未知UP主';
    if (item['owner'] != null) {
      artist = item['owner']['name'];
    } else if (item['author'] != null) {
      artist = item['author'];
    }

    String cover = item['pic'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    return Song(
      title: item['title'] ?? '无标题',
      artist: artist,
      coverUrl: cover,
      lyrics: '暂无歌词',
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: item['cid'] ?? 0,
    );
  }
}
