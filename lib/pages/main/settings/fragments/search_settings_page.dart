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
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '搜索历史',
            children: [
              SwitchListTile(
                title: const Text('本地搜索历史'),
                value: settingsProvider.saveSearchHistory,
                onChanged: (bool value) {
                  settingsProvider.setSaveSearchHistory(value);
                },
              ),
              ListTile(
                title: const Text('历史记录保存上限'),
                subtitle: Text('当前上限: ${settingsProvider.searchHistoryLimit} 条'),
                enabled: settingsProvider.saveSearchHistory,
                trailing: const Icon(Icons.edit, size: 20), // 加个小图标提示可编辑
                onTap: () {
                  _showLimitDialog(context, settingsProvider);
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: '联想推荐',
            children: [
              SwitchListTile(
                title: const Text('显示搜索推荐'),
                subtitle: const Text('输入时显示联想词'),
                value: settingsProvider.showSearchSuggest,
                onChanged: (bool value) {
                  settingsProvider.setShowSearchSuggest(value);
                },
              ),
            ],
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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '上限数量',
              hintText: '请输入数字',
              border: OutlineInputBorder(),
              suffixText: '条',
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

// 复用的分组组件
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