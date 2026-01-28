import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

class RawLog extends TalkerLog {
  RawLog(super.message, {super.logLevel});

  @override
  String generateTextMessage({TimeFormat timeFormat = TimeFormat.timeAndSeconds}) {
    return message?? '';
  }
}

class LogFormatter {
  LogFormatter._();

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _three(int n) => n.toString().padLeft(3, '0');

  static String formatDateTime(DateTime dt) {
    return '${dt.year}/${_two(dt.month)}/${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}.'
        '${_three(dt.millisecond)}';
  }

  static String format({
    required String message,
    required LogLevel level,
    required DateTime time,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final timeStr = formatDateTime(time);
    final levelStr = level.name.toUpperCase();
    final baseLog = "[$timeStr] [$levelStr] $message";

    if (exception != null || stackTrace != null) {
      final buffer = StringBuffer(baseLog);
      if (exception != null) {
        buffer.write("\nError: $exception");
      }
      if (stackTrace != null) {
        buffer.write("\nStack: $stackTrace");
      }
      return buffer.toString();
    }

    return baseLog;
  }
}

class ConsoleLogFormatter extends LoggerFormatter {
  @override
  String fmt(LogDetails details, TalkerLoggerSettings settings) {
    return LogFormatter.format(
      message: details.message,
      level: details.level,
      time: DateTime.now(),
    );
  }
}

class FileLogObserver extends TalkerObserver {
  final void Function(String record) onWrite;

  FileLogObserver({required this.onWrite});

  void _write(TalkerData data) {
    final formatted = LogFormatter.format(
      message: data.message ?? '',
      level: data.logLevel ?? LogLevel.debug,
      time: data.time,
      exception: data.exception,
      stackTrace: data.stackTrace,
    );
    onWrite(formatted);
  }

  @override
  void onLog(TalkerData log) => _write(log);

  @override
  void onError(TalkerError err) => _write(err);

  @override
  void onException(TalkerException err) => _write(err);
}

class Log {
  Log._();

  static LogLevel _currentLevel = LogLevel.warning;
  static const String _defaultTag = 'DEFAULT';
  static final int _pid = pid;

  static (String, dynamic) _parseArgs(dynamic classTag, [dynamic arg2]) {
    if (arg2 != null && classTag is String) {
      return (classTag, arg2);
    } else {
      return (_defaultTag, classTag);
    }
  }

  static String _formatMsg(String tag, dynamic msg) {
    return '[PID:$_pid] [UtopiaMusic] [$tag] $msg';
  }

  static void _dispatchLog(String message, LogLevel level) {
    LogService.instance.talker.logTyped(
      RawLog(message, logLevel: level),
    );
  }

  static void d(dynamic classTag, [dynamic arg2]) {
    if (_currentLevel == LogLevel.error ||
        _currentLevel == LogLevel.info ||
        _currentLevel == LogLevel.warning) {
      return;
    }
    if (LogLevel.debug.index < _currentLevel.index) return;

    final (tag, msg) = _parseArgs(classTag, arg2);
    _dispatchLog(_formatMsg(tag, msg), LogLevel.debug);
  }

  static void i(dynamic classTag, [dynamic arg2]) {
    if (_currentLevel == LogLevel.error || _currentLevel == LogLevel.warning) {
      return;
    }

    final (tag, msg) = _parseArgs(classTag, arg2);
    _dispatchLog(_formatMsg(tag, msg), LogLevel.info);
  }

  static void w(dynamic classTag, [dynamic arg2]) {
    if (_currentLevel == LogLevel.error) {
      return;
    }

    final (tag, msg) = _parseArgs(classTag, arg2);
    _dispatchLog(_formatMsg(tag, msg), LogLevel.warning);
  }

  static void v(dynamic classTag, [dynamic arg2]) {
    if (_currentLevel == LogLevel.error ||
        _currentLevel == LogLevel.info ||
        _currentLevel == LogLevel.debug ||
        _currentLevel == LogLevel.warning) {
      return;
    }

    final (tag, msg) = _parseArgs(classTag, arg2);
    _dispatchLog(_formatMsg(tag, msg), LogLevel.verbose);
  }

  static void e(
      dynamic classTag, [
        dynamic arg2,
        Object? error,
        StackTrace? stackTrace,
      ]) {
    final (tag, msg) = _parseArgs(classTag, arg2);
    final formattedMsg = _formatMsg(tag, msg);

    if (error != null) {
      LogService.instance.talker.handle(error, stackTrace, formattedMsg);
    } else {
      LogService.instance.talker.error(formattedMsg);
    }
  }

