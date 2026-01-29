import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "WBI_UTIL";

class WbiUtil {
  static String? _imgKey;
  static String? _subKey;
  static DateTime? _lastRefreshTime;

  static const Duration _keyValidDuration = Duration(minutes: 30);

  static bool _isRefreshing = false;

  static int _refreshFailCount = 0;
  static const int _maxRefreshRetries = 3;

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

  static bool _isKeyExpired() {
    if (_imgKey == null || _subKey == null || _lastRefreshTime == null) {
      return true;
    }
    return DateTime.now().difference(_lastRefreshTime!) > _keyValidDuration;
  }

  static Future<Map<String, dynamic>> signParams(
    Map<String, dynamic> params,
  ) async {
    await _ensureKeys();
    if (_imgKey == null || _subKey == null) {
      Log.w(_tag, "WBI keys missing, request may fail.");
      return params;
    }
    return _encWbi(params, _imgKey!, _subKey!);
  }

  static Future<void> _ensureKeys({bool force = false}) async {
    if (!force && !_isKeyExpired()) {
      return;
    }

    if (_isRefreshing) {
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!_isKeyExpired()) return;
    }

    _isRefreshing = true;

    try {
      await _fetchKeys();
      _refreshFailCount = 0;
    } catch (e) {
      _refreshFailCount++;
      Log.e(_tag, "Failed to fetch WBI keys (attempt $_refreshFailCount)", e);

      if (_refreshFailCount < _maxRefreshRetries) {
        await Future.delayed(Duration(seconds: _refreshFailCount * 2));
        _isRefreshing = false;
        return await _ensureKeys(force: true);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<void> _fetchKeys() async {
    final data = await Request().get(
      Api.urlNav,
      baseUrl: Api.urlBase,
      suppressErrorDialog: true,
    );

    if (data != null &&
        data['data'] != null &&
        data['data']['wbi_img'] != null) {
      final wbiImg = data['data']['wbi_img'];
      final imgUrl = wbiImg['img_url'] as String;
      final subUrl = wbiImg['sub_url'] as String;

      _imgKey = imgUrl.split('/').last.split('.').first;
      _subKey = subUrl.split('/').last.split('.').first;
      _lastRefreshTime = DateTime.now();

      Log.i(_tag, "WBI Keys refreshed successfully");
    } else {
      throw Exception("Invalid WBI response");
    }
  }

  static Future<void> invalidateKeys() async {
    Log.i(_tag, "Invalidating WBI keys...");
    _imgKey = null;
    _subKey = null;
    _lastRefreshTime = null;
    _refreshFailCount = 0;
    await _ensureKeys(force: true);
  }

  static Future<void> preRefresh() async {
    if (_isKeyExpired()) {
      Log.i(_tag, "Pre-refreshing WBI keys...");
      await _ensureKeys(force: true);
    }
  }

  static Future<void> periodicRefresh() async {
    if (_lastRefreshTime != null) {
      final elapsed = DateTime.now().difference(_lastRefreshTime!);
      final remaining = _keyValidDuration - elapsed;
      if (remaining < const Duration(minutes: 5)) {
        Log.i(_tag, "WBI keys expiring soon, refreshing...");
        await _ensureKeys(force: true);
      }
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
