import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:dio/dio.dart';

class UserApi {
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final data = await Request().get(
        Api.urlNav,
        baseUrl: Api.urlBase,
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserCard(int mid) async {
    try {
      final data = await Request().get(
        Api.urlUserCard,
        baseUrl: Api.urlBase,
        params: {'mid': mid, 'photo': 1},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching user card: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserStat(int mid) async {
    try {
      final data = await Request().get(
        Api.urlUserStat,
        baseUrl: Api.urlBase,
        params: {'vmid': mid},
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching user stat: $e');
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
        },
        useWbi: true,
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list']['vlist'] ?? [];
      }
    } catch (e) {
      print('Error fetching user videos: $e');
    }
    return [];
  }

  Future<List<dynamic>> getUserCreatedFavFolders(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCreatedList,
        baseUrl: Api.urlBase,
        params: {
          'up_mid': mid,
          'pn': page,
          'ps': 20,
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      print('Error fetching user created fav folders: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserCreatedFavFoldersAll(int mid, int rid) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCreatedListAll,
        baseUrl: Api.urlBase,
        params: {
          'up_mid': mid,
          'type': 2,
          'rid': rid,
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        final list = data['data']['list'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      print('Error fetching user created fav folders all: $e');
    }
    return [];
  }

  Future<List<dynamic>> getUserCollectedFavFolders(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlFavFolderCollectedList,
        baseUrl: Api.urlBase,
        params: {
          'up_mid': mid,
          'pn': page,
          'ps': 20,
          'platform': 'web',
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      print('Error fetching user collected fav folders: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getUserSeasonsSeriesList(int mid, int page) async {
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
      print('Error fetching user seasons series list: $e');
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
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      print('Error modifying relation: $e');
    }
    return false;
  }

  Future<List<dynamic>> getFollowings(int mid, int page) async {
    try {
      final data = await Request().get(
        Api.urlUserFollowings,
        baseUrl: Api.urlBase,
        params: {
          'vmid': mid,
          'pn': page,
          'ps': 20,
          'order': 'desc',
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['list'] ?? [];
      }
    } catch (e) {
      print('Error fetching followings: $e');
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
      print('Error fetching history: $e');
    }
    return null;
  }

  Future<bool> createFavFolder(String title, String intro, bool isPublic) async {
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
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      print('Error creating fav folder: $e');
    }
    return false;
  }

  Future<bool> editFavFolder(int mediaId, String title, String intro, bool isPublic) async {
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
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      print('Error editing fav folder: $e');
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
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return true;
      }
    } catch (e) {
      print('Error deleting fav folder: $e');
    }
    return false;
  }

  Future<List<dynamic>> searchUsers(String keyword, int page) async {
    try {
      final data = await Request().get(
        Api.urlSearch,
        baseUrl: Api.urlBase,
        params: {
          'search_type': 'bili_user',
          'keyword': keyword,
          'page': page,
        },
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data']['result'] ?? [];
      }
    } catch (e) {
      print('Error searching users: $e');
    }
    return [];
  }
}
