// The one place this app turns address parts into a line of text.
//
// Report 02#18 (01#17): addresses rendered as "123 Yaounde St, null, Tsinga".
// A field that exists but holds `null` was interpolated as the word "null",
// and reverse-geocoded `locality` strings reach Firestore with "null" already
// baked in ("18, null, Yaoundé, Région du Centre, null, Cameroun").
//
// This is a line-for-line port of the web panels' `spideliCleanAddressPart`
// / `spideliFormatAddress`, so the apps and the panels show the same text:
// * a part that is null, empty, or whose comma segment is the literal
//   `null` / `undefined` / `nil` (any case) is dropped -- whole segments only,
//   so "Nullarbor Road" and "Annullata Street" survive;
// * a part whose cleaned text repeats an earlier part (case-insensitively) is
//   dropped -- the same text is often stored in two fields;
// * '' when nothing is left, so the caller can hide the row.
// Storage is untouched.
//
// ```dart
// formatAddressParts(['123 Yaounde St', 'null, Tsinga', '  ']); // 123 Yaounde St, Tsinga
// ```

/// `spideliCleanAddressPart`: trims [value], splits it on commas, drops the
/// empty and placeholder segments and rejoins the rest with ", ".
String cleanAddressPart(Object? value) {
  if (value == null) return '';
  final String text = value.toString().trim();
  if (text.isEmpty) return '';
  return text.split(',').map((String p) => p.trim()).where((String p) {
    final String l = p.toLowerCase();
    return p.isNotEmpty && l != 'null' && l != 'undefined' && l != 'nil';
  }).join(', ');
}

/// `spideliFormatAddress` over a list of parts (in display order): each part
/// is cleaned with [cleanAddressPart], empty and repeated parts are skipped,
/// the rest joined with ", ".
String formatAddressParts(List<Object?> parts) {
  final Set<String> seen = <String>{};
  final List<String> out = <String>[];
  for (final Object? part in parts) {
    final String cleaned = cleanAddressPart(part);
    if (cleaned.isEmpty) continue;
    if (!seen.add(cleaned.toLowerCase())) continue;
    out.add(cleaned);
  }
  return out.join(', ');
}

/// `spideliFormatAddress(address, keys)` for a stored address map; [keys]
/// defaults to the panels' `address`, `locality`, `landmark`.
String formatAddressMap(Map<String, dynamic>? address, {List<String> keys = const <String>['address', 'locality', 'landmark']}) {
  if (address == null) return '';
  return formatAddressParts(keys.map((String key) => address[key]).toList());
}

/// [formatAddressParts] for a single, already-joined address string.
String formatAddressText(Object? address) => formatAddressParts(<Object?>[address]);
