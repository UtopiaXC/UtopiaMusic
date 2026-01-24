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
}
