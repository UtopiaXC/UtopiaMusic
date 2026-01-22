import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        children: [
          _buildThemeModeSection(context, settingsProvider),
          const Divider(),
          _buildColorSection(context, settingsProvider),
          const Divider(),
          _buildStartPageSection(context, settingsProvider),
        ],
      ),
    );
  }

  Widget _buildThemeModeSection(BuildContext context, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '深色模式',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('跟随系统'),
          value: ThemeMode.system,
          groupValue: provider.themeMode,
          onChanged: (value) {
            if (value != null) provider.setThemeMode(value);
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('始终深色'),
          value: ThemeMode.dark,
          groupValue: provider.themeMode,
          onChanged: (value) {
            if (value != null) provider.setThemeMode(value);
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('始终浅色'),
          value: ThemeMode.light,
          groupValue: provider.themeMode,
          onChanged: (value) {
            if (value != null) provider.setThemeMode(value);
          },
        ),
      ],
    );
  }

  Widget _buildColorSection(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('主题颜色'),
      subtitle: const Text('选择应用的主色调'),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context, provider),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: provider.seedColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider provider) {
    final List<Color> colors = [
      Colors.deepPurple,
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.pink,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () {
                  provider.setSeedColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: provider.seedColor.value == color.value
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartPageSection(BuildContext context, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '启动页',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        RadioListTile<int>(
          title: const Text('首页'),
          value: 0,
          groupValue: provider.startPageIndex,
          onChanged: (value) {
            if (value != null) provider.setStartPageIndex(value);
          },
        ),
        RadioListTile<int>(
          title: const Text('曲库'),
          value: 1,
          groupValue: provider.startPageIndex,
          onChanged: (value) {
            if (value != null) provider.setStartPageIndex(value);
          },
        ),
      ],
    );
  }
}
