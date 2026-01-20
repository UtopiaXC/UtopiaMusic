import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final DefaultCookieJar _cookieJar;
  late final Future<void> _initWait;

  factory Request() => _instance;

  Request._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: Api.baseUrl,
      connectTimeout: const Duration(
        milliseconds: HttpConstants.connectTimeout,
      ),
      receiveTimeout: const Duration(
        milliseconds: HttpConstants.receiveTimeout,
      ),
      headers: {
        'User-Agent': HttpConstants.userAgent,
        'Referer': HttpConstants.referer, // 确保 Referer 指向 B 站
      },
    );

    _dio = Dio(options);

    if (!kIsWeb) {
      _cookieJar = DefaultCookieJar();
      _dio.interceptors.add(CookieManager(_cookieJar));

      _initWait = _generateInitialCookie();
    } else {
      // Web 端处理（通常由浏览器自动管理 Cookie，不需要 CookieJar）
      _initWait = Future.value();
    }
  }

  Future<void> _generateInitialCookie() async {
    try {
      await _dio.get(HttpConstants.biliUrl);
      if (kDebugMode) {
        print("Init cookie succeed");
      }
    } catch (e) {
      print("Init cookie failed: $e");
    }
  }

  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? params,
        Options? options,
      }) async {
    //
    await _initWait;

    try {
      Response response = await _dio.get(
        path,
        queryParameters: params,
        options: options,
      );
      print(response.data);
      return response.data;
    } on DioException catch (e) {
      _printErrorLog(e);
      print("Request Error: ${e.message}");
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
      print("Response Data: ${e.response?.data}");
      print("Response Headers: ${e.response?.headers}");
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
        if (error.message?.contains('XMLHttpRequest') ?? false) {
          errorDescription = "CORS Error";
        } else {
          errorDescription = "Unknown Error: ${error.message}";
        }
        break;
      default:
        errorDescription = "Unknown Error: ${error.message}";
    }
    return errorDescription;
  }
}