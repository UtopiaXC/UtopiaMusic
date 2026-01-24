import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/app.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/security_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.utopiaxc.utopia.bilimusic',
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
    iOS: false,
    macOS: false,
  );
  runApp(
    Phoenix(
      child: MultiProvider(
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
    ),
  );
}
