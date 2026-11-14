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
import 'package:provider/provider.dart';
import 'package:talker_dio_logger/talker_dio_logger_interceptor.dart';
import 'package:talker_dio_logger/talker_dio_logger_settings.dart';
import 'package:utopia_music/connection/error/error_code.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/bili_id.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/generated/l10n.dart';

const String _tag = "REQUEST";

enum ResponseType { data, response }

class Request {
  static final Request _instance = Request._internal();
  late final Dio _dio;
  late final PersistCookieJar _cookieJar;
  late final Future<void> _initWait;
  int _maxRetries = 2;
  static bool _isShowingAuthDialog = false;
  static bool _isShowingErrorDialog = false;

  bool _isUserLoggedIn = false;

  factory Request() => _instance;

  /// Creates an isolated [Request] instance with an injected cookie directory
  /// and HTTP adapter so startup cookie bootstrap can be verified in tests.
  @visibleForTesting
  factory Request.createForTest({
    required Directory cookieDir,
    HttpClientAdapter? httpClientAdapter,
  }) => Request._withOverrides(
    cookieDirOverride: cookieDir,
    httpClientAdapter: httpClientAdapter,
  );

  Request._internal() : this._withOverrides();

  Request._withOverrides({
    Directory? cookieDirOverride,
    HttpClientAdapter? httpClientAdapter,
  }) {
    _initWait = _init(
      cookieDirOverride: cookieDirOverride,
      httpClientAdapter: httpClientAdapter,
    );
  }

  Future<PersistCookieJar> get cookieJar async {
    await _initWait;
    return _cookieJar;
  }

  Future<void> _init({
    Directory? cookieDirOverride,
    HttpClientAdapter? httpClientAdapter,
  }) async {
    Directory appDocDir =
        cookieDirOverride ?? await getApplicationDocumentsDirectory();
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
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(
      TalkerDioLogger(
        talker: LogService.instance.talker,
        settings: TalkerDioLoggerSettings(
          printRequestData: true,
          printRequestHeaders: false,
          printResponseHeaders: false,
          printResponseData: true,
          printResponseMessage: true,
          requestFilter: (RequestOptions options) => false,
          responseFilter: (Response response) {
            final statusCode = response.statusCode ?? 0;
            if (statusCode >= 200 && statusCode < 400) {
              return false;
            }
            return true;
          },
        ),
      ),
    );

    await _loadSettings();
    await _checkCookies();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _maxRetries = prefs.getInt(SettingsProvider.maxRetriesKey) ?? 3;
  }

  static final List<Uri> _cookieTargetUris = [
    Uri.parse(Api.urlBase),
    Uri.parse(Api.urlLoginBase),
    Uri.parse(Api.urlSiteBase),
    Uri.parse(Api.urlLiveBase),
    Uri.parse(Api.urlAppBase),
    Uri.parse('https://search.bilibili.com'),
  ];

  Completer<void>? _buvidCompleter;

  Cookie _buildBiliCookie(String name, String value) {
    return Cookie(name, value)
      ..domain = '.bilibili.com'
      ..path = '/'
      ..httpOnly = false;
  }

  bool _hasCookie(List<Cookie> cookies, String name) {
    return cookies.any((c) => c.name == name && c.value.isNotEmpty);
  }

  Future<void> syncCookiesToAllDomains(List<Cookie> cookies) async {
    await _initWait;
    await _syncCookiesToAllDomainsInternal(cookies);
  }

  Future<void> _syncCookiesToAllDomainsInternal(List<Cookie> cookies) async {
    if (cookies.isEmpty) return;
    final scoped = cookies
        .where((c) => c.value.isNotEmpty)
        .map((c) => _buildBiliCookie(c.name, c.value))
        .toList();
    if (scoped.isEmpty) return;
    for (final uri in _cookieTargetUris) {
      await _cookieJar.saveFromResponse(uri, scoped);
    }
  }

  Future<void> ensureBuvidCookies({bool forceRefresh = false}) async {
    await _initWait;
    await _ensureBuvidCookiesInternal(forceRefresh: forceRefresh);
  }

