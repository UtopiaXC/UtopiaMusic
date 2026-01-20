import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';

class WbiUtil {
  static String? _imgKey;
  static String? _subKey;

  static const List<int> _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
    36, 20, 34, 44, 52,
  ];

  static Future<Map<String, dynamic>> signParams(Map<String, dynamic> params) async {
    await _ensureKeys();

    if (_imgKey == null || _subKey == null) {
      print("Wbi keys missing, request may fail.");
      return params;
    }
    return _encWbi(params, _imgKey!, _subKey!);
  }

  static Future<void> _ensureKeys() async {
    if (_imgKey != null && _subKey != null) return;

    try {
      final data = await Request().get(Api.urlNav, useWbi: false);

      if (data != null && data['data'] != null && data['data']['wbi_img'] != null) {
        final wbiImg = data['data']['wbi_img'];
        final imgUrl = wbiImg['img_url'] as String;
        final subUrl = wbiImg['sub_url'] as String;

        _imgKey = imgUrl.split('/').last.split('.').first;
        _subKey = subUrl.split('/').last.split('.').first;
        print("Wbi Keys cached: $_imgKey, $_subKey");
      }
    } catch (e) {
      print("Failed to fetch Wbi keys: $e");
    }
  }

  static String _getMixinKey(String orig) {
    String result = '';
    for (int i in _mixinKeyEncTab) {
      if (i < orig.length) {
        result += orig[i];
      }
    }
    return result.substring(0, 32);
  }

  static Map<String, dynamic> _encWbi(
      Map<String, dynamic> params,
      String imgKey,
      String subKey,
      ) {
    final mixinKey = _getMixinKey(imgKey + subKey);
    final currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newParams = Map<String, dynamic>.from(params);
    newParams['wts'] = currTime;
    final sortedKeys = newParams.keys.toList()..sort();
    final filteredParams = <String, String>{};
    for (var k in sortedKeys) {
      final value = newParams[k].toString();
      final filteredValue = value.replaceAll(RegExp(r"[!'()*]"), "");
      filteredParams[k] = filteredValue;
    }
    final query = Uri(queryParameters: filteredParams).query;
    final wbiSign = md5.convert(utf8.encode(query + mixinKey)).toString();
    newParams['w_rid'] = wbiSign;
    return newParams;
  }
}