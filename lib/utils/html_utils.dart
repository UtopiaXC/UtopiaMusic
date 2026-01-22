import 'package:html_unescape/html_unescape.dart';

class HtmlUtils {
  static final HtmlUnescape _unescape = HtmlUnescape();

  static String unescape(String text) {
    return _unescape.convert(text);
  }
}
