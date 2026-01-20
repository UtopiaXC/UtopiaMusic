import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/wbi.dart';

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final DefaultCookieJar _cookieJar;
  late final Future<void> _initWait;
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
      _initWait = _generateInitialCookie();
    } else {
      _initWait = Future.value();
    }
  }

  Future<void> _generateInitialCookie() async {
    try {
      await _dio.get(HttpConstants.biliUrl);
      if (kDebugMode) {
        print("Cookie initialized via Homepage");
      }
    } catch (e) {
      print("Cookie initialization warning: $e");
    }
  }

  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? params,
        Options? options,
        bool useWbi = false,
      }) async {
    await _initWait;
    Map<String, dynamic>? finalParams = params;
    if (useWbi) {
      finalParams = await WbiUtil.signParams(params ?? {});
    }

    try {
      Response response = await _dio.get(
        path,
        queryParameters: finalParams,
        options: options,
      );

      if (response.data is Map && response.data['code'] != 0) {
        print("Request Business Error: ${response.data['code']} - ${response.data['message']}");
      }

      return response.data;
    } on DioException catch (e) {
      _printErrorLog(e);
      throw _handleError(e);
    }
  }

  Future<dynamic> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? params,
        Options? options,
      }) async {
    await _initWait;

    try {
      Response response = await _dio.post(
        path,
        data: data,
        queryParameters: params,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _printErrorLog(e);
      throw _handleError(e);
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