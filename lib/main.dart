import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/app.dart';
import 'package:utopia_music/providers/player_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const UtopiaMusicApp(),
    ),
  );
}
