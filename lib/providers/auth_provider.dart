import 'package:flutter/material.dart';

enum UserVipType {
  none,
  vip,
  annualVip,
}

class UserInfo {
  final String name;
  final String avatarUrl;
  final UserVipType vipType;

  UserInfo({
    required this.name,
    required this.avatarUrl,
    required this.vipType,
  });
}

class AuthProvider extends ChangeNotifier {
  UserInfo? _userInfo;
  bool get isLoggedIn => _userInfo != null;
  UserInfo? get userInfo => _userInfo;

  // Mock login for now
  Future<void> login() async {
    // TODO: Implement actual login logic
    _userInfo = UserInfo(
      name: 'Utopia User',
      avatarUrl: 'https://i0.hdslb.com/bfs/face/member/noface.jpg',
      vipType: UserVipType.annualVip,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _userInfo = null;
    notifyListeners();
  }
}