  Future<void> _ensureBuvidCookiesInternal({bool forceRefresh = false}) async {
    final pending = _buvidCompleter;
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<void>();
    _buvidCompleter = completer;
    try {
      final baseCookies = await _cookieJar.loadForRequest(Uri.parse(Api.urlBase));
      final hasBuvid3 = _hasCookie(baseCookies, 'buvid3');
      final hasBNut = _hasCookie(baseCookies, 'b_nut');
      if (!forceRefresh && hasBuvid3 && hasBNut) {
        final liveCookies = await _cookieJar.loadForRequest(
          Uri.parse(Api.urlLiveBase),
        );
        if (!_hasCookie(liveCookies, 'buvid3') || !_hasCookie(liveCookies, 'b_nut')) {
          await _syncCookiesToAllDomainsInternal(
            baseCookies
                .where(
                  (c) =>
                      c.name == 'buvid3' ||
                      c.name == 'buvid4' ||
                      c.name == 'b_nut',
                )
                .toList(),
          );
        }
        return;
      }

      String b3 = '';
      String b4 = '';
      try {
        final resp = await _dio.get(_buildUrl(Api.urlBase, Api.urlFingerSpi));
        final data = resp.data;
        if (data is Map && data['code'] == 0 && data['data'] is Map) {
          final spiData = data['data'] as Map;
          b3 = spiData['b_3']?.toString() ?? '';
          b4 = spiData['b_4']?.toString() ?? '';
        }
      } catch (e) {
        Log.w(_tag, "Failed to fetch finger/spi: $e");
      }

      if (b3.isEmpty) {
        final existingB3 = baseCookies.where((c) => c.name == 'buvid3');
        b3 = existingB3.isNotEmpty && existingB3.first.value.isNotEmpty
            ? existingB3.first.value
            : BiliIdUtils.generateBuvid3();
      }
      final bNut = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final newCookies = <Cookie>[
        _buildBiliCookie('buvid3', b3),
        if (b4.isNotEmpty) _buildBiliCookie('buvid4', b4),
        _buildBiliCookie('b_nut', bNut),
      ];
      await _syncCookiesToAllDomainsInternal(newCookies);
    } catch (e) {
      Log.w(_tag, "Failed to ensure buvid cookies: $e");
    } finally {
      _buvidCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _checkCookies() async {
    try {
      final uri = Uri.parse(Api.urlBase);
      final cookies = await _cookieJar.loadForRequest(uri);
      if (cookies.isEmpty) {
        await _fetchGuestCookiesInternal();
      } else {
        _isUserLoggedIn = _hasCookie(cookies, 'DedeUserID');
        final liveCookies = await _cookieJar.loadForRequest(
          Uri.parse(Api.urlLiveBase),
        );
        final hasLiveAuth = _hasCookie(liveCookies, 'DedeUserID');
        if (_isUserLoggedIn && !hasLiveAuth) {
          await _syncCookiesToAllDomainsInternal(cookies);
        }
        if (!_hasCookie(cookies, 'buvid3') || !_hasCookie(cookies, 'b_nut')) {
          await _fetchGuestCookiesInternal();
        }
      }
    } catch (e) {
      Log.w(_tag, "Failed to ensure cookies: $e");
    }
  }

  Future<void> fetchGuestCookies() async {
    await _initWait;
    await _fetchGuestCookiesInternal();
  }

  Future<void> _fetchGuestCookiesInternal() async {
    try {
      if (kDebugMode) {
        Log.d(_tag, "Fetching guest cookies...");
      }
      try {
        await _dio.get(_buildUrl(Api.urlBase, Api.urlNav));
      } catch (_) {}
      await _ensureBuvidCookiesInternal(forceRefresh: true);
      final cookies = await _cookieJar.loadForRequest(Uri.parse(Api.urlBase));
      _isUserLoggedIn = _hasCookie(cookies, 'DedeUserID');
    } catch (e) {
      Log.w(_tag, "Failed to fetch guest cookies: $e");
    }
  }

  Map<String, dynamic> signParams(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final query = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    final stringToSign = query + Api.tvAppSecret;
    final sign = md5.convert(utf8.encode(stringToSign)).toString();

    return {...params, 'sign': sign};
  }

  /// Signs parameters for Bilibili mobile App API endpoints.
  Map<String, dynamic> signAppParams(Map<String, dynamic> params) {
    final signed = <String, dynamic>{
      ...params,
      'appkey': Api.androidAppKey,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'mobi_app': 'android',
      'platform': 'android',
      'build': 2001100,
    };
    final sortedKeys = signed.keys.toList()..sort();
    final query = sortedKeys
        .map(
          (k) =>
              '${Uri.encodeComponent(k)}=${Uri.encodeComponent('${signed[k]}')}',
        )
        .join('&');
    final sign = md5
        .convert(utf8.encode(query + Api.androidAppSecret))
        .toString();
    return {...signed, 'sign': sign};
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
        cookies.add(_buildBiliCookie(name, value));
      }
    }

    if (cookies.isNotEmpty) {
      await _syncCookiesToAllDomainsInternal(cookies);
      _isUserLoggedIn = true;
      await _ensureBuvidCookiesInternal(forceRefresh: true);
      Log.i(_tag, "Manual cookies set (${cookies.length} items)");
    }
  }

