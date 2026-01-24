import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';
  static const String _startPageKey = 'start_page';
  static const String _saveSearchHistoryKey = 'save_search_history';
  static const String _searchHistoryLimitKey = 'search_history_limit';
  static const String maxRetriesKey = 'max_retries';
  static const String requestDelayKey = 'request_delay';
  static const String _localeKey = 'locale';
  static const String _cacheLimitKey = 'cache_limit';
  static const String _autoCheckUpdateKey = 'auto_check_update';
  static const String _checkPreReleaseKey = 'check_pre_release';
  static const String _ignoredVersionKey = 'ignored_version';
  static const String _enableCommentsKey = 'enable_comments';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.deepPurple;
  int _startPageIndex = 0;
  bool _saveSearchHistory = true;
  int _searchHistoryLimit = 10;
  int _maxRetries = 2;
  int _requestDelay = 50;
  Locale? _locale;
  int _cacheLimit = 200;
  bool _autoCheckUpdate = true;
  bool _checkPreRelease = false;
  String? _ignoredVersion;
  bool _isSettingsLoaded = false;
  bool _autoSkipInvalid = true;
  bool _enableComments = true;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  int get startPageIndex => _startPageIndex;
  bool get saveSearchHistory => _saveSearchHistory;
  int get searchHistoryLimit => _searchHistoryLimit;
  int get maxRetries => _maxRetries;
  int get requestDelay => _requestDelay;
  Locale? get locale => _locale;
  int get cacheLimit => _cacheLimit;
  bool get autoCheckUpdate => _autoCheckUpdate;
  bool get checkPreRelease => _checkPreRelease;
  String? get ignoredVersion => _ignoredVersion;
  bool get isSettingsLoaded => _isSettingsLoaded;
  bool get autoSkipInvalid => _autoSkipInvalid;
  bool get enableComments => _enableComments;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];

    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    _startPageIndex = prefs.getInt(_startPageKey) ?? 0;
    _saveSearchHistory = prefs.getBool(_saveSearchHistoryKey) ?? true;
    _searchHistoryLimit = prefs.getInt(_searchHistoryLimitKey) ?? 10;
    _maxRetries = prefs.getInt(maxRetriesKey) ?? 2;
    _requestDelay = prefs.getInt(requestDelayKey) ?? 50;

    final localeCode = prefs.getString(_localeKey);
    if (localeCode != null) {
      _locale = Locale(localeCode);
    } else {
      _locale = null;
    }
    _cacheLimit = prefs.getInt(_cacheLimitKey) ?? 200;
    _autoCheckUpdate = prefs.getBool(_autoCheckUpdateKey) ?? true;
    _checkPreRelease = prefs.getBool(_checkPreReleaseKey) ?? false;
    _ignoredVersion = prefs.getString(_ignoredVersionKey);
    _enableComments = prefs.getBool(_enableCommentsKey) ?? true;
    _isSettingsLoaded = true;

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

  Future<void> setSaveSearchHistory(bool value) async {
    _saveSearchHistory = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveSearchHistoryKey, value);
  }

  Future<void> setSearchHistoryLimit(int limit) async {
    _searchHistoryLimit = limit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_searchHistoryLimitKey, limit);
  }

  Future<void> setMaxRetries(int retries) async {
    _maxRetries = retries;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(maxRetriesKey, retries);
  }

  Future<void> setRequestDelay(int delay) async {
    _requestDelay = delay;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(requestDelayKey, delay);
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString(_localeKey, locale.languageCode);
    } else {
      await prefs.remove(_localeKey);
    }
  }

  Future<void> setCacheLimit(int limit) async {
    _cacheLimit = limit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cacheLimitKey, limit);
  }

  Future<void> setAutoCheckUpdate(bool value) async {
    _autoCheckUpdate = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckUpdateKey, value);
  }

  Future<void> setCheckPreRelease(bool value) async {
    _checkPreRelease = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checkPreReleaseKey, value);
  }

  Future<void> setIgnoredVersion(String? version) async {
    _ignoredVersion = version;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (version != null) {
      await prefs.setString(_ignoredVersionKey, version);
    } else {
      await prefs.remove(_ignoredVersionKey);
    }
  }

  Future<void> setEnableComments(bool value) async {
    _enableComments = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableCommentsKey, value);
  }


  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _seedColor = Colors.deepPurple;
    _startPageIndex = 0;
    _saveSearchHistory = true;
    _searchHistoryLimit = 10;
    _maxRetries = 2;
    _requestDelay = 50;
    _locale = null;
    _cacheLimit = 200;
    _autoCheckUpdate = true;
    _checkPreRelease = false;
    _ignoredVersion = null;
    _autoSkipInvalid = true;
    _enableComments = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeModeKey);
    await prefs.remove(_seedColorKey);
    await prefs.remove(_startPageKey);
    await prefs.remove(_saveSearchHistoryKey);
    await prefs.remove(_searchHistoryLimitKey);
    await prefs.remove(maxRetriesKey);
    await prefs.remove(requestDelayKey);
    await prefs.remove(_localeKey);
    await prefs.remove(_cacheLimitKey);
    await prefs.remove(_autoCheckUpdateKey);
    await prefs.remove(_checkPreReleaseKey);
    await prefs.remove(_ignoredVersionKey);
    await prefs.remove(_enableCommentsKey);
  }

  Future<void> resetApp() async {
    _themeMode = ThemeMode.system;
    _seedColor = Colors.deepPurple;
    _startPageIndex = 0;
    _saveSearchHistory = true;
    _searchHistoryLimit = 10;
    _maxRetries = 2;
    _requestDelay = 50;
    _locale = null;
    _cacheLimit = 200;
    _autoCheckUpdate = true;
    _checkPreRelease = false;
    _ignoredVersion = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final dbService = DatabaseService();
    await dbService.clearPlaylist();
  }
}
