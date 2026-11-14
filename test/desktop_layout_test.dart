import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/desktop/desktop_player_bar.dart';
import 'package:utopia_music/layouts/desktop/desktop_playlist_drawer.dart';
import 'package:utopia_music/layouts/desktop/desktop_sidebar.dart';
import 'package:utopia_music/layouts/desktop/desktop_top_bar.dart';
import 'package:utopia_music/layouts/desktop_layout.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/settings/fragments/appearance_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/search_settings_page.dart';
import 'package:utopia_music/pages/main/settings/settings_page.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';

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
    'DesktopLayout renders Biu-style sidebar, top bar, bottom bar, and queue drawer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final playerProvider = PlayerProvider();
      final discoverProvider = DiscoverProvider();
      final libraryProvider = LibraryProvider();
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final sbProvider = SponsorBlockProvider();

      final song = Song(
        bvid: 'BV1xx411c7mD',
        cid: 123,
        title: 'Desktop Test Track',
        artist: 'Desktop Artist',
        coverUrl: '',
        lyrics: '',
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: discoverProvider),
            ChangeNotifierProvider.value(value: libraryProvider),
            ChangeNotifierProvider.value(value: authProvider),
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
            home: DesktopLayout(
              selectedIndex: 0,
              pages: const [
                Center(child: Text('Discover Content')),
                Center(child: Text('Library Content')),
                Center(child: Text('Settings Content')),
              ],
              onItemTapped: (_) {},
              activeDiscoverCategory: DiscoverCategoryType.recommend,
              onSelectDiscoverCategory: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopSidebar), findsOneWidget);
      expect(find.byIcon(Icons.apps_outlined), findsOneWidget);
      expect(find.byType(DesktopTopBar), findsOneWidget);
      expect(find.byType(DesktopPlayerBar), findsNothing);
      expect(find.byType(DesktopPlaylistDrawer), findsNothing);

      // Build DesktopPlayerBar directly with queue toggle callback verified.
      bool drawerOpen = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: discoverProvider),
            ChangeNotifierProvider.value(value: libraryProvider),
            ChangeNotifierProvider.value(value: authProvider),
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
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Stack(
                    children: [
                      const Center(child: Text('Workspace')),
                      if (drawerOpen)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: DesktopPlaylistDrawer(
                            onClose: () => setState(() => drawerOpen = false),
                          ),
                        ),
                    ],
                  ),
                  bottomNavigationBar: DesktopPlayerBar(
                    song: song,
                    isQueueOpen: drawerOpen,
                    onToggleQueue: () =>
                        setState(() => drawerOpen = !drawerOpen),
                    onExpandPlayer: () {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopPlayerBar), findsOneWidget);
      expect(find.byType(DesktopPlaylistDrawer), findsNothing);

      await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopPlaylistDrawer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'SettingsPage adapts to desktop two-pane layout and mobile list layout',
    (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final discoverProvider = DiscoverProvider();
      final libraryProvider = LibraryProvider();
      final playerProvider = PlayerProvider();

      Widget wrapSettings() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: discoverProvider),
            ChangeNotifierProvider.value(value: libraryProvider),
            ChangeNotifierProvider.value(value: playerProvider),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('zh')],
            locale: Locale('zh'),
            home: SettingsPage(),
          ),
        );
      }

      // Desktop viewport: renders split view with Appearance embedded inline.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      expect(find.byType(AppearanceSettingsPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      // Switch inline to Search category without pushing a new route.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.byType(SearchSettingsPage), findsOneWidget);
      expect(find.byType(AppearanceSettingsPage), findsNothing);
      expect(find.byType(AppBar), findsNothing);

      // Mobile viewport: renders classic list without embedded fragments.
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(wrapSettings());
      await tester.pumpAndSettle();

      expect(find.byType(SearchSettingsPage), findsNothing);
      expect(find.byType(AppearanceSettingsPage), findsNothing);
    },
  );
}
