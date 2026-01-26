import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:utopia_music/connection/update/github_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:utopia_music/widgets/update/update_dialog.dart';

import '../../../../utils/update_util.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final securityProvider = Provider.of<SecurityProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('通用')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '全局',
            children: [
              ListTile(
                title: const Text('语言设置'),
                trailing: DropdownButton<Locale?>(
                  value: settingsProvider.locale,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (Locale? newLocale) {
                    settingsProvider.setLocale(newLocale);
                  },
                  items: [
                    const DropdownMenuItem<Locale?>(
                      value: null,
                      child: Text('跟随系统'),
                    ),
                    ...S.delegate.supportedLocales.map<DropdownMenuItem<Locale>>((Locale locale) {
                      String label = locale.languageCode;
                      if (locale.languageCode == 'zh') label = '中文';
                      if (locale.languageCode == 'en') label = 'English';
                      return DropdownMenuItem<Locale>(
                        value: locale,
                        child: Text(label),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: '更新',
            children: [
              SwitchListTile(
                title: const Text('自动检查更新'),
                value: settingsProvider.autoCheckUpdate,
                onChanged: (bool value) {
                  settingsProvider.setAutoCheckUpdate(value);
                  if (value) {
                    UpdateUtil.checkAndShow(context, isManualCheck: false);
                  }
                },
              ),
              SwitchListTile(
                title: const Text('检查测试版更新'),
                value: settingsProvider.checkPreRelease,
                onChanged: (bool value) {
                  settingsProvider.setCheckPreRelease(value);
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: '初始化',
            children: [
              ListTile(
                title: const Text('重置为默认设置'),
                trailing: const Icon(Icons.restore, size: 20),
                onTap: () => _showResetDefaultsDialog(context, settingsProvider, playerProvider, securityProvider),
              ),
              ListTile(
                title: const Text('重置软件'),
                subtitle: const Text('暂未实现'),
                trailing: const Icon(Icons.delete_forever, size: 20),
                onTap: () => _showResetAppDialog(context, settingsProvider, playerProvider, securityProvider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResetDefaultsDialog(BuildContext context, SettingsProvider settingsProvider, PlayerProvider playerProvider, SecurityProvider securityProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认重置设置'),
        content: const Text('是否将软件重置为默认设置？\n（账号登录状态和本地歌单不会被清除）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              settingsProvider.resetToDefaults();
              playerProvider.resetToDefaults();
              securityProvider.resetToDefaults();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已重置为默认设置')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showResetAppDialog(BuildContext context, SettingsProvider settingsProvider, PlayerProvider playerProvider, SecurityProvider securityProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认重置软件'),
        content: const Text('是否将软件彻底重置为刚安装的状态？\n此操作将清空所有数据（包括缓存、登录信息、设置等）并重启应用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await settingsProvider.resetApp();

              if (context.mounted) {
                Phoenix.rebirth(context);
              }
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}