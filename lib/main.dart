import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/app.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const UtopiaMusicApp(),
    ),
  );
}
