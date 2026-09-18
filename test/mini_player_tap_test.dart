import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/mini_player.dart';

void main() {
  testWidgets('MiniPlayer tap isolation: play/pause does not trigger onTap', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final song = Song(
      bvid: 'BV1234567890',
      title: 'Test Song Title',
      artist: 'Test Artist',
      coverUrl: '',
      lyrics: '',
      colorValue: 0,
      cid: 11111,
    );

    int tapCount = 0;
    int playPauseCount = 0;
    int closeCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>(
        create: (_) => PlayerProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
          ],
          home: Scaffold(
            body: MiniPlayer(
              song: song,
              isPlaying: true,
              onTap: () {
                tapCount++;
              },
              onPlayPause: () {
                playPauseCount++;
              },
              onNext: () {},
              onPrevious: () {},
              onClose: () {
                closeCount++;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Tap the pause button (Icons.pause)
    final pauseButtonFinder = find.byIcon(Icons.pause);
    expect(pauseButtonFinder, findsOneWidget);
    await tester.tap(pauseButtonFinder);
    await tester.pumpAndSettle();

    expect(playPauseCount, 1, reason: 'onPlayPause should be called once');
    expect(tapCount, 0, reason: 'onTap should NOT be called when tapping pause button');

    // 2. Tap the close button (Icons.close)
    final closeButtonFinder = find.byIcon(Icons.close);
    expect(closeButtonFinder, findsOneWidget);
    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();

    expect(closeCount, 1, reason: 'onClose should be called once');
    expect(tapCount, 0, reason: 'onTap should NOT be called when tapping close button');

    // 3. Tap the title / center area
    final titleFinder = find.text('Test Song Title');
    expect(titleFinder, findsOneWidget);
    await tester.tap(titleFinder);
    await tester.pumpAndSettle();

    expect(tapCount, 1, reason: 'onTap should be called when tapping the song title area');
  });
}
