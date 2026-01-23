import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
          _buildThemeModeItem(context, settingsProvider),
          _buildColorItem(context, settingsProvider),
          _buildStartPageItem(context, settingsProvider),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('深色模式'),
      trailing: DropdownButton<ThemeMode>(
        value: provider.themeMode,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('跟随系统'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('始终浅色'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('始终深色'),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setThemeMode(value);
        },
      ),
    );
  }

  Widget _buildColorItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('主题颜色'),
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
    Color pickerColor = provider.seedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2.0),
              topRight: Radius.circular(2.0),
            ),
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.setSeedColor(pickerColor);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartPageItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('启动页'),
      trailing: DropdownButton<int>(
        value: provider.startPageIndex,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(
            value: 0,
            child: Text('首页'),
          ),
          DropdownMenuItem(
            value: 1,
            child: Text('曲库'),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setStartPageIndex(value);
        },
      ),
    );
  }
}
