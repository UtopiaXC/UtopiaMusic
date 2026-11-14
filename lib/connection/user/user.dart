import 'package:flutter/foundation.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/bili_id.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:dio/dio.dart';

const String _tag = "USER_API";

class UserApi {
  final Map<String, String> _spaceAidCursors = {};

  Options _spaceOptions(int mid) => Options(
        headers: {
          'Origin': 'https://space.bilibili.com',
          'Referer': 'https://space.bilibili.com/$mid',
        },
      );

  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final data = await Request().get(Api.urlNav, baseUrl: Api.urlBase);

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user info: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserCard(int mid) async {
    try {
      final data = await Request().get(
        Api.urlUserCard,
        baseUrl: Api.urlBase,
        params: {'mid': mid, 'photo': 1},
        options: _spaceOptions(mid),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user card: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserStat(int mid) async {
    try {
      final data = await Request().get(
        Api.urlUserStat,
        baseUrl: Api.urlBase,
        params: {'vmid': mid},
        options: _spaceOptions(mid),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user stat: $e');
    }
    return null;
  }

  Future<List<dynamic>> getUserVideos(int mid, int page, String order) async {
    try {
      final data = await Request().get(
        Api.urlUserVideo,
        baseUrl: Api.urlBase,
        params: {
          'mid': mid,
          'pn': page,
          'ps': 20,
          'order': order,
          'web_location': 1550101,
          'dm_img_list': '[]',
          'dm_img_str': 'V2ViR0wgMS4wIChPcGVuR0wgRVMgMi4wIENocm9taXVtKQ',
          'dm_cover_img_str':
              'QU5HTEUgKEdvb2dsZSwgVnVsa2FuIDEuMy4wIChTd2lmdFNoYWRlciBEZXZpY2UgKFN1Ynplcm8pIChHb29nbGUgSW5jLikpLCBvciBzaW1pbGFyKQ',
          'dm_img_inter': '{"ds":[],"wh":[0,0,0],"of":[0,0,0]}',
        },
        useWbi: true,
        options: _spaceOptions(mid),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list']['vlist'] ?? [];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user videos (web): $e');
    }

    return _getUserVideosApp(mid, page, order);
  }

  Future<List<dynamic>> _getUserVideosApp(
    int mid,
    int page,
    String order,
  ) async {
    final cursorKey = '${mid}_$order';
    if (page <= 1) {
      _spaceAidCursors.remove(cursorKey);
    }
    final appOrder = order == 'click' ? 'click' : 'pubdate';
    final params = <String, dynamic>{
      'vmid': mid,
      'order': appOrder,
      'ps': 20,
    };
    if (page > 1) {
      final cursorAid = _spaceAidCursors[cursorKey];
      if (cursorAid == null || cursorAid.isEmpty) {
        return [];
      }
      params['aid'] = cursorAid;
    }

    try {
      final data = await Request().get(
        Api.urlAppSpaceArchive,
        baseUrl: Api.urlAppBase,
        params: params,
        useAppSign: true,
        suppressErrorDialog: true,
      );
      if (data != null && data is Map && data['code'] == 0) {
        final rawItems = data['data']?['item'];
        final mapped = mapAppArchiveItems(rawItems);
        if (mapped.isNotEmpty) {
          final lastAid = mapped.last['aid']?.toString() ?? '';
          if (lastAid.isNotEmpty) {
            _spaceAidCursors[cursorKey] = lastAid;
          }
        } else {
          _spaceAidCursors.remove(cursorKey);
        }
        return mapped;
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user videos (app fallback): $e');
    }
    return [];
  }

  /// Normalizes `/x/v2/space/archive/cursor` items into Web vlist format.
  @visibleForTesting
  static List<dynamic> mapAppArchiveItems(dynamic rawItems) {
    if (rawItems is! List) return [];
    final mapped = <Map<String, dynamic>>[];
    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final item = Map<String, dynamic>.from(entry);
      final int aid = int.tryParse('${item['param'] ?? item['aid'] ?? 0}') ?? 0;
      String bvid = item['bvid']?.toString() ?? '';
      if (bvid.isEmpty && aid > 0) {
        bvid = BiliIdUtils.av2bv(aid);
      }
      if (bvid.isEmpty) continue;
      String cover = item['cover']?.toString() ?? item['pic']?.toString() ?? '';
      if (cover.startsWith('http://')) {
        cover = cover.replaceFirst('http://', 'https://');
      } else if (cover.startsWith('//')) {
        cover = 'https:$cover';
      }
      final stat = item['stat'] is Map ? item['stat'] as Map : null;
      final int duration = item['duration'] is int
          ? item['duration'] as int
          : int.tryParse('${item['duration'] ?? 0}') ?? 0;
      mapped.add({
        'aid': aid,
        'bvid': bvid,
        'title': item['title']?.toString() ?? '',
        'author': item['author']?.toString() ?? '',
        'pic': cover,
        'play': stat?['view'] ?? item['view_content'] ?? 0,
        'video_review': stat?['danmaku'] ?? item['danmaku'] ?? 0,
        'duration': duration,
        'cid': item['first_cid'] ?? 0,
      });
    }
    return mapped;
  }

  Future<List<dynamic>> getUserCreatedFavFolders(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCreatedList,
        baseUrl: Api.urlBase,
        params: {'up_mid': mid, 'pn': page, 'ps': 20},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user created fav folders: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserCreatedFavFoldersAll(
    int mid,
    int rid,
  ) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCreatedListAll,
        baseUrl: Api.urlBase,
        params: {'up_mid': mid, 'type': 2, 'rid': rid},
      );

      if (data != null && data is Map && data['code'] == 0) {
        final list = data['data']['list'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user created fav folders all: $e');
    }
    return [];
  }

  Future<List<dynamic>> getUserCollectedFavFolders(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCollectedList,
        baseUrl: Api.urlBase,
        params: {'up_mid': mid, 'pn': page, 'ps': 20, 'platform': 'web'},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user collected fav folders: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getUserSeasonsSeriesList(
    int mid,
    int page,
  ) async {
    try {
      final data = await Request().get(
        Api.urlCreatedCollections,
        baseUrl: Api.urlBase,
        params: {
          'mid': mid,
          'page_num': page,
          'page_size': 20,
          'web_location': 0.0,
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching user seasons series list: $e');
    }
    return null;
  }

  Future<bool> modifyRelation(int fid, int act) async {
    try {
      final data = await Request().post(
        Api.urlRelationModify,
        baseUrl: Api.urlBase,
        data: {
          'fid': fid,
          'act': act,
          're_src': 11,
          'csrf': await Request().getCsrf(),
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      Log.e(_tag, 'Error modifying relation: $e');
    }
    return false;
  }

  Future<List<dynamic>> getFollowings(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlUserFollowings,
        baseUrl: Api.urlBase,
        params: {'vmid': mid, 'pn': page, 'ps': 20, 'order': 'desc'},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching followings: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getHistory(int max, int viewAt) async {
    try {
      final data = await Request().get(
        Api.urlHistoryCursor,
        baseUrl: Api.urlBase,
        params: {
          'ps': 20,
          'max': max,
          'view_at': viewAt,
          'business': 'archive',
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.w(_tag, 'Error fetching history: $e');
    }
    return null;
  }

  Future<bool> createFavFolder(
    String title,
    String intro,
    bool isPublic,
  ) async {
    try {
      final data = await Request().post(
        Api.urlFavFolderAdd,
        baseUrl: Api.urlBase,
        data: {
          'title': title,
          'intro': intro,
          'privacy': isPublic ? 0 : 1,
          'csrf': await Request().getCsrf(),
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      Log.e(_tag, 'Error creating fav folder: $e');
    }
    return false;
  }

  Future<bool> editFavFolder(
    int mediaId,
    String title,
    String intro,
    bool isPublic,
  ) async {
    try {
      final data = await Request().post(
        Api.urlFavFolderEdit,
        baseUrl: Api.urlBase,
        data: {
          'media_id': mediaId,
          'title': title,
          'intro': intro,
          'privacy': isPublic ? 0 : 1,
          'csrf': await Request().getCsrf(),
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      Log.e(_tag, 'Error editing fav folder: $e');
    }
    return false;
  }

  Future<bool> deleteFavFolder(int mediaId) async {
    try {
      final data = await Request().post(
        Api.urlFavFolderDel,
        baseUrl: Api.urlBase,
        data: {
          'media_ids': mediaId.toString(),
          'csrf': await Request().getCsrf(),
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      Log.e(_tag, 'Error deleting fav folder: $e');
    }
    return false;
  }

  Future<List<dynamic>> searchUsers(String keyword, int page) async {
    try {
      final data = await Request().get(
        Api.urlSearch,
        baseUrl: Api.urlBase,
        params: {'search_type': 'bili_user', 'keyword': keyword, 'page': page},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['result'] ?? [];
      }
    } catch (e) {
      Log.w(_tag, 'Error searching users: $e');
    }
    return [];
  }
}
