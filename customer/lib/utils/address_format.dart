// The one place the app turns address parts into a line of text.
//
// Report 02#18 (01#17): addresses came out as `123 Yaounde St, null, Tsinga`.
// Two causes, both handled here:
//
// * a stored component that is `null` / `"null"` was joined in as the four
//   characters `null`;
// * reverse-geocoded strings were built by interpolating `Placemark` fields,
//   so the word `null` is baked INSIDE one stored component (usually
//   `locality`: `18, null, Yaoundé, Région du Centre, null, Cameroun`).
//
// The rule is the panels' own, copied rather than reinvented
// (BUG-REPORT-01-APP.md §3 "02#18", `spideliCleanAddressPart` /
// `spideliFormatAddress`, identical in all four panels):
//
// * every part is split on its commas and each comma-separated segment is
//   trimmed; a segment that is empty or (case-insensitively) `null`,
//   `undefined` or `nil` is dropped. Only WHOLE segments go: `Nullarbor Road`
//   and `Annullata Street` survive;
// * a part whose cleaned text (case-insensitive) was already used is skipped
//   whole - the same text is often stored in two fields. Single segments are
//   never de-duplicated against each other;
// * nothing left gives `''`, never `", , "`, so the caller can hide the row.
//
// Storage is untouched: this is display only. Where the app BUILDS an address
// from geocoder fields it goes through [formatAddressLine] too, so new records
// never contain `null` in the first place.

/// `spideliCleanAddressPart`: [value] as display text with its empty and
/// placeholder comma-separated segments removed. `''` when nothing is left.
///
/// ```dart
/// cleanAddressPart('18, null, Yaoundé, nil') // 18, Yaoundé
/// cleanAddressPart(null)                     // ''
/// ```
String cleanAddressPart(Object? value) {
  if (value == null) return '';
  final String text = value.toString().trim();
  if (text.isEmpty) return '';
  return text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty && !_isPlaceholder(p)).join(', ');
}

/// One stored address string (a ride's `sourceLocationName`, a parcel
/// party's `address`, a store's `location`) for display: [cleanAddressPart],
/// or [fallback] when nothing is left.
String displayAddress(Object? value, {String fallback = ''}) {
  final String cleaned = cleanAddressPart(value);
  return cleaned.isEmpty ? fallback : cleaned;
}

/// `spideliFormatAddress`: the fields [keys] of a stored address map (an
/// order's `address`, a `shippingAddress[]` entry), cleaned and de-duplicated
/// by [formatAddressLine]. `''` for anything that is not a map.
String formatAddressMap(Object? address, {List<String> keys = const ['address', 'locality', 'landmark']}) {
  if (address is! Map) return '';
  return formatAddressLine(keys.map((key) => address[key]));
}

/// The same rule over parts already in hand, in order: each part cleaned by
/// [cleanAddressPart], a part repeating an earlier part's cleaned text
/// (case-insensitive) skipped, the rest joined with [separator].
///
/// ```dart
/// formatAddressLine(['123 Yaounde St', 'null, Tsinga', '  ']) // 123 Yaounde St, Tsinga
/// ```
String formatAddressLine(Iterable<Object?> parts, {String separator = ', '}) {
  final Set<String> seen = <String>{};
  final List<String> out = <String>[];
  for (final Object? part in parts) {
    final String cleaned = cleanAddressPart(part);
    if (cleaned.isEmpty) continue;
    if (!seen.add(cleaned.toLowerCase())) continue;
    out.add(cleaned);
  }
  return out.join(separator);
}

bool _isPlaceholder(String segment) {
  switch (segment.toLowerCase()) {
    case 'null':
    case 'undefined':
    case 'nil':
      return true;
    default:
      return false;
  }
}
