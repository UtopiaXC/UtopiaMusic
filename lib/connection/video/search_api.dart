import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';

class SearchApi {
  Future<List<Song>> searchVideos(String keyword, {int page = 1}) async {
    final params = {
      'search_type': 'video',
      'keyword': keyword,
      'page': page,
    };

    try {
      final data = await Request().get(
        Api.urlSearch,
        params: params,
        useWbi: true,
      );

      if (data != null && data is Map && data['code'] == 0) {
        final result = data['data']?['result'];
        if (result is List) {
          return result.map((item) => _mapToSong(item)).toList();
        } else {
          return [];
        }
      } else {
        print(
          'Failed to search videos: ${data is Map ? data['message'] : 'Unknown error'} (${data is Map ? data['code'] : 'Unknown code'})',
        );
        return [];
      }
    } catch (e) {
      print('Error searching videos: $e');
      return [];
    }
  }

  Song _mapToSong(dynamic item) {
    final artist = item['author'] ?? '未知UP主';
    String cover = item['pic'] ?? '';
    if (cover.startsWith('//')) {
      cover = 'https:$cover';
    } else if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    int cid = 0; 
    String bvid = item['bvid'] ?? '';

    return Song(
      title: item['title']?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '无标题',
      artist: artist,
      coverUrl: cover,
      lyrics: '暂无歌词',
      colorValue: 0xFF2196F3,
      bvid: bvid,
      cid: cid,
    );
  }

  Future<int> fetchCid(String bvid) async {
    if (bvid.isEmpty) return 0;
    try {
      final detailData = await Request().get(
        Api.urlVideoDetail,
        params: {'bvid': bvid},
      );
      if (detailData != null && detailData is Map && detailData['code'] == 0) {
        return detailData['data']['cid'] ?? 0;
      }
    } catch (e) {
      print('Error fetching video detail for cid: $e');
    }
    return 0;
  }
}
