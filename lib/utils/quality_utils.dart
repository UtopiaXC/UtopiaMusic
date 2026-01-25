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

  static String getQualityLabel(int quality, {bool detailed = false}) {
    switch (quality) {
      case qualityHiRes:
        return detailed ? 'Hi-Res无损 (大会员)' : 'Hi-Res (大会员)';
      case qualityDolby:
        return detailed ? '杜比全景声 (大会员)' : '杜比全景声 (大会员)';
      case quality192k:
        return detailed ? '高音质 (192k)' : '高音质';
      case quality132k:
        return detailed ? '标准音质 (132K)' : '标准音质';
      case quality64k:
        return detailed ? '低音质 (64k)' : '低音质';
      default:
        return detailed ? '未知 ($quality)' : '未知';
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