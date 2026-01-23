import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/main_layout.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/utils/font_utils.dart';
import 'package:utopia_music/pages/main/lock_screen.dart';

class UtopiaMusicApp extends StatefulWidget {
  const UtopiaMusicApp({super.key});

  @override
  State<UtopiaMusicApp> createState() => _UtopiaMusicAppState();
}

class _UtopiaMusicAppState extends State<UtopiaMusicApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      securityProvider.setAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      securityProvider.setAppResumed();
    } else if (state == AppLifecycleState.detached) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final securityProvider = Provider.of<SecurityProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Utopia Music',
      locale: settingsProvider.locale, // Apply locale from settings
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
      home: securityProvider.isLocked ? const LockScreen() : const MainLayout(),
    );
  }
  String? _getMainFontFamily() {
    if (!kIsWeb && Platform.isWindows) {
      return 'Microsoft YaHei UI';
    }
    return null;
  }
}
