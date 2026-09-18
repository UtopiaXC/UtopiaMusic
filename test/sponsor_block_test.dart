import 'package:flutter_test/flutter_test.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/models/sponsor_block/segment_item_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/services/sponsor_block/sponsor_block_service.dart';

void main() {
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
  });
}
