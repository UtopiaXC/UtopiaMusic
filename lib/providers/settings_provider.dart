import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/log.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';
  static const String _startPageKey = 'start_page';
  static const String _saveSearchHistoryKey = 'save_search_history';
  static const String _searchHistoryLimitKey = 'search_history_limit';
  //TODO: NEEDS TO REFACTOR FOR RETRY AND DELAY
  static const String _maxRetriesKey = 'max_retries';
  static const String maxRetriesKey = _maxRetriesKey;
  static const String _requestDelayKey = 'request_delay';
  // static const String requestDelayKey = _requestDelayKey;

  static const String _localeKey = 'locale';
  static const String _cacheLimitKey = 'cache_limit';
  static const String _autoCheckUpdateKey = 'auto_check_update';
  static const String _checkPreReleaseKey = 'check_pre_release';
  static const String _ignoredVersionKey = 'ignored_version';
  static const String _enableCommentsKey = 'enable_comments';
  static const String _defaultAudioQualityKey = 'default_audio_quality';
  static const String _defaultDownloadQualityKey = 'default_download_quality';
  static const String _showSearchSuggestKey = 'show_search_suggest';
  static const String _enableHistoryReportKey = 'enable_history_report';
  static const String _historyReportDelayKey = 'history_report_delay';
  static const String _playerBackgroundModeKey = 'player_background_mode_v2';
  static const String _debugModeKey = 'debug_mode';
  static const String _logLevelKey = 'log_level';

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
  int _defaultAudioQuality = 30280;
  int _defaultDownloadQuality = 30280;
  bool _showSearchSuggest = true;
  bool _enableHistoryReport = false;
  int _historyReportDelay = 3;
  String _playerBackgroundMode = 'gradient';
  bool _debugMode = false;
  LogLevel _logLevel = LogLevel.warning;

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

  int get defaultAudioQuality => _defaultAudioQuality;

  int get defaultDownloadQuality => _defaultDownloadQuality;

  bool get showSearchSuggest => _showSearchSuggest;

  bool get enableHistoryReport => _enableHistoryReport;

  int get historyReportDelay => _historyReportDelay;

  String get playerBackgroundMode => _playerBackgroundMode;

  bool get debugMode => _debugMode;

  LogLevel get logLevel => _logLevel;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex =
        prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];

    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    _startPageIndex = prefs.getInt(_startPageKey) ?? 0;
    _saveSearchHistory = prefs.getBool(_saveSearchHistoryKey) ?? true;
    _searchHistoryLimit = prefs.getInt(_searchHistoryLimitKey) ?? 10;
    _maxRetries = prefs.getInt(_maxRetriesKey) ?? 2;
    _requestDelay = prefs.getInt(_requestDelayKey) ?? 50;

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
    _defaultAudioQuality = prefs.getInt(_defaultAudioQualityKey) ?? 30280;
    AudioPlayerService().setPreferredQuality(_defaultAudioQuality);
    _isSettingsLoaded = true;
    _defaultDownloadQuality = prefs.getInt(_defaultDownloadQualityKey) ?? 30280;
    _showSearchSuggest = prefs.getBool(_showSearchSuggestKey) ?? true;
    _enableHistoryReport = prefs.getBool(_enableHistoryReportKey) ?? false;
    _historyReportDelay = prefs.getInt(_historyReportDelayKey) ?? 3;
    String? mode = prefs.getString(_playerBackgroundModeKey);
    if (mode == null) {
      _playerBackgroundMode = 'gradient';
    } else {
      _playerBackgroundMode = mode;
    }

    _debugMode = prefs.getBool(_debugModeKey) ?? false;
    final logLevelIndex = prefs.getInt(_logLevelKey) ?? LogLevel.warning.index;
    if (logLevelIndex >= 0 && logLevelIndex < LogLevel.values.length) {
      _logLevel = LogLevel.values[logLevelIndex];
    } else {
      _logLevel = LogLevel.warning;
    }
    Log.setLevel(_logLevel);

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
    await prefs.setInt(_maxRetriesKey, retries);
  }

  Future<void> setRequestDelay(int delay) async {
    _requestDelay = delay;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_requestDelayKey, delay);
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

  Future<void> setDefaultAudioQuality(int quality) async {
    _defaultAudioQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultAudioQualityKey, quality);
    await AudioPlayerService().switchQuality(quality);
    notifyListeners();
  }

  Future<void> setDefaultDownloadQuality(int quality) async {
    _defaultDownloadQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultDownloadQualityKey, quality);
    notifyListeners();
  }

  Future<void> setShowSearchSuggest(bool value) async {
    _showSearchSuggest = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSearchSuggestKey, value);
  }

  Future<void> setEnableHistoryReport(bool value) async {
    _enableHistoryReport = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableHistoryReportKey, value);
  }

  Future<void> setHistoryReportDelay(int value) async {
    _historyReportDelay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_historyReportDelayKey, value);
  }

  Future<void> setPlayerBackgroundMode(String value) async {
    _playerBackgroundMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerBackgroundModeKey, value);
  }

  Future<void> setDebugMode(bool value) async {
    _debugMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugModeKey, value);
  }

  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    Log.setLevel(level);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logLevelKey, level.index);
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
    _defaultAudioQuality = 30280;
    _defaultDownloadQuality = 30280;
    _showSearchSuggest = true;
    _enableHistoryReport = false;
    _historyReportDelay = 3;
    _playerBackgroundMode = 'gradient';
    _debugMode = false;
    _logLevel = LogLevel.warning;
    Log.setLevel(_logLevel);
    AudioPlayerService().setPreferredQuality(_defaultAudioQuality);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeModeKey);
    await prefs.remove(_seedColorKey);
    await prefs.remove(_startPageKey);
    await prefs.remove(_saveSearchHistoryKey);
    await prefs.remove(_searchHistoryLimitKey);
    await prefs.remove(_maxRetriesKey);
    await prefs.remove(_requestDelayKey);
    await prefs.remove(_localeKey);
    await prefs.remove(_cacheLimitKey);
    await prefs.remove(_autoCheckUpdateKey);
    await prefs.remove(_checkPreReleaseKey);
    await prefs.remove(_ignoredVersionKey);
    await prefs.remove(_enableCommentsKey);
    await prefs.remove(_defaultAudioQualityKey);
    await prefs.remove(_defaultDownloadQualityKey);
    await prefs.remove(_showSearchSuggestKey);
    await prefs.remove(_enableHistoryReportKey);
    await prefs.remove(_historyReportDelayKey);
    await prefs.remove(_playerBackgroundModeKey);
    await prefs.remove(_debugModeKey);
    await prefs.remove(_logLevelKey);
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
    _autoSkipInvalid = true;
    _enableComments = true;
    _defaultAudioQuality = 30280;
    _defaultDownloadQuality = 30280;
    _showSearchSuggest = true;
    _enableHistoryReport = false;
    _historyReportDelay = 3;
    _playerBackgroundMode = 'gradient';
    _debugMode = false;
    _logLevel = LogLevel.warning;
    notifyListeners();
    try {
      final audioService = AudioPlayerService();
      await audioService.resetState();
    } catch (e) {
      print("Error stopping player: $e");
    }
    try {
      final downloadManager = DownloadManager();
      await downloadManager.setMaxConcurrentDownloads(0);
      await Future.delayed(const Duration(milliseconds: 200));
      await downloadManager.clearAllCache();
      await downloadManager.deleteAllDownloads();
    } catch (e) {
      print("Error clearing download manager: $e");
    }
    try {
      await DatabaseService().deleteDatabaseFile();
    } catch (e) {
      print("Error deleting DB: $e");
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _nukeFileSystem();
  }

  Future<void> _nukeFileSystem() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await _deleteDirectoryContents(tempDir);
      }
      final appDocDir = await getApplicationDocumentsDirectory();
      if (await appDocDir.exists()) {
        final musicDlDir = Directory('${appDocDir.path}/MusicDownload');
        if (await musicDlDir.exists()) {
          await musicDlDir.delete(recursive: true);
        }
      }
      final supportDir = await getApplicationSupportDirectory();
      if (await supportDir.exists()) {
        await _deleteDirectoryContents(supportDir);
      }
    } catch (e) {
      print("Error nuking file system: $e");
    }
  }

  Future<void> _deleteDirectoryContents(Directory dir) async {
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (e) {
          print("Skipping file ${entity.path}: $e");
        }
      }
    } catch (e) {
      print("Error listing directory ${dir.path}: $e");
    }
  }
}
