import 'dart:math';

/// Helpers for Bilibili AV/BV identifier conversion and guest fingerprint IDs.
class BiliIdUtils {
  BiliIdUtils._();

  static const int _xorCode = 23442827791579;
  static const int _maxAid = 1 << 51;
  static const String _alphabet =
      'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf';
  static const int _base = 58;
  static final Random _random = Random.secure();

  /// Converts a numeric Bilibili AV ID (`aid`) to its canonical BV string.
  static String av2bv(int aid) {
    if (aid <= 0) return '';
    final bytes = 'BV1000000000'.split('');
    int bvIndex = 11;
    int tmp = (_maxAid | aid) ^ _xorCode;
    while (tmp != 0) {
      bytes[bvIndex] = _alphabet[tmp % _base];
      tmp ~/= _base;
      bvIndex--;
    }
    final t3 = bytes[3];
    bytes[3] = bytes[9];
    bytes[9] = t3;
    final t4 = bytes[4];
    bytes[4] = bytes[7];
    bytes[7] = t4;
    return bytes.join();
  }

  /// Generates a locally valid fallback `buvid3` token matching Bilibili's format.
  static String generateBuvid3() {
    String hex(int count) {
      final buffer = StringBuffer();
      for (int i = 0; i < count; i++) {
        buffer.write(_random.nextInt(16).toRadixString(16).toUpperCase());
      }
      return buffer.toString();
    }

    final variant = (8 + _random.nextInt(4)).toRadixString(16).toUpperCase();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}infoc';
  }
}
