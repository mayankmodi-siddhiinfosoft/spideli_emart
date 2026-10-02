/// The one place this app turns address parts into a line of text.
///
/// Bug #17 (1 October): addresses rendered as "123 Yaounde St, null, Tsinga".
/// Two things produce that. `AddressModel.getFullAddress()` interpolated
/// `locality` with no guard, so a missing locality printed the four characters
/// `null`; and the reverse-geocoded strings this app and the panels store are
/// themselves built by interpolating `Placemark` fields, so the word `null`
/// often sits *inside* one stored component.
///
/// [formatAddressParts] therefore splits every part on its own separators as
/// well, drops the pieces that carry no information -- empty, whitespace-only,
/// or the literal `null` / `nil` / `undefined` -- and rejoins what is left, so
/// the separators collapse instead of leaving ", ," or a trailing comma. A
/// part repeating an earlier part's text is dropped. Returns '' when nothing
/// is left, so the caller can hide the row. Storage is untouched.
///
/// ```dart
/// formatAddressParts(['123 Yaounde St', 'null, Tsinga', '  ']); // 123 Yaounde St, Tsinga
/// ```
String formatAddressParts(List<Object?> parts, {String separator = ', '}) {
  final List<String> clean = <String>[];
  // Panel rule (spideliFormatAddress): the same text is often stored in two
  // fields, so a part whose cleaned text (case-insensitive) was already used
  // is skipped whole. Individual segments are never de-duplicated.
  final Set<String> seen = <String>{};
  for (final Object? part in parts) {
    if (part == null) continue;
    final List<String> pieces = <String>[];
    for (final String piece in part.toString().split(',')) {
      final String value = piece.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isEmpty) continue;
      if (_isPlaceholder(value)) continue;
      pieces.add(value);
    }
    if (pieces.isEmpty) continue;
    if (!seen.add(pieces.join(', ').toLowerCase())) continue;
    clean.addAll(pieces);
  }
  return clean.join(separator);
}

/// [formatAddressParts] for a single, already-joined address string.
String formatAddressText(Object? address, {String separator = ', '}) => formatAddressParts(<Object?>[address], separator: separator);

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
