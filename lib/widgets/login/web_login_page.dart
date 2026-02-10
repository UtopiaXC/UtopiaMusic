import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "WEB_LOGIN_PAGE";

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  InAppWebViewController? _controller;
  final CookieManager _cookieManager = CookieManager.instance();
  bool _isLoading = true;
  bool _isLoginSuccess = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _getUserAgent() {
    if (io.Platform.isIOS) {
      return HttpConstants.userAgentIOS;
    } else if (io.Platform.isAndroid) {
      return HttpConstants.userAgentAndroid;
    }
    return HttpConstants.userAgent;
  }

  Future<void> _checkLoginSuccess(String url) async {
    if (_isLoginSuccess) return;

    bool isSuccess = Api.webLoginSuccessUrls.any((successUrl) => url.startsWith(successUrl));

    if (isSuccess) {
      Log.i(_tag, 'Detected successful login redirect to: $url');
      _startPollingForCookies();
    }
  }

  void _startPollingForCookies() {
    _pollTimer?.cancel();
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      attempts++;
      if (attempts > 10 || _isLoginSuccess) {
        timer.cancel();
        return;
      }
      await _extractAndSaveCookies(showError: false);
    });
  }

  Future<void> _extractAndSaveCookies({bool showError = true}) async {
    if (_isLoginSuccess) return;

    try {
      // Get cookies from multiple domains
      final passportCookies = await _cookieManager.getCookies(url: WebUri(Api.urlLoginBase));
      final siteCookies = await _cookieManager.getCookies(url: WebUri(Api.urlSiteBase));

      // Merge cookies, preferring passport cookies
      final Map<String, io.Cookie> cookieMap = {};
      for (var cookie in siteCookies) {
        cookieMap[cookie.name] = io.Cookie(cookie.name, cookie.value);
      }
      for (var cookie in passportCookies) {
        cookieMap[cookie.name] = io.Cookie(cookie.name, cookie.value);
      }

      final allCookies = cookieMap.values.toList();

      Log.d(_tag, 'Found ${allCookies.length} cookies');
      for (var cookie in allCookies) {
        final displayValue = cookie.value.length > 10
            ? '${cookie.value.substring(0, 10)}...'
            : cookie.value;
        Log.d(_tag, 'Cookie: ${cookie.name}=$displayValue');
      }

      if (allCookies.isEmpty) {
        Log.w(_tag, 'No cookies found');
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).weight_login_web_no_cookie)),
          );
        }
        return;
      }

      final hasDedeUserID = allCookies.any((c) => c.name == 'DedeUserID' && c.value.isNotEmpty);
      final hasSESSDATA = allCookies.any((c) => c.name == 'SESSDATA' && c.value.isNotEmpty);

      if (!hasDedeUserID || !hasSESSDATA) {
        Log.d(_tag, 'Essential cookies not found. hasDedeUserID=$hasDedeUserID, hasSESSDATA=$hasSESSDATA');
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).weight_login_web_no_login_info)),
          );
        }
        return;
      }

      Log.i(_tag, 'Found essential cookies, saving...');

      _isLoginSuccess = true;
      _pollTimer?.cancel();

      final request = Request();
      final cookieJar = await request.cookieJar;

      await cookieJar.saveFromResponse(Uri.parse(Api.urlBase), allCookies);
      await cookieJar.saveFromResponse(Uri.parse(Api.urlLoginBase), allCookies);
      await cookieJar.saveFromResponse(Uri.parse(Api.urlSiteBase), allCookies);

      Log.i(_tag, 'Cookies saved successfully');

      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.login(type: 'web');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).common_succeed)),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      Log.e(_tag, 'Error extracting cookies: $e');
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).common_failed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).weight_login_web_login),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
            tooltip: S.of(context).common_refresh,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _extractAndSaveCookies(showError: true),
            tooltip: S.of(context).weight_login_manual_confirm,
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(Api.urlWebLogin)),
            initialSettings: InAppWebViewSettings(
              userAgent: _getUserAgent(),
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              if (mounted) setState(() => _isLoading = false);
              if (url != null) await _checkLoginSuccess(url.toString());
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}








