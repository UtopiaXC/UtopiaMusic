import 'package:dio/dio.dart' hide ResponseType;
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class LoginApi {
  Future<Map<String, dynamic>?> generateQrCode() async {
    try {
      final data = await Request().get(
        Api.urlLoginQRCodeGenerate,
        baseUrl: Api.urlLoginBase,
        useCookie: false,
      );
      if (data != null && data is Map && data['code'] == 0) {
        return data['data'];
      }
    } catch (e) {
      print('Error generating QR code: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> pollQrCode(String qrCodeKey) async {
    try {
      final response = await Request().get(
        Api.urlLoginQRCodePoll,
        baseUrl: Api.urlLoginBase,
        params: {'qrcode_key': qrCodeKey},
        useCookie: false,
        responseType: ResponseType.response,
      );

      final data = response.data;
      
      print('Poll QR Code Response: $data');

      if (data != null && data is Map && data['code'] == 0) {
        final code = data['data']['code'];
        // 0: success, 86101: not scanned, 86090: scanned but not confirmed, 86038: expired
        
        if (code == 0) {
          final List<String>? setCookieList = response.headers['set-cookie'];
          
          print('Set-Cookie Headers: $setCookieList');
          
          String? cookieString;
          if (setCookieList != null && setCookieList.isNotEmpty) {
            final cookies = <String, String>{};
            for (var cookieStr in setCookieList) {
              print('Processing cookie: $cookieStr');
              final parts = cookieStr.split(';');
              if (parts.isNotEmpty) {
                final kv = parts[0].split('=');
                if (kv.length >= 2) {
                  cookies[kv[0].trim()] = kv.sublist(1).join('=').trim();
                }
              }
            }
            
            final dedeUserID = cookies['DedeUserID'];
            final dedeUserIDCkMd5 = cookies['DedeUserID__ckMd5'];
            final sessData = cookies['SESSDATA'];
            final biliJct = cookies['bili_jct'];
            
            print('Extracted Cookies: DedeUserID=$dedeUserID, DedeUserID__ckMd5=$dedeUserIDCkMd5, SESSDATA=$sessData, bili_jct=$biliJct');
            
            if (dedeUserID != null && sessData != null && biliJct != null) {
              cookieString = 'DedeUserID=$dedeUserID; DedeUserID__ckMd5=$dedeUserIDCkMd5; SESSDATA=$sessData; bili_jct=$biliJct';
            }
          } else {
             final url = data['data']['url'] as String;
             final uri = Uri.parse(url);
             final params = uri.queryParameters;
             
             final dedeUserID = params['DedeUserID'];
             final dedeUserIDCkMd5 = params['DedeUserID__ckMd5'];
             final sessData = params['SESSDATA'];
             final biliJct = params['bili_jct'];
             
             if (dedeUserID != null && sessData != null && biliJct != null) {
               cookieString = 'DedeUserID=$dedeUserID; DedeUserID__ckMd5=$dedeUserIDCkMd5; SESSDATA=$sessData; bili_jct=$biliJct';
             }
          }
          
          return {
            'code': 0,
            'cookie': cookieString,
          };
        } else {
          return {
            'code': code,
          };
        }
      }
    } catch (e) {
      print('Error polling QR code: $e');
    }
    return null;
  }
}
