import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/utils/update_util.dart';
import 'package:utopia_music/generated/l10n.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final securityProvider = Provider.of<SecurityProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).pages_settings_tag_general)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_general_global,
            children: [
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_general_global_language,
                ),
                trailing: DropdownButton<Locale?>(
                  value: settingsProvider.locale,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (Locale? newLocale) {
                    settingsProvider.setLocale(newLocale);
                  },
                  items: [
                    DropdownMenuItem<Locale?>(
                      value: null,
                      child: Text(
                        S
                            .of(context)
                            .pages_settings_tag_general_global_language_system,
                      ),
                    ),
                    ...S.delegate.supportedLocales
                        .map<DropdownMenuItem<Locale>>((Locale locale) {
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
            title: S.of(context).pages_settings_tag_general_update,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_general_update_auto_check,
                ),
                value: settingsProvider.autoCheckUpdate,
                onChanged: (bool value) {
                  settingsProvider.setAutoCheckUpdate(value);
                  if (value) {
                    UpdateUtil.checkAndShow(context, isManualCheck: false);
                  }
                },
              ),
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_general_update_check_beta,
                ),
                value: settingsProvider.checkPreRelease,
                onChanged: (bool value) {
                  settingsProvider.setCheckPreRelease(value);
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_general_initial,
            children: [
              ListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_general_initial_reset_settings,
                ),
                trailing: const Icon(Icons.restore, size: 20),
                onTap: () => _showResetDefaultsDialog(
                  context,
                  settingsProvider,
                  playerProvider,
                  securityProvider,
                ),
              ),
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_general_initial_reset_app,
                ),
                trailing: const Icon(Icons.delete_forever, size: 20),
                onTap: () => _showResetAppDialog(
                  context,
                  settingsProvider,
                  playerProvider,
                  securityProvider,
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_general_development,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_general_development_debug,
                ),
                value: settingsProvider.debugMode,
                onChanged: (bool value) {
                  if (value) {
                    _showDebugModeWarningDialog(context, settingsProvider);
                  } else {
                    settingsProvider.setDebugMode(false);
                  }
                },
              ),
              if (settingsProvider.debugMode) ...[
                ListTile(
                  title: Text(
                    S
                        .of(context)
                        .pages_settings_tag_general_development_log_level,
                  ),
                  trailing: DropdownButton<LogLevel>(
                    value: settingsProvider.logLevel,
                    underline: const SizedBox(),
                    alignment: Alignment.centerRight,
                    onChanged: (LogLevel? newValue) {
                      if (newValue != null) {
                        settingsProvider.setLogLevel(newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: LogLevel.verbose,
                        child: Text(
                          S
                              .of(context)
                              .pages_settings_tag_general_development_log_level_verbose,
                        ),
                      ),
                      DropdownMenuItem(
                        value: LogLevel.debug,
                        child: Text(
                          S
                              .of(context)
                              .pages_settings_tag_general_development_log_level_debug,
                        ),
                      ),
                      DropdownMenuItem(
                        value: LogLevel.info,
                        child: Text(
                          S
                              .of(context)
                              .pages_settings_tag_general_development_log_level_info,
                        ),
                      ),
                      DropdownMenuItem(
                        value: LogLevel.warning,
                        child: Text(
                          S
                              .of(context)
                              .pages_settings_tag_general_development_log_level_warning,
                        ),
                      ),
                      DropdownMenuItem(
                        value: LogLevel.error,
                        child: Text(
                          S
                              .of(context)
                              .pages_settings_tag_general_development_log_level_error,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: Text(
                    S
                        .of(context)
                        .pages_settings_tag_general_development_log_export,
                  ),
                  trailing: const Icon(Icons.share, size: 20),
                  onTap: () async {
                    await LogService.instance.exportLogs();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDebugModeWarningDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          S
              .of(context)
              .pages_settings_tag_general_development_log_level_warning,
        ),
        // 警告内容
        content: Text(
          S.of(context).pages_settings_tag_general_development_enable_alert,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              settingsProvider.setDebugMode(true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    S
                        .of(context)
                        .pages_settings_tag_general_development_enabled_toast,
                  ),
                ),
              );
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  void _showResetDefaultsDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
    PlayerProvider playerProvider,
    SecurityProvider securityProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S
              .of(context)
              .pages_settings_tag_general_initial_reset_settings_alert_message,
        ),
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
                SnackBar(content: Text(S.of(context).common_succeed)),
              );
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  void _showResetAppDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
    PlayerProvider playerProvider,
    SecurityProvider securityProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S
              .of(context)
              .pages_settings_tag_general_initial_reset_app_alert_message,
        ),
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
                Restart.restartApp();
              }
            },
            child: Text(S.of(context).common_confirm),
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
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
