import 'package:utopia_music/models/sponsor_block/segment_item_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';

class SegmentModel implements Comparable<SegmentModel> {
  final String uuid;
  final SegmentType segmentType;
  final (int, int) segment;
  final SkipType skipType;
  bool hasSkipped = false;

  SegmentModel({
    required this.uuid,
    required this.segmentType,
    required this.segment,
    required this.skipType,
  });

  factory SegmentModel.fromItemModel(
    SegmentItemModel model, {
    required Map<SegmentType, SkipType> blockSettings,
    required double blockLimitMs,
  }) {
    SegmentType? type;
    try {
      type = SegmentType.values.byName(model.category);
    } catch (_) {
      type = SegmentType.sponsor;
    }

    final start = model.segment.isNotEmpty ? model.segment[0] : 0;
    final end = model.segment.length > 1 ? model.segment[1] : start;
    final seg = (start, end);

    SkipType skipType = blockSettings[type] ?? SkipType.skipOnce;
    if (skipType != SkipType.showOnly && skipType != SkipType.disable) {
      if (seg.isEq || seg.length < blockLimitMs) {
        skipType = SkipType.showOnly;
      }
    }

    return SegmentModel(
      uuid: model.uuid,
      segmentType: type,
      segment: seg,
      skipType: skipType,
    );
  }

  @override
  int compareTo(SegmentModel other) => segment.$1.compareTo(other.segment.$1);
}

extension IntRecordExt on (int, int) {
  bool get isEq => $1 == $2;
  int get length => $2 - $1;
  bool contains(num other) => $1 <= other && other < $2;
}
