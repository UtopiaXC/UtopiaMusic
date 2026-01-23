import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/connection/utils/request.dart';

enum UserVipType {
  none,
  vip,
  annualVip,
}

enum LoginStatus {
  notLoggedIn,
  loggedIn,
  expired,
}

class UserInfo {
  final String name;
  final String avatarUrl;
  final UserVipType vipType;
  final int mid;

  UserInfo({
    required this.name,
    required this.avatarUrl,
    required this.vipType,
    required this.mid,
  });
}

class AuthProvider extends ChangeNotifier {
  UserInfo? _userInfo;
  LoginStatus _loginStatus = LoginStatus.notLoggedIn;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _cookieKey = 'bili_cookies';
  final UserApi _userApi = UserApi();

  bool get isLoggedIn => _loginStatus == LoginStatus.loggedIn;
  UserInfo? get userInfo => _userInfo;
  LoginStatus get loginStatus => _loginStatus;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final storedCookies = await _storage.read(key: _cookieKey);
    if (storedCookies != null && storedCookies.isNotEmpty) {
      await _fetchUserInfo();
    } else {
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
        );
        _loginStatus = LoginStatus.loggedIn;
      } else {
        _loginStatus = LoginStatus.expired;
        _userInfo = null;
      }
    } catch (e) {
      print('Error fetching user info: $e');
      _loginStatus = LoginStatus.expired;
      _userInfo = null;
    }
    notifyListeners();
  }

  Future<void> login() async {
    // This method is now just a trigger for the UI to show the login dialog
    // The actual login logic happens in the LoginDialog
    // But we can expose a method to refresh user info after login
    await _fetchUserInfo();
  }

  Future<void> logout() async {
    await _storage.delete(key: _cookieKey);
    _userInfo = null;
    _loginStatus = LoginStatus.notLoggedIn;
    
    // Reload cookies in Request to clear them
    await Request().reloadCookies();
    
    notifyListeners();
  }
  
  Future<void> saveCookies(String cookieString) async {
    await _storage.write(key: _cookieKey, value: cookieString);
    await Request().reloadCookies();
    await _fetchUserInfo();
  }
}