  static void setLevel(LogLevel level) {
    _currentLevel = level;
    _dispatchLog('Log Level changed to: ${level.name}', LogLevel.info);
  }
}

class LogService {
  LogService._();

  static final LogService instance = LogService._();
  late Talker _talker;

  Talker get talker => _talker;
  IOSink? _logSink;
  File? _currentLogFile;
  int _currentFileSize = 0;
  bool _isRotating = false;
  static const int _maxFileSize = 1024 * 1024;

  Future<void> init() async {
    await _initLogFile();
    final prefs = await SharedPreferences.getInstance();
    final isDebugMode = prefs.getBool('debug_mode') ?? kDebugMode;
    final logLevelIndex = prefs.getInt('log_level') ?? LogLevel.warning.index;

    _talker = TalkerFlutter.init(
      observer: FileLogObserver(onWrite: _writeLogToDisk),
      settings: TalkerSettings(
        enabled: true,
        useHistory: true,
        maxHistoryItems: 1000,
        useConsoleLogs: isDebugMode || kDebugMode,
      ),
      logger: TalkerLogger(
        output: debugPrint,
        settings: TalkerLoggerSettings(enableColors: true),
        formatter: ConsoleLogFormatter(),
      ),
    );

    if (logLevelIndex >= 0 && logLevelIndex < LogLevel.values.length) {
      Log.setLevel(LogLevel.values[logLevelIndex]);
    } else {
      Log.setLevel(LogLevel.warning);
    }

    FlutterError.onError = (details) {
      Log.e(
        'FlutterError',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      _flushSink();
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('AsyncError', error.toString(), error, stack);
      _flushSink();
      return true;
    };
  }

  void _writeLogToDisk(String logRecord) {
    if (_logSink == null || _isRotating) return;

    try {
      final List<int> bytes = utf8.encode('$logRecord\n');
      _logSink!.add(bytes);
      _currentFileSize += bytes.length;
      if (_currentFileSize > _maxFileSize) {
        _rotateLogFile();
      }
    } catch (e) {
      debugPrint("Write log failed: $e");
    }
  }

  Future<void> _initLogFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final latestLog = File('${logDir.path}/latest.log');
      final previousLog = File('${logDir.path}/previous.log');
      if (await latestLog.exists()) {
        if (await previousLog.exists()) {
          await previousLog.delete();
        }
        await latestLog.rename(previousLog.path);
      }
      _currentLogFile = File('${logDir.path}/latest.log');
      _currentFileSize = 0;
      _logSink = _currentLogFile!.openWrite(mode: FileMode.write);

      final startMsg = '=== Session Start: ${DateTime.now()} | Platform: ${defaultTargetPlatform.name} ===\n';
      final bytes = utf8.encode(startMsg);
      _logSink!.add(bytes);
      _currentFileSize += bytes.length;
    } catch (e) {
      debugPrint("Init log file failed: $e");
    }
  }

  Future<void> _rotateLogFile() async {
    if (_isRotating) return;
    _isRotating = true;

    try {
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;

      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      final latestLog = File('${logDir.path}/latest.log');
      final previousLog = File('${logDir.path}/previous.log');
      if (await previousLog.exists()) {
        await previousLog.delete();
      }

      if (await latestLog.exists()) {
        await latestLog.rename(previousLog.path);
      }

      _currentLogFile = File('${logDir.path}/latest.log');
      _logSink = _currentLogFile!.openWrite(mode: FileMode.write);
      _currentFileSize = 0;

      const header = '\n=== Log Rotated (Previous file exceeded 1MB) ===\n';
      final bytes = utf8.encode(header);
      _logSink!.add(bytes);
      _currentFileSize += bytes.length;
    } catch (e) {
      debugPrint("Rotate log failed: $e");
    } finally {
      _isRotating = false;
    }
  }

  bool _flushSink() {
    try {
      _logSink?.flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> exportLogs() async {
    try {
      await _flushSink();

      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');

      final latestLog = File('${logDir.path}/latest.log');
      final previousLog = File('${logDir.path}/previous.log');

      List<XFile> filesToShare = [];

      if (await latestLog.exists()) filesToShare.add(XFile(latestLog.path));
      if (await previousLog.exists()) filesToShare.add(XFile(previousLog.path));

      if (filesToShare.isEmpty) {
        _talker.warning('No log files found');
        return;
      }

      await SharePlus.instance.share(
        ShareParams(text: 'UtopiaMusic Logs', files: filesToShare),
      );
    } catch (e, stack) {
      _talker.handle(e, stack, 'Failed to export logs');
    }
  }
}