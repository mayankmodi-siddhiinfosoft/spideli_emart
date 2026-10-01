/// The one place the app turns address parts into a line of text.
///
/// Bug #17 (1 October): addresses came out as `123 Yaounde St, null, Tsinga`.
/// Nothing is wrong with what is stored — the reverse-geocoded strings this app
/// (and the panels) write are built by interpolating `Placemark` fields, and a
/// field that is null interpolates as the four characters `null`. That text
/// then lives inside a single stored component (usually `locality`), so simply
/// skipping empty components was never enough.
///
/// [formatAddressLine] therefore splits every part on its separators as well,
/// drops the pieces that carry no information — empty, whitespace-only, or the
/// literal `null` / `nil` / `undefined` — and rejoins what is left with a
/// single `, `. Storage is untouched: this is display only.
///
/// ```dart
/// formatAddressLine(['123 Yaounde St', 'null, Tsinga', '  ']) // 123 Yaounde St, Tsinga
/// ```
String formatAddressLine(Iterable<String?> parts, {String separator = ', '}) {
  final List<String> kept = [];
  for (final String? part in parts) {
    if (part == null) continue;
    for (final String piece in part.split(',')) {
      final String value = piece.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isEmpty) continue;
      if (_isPlaceholder(value)) continue;
      kept.add(value);
    }
  }
  return kept.join(separator);
}

bool _isPlaceholder(String value) {
  switch (value.toLowerCase()) {
    case 'null':
    case 'nil':
    case 'undefined':
      return true;
    default:
      return false;
  }
}
