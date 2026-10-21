/// Search helpers. Firestore has no full-text search, so each product stores a
/// `keywords` array of lower-case words and word prefixes. The app queries one
/// keyword with `array-contains`, then filters the rest on the device.
/// For large catalogues, switch to the Algolia or Typesense Firebase extension.
class Keywords {
  static List<String> tokens(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toList();

  /// Words plus their prefixes (min 2 chars), e.g. "tecno" -> te, tec, tecn, tecno.
  static List<String> build(List<String> fields) {
    final out = <String>{};
    for (final f in fields) {
      for (final w in tokens(f)) {
        final max = w.length > 15 ? 15 : w.length;
        for (var i = 2; i <= max; i++) {
          out.add(w.substring(0, i));
        }
      }
    }
    return out.take(200).toList();
  }
}
