import 'dart:io';
import 'package:dio/dio.dart' hide ResponseType;
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "LOGIN_API";

class LoginApi {
  Future<Map<String, dynamic>?> generateTvQrCode() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final params = {'appkey': Api.tvAppKey, 'local_id': '0', 'ts': '$ts'};

      final signedParams = Request().signParams(params);
      final data = await Request().post(
        Api.urlTvLoginQRCodeAuthCode,
        baseUrl: Api.passportTvBase,
        data: signedParams,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      Log.e(_tag, 'Error generating TV QR code: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> pollTvQrCode(String authCode) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final params = {
        'appkey': Api.tvAppKey,
        'auth_code': authCode,
        'local_id': '0',
        'ts': '$ts',
      };

      final signedParams = Request().signParams(params);

      final data = await Request().post(
        Api.urlTvLoginQRCodePoll,
        baseUrl: Api.passportTvBase,
        data: signedParams,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (data != null && data is Map) {
        final code = data['code'];
        if (code == 0) {
          final resultData = data['data'];
          if (resultData != null && resultData.containsKey('cookie_info')) {
            final cookieInfo = resultData['cookie_info'];
            if (cookieInfo != null && cookieInfo['cookies'] != null) {
              List<dynamic> cookieList = cookieInfo['cookies'];
              List<Cookie> newCookies = [];
              for (var item in cookieList) {
                newCookies.add(Cookie(item['name'], item['value']));
              }
              final jar = await Request().cookieJar;
              await jar.saveFromResponse(Uri.parse(Api.urlBase), newCookies);
              await jar.saveFromResponse(
                Uri.parse(Api.urlLoginBase),
                newCookies,
              );

              Log.i(_tag, "Login Success: Cookies saved.");
            }
          }

          return {'code': 0, 'data': resultData};
        } else {
          return {'code': code, 'message': data['message']};
        }
      }
    } catch (e) {
      Log.e(_tag, 'Error polling TV QR code: $e');
    }
    return null;
  }
}
