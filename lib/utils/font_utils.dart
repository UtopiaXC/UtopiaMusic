import 'dart:io';
import 'package:flutter/foundation.dart';

class FontUtils {
  static List<String> get systemFontFamilyFallback {
    if (kIsWeb) {
      return const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans SC',
        'sans-serif',
      ];
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return const [
        'PingFang SC',
        '.AppleSystemUIFont',
        'Helvetica Neue',
        'Helvetica',
      ];
    }

    if (Platform.isWindows) {
      return const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'Segoe UI',
        'SimHei',
      ];
    }

    if (Platform.isAndroid) {
      return const [
        'Source Han Sans SC',
        'Noto Sans CJK SC',
        'sans-serif',
      ];
    }

    return const ['sans-serif'];
  }
}