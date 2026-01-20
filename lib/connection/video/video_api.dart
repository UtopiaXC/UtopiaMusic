import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/utils/wbi.dart';

class VideoApi {
  int _freshIdx = 1;
  Map<String, String>? _cachedKeys;Future<Map<String, String>?> _getWbiKeys({bool forceRefresh = false}) async {
    // 1. 如果有缓存且不强制刷新，直接返回
    if (_cachedKeys != null && !forceRefresh) {
      return _cachedKeys;
    }

    try {
      // 2. 发起请求
      print('🔍 正在请求 Api.nav 获取 Wbi Keys...');
      final data = await Request().get(Api.nav);

      // 【调试核心】打印完整的返回数据，看看到底缺了什么
      print('🔍 Api.nav 返回数据: $data');

      if (data['code'] == 0) {
        // 检查 data['data'] 是否存在
        if (data['data'] == null) {
          print('❌ Api.nav 返回成功(code=0)，但 data 字段为 null');
          return null;
        }

        final wbiImg = data['data']['wbi_img'];

        if (wbiImg != null) {
          final imgUrl = wbiImg['img_url'] as String;
          final subUrl = wbiImg['sub_url'] as String;

          final imgKey = imgUrl.split('/').last.split('.').first;
          final subKey = subUrl.split('/').last.split('.').first;

          _cachedKeys = {'imgKey': imgKey, 'subKey': subKey};
          print('✅ Wbi Keys 解析成功: $_cachedKeys');
          return _cachedKeys;
        } else {
          print('❌ Api.nav 返回数据中找不到 wbi_img 字段');
          // 有时候如果是游客身份，结构可能略有不同，或者 B 站未下发
        }
      } else {
        print('❌ Api.nav 请求失败，业务码: ${data['code']}, 消息: ${data['message']}');
      }
    } catch (e) {
      print('❌ 获取 Wbi keys 发生异常: $e');
    }
    return null;
  }

  Future<List<Song>> getRcmdVideos() async {
    return _getRcmdVideosInternal(retryCount: 1);
  }

  Future<List<Song>> _getRcmdVideosInternal({required int retryCount}) async {
    try {
      final keys = await _getWbiKeys(forceRefresh: retryCount < 1);
      print('Wbi keys: $keys');
      if (keys == null) {
        print('Failed to fetch Wbi keys, skip...');
        return getRankingVideos();
      }
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

      final signedParams = WbiUtil.encWbi(params, keys['imgKey']!, keys['subKey']!);
      final data = await Request().get(
        Api.recommendList,
        params: signedParams,
      );

      if (data['code'] == 0) {
        final List<dynamic> list = data['data']['item'];
        return list.map((item) {
          final owner = item['owner'];
          final artist = owner != null ? owner['name'] : '未知UP主';
          
          return Song(
            title: item['title'] ?? '无标题',
            artist: artist ?? '未知UP主',
            album: item['tname'] ?? '首页推荐', 
            coverUrl: item['pic'] ?? '',
            lyrics: '暂无歌词', 
            colorValue: 0xFF2196F3, 
            audioUrl: '', 
          );
        }).toList();
      } else if (data['code'] == 62011) {
        print('Feed exhausted, resetting fresh_idx...');
        _freshIdx = 0;
        if (retryCount > 0) {
          return _getRcmdVideosInternal(retryCount: retryCount - 1);
        }
        return getRankingVideos();
      } else {
        print('Failed to load rcmd videos: ${data['message']} (Code: ${data['code']})');
        if (retryCount > 0) {
          print('Retrying with new Wbi keys...');
          return _getRcmdVideosInternal(retryCount: retryCount - 1);
        }
        return getRankingVideos();
      }
    } catch (e) {
      print('Error fetching rcmd videos: $e');
      if (retryCount > 0) {
         return _getRcmdVideosInternal(retryCount: retryCount - 1);
      }
      return getRankingVideos();
    }
  }

  Future<List<Song>> getRankingVideos() async {
    try {
      final data = await Request().get(
        '/x/web-interface/ranking/v2',
        params: {
          'rid': 0,
          'type': 'all',
        },
      );

      if (data['code'] == 0) {
        final List<dynamic> list = data['data']['list'];
        return list.take(20).map((item) {
          return Song(
            title: item['title'] ?? '',
            artist: item['owner']['name'] ?? '',
            album: item['tname'] ?? '全站热门', 
            coverUrl: item['pic'] ?? '',
            lyrics: '暂无歌词', 
            colorValue: 0xFF2196F3, 
            audioUrl: '', 
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching ranking videos: $e');
    }
    return [];
  }
}
