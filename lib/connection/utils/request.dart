import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/error/error_code.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/providers/settings_provider.dart';

enum ResponseType {
  data,
  response,
}

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final DefaultCookieJar _cookieJar;
  late final Future<void> _initWait;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _cookieKey = 'bili_cookies';
  static const String _guestCookieKey = 'bili_guest_cookies';
  bool _isUserLoggedIn = false;

  int _maxRetries = 2;

  factory Request() => _instance;

  Request._internal() {
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
    if (!kIsWeb) {
      _cookieJar = DefaultCookieJar();
      _dio.interceptors.add(CookieManager(_cookieJar));
      _initWait = _initializeCookie();
    } else {
      _initWait = Future.value();
    }

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;
  }

  Future<void> _initializeCookie() async {
    try {
      final storedCookies = await _storage.read(key: _cookieKey);
      bool hasUserCookies = false;

      if (storedCookies != null && storedCookies.isNotEmpty) {
        List<Cookie> cookies = [];
        final splitCookies = storedCookies.split(';');

        for (var c in splitCookies) {
          final trimmed = c.trim();
          if (trimmed.isEmpty) continue;

          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            String value = parts.sublist(1).join('=').trim();
            if (['DedeUserID', 'DedeUserID__ckMd5', 'SESSDATA', 'bili_jct'].contains(name)) {
               try {
                cookies.add(Cookie(name, value));
              } catch (e) {
                if (value.contains(',')) {
                  try {
                    final encodedValue = Uri.encodeComponent(value);
                    cookies.add(Cookie(name, encodedValue));
                  } catch (retryError) {
                    print("Failed to fix cookie $name: $retryError");
                  }
                } else {
                  print("Skipping invalid cookie: $name, error: $e");
                }
              }
            }
          }
        }

        if (cookies.isNotEmpty) {
          await _cookieJar.deleteAll();
          await _cookieJar.saveFromResponse(Uri.parse(HttpConstants.biliUrl), cookies);
          hasUserCookies = true;
          _isUserLoggedIn = true;
          if (kDebugMode) {
            print("User cookies loaded and merged (${cookies.length} cookies)");
          }
        }
      }

      if (!hasUserCookies) {
        _isUserLoggedIn = false;
        await _loadOrGenerateGuestCookie();
      }

    } catch (e) {
      print("Cookie initialization error: $e");
      _isUserLoggedIn = false;
      await _loadOrGenerateGuestCookie();
    }
  }
  
  Future<void> reloadCookies() async {
    await _initializeCookie();
  }

  Future<void> _loadOrGenerateGuestCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guestCookieString = prefs.getString(_guestCookieKey);

      bool loaded = false;
      if (guestCookieString != null && guestCookieString.isNotEmpty) {
         List<Cookie> cookies = [];
         final splitCookies = guestCookieString.split(';');
         for (var c in splitCookies) {
            final trimmed = c.trim();
            if (trimmed.isEmpty) continue;
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
               cookies.add(Cookie(parts[0].trim(), parts.sublist(1).join('=').trim()));
            }
         }
         if (cookies.isNotEmpty) {
            await _cookieJar.saveFromResponse(Uri.parse(HttpConstants.biliUrl), cookies);
            loaded = true;
            if (kDebugMode) {
               print("Guest cookies loaded from storage");
            }
         }
      }

      if (!loaded) {
         await _generateInitialCookie();
      }
    } catch (e) {
      print("Guest cookie load error: $e");
      await _generateInitialCookie();
    }
  }

  Future<void> _generateInitialCookie() async {
    try {
      await _dio.get(HttpConstants.biliUrl);

      final cookies = await _cookieJar.loadForRequest(Uri.parse(HttpConstants.biliUrl));
      if (cookies.isNotEmpty) {
         final cookieString = cookies.map((c) => "${c.name}=${c.value}").join(';');
         final prefs = await SharedPreferences.getInstance();
         await prefs.setString(_guestCookieKey, cookieString);
      }

      if (kDebugMode) {
        print("Initial guest cookie generated via Homepage");
      }
    } catch (e) {
      print("Cookie generation warning: $e");
    }
  }

  Future<void> _cleanExpiredCookie() async {
    try {
      await _storage.delete(key: _cookieKey);
      await _cookieJar.deleteAll();
      _isUserLoggedIn = false;
      await _generateInitialCookie();
      if (kDebugMode) {
        print("Expired cookies cleaned");
      }
    } catch (e) {
      print("Error cleaning cookies: $e");
    }
  }

  String _buildUrl(String baseUrl, String path) {
    if (path.startsWith('http')) return path;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  Future<dynamic> get(
    String path, {
    String baseUrl = Api.urlBase,
    Map<String, dynamic>? params,
    bool useCookie = true,
    bool useWbi = false,
    ResponseType responseType = ResponseType.data,
    Options? options,
  }) async {
    return _request(
      method: 'GET',
      path: path,
      baseUrl: baseUrl,
      params: params,
      useCookie: useCookie,
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
    bool useCookie = true,
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
      useCookie: useCookie,
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
    required bool useCookie,
    required bool useWbi,
    required ResponseType responseType,
    Options? options,
  }) async {
    if (useCookie) {
      await _initWait;
      await _loadSettings();
    }

    final Dio requestDio = useCookie
        ? _dio
        : Dio(BaseOptions(
            connectTimeout: const Duration(milliseconds: HttpConstants.connectTimeout),
            receiveTimeout: const Duration(milliseconds: HttpConstants.receiveTimeout),
            headers: {
              'User-Agent': HttpConstants.userAgent,
              'Referer': HttpConstants.referer,
            },
            validateStatus: (status) => true,
          ));

    return _requestWithRetry(() async {
      Map<String, dynamic> finalParams = params ?? {};
      if (useWbi) {
        finalParams = await WbiUtil.signParams(finalParams);
      }

      final url = _buildUrl(baseUrl, path);
      
      Response response;
      if (method == 'GET') {
        response = await requestDio.get(
          url,
          queryParameters: finalParams,
          options: options,
        );
      } else {
        response = await requestDio.post(
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
    }, retryCount: 0, useCookie: useCookie);
  }

  Future<dynamic> _requestWithRetry(
    Future<dynamic> Function() requestFunc, {
    int retryCount = 0,
    required bool useCookie,
  }) async {
    try {
      final result = await requestFunc();
      
      dynamic data;
      if (result is Response) {
        data = result.data;
      } else {
        data = result;
      }

      if (data is String && data.toString().trim().startsWith('<!DOCTYPE html>')) {
         if (retryCount < _maxRetries) {
            if (kDebugMode) {
              print("HTML response detected (likely WAF/Error page), retrying... Retry: ${retryCount + 1}");
            }
            await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
            return await _requestWithRetry(requestFunc, retryCount: retryCount + 1, useCookie: useCookie);
         } else {
           _showErrorDialog(ErrorCode.serverErrorCute, "请求出错: 返回了HTML页面");
         }
      }

      if (data is Map) {
        final int code = data['code'] ?? 0;
        final String message = data['message']?.toString() ?? '';
        if (_isUserLoggedIn && [
          ErrorCode.notLoggedIn,
          ErrorCode.riskControlFail,
          ErrorCode.tokenExpired,
          ErrorCode.locked,
          ErrorCode.unauthorized,
          ErrorCode.ipRiskControl
        ].contains(code)) {
           if (retryCount < _maxRetries) {
              if (kDebugMode) {
                print("Critical error detected (code $code, msg: $message), retrying... Retry: ${retryCount + 1}");
              }
              await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
              return await _requestWithRetry(requestFunc, retryCount: retryCount + 1, useCookie: useCookie);
           } else {
             await _handleLoginExpired(code, message);
           }
        }
        else if (code != 0) {
           if (retryCount < _maxRetries) {
             if (kDebugMode) {
                print("Business error detected (code $code, msg: $message), retrying... Retry: ${retryCount + 1}");
             }
             await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
             return await _requestWithRetry(requestFunc, retryCount: retryCount + 1, useCookie: useCookie);
           } else {
             if (!_isUserLoggedIn && code == ErrorCode.notLoggedIn) {
                return result;
             }
             _showErrorDialog(code, message);
           }
        }
      }

      return result;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && retryCount < _maxRetries) {
         if (kDebugMode) {
            print("Network error (${e.type}), retrying... Retry: ${retryCount + 1}");
         }
         await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
         return await _requestWithRetry(requestFunc, retryCount: retryCount + 1, useCookie: useCookie);
      }
      
      if (retryCount >= _maxRetries) {
        _showErrorDialog(ErrorCode.serverError, "网络错误: ${e.message}");
      }

      _printErrorLog(e);
      throw _handleError(e);
    } catch (e) {
      if (retryCount < _maxRetries) {
         if (kDebugMode) {
            print("Unknown error ($e), retrying... Retry: ${retryCount + 1}");
         }
         await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
         return await _requestWithRetry(requestFunc, retryCount: retryCount + 1, useCookie: useCookie);
      }
      
      if (retryCount >= _maxRetries) {
        _showErrorDialog(ErrorCode.serverError, "未知错误: $e");
      }
      
      rethrow;
    }
  }

  Future<void> _handleLoginExpired(int code, String message) async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('登录失效或受限'),
          content: Text('错误码: $code\n信息: ${ErrorCode.getMessage(code)}\n\n您的登录状态可能已失效或受到限制。您可以选择清理登录信息重新登录，或者尝试重试。'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cleanExpiredCookie();
              },
              child: const Text('清理并退出登录'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
            content: Text('错误码: $code\n信息: ${ErrorCode.getMessage(code)}\n详细: $message'),
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

  void _printErrorLog(DioException e) {
    print("Request Error: ${e.message}");
    if (e.response != null) {
      print("Data: ${e.response?.data}");
    }
  }

  String _handleError(DioException error) {
    String errorDescription = "";
    switch (error.type) {
      case DioExceptionType.cancel:
        errorDescription = "Request Cancelled";
        break;
      case DioExceptionType.connectionTimeout:
        errorDescription = "Connection Timeout";
        break;
      case DioExceptionType.receiveTimeout:
        errorDescription = "Receive Timeout";
        break;
      case DioExceptionType.badResponse:
        errorDescription = "Server Error: ${error.response?.statusCode}";
        break;
      case DioExceptionType.sendTimeout:
        errorDescription = "Send Timeout";
        break;
      case DioExceptionType.unknown:
        errorDescription = "Unknown Error: ${error.message}";
        break;
      default:
        errorDescription = "Unknown Error: ${error.message}";
    }
    return errorDescription;
  }
}
