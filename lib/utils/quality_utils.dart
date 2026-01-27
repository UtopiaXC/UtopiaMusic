import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

class QualityUtils {
  QualityUtils._();

  static const int qualityHiRes = 30251;
  static const int qualityDolby = 30250;
  static const int quality192k = 30280;
  static const int quality132k = 30232;
  static const int quality64k = 30216;

  static const List<int> supportQualities = [
    qualityHiRes,
    qualityDolby,
    quality192k,
    quality132k,
    quality64k,
  ];

  static String getQualityLabel(
    BuildContext context,
    int quality, {
    bool detailed = false,
  }) {
    switch (quality) {
      case qualityHiRes:
        return detailed
            ? S.of(context).util_audio_quality_hires_detail
            : S.of(context).util_audio_quality_hires;
      case qualityDolby:
        return detailed
            ? S.of(context).util_audio_quality_dolby_detail
            : S.of(context).util_audio_quality_dolby;
      case quality192k:
        return detailed
            ? S.of(context).util_audio_quality_high_detail
            : S.of(context).util_audio_quality_high;
      case quality132k:
        return detailed
            ? S.of(context).util_audio_quality_middle_detail
            : S.of(context).util_audio_quality_middle;
      case quality64k:
        return detailed
            ? S.of(context).util_audio_quality_low_detail
            : S.of(context).util_audio_quality_low;
      default:
        return detailed
            ? '${S.of(context).common_unknown} ($quality)'
            : S.of(context).common_unknown;
    }
  }

  static int getScore(int quality) {
    switch (quality) {
      case qualityHiRes:
        return 5;
      case qualityDolby:
        return 4;
      case quality192k:
        return 3;
      case quality132k:
        return 2;
      case quality64k:
        return 1;
      default:
        return 0;
    }
  }

  static bool isVipQuality(int quality) {
    return quality == qualityHiRes || quality == qualityDolby;
  }
}
