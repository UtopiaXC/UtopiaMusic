import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).pages_settings_tag_security)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_security_lock,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_security_biometrics,
                ),
                subtitle: isWindows
                    ? Text(
                        S
                            .of(context)
                            .pages_settings_tag_security_biometrics_windows_inapplicable,
                      )
                    : null,
                value: securityProvider.biometricEnabled,
                onChanged: isWindows
                    ? null
                    : (value) {
                        securityProvider.setBiometricEnabled(value);
                      },
              ),
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_security_hide_in_task,
                ),
                value: securityProvider.privacyScreenEnabled,
                onChanged: securityProvider.biometricEnabled
                    ? null
                    : (value) {
                        securityProvider.setPrivacyScreenEnabled(value);
                      },
              ),
              if (securityProvider.biometricEnabled)
                ListTile(
                  title: Text(
                    S.of(context).pages_settings_tag_security_lock_delay,
                  ),
                  subtitle: Text(
                    _getLockDelayText(
                      context,
                      securityProvider.lockDelayOption,
                      securityProvider.customLockDelayMinutes,
                    ),
                  ),
                  trailing: DropdownButton<LockDelayOption>(
                    value: securityProvider.lockDelayOption,
                    underline: const SizedBox(),
                    alignment: Alignment.centerRight,
                    onChanged: (LockDelayOption? newValue) {
                      if (newValue != null) {
                        if (newValue == LockDelayOption.custom) {
                          _showCustomDelayDialog(context, securityProvider);
                        } else {
                          securityProvider.setLockDelayOption(newValue);
                        }
                      }
                    },
                    items: LockDelayOption.values
                        .map<DropdownMenuItem<LockDelayOption>>((
                          LockDelayOption value,
                        ) {
                          return DropdownMenuItem<LockDelayOption>(
                            value: value,
                            child: Text(
                              _getLockDelayText(
                                context,
                                value,
                                securityProvider.customLockDelayMinutes,
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLockDelayText(
    BuildContext context,
    LockDelayOption option,
    int customMinutes,
  ) {
    switch (option) {
      case LockDelayOption.immediate:
        return S.of(context).pages_settings_tag_security_lock_delay_everytime;
      case LockDelayOption.oneMinute:
        return '1 ${S.of(context).time_minute}';
      case LockDelayOption.threeMinutes:
        return '3 ${S.of(context).time_minute}';
      case LockDelayOption.fiveMinutes:
        return '5 ${S.of(context).time_minute}';
      case LockDelayOption.tenMinutes:
        return '10 ${S.of(context).time_minute}';
      case LockDelayOption.thirtyMinutes:
        return '30 ${S.of(context).time_minute}';
      case LockDelayOption.custom:
        return '${S.of(context).common_custom} ($customMinutes ${S.of(context).time_minute})';
    }
  }

  void _showCustomDelayDialog(BuildContext context, SecurityProvider provider) {
    final TextEditingController controller = TextEditingController(
      text: provider.customLockDelayMinutes.toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).common_custom),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: S
                  .of(context)
                  .pages_settings_tag_security_lock_delay_custom_input,
              border: OutlineInputBorder(),
              suffixText: S.of(context).time_minute,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () {
                final int? minutes = int.tryParse(controller.text);
                if (minutes != null && minutes >= 0) {
                  provider.setCustomLockDelay(minutes);
                  provider.setLockDelayOption(LockDelayOption.custom);
                  Navigator.pop(context);
                }
              },
              child: Text(S.of(context).common_confirm),
            ),
          ],
        );
      },
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
