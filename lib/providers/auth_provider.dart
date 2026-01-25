import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/connection/utils/api.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:dio/dio.dart';

enum UserVipType { none, vip, annualVip }

enum LoginStatus { notLoggedIn, loggedIn, expired }

class UserInfo {
  final String name;
  final String avatarUrl;
  final UserVipType vipType;
  final int mid;
  final int level;

  UserInfo({
    required this.name,
    required this.avatarUrl,
    required this.vipType,
    required this.mid,
    required this.level,
  });
}

class AuthProvider extends ChangeNotifier {
  UserInfo? _userInfo;
  LoginStatus _loginStatus = LoginStatus.notLoggedIn;
  final UserApi _userApi = UserApi();
  static const String _loginTypeKey = 'auth_login_type';

  bool get isLoggedIn => _loginStatus == LoginStatus.loggedIn;

  UserInfo? get userInfo => _userInfo;

  LoginStatus get loginStatus => _loginStatus;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final jar = await Request().cookieJar;
      final cookies = await jar.loadForRequest(Uri.parse(Api.urlBase));

      final hasLoginCookie = cookies.any(
        (c) => c.name == 'DedeUserID' && c.value.isNotEmpty,
      );

      if (hasLoginCookie) {
        await _fetchUserInfo();
      } else {
        _loginStatus = LoginStatus.notLoggedIn;
        notifyListeners();
      }
    } catch (e) {
      print('Auth: Error checking login status: $e');
      _loginStatus = LoginStatus.notLoggedIn;
      notifyListeners();
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final accountData = await _userApi.getUserInfo();
      if (accountData != null) {
        final mid = accountData['mid'];
        final name = accountData['uname'];
        final avatarUrl = accountData['face'];
        final vipStatus = accountData['vip']['status'];
        final vipTypeInt = accountData['vip']['type'];
        final level = accountData['level_info']['current_level'] ?? 0;

        UserVipType vipType = UserVipType.none;
        if (vipStatus == 1) {
          if (vipTypeInt == 2) {
            vipType = UserVipType.annualVip;
          } else if (vipTypeInt == 1) {
            vipType = UserVipType.vip;
          }
        }

        _userInfo = UserInfo(
          name: name,
          avatarUrl: avatarUrl,
          vipType: vipType,
          mid: mid,
          level: level,
        );
        _loginStatus = LoginStatus.loggedIn;
      } else {
        _loginStatus = LoginStatus.expired;
        _userInfo = null;
      }
    } catch (e) {
      print('Auth: Error fetching user info: $e');
      _loginStatus = LoginStatus.expired;
      _userInfo = null;
    }
    notifyListeners();
  }

  Future<void> _setLoginType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginTypeKey, type);
  }

  Future<String?> _getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loginTypeKey);
  }

  Future<void> login({String type = 'qr'}) async {
    await _setLoginType(type);
    await _checkLoginStatus();
  }

  Future<void> logout() async {
    try {
      final jar = await Request().cookieJar;
      final loginType = await _getLoginType();
      if (loginType == 'qr') {
        try {
          final cookies = await jar.loadForRequest(Uri.parse(Api.urlBase));
          final biliJct = cookies.firstWhere(
            (c) => c.name == 'bili_jct',
            orElse: () => null as dynamic,
          );

          if (biliJct != null) {
            await Request()
                .post(
                  Api.urlExit,
                  baseUrl: Api.urlLoginBase,
                  data: {'biliCSRF': biliJct.value},
                  options: Options(
                    contentType: Headers.formUrlEncodedContentType,
                  ),
                )
                .timeout(const Duration(seconds: 2))
                .catchError((e) {
                  print(
                    "Auth: Exit API call failed or timed out (ignoring): $e",
                  );
                  return null;
                });
          }
        } catch (e) {
          print("Auth: Error during exit API call: $e");
        }
      }

      await jar.deleteAll();
      _userInfo = null;
      _loginStatus = LoginStatus.notLoggedIn;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginTypeKey);

      notifyListeners();
      await Request().fetchGuestCookies();
    } catch (e) {
      print('Auth: Error during logout: $e');
    }
  }

  Future<void> saveCookies(String cookieString) async {
    await Request().setManualCookies(cookieString);
    await login(type: 'manual');
  }
}
