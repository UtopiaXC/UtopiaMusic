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
        children: [
          ListTile(
            title: const Text('请求重试次数'),
            subtitle: const Text('网络错误或无法解析时重试的次数'),
            trailing: DropdownButton<int>(
              value: settingsProvider.maxRetries,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  settingsProvider.setMaxRetries(newValue);
                }
              },
              items: [0, 1, 2, 3, 4, 5].map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('延迟请求'),
            subtitle: const Text('为高频请求的接口添加一个延迟防止被风控'),
            trailing: DropdownButton<int>(
              value: settingsProvider.requestDelay,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  settingsProvider.setRequestDelay(newValue);
                }
              },
              items: [0, 10, 50, 100, 200, 300, 400, 500]
                  .map<DropdownMenuItem<int>>((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value ms'),
                    );
                  })
                  .toList(),
            ),
          ),
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
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    settingsProvider.setHistoryReportDelay(newValue);
                  }
                },
                items: [0, 1, 3, 5, 10].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value == 0 ? '禁用' : '$value 秒'),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
