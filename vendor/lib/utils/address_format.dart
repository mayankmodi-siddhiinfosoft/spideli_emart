/// One place that turns address pieces into text people can read.
///
/// Firestore rows written by the panels and by older app builds carry missing
/// parts in three shapes: a real `null`, an empty string, and the *string*
/// `"null"` (a `"$value"` interpolation of a null). Rendering them straight
/// produced lines such as "123 Yaounde St, null, Tsinga" (client report #17).
/// Every address shown in the Store app goes through [formatAddress] so a
/// missing part simply disappears, together with the separator that would
/// have introduced it.
library;

/// True when [value] carries no usable text: null, blank, or one of the
/// placeholder words a null ended up being written as.
bool isBlankAddressPart(Object? value) {
  if (value == null) return true;
  final String text = value.toString().trim();
  if (text.isEmpty) return true;
  switch (text.toLowerCase()) {
    case 'null':
    case 'nil':
    case 'none':
    case 'undefined':
    case '-':
    case ',':
      return true;
  }
  return false;
}

/// Joins [parts] with [separator], dropping blank / "null" parts and trimming
/// what is left. Returns `''` when nothing usable remains, so callers can fall
/// back to their own placeholder.
String formatAddress(Iterable<Object?> parts, {String separator = ', '}) {
  final List<String> kept = [];
  for (final Object? part in parts) {
    if (isBlankAddressPart(part)) continue;
    final String text = _collapse(part.toString());
    if (text.isEmpty) continue;
    // The same line twice (address == locality happens on panel-created rows)
    // reads as a mistake, so keep only the first.
    if (kept.any((e) => e.toLowerCase() == text.toLowerCase())) continue;
    kept.add(text);
  }
  return kept.join(separator);
}

/// Collapses runs of whitespace and the separators a dropped part leaves
/// behind (", ,", " ,", a leading / trailing comma).
String _collapse(String value) {
  String text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  // "null" written inside a single stored string, e.g. "A, null, B".
  text = text.replaceAll(RegExp(r'(^|,)\s*null\s*(?=,|$)', caseSensitive: false), ',');
  text = text.replaceAll(RegExp(r'(\s*,\s*){2,}'), ', ');
  text = text.replaceAll(RegExp(r'^\s*[,;]\s*'), '');
  text = text.replaceAll(RegExp(r'\s*[,;]\s*$'), '');
  return text.trim();
}

/// "12.97000, 77.59460" - the coordinates of a picked point, for the places
/// that show where a store sits as well as its address.
String formatLatLng(double? latitude, double? longitude, {int digits = 5}) {
  if (latitude == null || longitude == null) return '';
  return '${latitude.toStringAsFixed(digits)}, ${longitude.toStringAsFixed(digits)}';
}
