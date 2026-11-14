import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/widgets/player/components/player_controls.dart';
import 'package:utopia_music/widgets/player/components/segment_slider_track_shape.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';

class _RecordingCanvas implements Canvas {
  final List<RRect> drawnRRects = [];

  @override
  void drawRRect(RRect rrect, Paint paint) {
    drawnRRects.add(rrect);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePaintingContext extends PaintingContext {
  _FakePaintingContext(this._canvas)
    : super(ContainerLayer(), const Rect.fromLTWH(0, 0, 100, 100));

  final _RecordingCanvas _canvas;

  @override
  Canvas get canvas => _canvas;
}

class _FakeRenderBox extends RenderBox {
  _FakeRenderBox(this.fixedSize);

  final Size fixedSize;

  @override
  Size get size => fixedSize;

  @override
  void performLayout() {
    size = fixedSize;
  }
}

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

  group('SponsorBlock Equality & Slider Paint Guards', () {
    test('SegmentModel implements value equality and hashCode', () {
      final a = SegmentModel(
        uuid: 'u1',
        segmentType: SegmentType.sponsor,
        segment: (1000, 5000),
        skipType: SkipType.skipOnce,
      );
      final b = SegmentModel(
        uuid: 'u1',
        segmentType: SegmentType.sponsor,
        segment: (1000, 5000),
        skipType: SkipType.skipOnce,
      );
      final c = SegmentModel(
        uuid: 'u2',
        segmentType: SegmentType.sponsor,
        segment: (1000, 5000),
        skipType: SkipType.skipOnce,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test(
      'SegmentSliderTrackShape implements value equality across fresh list/map wrappers',
      () {
        final s1 = [
          SegmentModel(
            uuid: 'u1',
            segmentType: SegmentType.sponsor,
            segment: (1000, 5000),
            skipType: SkipType.skipOnce,
          ),
        ];
        final s2 = [
          SegmentModel(
            uuid: 'u1',
            segmentType: SegmentType.sponsor,
            segment: (1000, 5000),
            skipType: SkipType.skipOnce,
          ),
        ];

        final shapeA = SegmentSliderTrackShape(
          segments: List.unmodifiable(s1),
          duration: const Duration(minutes: 3),
          blockColor: Map.unmodifiable({
            SegmentType.sponsor: const Color(0xFF00D400),
          }),
        );
        final shapeB = SegmentSliderTrackShape(
          segments: List.unmodifiable(s2),
          duration: const Duration(minutes: 3),
          blockColor: Map.unmodifiable({
            SegmentType.sponsor: const Color(0xFF00D400),
          }),
        );

        expect(shapeA, equals(shapeB));
        expect(shapeA.hashCode, equals(shapeB.hashCode));
      },
    );

    test(
      'SegmentSliderTrackShape clamps narrow track width safely without ArgumentError',
      () {
        final shape = SegmentSliderTrackShape(
          segments: [
            SegmentModel(
              uuid: 'u1',
              segmentType: SegmentType.sponsor,
              segment: (0, 5),
              skipType: SkipType.skipOnce,
            ),
          ],
          duration: const Duration(minutes: 10),
          blockColor: {SegmentType.sponsor: Colors.green},
        );
        final canvas = _RecordingCanvas();
        final paintContext = _FakePaintingContext(canvas);
        final parentBox = _FakeRenderBox(const Size(2.0, 20.0));
        final sliderTheme = SliderThemeData.fromPrimaryColors(
          primaryColor: Colors.blue,
          primaryColorDark: Colors.blue,
          primaryColorLight: Colors.blue,
          valueIndicatorTextStyle: const TextStyle(),
        );

        expect(
          () => shape.paint(
            paintContext,
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: const AlwaysStoppedAnimation<double>(1.0),
            textDirection: TextDirection.ltr,
            thumbCenter: const Offset(1.0, 10.0),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('FullPlayerPage & PlayerControls Isolation', () {
    testWidgets(
      'Long title Marquee does not overlap trailing SponsorBlock shield button',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(420, 840);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final sbProvider = SponsorBlockProvider();
        final playerProvider = PlayerProvider();
        final settingsProvider = SettingsProvider();
        final authProvider = AuthProvider();

        final song = Song(
          bvid: 'BV1xx411c7mD',
          cid: 999,
          title:
              'A Very Long Song Title That Exceeds Width And Must Scroll Cleanly Inside Header Without Overlapping Shield',
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
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              localizationsDelegates: const [S.delegate],
              home: FullPlayerPage(
                song: song,
                onCollapse: () {},
                onSongSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(Marquee), findsOneWidget);
        expect(find.byType(PlayerControls), findsOneWidget);

        // Verify PlayerControls slider is wrapped in a RepaintBoundary for paint isolation.
        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);
        expect(
          find.ancestor(
            of: sliderFinder,
            matching: find.byType(RepaintBoundary),
          ),
          findsWidgets,
        );

        // Dispose cleanly and flush any pending marquee/network timers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('PlayerControls wraps Slider inside RepaintBoundary', (
      WidgetTester tester,
    ) async {
      final playerProvider = PlayerProvider();
      final sbProvider = SponsorBlockProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: sbProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [S.delegate],
            home: Scaffold(
              body: PlayerControls(
                isPlaying: true,
                isLoading: false,
                duration: const Duration(minutes: 3),
                position: const Duration(seconds: 30),
                loopMode: PlayMode.sequence,
                onShuffle: () {},
                onSeek: (_) {},
                onPlayPause: () {},
                onNext: () {},
                onPrevious: () {},
                onPlaylist: () {},
              ),
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
      expect(
        find.ancestor(of: sliderFinder, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
