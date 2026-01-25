import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class ReportHistoryApi {
  Future<bool> reportHistory({
    required String bvid,
    required int cid,
    required int playedTime,
  }) async {
    try {
      final data = await Request().post(
        Api.urlPlayHistoryHeartbeat,
        baseUrl: Api.urlBase,
        data: {
          'bvid': bvid,
          'cid': cid,
          'played_time': playedTime,
          'csrf': await Request().getCsrf(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
        suppressErrorDialog: true,
      );
      return data != null && data is Map && data['code'] == 0;
    } catch (e) {
      print('Error reporting history: $e');
    }
    return false;
  }
}
