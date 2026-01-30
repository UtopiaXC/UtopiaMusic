import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/app.dart';
import 'package:utopia_music/services/audio/audio_playback_optimizer.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/connection/utils/request.dart';
import 'package:utopia_music/connection/utils/wbi.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/services/audio/background_playback_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Timer? _wbiRefreshTimer;

void main() async {
  Log.i("Starting UtopiaMusic APP");
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.init();
  Request();
  WbiUtil.preRefresh();
  _wbiRefreshTimer = Timer.periodic(const Duration(minutes: 25), (_) {
    WbiUtil.periodicRefresh();
  });

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.utopiaxc.utopia.music',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: false,
    androidShowNotificationBadge: true,
    androidStopForegroundOnPause: true,
    androidNotificationIcon: "drawable/ic_launcher",
  );

  JustAudioMediaKit.ensureInitialized(
    windows: true,
    linux: true,
    android: false,
    iOS: true,
    macOS: true,
  );

  await BackgroundPlaybackService().init();
  await AudioPlaybackOptimizer().init();
  await DownloadManager().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => DiscoverProvider()),
      ],
      child: const UtopiaMusicApp(),
    ),
  );
}
