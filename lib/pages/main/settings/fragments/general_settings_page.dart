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
        children: [
          ListTile(
            title: const Text('语言设置'),
            trailing: DropdownButton<Locale?>(
              value: settingsProvider.locale,
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
          SwitchListTile(
            title: const Text('自动检查更新'),
            value: settingsProvider.autoCheckUpdate,
            onChanged: (bool value) {
              settingsProvider.setAutoCheckUpdate(value);
              if (value) {
                _checkUpdate(context, settingsProvider, silent: true);
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
          ListTile(
            title: const Text('重置为默认设置'),
            onTap: () => _showResetDefaultsDialog(context, settingsProvider, playerProvider, securityProvider),
          ),
          ListTile(
            title: const Text('重置软件'),
            onTap: () => _showResetAppDialog(context, settingsProvider, playerProvider, securityProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context, SettingsProvider settingsProvider, {required bool silent}) async {
    if (!silent) {
       // Manual check logic is handled in AboutSettingsPage, but if we wanted to reuse logic we could extract it.
       // However, the requirement says "When opening auto update settings... silently check".
       // So here we just trigger the silent check.
    }
    
    // Silent check implementation
    // We should probably move the check logic to a service or utility to avoid duplication
    // But for now, let's implement the silent check here as requested for the "toggle on" action.
    
    // Actually, the requirement says: "When turned on, automatically check... every time app starts AND when clicking auto update setting".
    // "When clicking auto update setting" likely means when the user toggles the switch to ON.
    
    try {
      final githubApi = GithubApi();
      Map<String, dynamic>? release;
      
      if (settingsProvider.checkPreRelease) {
        release = await githubApi.getLatestPreRelease();
      } else {
        release = await githubApi.getLatestRelease();
      }

      if (release != null && context.mounted) {
        final tagName = release['tag_name'] as String;
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = 'v${packageInfo.version}'; // Assuming tag starts with v

        // Simple version comparison (string equality for now as per requirement "check if consistent")
        // Ideally we should parse semantic versioning, but requirement says "check if consistent".
        // Usually tags are like "v1.0.0", version is "1.0.0".
        
        bool hasUpdate = tagName != currentVersion;
        // If tag doesn't have 'v', add it for comparison or remove 'v' from tag.
        // Let's try to normalize.
        String normalizedTag = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        String normalizedCurrent = packageInfo.version;
        
        if (normalizedTag != normalizedCurrent) {
           // Check if ignored
           if (settingsProvider.ignoredVersion == tagName) {
             return;
           }
           
           showDialog(
             context: context,
             builder: (context) => UpdateDialog(releaseData: release!),
           );
        }
      }
    } catch (e) {
      // Silent error
    }
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
              // Reset other providers first if needed, but resetApp clears SharedPreferences
              // which affects all providers. However, in-memory state needs to be cleared too.
              // Since we are restarting the app with Phoenix, in-memory state will be reset.
              // But we need to make sure persistent storage is cleared.
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
