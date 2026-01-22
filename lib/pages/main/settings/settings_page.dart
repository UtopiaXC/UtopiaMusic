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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildUserSection(context),
          const SizedBox(height: 16),
          _buildSettingsList(context),
        ],
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
          authProvider.login();
        } else {
          // Navigate to user profile or show logout option
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('退出登录'),
              content: const Text('确定要退出登录吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    authProvider.logout();
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
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
                    )
                  : const Text(
                      '点击登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            if (isLoggedIn)
              Row(
                children: [
                  Text(
                    '我的投稿',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
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
