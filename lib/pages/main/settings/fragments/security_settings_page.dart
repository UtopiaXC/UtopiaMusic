import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/security_provider.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: AppBar(title: const Text('安全')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '锁定',
            children: [
              SwitchListTile(
                title: const Text('启用生物识别'),
                subtitle: isWindows ? const Text('Windows平台不适用') : null,
                value: securityProvider.biometricEnabled,
                onChanged: isWindows
                    ? null
                    : (value) {
                  securityProvider.setBiometricEnabled(value);
                },
              ),
              SwitchListTile(
                title: const Text('多任务中模糊'),
                value: securityProvider.privacyScreenEnabled,
                onChanged: securityProvider.biometricEnabled
                    ? null
                    : (value) {
                  securityProvider.setPrivacyScreenEnabled(value);
                },
              ),
              if (securityProvider.biometricEnabled)
                ListTile(
                  title: const Text('锁定延迟'),
                  subtitle: Text(
                    _getLockDelayText(
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
                    items: LockDelayOption.values.map<
                        DropdownMenuItem<LockDelayOption>
                    >((LockDelayOption value) {
                      return DropdownMenuItem<LockDelayOption>(
                        value: value,
                        child: Text(
                          _getLockDelayText(
                            value,
                            securityProvider.customLockDelayMinutes,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLockDelayText(LockDelayOption option, int customMinutes) {
    switch (option) {
      case LockDelayOption.immediate:
        return '每次切换';
      case LockDelayOption.oneMinute:
        return '1 分钟';
      case LockDelayOption.threeMinutes:
        return '3 分钟';
      case LockDelayOption.fiveMinutes:
        return '5 分钟';
      case LockDelayOption.tenMinutes:
        return '10 分钟';
      case LockDelayOption.thirtyMinutes:
        return '30 分钟';
      case LockDelayOption.custom:
        return '自定义 ($customMinutes 分钟)';
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
          title: const Text('自定义锁定延迟 (分钟)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入分钟数',
              border: OutlineInputBorder(),
              suffixText: '分钟',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
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
              child: const Text('确定'),
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
                color: Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}