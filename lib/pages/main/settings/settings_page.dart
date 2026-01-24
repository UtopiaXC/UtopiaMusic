import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/pages/main/settings/fragments/appearance_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/search_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/play_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/performance_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/network_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/security_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/general_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/about_settings_page.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      await authProvider.login();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _handleRefresh(context),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _buildUserSection(context),
            const SizedBox(height: 16),
            _buildSettingsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final userInfo = authProvider.userInfo;

    return InkWell(
      onTap: () {
        if (!isLoggedIn) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const LoginDialog(),
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SpaceSheet(mid: userInfo!.mid),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: isLoggedIn && userInfo != null
                  ? NetworkImage(userInfo.avatarUrl)
                  : null,
              child: !isLoggedIn
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: isLoggedIn && userInfo != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userInfo.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getLevelColor(userInfo.level),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'LV${userInfo.level}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getVipLabel(userInfo.vipType),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Text(
                      '点击登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
      case 1:
        return const Color(0xFFBFBFBF);
      case 2:
        return const Color(0xFF95DDB2);
      case 3:
        return const Color(0xFF92D1E5);
      case 4:
        return const Color(0xFFFFB37C);
      case 5:
        return const Color(0xFFFF6C00);
      case 6:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFBFBFBF);
    }
  }

  String _getVipLabel(UserVipType type) {
    switch (type) {
      case UserVipType.vip:
        return '大会员';
      case UserVipType.annualVip:
        return '年度大会员';
      default:
        return '普通用户';
    }
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        _buildSettingItem(context, '外观', Icons.palette_outlined, const AppearanceSettingsPage()),
        _buildSettingItem(context, '搜索', Icons.search, const SearchSettingsPage()),
        _buildSettingItem(context, '播放', Icons.play_circle_outline, const PlaySettingsPage()),
        _buildSettingItem(context, '性能', Icons.speed, const PerformanceSettingsPage()),
        _buildSettingItem(context, '网络', Icons.wifi, const NetworkSettingsPage()),
        _buildSettingItem(context, '安全', Icons.security, const SecuritySettingsPage()),
        _buildSettingItem(context, '通用', Icons.settings_outlined, const GeneralSettingsPage()),
        _buildSettingItem(context, '关于', Icons.info_outline, const AboutSettingsPage()),
      ],
    );
  }

  Widget _buildSettingItem(BuildContext context, String title, IconData icon, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
    );
  }
}
