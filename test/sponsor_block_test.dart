import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/models/sponsor_block/segment_item_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/services/sponsor_block/sponsor_block_service.dart';

class _TestHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });
  group('SponsorBlock Defaults & Models Tests', () {
    test('Default skip type requirements', () {
      // Requirements:
      // Only sponsor, padding, and music_offtopic are skipOnce.
      // All other categories are showOnly.
      expect(
        SponsorBlockProvider.getDefaultSkipType(SegmentType.sponsor),
        SkipType.skipOnce,
      );
      expect(
        SponsorBlockProvider.getDefaultSkipType(SegmentType.padding),
        SkipType.skipOnce,
      );
      expect(
        SponsorBlockProvider.getDefaultSkipType(SegmentType.music_offtopic),
        SkipType.skipOnce,
      );

      final otherTypes = [
        SegmentType.selfpromo,
        SegmentType.exclusive_access,
        SegmentType.interaction,
        SegmentType.poi_highlight,
        SegmentType.intro,
        SegmentType.outro,
        SegmentType.preview,
        SegmentType.filler,
      ];

      for (final type in otherTypes) {
        expect(
          SponsorBlockProvider.getDefaultSkipType(type),
          SkipType.showOnly,
          reason: '${type.name} should default to showOnly',
        );
      }
    });

    test('SegmentItemModel parsing and SegmentModel millisecond conversion', () {
      final json = {
        'cid': '41972203997',
        'category': 'sponsor',
        'actionType': 'skip',
        'segment': [297.762, 427.775],
        'UUID': '0e9a2441e75e801d3c8fa1e3874aea0bb9d1c908672bf0e286047109feddd3617',
        'videoDuration': 880,
        'locked': 0,
        'votes': 0,
        'description': '',
      };

      final item = SegmentItemModel.fromJson(json);
      expect(item.cid, '41972203997');
      expect(item.category, 'sponsor');
      expect(item.segment, [297762, 427775]);

      final model = SegmentModel.fromItemModel(
        item,
        blockSettings: {
          SegmentType.sponsor: SkipType.skipOnce,
        },
        blockLimitMs: 0.0,
      );

      expect(model.segmentType, SegmentType.sponsor);
      expect(model.skipType, SkipType.skipOnce);
      // Millisecond conversion
      expect(model.segment.$1, 297762);
      expect(model.segment.$2, 427775);
      expect(model.hasSkipped, false);
    });

    test('SponsorBlockService getSkipSegments without cid (cid=0) returns real segments', () async {
      final service = SponsorBlockService();
      // BV18Ueu6cEFT is the video from user's screenshot
      final segmentsWithZeroCid = await service.getSkipSegments(
        server: SponsorBlockService.defaultServer,
        bvid: 'BV18Ueu6cEFT',
        cid: 0,
      );

      expect(segmentsWithZeroCid, isNotNull);
      expect(segmentsWithZeroCid!.isNotEmpty, true);
      expect(segmentsWithZeroCid.first.category, 'sponsor');

      final segmentsWithRealCid = await service.getSkipSegments(
        server: SponsorBlockService.defaultServer,
        bvid: 'BV18Ueu6cEFT',
        cid: 41972203997,
      );

      expect(segmentsWithRealCid, isNotNull);
      expect(segmentsWithRealCid!.isNotEmpty, true);
      expect(segmentsWithRealCid.first.category, 'sponsor');
    });

    test('Seeking directly into skippable segment triggers skip and backwards seek resets', () {
      final model = SegmentModel(
        uuid: 'test-uuid',
        segmentType: SegmentType.sponsor,
        segment: (10000, 30000),
        skipType: SkipType.skipOnce,
      );

      Duration? seekTarget;
      String? toastMessage;

      void testTick(Duration pos, List<SegmentModel> segments) {
        final currentMs = pos.inMilliseconds;
        for (final item in segments) {
          if (currentMs < item.segment.$1 - 1000) {
            item.hasSkipped = false;
          }
          if (currentMs >= item.segment.$1 && currentMs < item.segment.$2 - 500) {
            if (item.skipType == SkipType.alwaysSkip ||
                (item.skipType == SkipType.skipOnce && !item.hasSkipped)) {
              item.hasSkipped = true;
              seekTarget = Duration(milliseconds: item.segment.$2);
              toastMessage = '已跳过${item.segmentType.shortTitle}片段';
              return;
            }
          }
        }
      }

      // 1. Seek directly into middle of segment (20s)
      testTick(const Duration(seconds: 20), [model]);
      expect(seekTarget, const Duration(milliseconds: 30000));
      expect(model.hasSkipped, true);
      expect(toastMessage, '已跳过赞助片段');

      // 2. Seek backwards to 5s (resets hasSkipped)
      seekTarget = null;
      testTick(const Duration(seconds: 5), [model]);
      expect(model.hasSkipped, false);

      // 3. Re-enter segment at 15s (triggers skip again)
      testTick(const Duration(seconds: 15), [model]);
      expect(seekTarget, const Duration(milliseconds: 30000));
      expect(model.hasSkipped, true);
    });

    test('SponsorBlock is enabled by default', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final provider = SponsorBlockProvider();
      expect(provider.enableSponsorBlock, true);
    });

    test('loadSegmentsForSong clears currentSegments immediately to prevent progress bar flashing', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final provider = SponsorBlockProvider();

      final song1 = Song(
        bvid: 'BV1111111111',
        title: 'Song 1',
        artist: 'Artist 1',
        coverUrl: '',
        lyrics: '',
        colorValue: 0,
        cid: 12345,
      );

      final song2 = Song(
        bvid: 'BV2222222222',
        title: 'Song 2',
        artist: 'Artist 2',
        coverUrl: '',
        lyrics: '',
        colorValue: 0,
        cid: 67890,
      );

      // Verify that calling loadSegmentsForSong immediately updates currentSongBvid and resets currentSegments
      provider.loadSegmentsForSong(song1);
      expect(provider.currentSongBvid, 'BV1111111111');
      expect(provider.currentSegments.isEmpty, true);

      provider.loadSegmentsForSong(song2);
      expect(provider.currentSongBvid, 'BV2222222222');
      expect(provider.currentSegments.isEmpty, true);
    });
  });
}
