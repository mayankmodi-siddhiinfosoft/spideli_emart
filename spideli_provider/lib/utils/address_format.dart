/// The one place this app turns address parts into a line of text.
///
/// Bug #17 (1 October): addresses rendered as "123 Yaounde St, null, Tsinga".
/// Two things produce that. `AddressModel.getFullAddress()` interpolated
/// `locality` with no guard, so a missing locality printed the four characters
/// `null`; and the reverse-geocoded strings this app and the panels store are
/// themselves built by interpolating `Placemark` fields, so the word `null`
/// often sits *inside* one stored component.
///
/// [formatAddressParts] mirrors the web panels' `spideliFormatAddress` /
/// `spideliCleanAddressPart` (report 02#18): it splits every part on its commas
/// as well, drops the pieces that carry no information -- empty, whitespace-only,
/// or the literal `null` / `nil` / `undefined` -- and rejoins what is left, so
/// the separators collapse instead of leaving ", ," or a trailing comma. A
/// part repeating an earlier part's text is dropped. Returns '' when nothing
/// is left, so the caller can hide the row. Storage is untouched.
///
/// ```dart
/// formatAddressParts(['123 Yaounde St', 'null, Tsinga', '  ']); // 123 Yaounde St, Tsinga
/// ```
String formatAddressParts(List<Object?> parts) {
  // Panel rule (spideliFormatAddress): the same text is often stored in two
  // fields, so a part whose cleaned text (case-insensitive) was already used
  // is skipped whole. Individual segments are never de-duplicated.
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final Object? part in parts) {
    final String cleaned = cleanAddressPart(part);
    if (cleaned.isEmpty) continue;
    if (!seen.add(cleaned.toLowerCase())) continue;
    out.add(cleaned);
  }
  return out.join(', ');
}

/// [formatAddressParts] for a single, already-joined address string.
String formatAddressText(Object? address) => formatAddressParts(<Object?>[address]);

/// Dart twin of the panels' `spideliCleanAddressPart`: splits one stored value
/// on its commas, trims each segment, drops the empty ones and the literal
/// `null` / `undefined` / `nil` (case-insensitive, whole segments only, so
/// "Nullarbor Road" survives) and rejoins the rest with ", ". '' when nothing
/// is left.
String cleanAddressPart(Object? value) {
  if (value == null) return '';
  final String text = value.toString().trim();
  if (text.isEmpty) return '';
  return text.split(',').map((String p) => p.trim()).where((String p) => p.isNotEmpty && !_isPlaceholder(p)).join(', ');
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
