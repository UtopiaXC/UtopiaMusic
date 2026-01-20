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
      'ps': 10,
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

  Future<List<Song>> getRankingVideos() async {
    try {
      final data = await Request().get(
        Api.urlRanking,
        params: {'rid': 0, 'type': 'all'},
      );

      if (data != null && data['code'] == 0) {
        final List<dynamic> list = data['data']['list'] ?? [];
        return list
            .where((item) => item['owner'] != null)
            .map((item) => _mapToSong(item))
            .toList();
      }
    } catch (e) {
      print('Error fetching ranking videos: $e');
    }
    return [];
  }

  Song _mapToSong(dynamic item) {
    final owner = item['owner'];

    final artist = owner != null ? owner['name'] : '未知UP主';
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
