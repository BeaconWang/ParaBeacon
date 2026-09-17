/// Script detection for search input.
///
/// Lives in the data layer because both the UI (deciding when a query is ready
/// to send) and the geocoding chain (deciding which provider can answer a
/// query) need the same answer, and two copies of a Unicode range table would
/// inevitably drift apart.
class Cjk {
  Cjk._();

  /// Whether [text] contains CJK ideographs or Japanese kana.
  ///
  /// Note this is deliberately about the *characters*, not the language:
  /// romanized pinyin ("xiaojingwan") is Latin text and returns false. That
  /// distinction matters — a pinyin fragment looks exactly like an English
  /// query, which is why IME composing state, not content, gates the search.
  static bool contains(String text) {
    for (final code in text.runes) {
      if ((code >= 0x3400 && code <= 0x4dbf) || // CJK ext A
          (code >= 0x4e00 && code <= 0x9fff) || // CJK unified
          (code >= 0xf900 && code <= 0xfaff) || // compatibility ideographs
          (code >= 0x3040 && code <= 0x30ff)) {
        // hiragana / katakana
        return true;
      }
    }
    return false;
  }
}
