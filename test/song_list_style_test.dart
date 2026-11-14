import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/settings/fragments/appearance_settings_page.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
  });

  group('Track List Style Settings & SongList Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsProvider defaults to SongListStyle.cardGrid and persists', () async {
      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.songListStyle, SongListStyle.cardGrid);

      await provider.setSongListStyle(SongListStyle.seamlessList);
      expect(provider.songListStyle, SongListStyle.seamlessList);

      await provider.setSongListStyle(SongListStyle.cardList);
      expect(provider.songListStyle, SongListStyle.cardList);
    });

    testWidgets(
      'AppearanceSettingsPage shows track list style dropdown with all three options',
      (WidgetTester tester) async {
        final settingsProvider = SettingsProvider();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider(create: (_) => LibraryProvider()),
              ChangeNotifierProvider(create: (_) => DiscoverProvider()),
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
              home: AppearanceSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('曲目列表样式'), findsOneWidget);
        expect(find.text('卡片平铺'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<SongListStyle>));
        await tester.pumpAndSettle();

        expect(find.text('卡片列表').last, findsOneWidget);
        expect(find.text('无缝列表').last, findsOneWidget);

        await tester.tap(find.text('无缝列表').last);
        await tester.pumpAndSettle();
        expect(settingsProvider.songListStyle, SongListStyle.seamlessList);
      },
    );

    testWidgets(
      'SongList renders PiliPlus grid, card list, and seamless divider list according to SettingsProvider',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(420, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final settingsProvider = SettingsProvider();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        final playerProvider = PlayerProvider();

        final songs = [
          Song(
            bvid: 'BV1001',
            cid: 1,
            title: 'Pili Card Track One',
            artist: 'Author One',
            coverUrl: '',
            lyrics: '',
            colorValue: 0,
            durationSeconds: 185,
            viewCount: 227000,
            danmakuCount: 983,
            isFollowed: true,
          ),
          Song(
            bvid: 'BV1002',
            cid: 2,
            title: 'Pili Card Track Two',
            artist: 'Author Two',
            coverUrl: '',
            lyrics: '',
            colorValue: 0,
            durationSeconds: 90,
            viewCount: 523,
            danmakuCount: 12,
          ),
        ];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider.value(value: playerProvider),
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
                body: SongList(
                  songs: songs,
                  hasMore: false,
                  followGlobalStyle: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Default cardGrid renders PiliPlus 16:10 grid cards with duration & followed tag.
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(AspectRatio), findsNWidgets(2));
        expect(find.text('03:05'), findsOneWidget);
        expect(find.text('01:30'), findsOneWidget);
        expect(find.text('已关注'), findsOneWidget);

        // 2. Switch to cardList -> mobile uses ListView without Divider or grid AspectRatio.
        await settingsProvider.setSongListStyle(SongListStyle.cardList);
        await tester.pumpAndSettle();
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(AspectRatio), findsNothing);
        expect(find.byType(Divider), findsNothing);

        // 3. Switch to seamlessList -> flat rows separated by Dividers.
        await settingsProvider.setSongListStyle(SongListStyle.seamlessList);
        await tester.pumpAndSettle();
        expect(find.byType(Divider), findsWidgets);
        expect(find.byType(AspectRatio), findsNothing);
      },
    );

    testWidgets(
      'Non-global SongListItem (used on SpaceSheet user profile videos) keeps list row when global style is cardGrid',
      (WidgetTester tester) async {
        final settingsProvider = SettingsProvider();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        expect(settingsProvider.songListStyle, SongListStyle.cardGrid);

        final song = Song(
          bvid: 'BV999',
          cid: 9,
          title: 'Space Video Item',
          artist: 'Space Author',
          coverUrl: '',
          lyrics: '',
          colorValue: 0,
          durationSeconds: 120,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider(create: (_) => PlayerProvider()),
            ],
            child: MaterialApp(
              localizationsDelegates: const [S.delegate],
              locale: const Locale('zh'),
              home: Scaffold(
                body: SongListItem(
                  song: song,
                  contextList: [song],
                  followGlobalStyle: false,
                  useCardStyle: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AspectRatio), findsNothing);
        expect(find.text('02:00'), findsNothing);
      },
    );

    testWidgets(
      'Default SongList (non-Discover views such as favorites/collections) ignores global cardGrid setting',
      (WidgetTester tester) async {
        final settingsProvider = SettingsProvider();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        expect(settingsProvider.songListStyle, SongListStyle.cardGrid);

        final songs = [
          Song(
            bvid: 'BV888',
            cid: 8,
            title: 'Collection Track',
            artist: 'Collection Author',
            coverUrl: '',
            lyrics: '',
            colorValue: 0,
            durationSeconds: 185,
            isFollowed: true,
          ),
        ];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider(create: (_) => PlayerProvider()),
            ],
            child: MaterialApp(
              localizationsDelegates: const [S.delegate],
              locale: const Locale('zh'),
              home: Scaffold(
                body: SongList(songs: songs, hasMore: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(AspectRatio), findsNothing);
        expect(find.text('03:05'), findsNothing);
        expect(find.text('已关注'), findsNothing);
        expect(find.text('Collection Track'), findsOneWidget);
      },
    );
  });
}
