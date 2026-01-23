import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utopia_music/connection/error/error_code.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/providers/settings_provider.dart';

enum ResponseType { data, response }

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final PersistCookieJar _cookieJar;
  late final Future<void> _initWait;
  int _maxRetries = 2;

  bool _isUserLoggedIn = false;

  factory Request() => _instance;

  Request._internal() {
    _initWait = _init();
  }

  Future<PersistCookieJar> get cookieJar async {
    await _initWait;
    return _cookieJar;
  }

  Future<void> _init() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    _cookieJar = PersistCookieJar(
      storage: FileStorage("$appDocPath/.cookies/"),
      ignoreExpires: true,
    );

    BaseOptions options = BaseOptions(
      connectTimeout: const Duration(
        milliseconds: HttpConstants.connectTimeout,
      ),
      receiveTimeout: const Duration(
        milliseconds: HttpConstants.receiveTimeout,
      ),
      headers: {
        'User-Agent': HttpConstants.userAgent,
        'Referer': HttpConstants.referer,
      },
      validateStatus: (status) => true,
    );

    _dio = Dio(options);
    _dio.interceptors.add(CookieManager(_cookieJar));

    await _loadSettings();
    await _checkCookies();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;
  }

  Future<void> _checkCookies() async {
    try {
      final uri = Uri.parse(Api.urlBase);
      final cookies = await _cookieJar.loadForRequest(uri);
      if (cookies.isEmpty) {
        await fetchGuestCookies();
      } else {
        _isUserLoggedIn = cookies.any(
          (c) => c.name == 'DedeUserID' && c.value.isNotEmpty,
        );
      }
    } catch (e) {
      print("Request: Failed to ensure cookies: $e");
    }
  }

  Future<void> fetchGuestCookies() async {
    try {
      if (kDebugMode) {
        print("Request: Fetching guest cookies...");
      }
      await _dio.get(Api.urlBase);
    } catch (e) {
      print("Request: Failed to fetch guest cookies: $e");
    }
  }

  Map<String, dynamic> signParams(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final query = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    final stringToSign = query + Api.tvAppSecret;
    final sign = md5.convert(utf8.encode(stringToSign)).toString();

    return {...params, 'sign': sign};
  }

  Future<void> setManualCookies(String cookieString) async {
    await _initWait;
    List<Cookie> cookies = [];
    final splitCookies = cookieString.split(';');
    for (var c in splitCookies) {
      final trimmed = c.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        cookies.add(Cookie(name, value));
      }
    }

    if (cookies.isNotEmpty) {
      await _cookieJar.saveFromResponse(Uri.parse(Api.urlBase), cookies);
      await _cookieJar.saveFromResponse(Uri.parse(Api.urlLoginBase), cookies);
      _isUserLoggedIn = true;
      print("Request: Manual cookies set (${cookies.length} items)");
    }
  }

  Future<dynamic> get(
    String path, {
    String baseUrl = Api.urlBase,
    Map<String, dynamic>? params,
    bool useWbi = false,
    ResponseType responseType = ResponseType.data,
    Options? options,
  }) async {
    return _request(
      method: 'GET',
      path: path,
      baseUrl: baseUrl,
      params: params,
      useWbi: useWbi,
      responseType: responseType,
      options: options,
    );
  }

  Future<dynamic> post(
    String path, {
    String baseUrl = Api.urlBase,
    dynamic data,
    Map<String, dynamic>? params,
    bool useWbi = false,
    ResponseType responseType = ResponseType.data,
    Options? options,
  }) async {
    return _request(
      method: 'POST',
      path: path,
      baseUrl: baseUrl,
      data: data,
      params: params,
      useWbi: useWbi,
      responseType: responseType,
      options: options,
    );
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    required String baseUrl,
    dynamic data,
    Map<String, dynamic>? params,
    required bool useWbi,
    required ResponseType responseType,
    Options? options,
  }) async {
    await _initWait;

    return _requestWithRetry(() async {
      Map<String, dynamic> finalParams = params ?? {};
      if (useWbi) {
        finalParams = await WbiUtil.signParams(finalParams);
      }

      final url = _buildUrl(baseUrl, path);

      Response response;
      if (method == 'GET') {
        response = await _dio.get(
          url,
          queryParameters: finalParams,
          options: options,
        );
      } else {
        response = await _dio.post(
          url,
          data: data,
          queryParameters: finalParams,
          options: options,
        );
      }

      if (responseType == ResponseType.response) {
        return response;
      }
      return response.data;
    }, retryCount: 0);
  }

  Future<dynamic> _requestWithRetry(
    Future<dynamic> Function() requestFunc, {
    int retryCount = 0,
  }) async {
    try {
      final result = await requestFunc();

      dynamic data;
      if (result is Response) {
        data = result.data;
      } else {
        data = result;
      }

      if (data is String &&
          data.toString().trim().startsWith('<!DOCTYPE html>')) {
        if (retryCount < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          return await _requestWithRetry(
            requestFunc,
            retryCount: retryCount + 1,
          );
        } else {
          if (kDebugMode) {
            print(
              "Request Warning: API returned HTML content (WAF or Error Page). Suppressed dialog.",
            );
          }
          return result;
        }
      }

      if (data is Map) {
        final int code = data['code'] ?? 0;
        final String message = data['message']?.toString() ?? '';

        if (_isUserLoggedIn &&
            [
              ErrorCode.notLoggedIn,
              ErrorCode.riskControlFail,
              ErrorCode.tokenExpired,
              ErrorCode.locked,
              ErrorCode.unauthorized,
              ErrorCode.ipRiskControl,
            ].contains(code)) {
          if (retryCount < _maxRetries) {
            await Future.delayed(
              Duration(milliseconds: 500 * (retryCount + 1)),
            );
            return await _requestWithRetry(
              requestFunc,
              retryCount: retryCount + 1,
            );
          } else {
            await _handleLoginExpired(code, message);
          }
        } else if (code != 0) {
          if (retryCount < _maxRetries) {
            if (kDebugMode) print("Business error (code $code), retrying...");
            await Future.delayed(
              Duration(milliseconds: 500 * (retryCount + 1)),
            );
            return await _requestWithRetry(
              requestFunc,
              retryCount: retryCount + 1,
            );
          } else {
            if (!_isUserLoggedIn && code == ErrorCode.notLoggedIn)
              return result;
            if (ErrorCode.isDefined(code)) {
              _showErrorDialog(code, message);
            } else {
              if (kDebugMode)
                print("Request: Ignored undefined error code: $code");
            }
          }
        }
      }
      return result;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && retryCount < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
        return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
      }
      if (retryCount >= _maxRetries) {
        _showErrorDialog(ErrorCode.serverError, "网络错误: ${e.message}");
      }
      throw _handleError(e);
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
        return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  String _buildUrl(String baseUrl, String path) {
    if (path.startsWith('http')) return path;
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  Future<void> _handleLoginExpired(int code, String message) async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('登录失效或受限'),
          content: Text(
            '错误码: $code\n信息: ${ErrorCode.getMessage(code)}\n\n您的登录状态可能已失效或受到限制。建议重新登录。',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cookieJar.deleteAll();
                _isUserLoggedIn = false;
                await fetchGuestCookies();
              },
              child: const Text('退出登录'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    }
  }

  void _showErrorDialog(int code, String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Future.microtask(() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('请求错误'),
            content: Text(
              '错误码: $code\n信息: ${ErrorCode.getMessage(code)}\n详细: $message',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      });
    }
  }

  String _handleError(DioException error) => error.message ?? "Unknown Error";
}
