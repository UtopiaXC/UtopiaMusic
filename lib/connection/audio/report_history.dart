import 'package:dio/dio.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "REPORT_HISTORY_API";

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
        options: Options(contentType: Headers.formUrlEncodedContentType),
        suppressErrorDialog: true,
      );
      return data != null && data is Map && data['code'] == 0;
    } catch (e) {
      Log.w(_tag, 'Error reporting history: $e');
    }
    return false;
  }
}
