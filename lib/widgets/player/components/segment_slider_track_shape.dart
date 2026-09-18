import 'package:flutter/material.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';

class SegmentSliderTrackShape extends RoundedRectSliderTrackShape {
  final List<SegmentModel> segments;
  final Duration duration;
  final Map<SegmentType, Color> blockColor;

  const SegmentSliderTrackShape({
    required this.segments,
    required this.duration,
    required this.blockColor,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    // 1. Draw base slider track
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    // 2. Overlay segments if any
    final durationMs = duration.inMilliseconds;
    if (segments.isEmpty || durationMs <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final canvas = context.canvas;
    final paint = Paint()..style = PaintingStyle.fill;

    final double activeHalfHeight = additionalActiveTrackHeight / 2.0;
    final double segTop = trackRect.top - activeHalfHeight;
    final double segHeight = trackRect.height + additionalActiveTrackHeight;

    for (final seg in segments) {
      final startRatio = (seg.segment.$1 / durationMs).clamp(0.0, 1.0);
      final endRatio = (seg.segment.$2 / durationMs).clamp(0.0, 1.0);

      final left = trackRect.left + startRatio * trackRect.width;
      final right = trackRect.left + endRatio * trackRect.width;
      final paintColor = blockColor[seg.segmentType] ?? seg.segmentType.color;

      paint.color = paintColor;

      double segmentWidth = right - left;
      double segmentLeft = left;

      if (segmentWidth < 4.0) {
        segmentWidth = 4.0;
        segmentLeft = (left - 2.0).clamp(trackRect.left, trackRect.right - 4.0);
      }

      final segmentRect = Rect.fromLTWH(
        segmentLeft,
        segTop,
        segmentWidth,
        segHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(segmentRect, Radius.circular(segHeight / 2.0)),
        paint,
      );
    }
  }
}
