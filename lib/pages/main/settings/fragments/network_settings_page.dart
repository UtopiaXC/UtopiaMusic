import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class NetworkSettingsPage extends StatelessWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('网络')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '接口请求',
            children: [
              ListTile(
                title: const Text('请求重试次数'),
                subtitle: const Text('网络错误或无法解析时重试的次数'),
                trailing: DropdownButton<int>(
                  value: settingsProvider.maxRetries,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setMaxRetries(newValue);
                    }
                  },
                  items:
                  [0, 1, 2, 3, 4, 5].map<DropdownMenuItem<int>>((
                      int value,
                      ) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                title: const Text('延迟请求'),
                subtitle: const Text('降低风控风险'),
                trailing: DropdownButton<int>(
                  value: settingsProvider.requestDelay,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setRequestDelay(newValue);
                    }
                  },
                  items:
                  [0, 10, 50, 100, 200, 300, 400, 500].map<
                      DropdownMenuItem<int>
                  >((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value ms'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: '历史记录',
            children: [
              SwitchListTile(
                title: const Text('上报播放记录'),
                subtitle: const Text('将播放历史同步到B站'),
                value: settingsProvider.enableHistoryReport,
                onChanged: (bool value) {
                  settingsProvider.setEnableHistoryReport(value);
                },
              ),
              if (settingsProvider.enableHistoryReport)
                ListTile(
                  title: const Text('上报延迟'),
                  subtitle: Text(
                    '为防止出现大量无效请求，在播放开始后的${settingsProvider.historyReportDelay}秒才会开始上报记录',
                  ),
                  trailing: DropdownButton<int>(
                    value: settingsProvider.historyReportDelay,
                    underline: const SizedBox(),
                    alignment: Alignment.centerRight,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        settingsProvider.setHistoryReportDelay(newValue);
                      }
                    },
                    items:
                    [0, 1, 3, 5, 10].map<DropdownMenuItem<int>>((
                        int value,
                        ) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value == 0 ? '禁用' : '$value 秒'),
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