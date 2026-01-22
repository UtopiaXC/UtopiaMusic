import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/main_layout.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/font_utils.dart';

class UtopiaMusicApp extends StatelessWidget {
  const UtopiaMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Utopia Music',
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: settingsProvider.seedColor),
        useMaterial3: true,
        fontFamily: _getMainFontFamily(),
        fontFamilyFallback: FontUtils.systemFontFamilyFallback,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(),
          bodyMedium: TextStyle(),
          titleMedium: TextStyle(),
        ).apply(
          fontFamilyFallback: FontUtils.systemFontFamilyFallback,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: settingsProvider.seedColor, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: _getMainFontFamily(),
        fontFamilyFallback: FontUtils.systemFontFamilyFallback,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(),
          bodyMedium: TextStyle(),
          titleMedium: TextStyle(),
        ).apply(
          fontFamilyFallback: FontUtils.systemFontFamilyFallback,
        ),
      ),
      themeMode: settingsProvider.themeMode,
      home: const MainLayout(),
    );
  }
  String? _getMainFontFamily() {
    if (!kIsWeb && Platform.isWindows) {
      return 'Microsoft YaHei UI';
    }
    return null;
  }
}