  Future<String> getCsrf() async {
    await _initWait;
    try {
      final cookies = await _cookieJar.loadForRequest(Uri.parse(Api.urlBase));
      final biliJct = cookies.firstWhere(
        (c) => c.name == 'bili_jct',
        orElse: () => Cookie('bili_jct', ''),
      );
      return biliJct.value;
    } catch (e) {
      return '';
    }
  }

  Future<dynamic> get(
    String path, {
    String baseUrl = Api.urlBase,
    Map<String, dynamic>? params,
    bool useWbi = false,
    bool useAppSign = false,
    ResponseType responseType = ResponseType.data,
    Options? options,
    bool suppressErrorDialog = true,
  }) async {
    return _request(
      method: 'GET',
      path: path,
      baseUrl: baseUrl,
      params: params,
      useWbi: useWbi,
      useAppSign: useAppSign,
      responseType: responseType,
      options: options,
      suppressErrorDialog: suppressErrorDialog,
    );
  }

  Future<dynamic> post(
    String path, {
    String baseUrl = Api.urlBase,
    dynamic data,
    Map<String, dynamic>? params,
    bool useWbi = false,
    bool useAppSign = false,
    ResponseType responseType = ResponseType.data,
    Options? options,
    bool suppressErrorDialog = true,
  }) async {
    return _request(
      method: 'POST',
      path: path,
      baseUrl: baseUrl,
      data: data,
      params: params,
      useWbi: useWbi,
      useAppSign: useAppSign,
      responseType: responseType,
      options: options,
      suppressErrorDialog: suppressErrorDialog,
    );
  }

