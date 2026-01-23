import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final DefaultCookieJar _cookieJar;
  late final Future<void> _initWait;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _cookieKey = 'bili_cookies';

  int _maxRetries = 2;

  factory Request() => _instance;

  Request._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: Api.urlBase,
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
      if (storedCookies != null && storedCookies.isNotEmpty) {
        List<Cookie> cookies = storedCookies.split(';').map((c) {
          final parts = c.trim().split('=');
          if (parts.length == 2) {
            return Cookie(parts[0], parts[1]);
          }
          return null;
        }).whereType<Cookie>().toList();

        if (cookies.isNotEmpty) {
          await _cookieJar.saveFromResponse(Uri.parse(HttpConstants.biliUrl), cookies);
          if (kDebugMode) {
            print("Cookie initialized from storage");
          }
          return;
        }
      }

      await _generateInitialCookie();
    } catch (e) {
      print("Cookie initialization error: $e");
      await _generateInitialCookie();
    }
  }

  Future<void> _generateInitialCookie() async {
    try {
      await _dio.get(HttpConstants.biliUrl);

      final cookies = await _cookieJar.loadForRequest(Uri.parse(HttpConstants.biliUrl));
      if (cookies.isNotEmpty) {
        final cookieString = cookies.map((c) => "${c.name}=${c.value}").join(';');
        await _storage.write(key: _cookieKey, value: cookieString);
      }

      if (kDebugMode) {
        print("Cookie initialized via Homepage and saved");
      }
    } catch (e) {
      print("Cookie generation warning: $e");
    }
  }

  Future<void> _cleanExpiredCookie() async {
    try {
      await _storage.delete(key: _cookieKey);
      await _cookieJar.deleteAll();
      if (kDebugMode) {
        print("Expired cookies cleaned");
      }
    } catch (e) {
      print("Error cleaning cookies: $e");
    }
  }

  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? params,
        Options? options,
        bool useWbi = false,
      }) async {
    await _initWait;
    await _loadSettings();
    return _requestWithRetry(() async {
      Map<String, dynamic>? finalParams = params;
      if (useWbi) {
        finalParams = await WbiUtil.signParams(params ?? {});
      }
      return await _dio.get(
        path,
        queryParameters: finalParams,
        options: options,
      );
    });
  }

  Future<dynamic> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? params,
        Options? options,
      }) async {
    await _initWait;
    await _loadSettings();
    return _requestWithRetry(() async {
      return await _dio.post(
        path,
        data: data,
        queryParameters: params,
        options: options,
      );
    });
  }

  Future<dynamic> _requestWithRetry(Future<Response> Function() requestFunc, {int retryCount = 0}) async {
    try {
      Response response = await requestFunc();
      if (response.data is String && response.data.toString().trim().startsWith('<!DOCTYPE html>')) {
         if (retryCount < _maxRetries) {
            if (kDebugMode) {
              print("HTML response detected (likely WAF/Error page), retrying... Retry: ${retryCount + 1}");
            }
            if (retryCount < 2) {
               await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
            } else {
               await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
               await _cleanExpiredCookie();
               await _generateInitialCookie();
            }
            
            return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
         }
      }

      if (response.data is Map) {
        final int code = response.data['code'] ?? 0;
        final String message = response.data['message']?.toString() ?? '';

        if (code == -352 || code == -412) {
           if (retryCount < _maxRetries) {
              if (kDebugMode) {
                print("Risk control detected (code $code, msg: $message), refreshing cookie... Retry: ${retryCount + 1}");
              }
              await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
              await _cleanExpiredCookie();
              await _generateInitialCookie();
              return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
           }
        }
        else if ((code != 0 && (message.contains('风控') || message.contains('出错')))) {
          if (retryCount < _maxRetries) {
            if (kDebugMode) {
              print("Risk control detected (code $code, msg: $message), retrying... Retry: ${retryCount + 1}");
            }
            if (retryCount < 2) {
               await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
            } else {
               await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
               await _cleanExpiredCookie();
               await _generateInitialCookie();
            }
            
            return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
          }
        }
        
        if (code != 0) {
           print("Request Business Error: $code - $message");
        }
      }

      return response.data;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && retryCount < _maxRetries) {
         if (kDebugMode) {
            print("Network error (${e.type}), retrying... Retry: ${retryCount + 1}");
         }
         await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
         return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
      }

      _printErrorLog(e);
      throw _handleError(e);
    } catch (e) {
      if (retryCount < _maxRetries) {
         if (kDebugMode) {
            print("Unknown error ($e), retrying... Retry: ${retryCount + 1}");
         }
         await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
         return await _requestWithRetry(requestFunc, retryCount: retryCount + 1);
      }
      rethrow;
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
