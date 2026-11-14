import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/desktop/desktop_player_bar.dart';
import 'package:utopia_music/layouts/desktop/desktop_playlist_drawer.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/library/downloaded_sheet.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/player/components/lyrics_card.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'DownloadedSheet with asPage renders inside Scaffold with valid theme text (no debug underline)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          locale: const Locale('zh'),
          home: const DownloadedSheet(asPage: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    },
  );

  testWidgets(
    'DesktopPlayerBar lyrics button opens FullPlayerPage directly to lyrics and collapses cleanly',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final playerProvider = PlayerProvider();
      final settingsProvider = SettingsProvider();
      final sbProvider = SponsorBlockProvider();

      final song = Song(
        bvid: 'BV1lyricsTest',
        cid: 42,
        title: 'Lyrics Test Track',
        artist: 'Test Artist',
        coverUrl: '',
        lyrics: '',
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: sbProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            home: Scaffold(
              body: FullPlayerPage(
                song: song,
                onCollapse: playerProvider.collapsePlayer,
                onSongSelected: (_) {},
              ),
              bottomNavigationBar: DesktopPlayerBar(
                song: song,
                isQueueOpen: false,
                onToggleQueue: () {},
                onExpandPlayer: playerProvider.togglePlayerExpansion,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially lyrics overlay is hidden below screen (Offset(0, 1)).
      final lyricsSlideFinder = find.ancestor(
        of: find.byType(LyricsPage),
        matching: find.byType(AnimatedSlide),
      );
      expect(
        tester.widget<AnimatedSlide>(lyricsSlideFinder).offset,
        const Offset(0, 1),
      );

      // Tap lyrics button on DesktopPlayerBar -> opens player directly to lyrics.
      await tester.tap(find.byIcon(Icons.lyrics_outlined).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(playerProvider.showFullPlayer, isTrue);
      expect(playerProvider.showFullPlayerLyrics, isTrue);
      expect(
        tester.widget<AnimatedSlide>(lyricsSlideFinder).offset,
        Offset.zero,
      );

      // Verify TickerMode is nested inside AnimatedSlide so collapse animates back down.
      expect(
        find.descendant(
          of: lyricsSlideFinder,
          matching: find.byType(TickerMode),
        ),
        findsAtLeastNWidgets(1),
      );

      // Tap lyrics button inside LyricsPage -> collapses lyrics cleanly.
      final lyricsPageLyricsBtn = find.descendant(
        of: find.byType(LyricsPage),
        matching: find.byIcon(Icons.lyrics_outlined),
      );
      expect(lyricsPageLyricsBtn, findsOneWidget);
      await tester.tap(lyricsPageLyricsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(playerProvider.showFullPlayerLyrics, isFalse);
      expect(
        tester.widget<AnimatedSlide>(lyricsSlideFinder).offset,
        const Offset(0, 1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'DesktopPlaylistDrawer and DesktopPlayerBar use BackdropFilter and high-contrast frosted tint in Liquid Glass',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final playerProvider = PlayerProvider();
      final sbProvider = SponsorBlockProvider();
      final song = Song(
        bvid: 'BV1glassTest',
        cid: 77,
        title: 'Glass Track',
        artist: 'Glass Artist',
        coverUrl: '',
        lyrics: '',
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: sbProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [S.delegate],
            locale: const Locale('zh'),
            theme: AppTheme.buildTheme(
              brightness: Brightness.light,
              seedColor: Colors.blue,
              enableLiquidGlass: true,
            ),
            home: Scaffold(
              body: DesktopPlaylistDrawer(onClose: () {}),
              bottomNavigationBar: DesktopPlayerBar(
                song: song,
                isQueueOpen: true,
                onToggleQueue: () {},
                onExpandPlayer: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DesktopPlaylistDrawer),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DesktopPlayerBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );

      final drawerGlass = tester.widget<LiquidGlassContainer>(
        find.descendant(
          of: find.byType(DesktopPlaylistDrawer),
          matching: find.byType(LiquidGlassContainer),
        ),
      );
      expect(drawerGlass.highContrastScrim, isTrue);
      expect(drawerGlass.tintColor!.a, greaterThanOrEqualTo(0.78));

      final barGlass = tester.widget<LiquidGlassContainer>(
        find.descendant(
          of: find.byType(DesktopPlayerBar),
          matching: find.byType(LiquidGlassContainer),
        ),
      );
      expect(barGlass.refractionStrength, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
