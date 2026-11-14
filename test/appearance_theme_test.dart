import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/mobile_layout.dart';
import 'package:utopia_music/pages/main/settings/fragments/appearance_settings_page.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/live/live_room_card.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/pages/main/settings/widgets/settings_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
  });

  group('Appearance Settings & Theme Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enableLiquidGlass and enableMonetColor default to false', () async {
      final provider = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.enableLiquidGlass, false);
      expect(provider.enableMonetColor, false);
      expect(provider.isMonetColorActive, false);
    });

    test(
      'setEnableLiquidGlass overrides isMonetColorActive while preserving saved Monet preference',
      () async {
        final provider = SettingsProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        await provider.setEnableMonetColor(true);
        expect(provider.enableMonetColor, true);
        expect(provider.isMonetColorActive, true);

        await provider.setEnableLiquidGlass(true);
        expect(provider.enableLiquidGlass, true);
        expect(provider.enableMonetColor, true);
        expect(provider.isMonetColorActive, false);

        await provider.setEnableLiquidGlass(false);
        expect(provider.isMonetColorActive, true);
      },
    );

    testWidgets(
      'Android AppearanceSettingsPage disables and greys out Monet switch when Liquid Glass is enabled',
      (WidgetTester tester) async {
        final settingsProvider = SettingsProvider();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        final libraryProvider = LibraryProvider();
        final discoverProvider = DiscoverProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider.value(value: libraryProvider),
              ChangeNotifierProvider.value(value: discoverProvider),
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
              home: const AppearanceSettingsPage(isAndroidOverride: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final monetTileFinder = find.widgetWithText(SwitchListTile, '莫奈取色');
        expect(monetTileFinder, findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(monetTileFinder).onChanged,
          isNotNull,
        );

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        final glassTileFinder = find.widgetWithText(SwitchListTile, '液态玻璃');
        expect(glassTileFinder, findsOneWidget);
        await tester.tap(glassTileFinder);
        await tester.pumpAndSettle();

        expect(settingsProvider.enableLiquidGlass, true);

        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(monetTileFinder).onChanged,
          isNull,
        );
        expect(find.text('液态玻璃开启时已禁用'), findsOneWidget);
      },
    );

    testWidgets('Non-Android AppearanceSettingsPage hides Monet option', (
      WidgetTester tester,
    ) async {
      final settingsProvider = SettingsProvider();
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      final libraryProvider = LibraryProvider();
      final discoverProvider = DiscoverProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: libraryProvider),
            ChangeNotifierProvider.value(value: discoverProvider),
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
            home: const AppearanceSettingsPage(isAndroidOverride: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SwitchListTile, '莫奈取色'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, '液态玻璃'), findsOneWidget);
    });

    testWidgets(
      'MobileLayout switches from docked NavigationBar to floating LiquidGlass capsule',
      (WidgetTester tester) async {
        final playerProvider = PlayerProvider();

        Widget buildLayout(bool liquidGlass) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: playerProvider),
            ],
            child: MaterialApp(
              localizationsDelegates: const [S.delegate],
              locale: const Locale('zh'),
              theme: AppTheme.buildTheme(
                brightness: Brightness.light,
                seedColor: Colors.deepPurple,
                enableLiquidGlass: liquidGlass,
              ),
              home: MobileLayout(
                selectedIndex: 0,
                pages: const [
                  Center(child: Text('P0')),
                  Center(child: Text('P1')),
                  Center(child: Text('P2')),
                ],
                onItemTapped: (_) {},
              ),
            ),
          );
        }

        await tester.pumpWidget(buildLayout(false));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(LiquidGlassContainer), findsNothing);

        await tester.pumpWidget(buildLayout(true));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(LiquidGlassContainer), findsOneWidget);

        final glassContainer = tester.widget<LiquidGlassContainer>(
          find.byType(LiquidGlassContainer),
        );
        expect(glassContainer.refractionStrength, greaterThan(0));
        expect(glassContainer.tintColor!.a, inInclusiveRange(0.65, 0.85));

        final liquidTheme = AppTheme.buildTheme(
          brightness: Brightness.light,
          seedColor: Colors.blue,
          enableLiquidGlass: true,
        );
        final themeGlass = liquidTheme.extension<LiquidGlassThemeExtension>()!;
        expect(themeGlass.glassTint.a, inInclusiveRange(0.65, 0.85));
        expect(themeGlass.blurSigma, greaterThanOrEqualTo(10.0));

        final tooltipDeco = liquidTheme.tooltipTheme.decoration as BoxDecoration;
        expect(tooltipDeco.color!.a, inInclusiveRange(0.80, 0.94));
        expect(liquidTheme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(
          liquidTheme.snackBarTheme.backgroundColor!.a,
          inInclusiveRange(0.80, 0.94),
        );
        expect(
          liquidTheme.bottomSheetTheme.modalBackgroundColor!.a,
          inInclusiveRange(0.80, 0.94),
        );
        final sheetShape =
            liquidTheme.bottomSheetTheme.shape as RoundedRectangleBorder;
        expect(sheetShape.side, BorderSide.none);
      },
    );

    testWidgets(
      'LiquidGlass applies consistently to Library category cards, grid surfaces, and sheets',
      (WidgetTester tester) async {
        final libraryProvider = LibraryProvider();
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: libraryProvider),
              ChangeNotifierProvider.value(value: authProvider),
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
              theme: AppTheme.buildTheme(
                brightness: Brightness.light,
                seedColor: Colors.blue,
                enableLiquidGlass: true,
              ),
              home: Scaffold(
                body: ListView(
                  children: const [
                    PlaylistCategoryWidget(
                      type: PlaylistCategoryType.favorites,
                      title: '我的收藏',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: LiveRoomCard(
                          room: LiveRoom(
                            roomId: 901,
                            uid: 42,
                            uname: 'Tester',
                            face: '',
                            title: 'Glass Live Room',
                            cover: '',
                          ),
                        ),
                      ),
                    ),
                    LiquidGlassSurface(
                      child: SizedBox(height: 40, child: Text('Card Item')),
                    ),
                    LiquidGlassSheetSurface(
                      child: SizedBox(height: 40, child: Text('Sheet Body')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LiquidGlassContainer), findsOneWidget);
        expect(find.byType(LiquidGlassSurface), findsNWidgets(3));
        expect(find.byType(LiquidGlassSheetSurface), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsFragmentScaffold places LiquidGlassBackdrop behind Scaffold and SettingsGroup uses LiquidGlassSurface',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(
              brightness: Brightness.light,
              seedColor: Colors.blue,
              enableLiquidGlass: true,
            ),
            home: SettingsFragmentScaffold(
              title: 'Appearance',
              body: ListView(
                children: const [
                  SettingsGroup(
                    title: 'Global',
                    children: [ListTile(title: Text('Option'))],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.byType(Scaffold),
            matching: find.byType(LiquidGlassBackdrop),
          ),
          findsOneWidget,
        );
        expect(find.byType(SettingsGroup), findsOneWidget);
        expect(find.byType(LiquidGlassSurface), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );

    testWidgets(
      'LiquidGlassSheetSurface hugs content height cleanly without stretching full-screen',
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
            theme: AppTheme.buildTheme(
              brightness: Brightness.light,
              seedColor: Colors.blue,
              enableLiquidGlass: true,
            ),
            home: const Scaffold(
              backgroundColor: Colors.transparent,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: LiquidGlassSheetSurface(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Compact Sheet Content'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final sheetSize = tester.getSize(find.byType(LiquidGlassSheetSurface));
        final screenSize = tester.getSize(find.byType(Scaffold));
        expect(sheetSize.height, lessThan(screenSize.height * 0.75));
      },
    );
  });
}
