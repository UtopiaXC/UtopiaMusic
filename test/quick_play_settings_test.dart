import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/player/dialogs/play_options_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  group('SettingsProvider Quick Play & Quick Replace Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default values for quickPlay and quickPlaylistReplace', () async {
      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.quickPlay, true);
      expect(provider.quickPlaylistReplace, 0);
    });

    test('setQuickPlay updates state and persists', () async {
      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.setQuickPlay(false);
      expect(provider.quickPlay, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('quick_play'), false);

      await provider.setQuickPlay(true);
      expect(provider.quickPlay, true);
      expect(prefs.getBool('quick_play'), true);
    });

    test('setQuickPlaylistReplace updates state and persists', () async {
      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      for (int i = 0; i <= 5; i++) {
        await provider.setQuickPlaylistReplace(i);
        expect(provider.quickPlaylistReplace, i);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('quick_playlist_replace'), i);
      }
    });

    test('reloading settings restores persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'quick_play': false,
        'quick_playlist_replace': 3,
      });

      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.quickPlay, false);
      expect(provider.quickPlaylistReplace, 3);
    });
  });
}


