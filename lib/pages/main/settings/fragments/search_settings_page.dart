import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class SearchSettingsPage extends StatelessWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('保存本地搜索历史'),
            subtitle: const Text('关闭后将不再记录新的搜索历史，且不显示历史记录'),
            value: settingsProvider.saveSearchHistory,
            onChanged: (bool value) {
              settingsProvider.setSaveSearchHistory(value);
            },
          ),
          ListTile(
            title: const Text('历史记录保存上限'),
            subtitle: Text('当前上限: ${settingsProvider.searchHistoryLimit} 条'),
            enabled: settingsProvider.saveSearchHistory,
            onTap: () {
              _showLimitDialog(context, settingsProvider);
            },
          ),
        ],
      ),
    );
  }

  void _showLimitDialog(BuildContext context, SettingsProvider provider) {
    final TextEditingController controller = TextEditingController(
      text: provider.searchHistoryLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置历史记录上限'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '上限数量',
              hintText: '请输入数字',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final int? limit = int.tryParse(controller.text);
                if (limit != null && limit > 0) {
                  provider.setSearchHistoryLimit(limit);
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
