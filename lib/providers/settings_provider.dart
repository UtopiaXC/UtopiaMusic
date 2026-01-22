import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';
  static const String _startPageKey = 'start_page';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.deepPurple;
  int _startPageIndex = 0;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  int get startPageIndex => _startPageIndex;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme Mode
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];

    // Load Seed Color
    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }

    // Load Start Page
    _startPageIndex = prefs.getInt(_startPageKey) ?? 0;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.value);
  }

  Future<void> setStartPageIndex(int index) async {
    _startPageIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startPageKey, index);
  }
}