  bool _isRiskControlResponse(int? statusCode, dynamic data) {
    if (statusCode == 412) return true;
    if (data is Map) {
      final int code = data['code'] ?? 0;
      if (code == ErrorCode.riskControlFail ||
          code == ErrorCode.unauthorized ||
          code == ErrorCode.ipRiskControl ||
          code == -403 ||
          code == -412) {
        return true;
      }
      final inner = data['data'];
      if (inner is Map && inner['v_voucher'] != null) {
        return true;
      }
    }
    return false;
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    required String baseUrl,
    dynamic data,
    Map<String, dynamic>? params,
    required bool useWbi,
    required bool useAppSign,
    required ResponseType responseType,
    Options? options,
    required bool suppressErrorDialog,
  }) async {
    await _initWait;

    final result = await _requestWithRetry(
      () async {
        Map<String, dynamic> finalParams = params ?? {};
        Options? requestOptions = options;
        if (useAppSign) {
          finalParams = signAppParams(finalParams);
          final mergedHeaders = <String, dynamic>{
            'User-Agent': HttpConstants.userAgentApp,
            'env': HttpConstants.appEnv,
            'app-key': HttpConstants.appKeyHeader,
            'x-bili-aurora-zone': HttpConstants.auroraZone,
            ...?options?.headers,
          };
          requestOptions = (options ?? Options()).copyWith(
            headers: mergedHeaders,
          );
        } else {
          if (useWbi && path != Api.urlFingerSpi && path != Api.urlNav) {
            await ensureBuvidCookies();
          }
          if (useWbi) {
            finalParams = await WbiUtil.signParams(finalParams);
          }
        }

        final url = _buildUrl(baseUrl, path);

        Response response;
        if (method == 'GET') {
          response = await _dio.get(
            url,
            queryParameters: finalParams,
            options: requestOptions,
          );
        } else {
          response = await _dio.post(
            url,
            data: data,
            queryParameters: finalParams,
            options: requestOptions,
          );
        }

        return response;
      },
      retryCount: 0,
      suppressErrorDialog: suppressErrorDialog,
      onRiskControlRefresh: useAppSign || path == Api.urlFingerSpi
          ? null
          : () async {
              await ensureBuvidCookies(forceRefresh: true);
              if (useWbi) {
                await WbiUtil.invalidateKeys();
              }
            },
    );

    if (responseType == ResponseType.response) {
      return result;
    }
    return result is Response ? result.data : result;
  }

  Future<dynamic> _requestWithRetry(
    Future<dynamic> Function() requestFunc, {
    int retryCount = 0,
    bool riskControlRefreshed = false,
    Future<void> Function()? onRiskControlRefresh,
    required bool suppressErrorDialog,
  }) async {
    try {
      final result = await requestFunc();

      final int? statusCode = result is Response ? result.statusCode : null;
      final dynamic data = result is Response ? result.data : result;

      if (!riskControlRefreshed &&
          onRiskControlRefresh != null &&
          _isRiskControlResponse(statusCode, data)) {
        if (kDebugMode) {
          Log.d(_tag, "Risk control triggered ($statusCode), refreshing session...");
        }
        await onRiskControlRefresh();
        await Future.delayed(const Duration(milliseconds: 350));
        return await _requestWithRetry(
          requestFunc,
          retryCount: retryCount,
          riskControlRefreshed: true,
          onRiskControlRefresh: onRiskControlRefresh,
          suppressErrorDialog: suppressErrorDialog,
        );
      }

      if (data is String &&
          data.toString().trim().startsWith('<!DOCTYPE html>')) {
        if (retryCount < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          return await _requestWithRetry(
            requestFunc,
            retryCount: retryCount + 1,
            riskControlRefreshed: riskControlRefreshed,
            onRiskControlRefresh: onRiskControlRefresh,
            suppressErrorDialog: suppressErrorDialog,
          );
        } else {
          if (kDebugMode) {
            Log.w(
              _tag,
              "API returned HTML content (WAF or Error Page). Suppressed dialog.",
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
              riskControlRefreshed: riskControlRefreshed,
              onRiskControlRefresh: onRiskControlRefresh,
              suppressErrorDialog: suppressErrorDialog,
            );
          } else {
            if (!suppressErrorDialog) {
              await _handleLoginExpired(code, message);
            }
          }
        } else if (code != 0) {
          if (code == ErrorCode.notFound || suppressErrorDialog) {
            if (kDebugMode)
              Log.d(_tag, "Suppressed error dialog for code $code.");
            return result;
          }

          if (retryCount < _maxRetries) {
            if (kDebugMode)
              Log.d(_tag, "Business error (code $code), retrying...");
            await Future.delayed(
              Duration(milliseconds: 500 * (retryCount + 1)),
            );
            return await _requestWithRetry(
              requestFunc,
              retryCount: retryCount + 1,
              riskControlRefreshed: riskControlRefreshed,
              onRiskControlRefresh: onRiskControlRefresh,
              suppressErrorDialog: suppressErrorDialog,
            );
          } else {
            if (!_isUserLoggedIn && code == ErrorCode.notLoggedIn) {
              return result;
            }
            if (ErrorCode.isDefined(code)) {
              _showErrorDialog(code, message);
            } else {
              if (kDebugMode) {
                Log.d(_tag, "Ignored undefined error code: $code");
              }
            }
          }
        }
      }
      return result;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && retryCount < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
        return await _requestWithRetry(
          requestFunc,
          retryCount: retryCount + 1,
          riskControlRefreshed: riskControlRefreshed,
          onRiskControlRefresh: onRiskControlRefresh,
          suppressErrorDialog: suppressErrorDialog,
        );
      }
      if (retryCount >= _maxRetries) {
        if (!suppressErrorDialog) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            _showErrorDialog(
              ErrorCode.serverError,
              "${S.of(context).common_network_error}: ${e.message}",
            );
          }
        }
      }
      throw _handleError(e);
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
        return await _requestWithRetry(
          requestFunc,
          retryCount: retryCount + 1,
          riskControlRefreshed: riskControlRefreshed,
          onRiskControlRefresh: onRiskControlRefresh,
          suppressErrorDialog: suppressErrorDialog,
        );
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
    if (_isShowingAuthDialog) return;
    _isShowingAuthDialog = true;

    final context = navigatorKey.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).connection_error_login_invalid),
          content: Text(
            '${S.of(context).connection_error_code}: $code\n${S.of(context).connection_error_message}: ${ErrorCode.getMessage(code)}\n\n${S.of(context).connection_error_login_invalid_description}',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                } catch (e) {
                  Log.w(_tag, "Failed to invoke AuthProvider logout: $e");
                  await _cookieJar.deleteAll();
                  _isUserLoggedIn = false;
                  await fetchGuestCookies();
                }
              },
              child: Text(S.of(context).weight_login_logout),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).common_cancel),
            ),
          ],
        ),
      );
    }

    _isShowingAuthDialog = false;
  }

  void _showErrorDialog(int code, String message) {
    if (_isShowingErrorDialog) return;
    _isShowingErrorDialog = true;

    final context = navigatorKey.currentContext;
    if (context != null) {
      Future.microtask(() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.of(context).common_network_error),
            content: Text(
              '${S.of(context).connection_error_code}: $code\n${S.of(context).connection_error_message}: ${ErrorCode.getMessage(code)}\n${S.of(context).connection_error_detail}: $message',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _isShowingErrorDialog = false;
                },
                child: const Text('确定'),
              ),
            ],
          ),
        ).then((_) {
          _isShowingErrorDialog = false;
        });
      });
    } else {
      _isShowingErrorDialog = false;
    }
  }

  String _handleError(DioException error) => error.message ?? "Unknown Error";
}
