import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class UserApi {
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final data = await Request().get(
        Api.urlUserInfo,
        baseUrl: Api.urlBase,
        useCookie: true,
      );
      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    return null;
  }
}
