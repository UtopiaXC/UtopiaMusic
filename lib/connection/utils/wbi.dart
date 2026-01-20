import 'dart:convert';
import 'package:crypto/crypto.dart';

class WbiUtil {
  static const List<int> _mixinKeyEncTab = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  static String _getMixinKey(String orig) {
    String result = '';
    for (int i in _mixinKeyEncTab) {
      if (i < orig.length) {
        result += orig[i];
      }
    }
    return result.substring(0, 32);
  }

  static Map<String, dynamic> encWbi(
    Map<String, dynamic> params,
    String imgKey,
    String subKey,
  ) {
    final mixinKey = _getMixinKey(imgKey + subKey);
    final currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newParams = Map<String, dynamic>.from(params);
    newParams['wts'] = currTime;
    final sortedKeys = newParams.keys.toList()..sort();
    final sortedParams = {for (var k in sortedKeys) k: newParams[k]};
    final filteredParams = <String, String>{};
    sortedParams.forEach((key, value) {
      final strValue = value.toString();
      final filteredValue = strValue.replaceAll(RegExp(r"[!'()*]"), "");
      filteredParams[key] = filteredValue;
    });
    final query = Uri(queryParameters: filteredParams).query;
    final wbiSign = md5.convert(utf8.encode(query + mixinKey)).toString();
    newParams['w_rid'] = wbiSign;
    return newParams;
  }
}
