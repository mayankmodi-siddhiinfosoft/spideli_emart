/// One place that turns address parts into something a human reads.
///
/// Client point 17 / 02#18: addresses were built with plain string
/// interpolation, so a missing part came out as the literal `null` ("123
/// Yaounde St, null, Tsinga") and an empty part left a dangling comma. Worse,
/// a reverse-geocoded line reaches Firestore already joined with the word
/// baked in ("18, null, Yaoundé, Région du Centre, null, Cameroun"), so every
/// part is also split on its commas.
///
/// The rule is the web panels' `spideliCleanAddressPart` /
/// `spideliFormatAddress` (and the customer app's `formatAddressLine`):
/// - drop WHOLE comma-separated segments that are empty, `null`, `nil`,
///   `undefined` or `-` (case-insensitive) — "Nullarbor Road" and "Annullata
///   Street" survive;
/// - drop a whole field whose cleaned text repeats an earlier field's
///   (case-insensitive) — single segments are never de-duplicated;
/// - `''` when nothing is left, so the caller can hide the row.
///
/// Display and composition only: stored data is never rewritten.
class AddressFormat {
  AddressFormat._();

  /// A single part with its blank / placeholder segments dropped, or `null`
  /// when nothing worth showing is left. An already-joined value keeps its
  /// remaining segments, joined with `, `.
  static String? part(dynamic value) {
    if (value == null) return null;
    final List<String> segments = <String>[];
    for (final String piece in value.toString().split(',')) {
      final String segment = piece.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (segment.isEmpty || _isPlaceholder(segment)) continue;
      segments.add(segment);
    }
    return segments.isEmpty ? null : segments.join(', ');
  }

  /// True when [value] has nothing worth showing.
  static bool isBlank(dynamic value) => part(value) == null;

  /// Joins [parts] with [separator]: each part cleaned by [part], blank parts
  /// dropped, and a part repeating an earlier part's text (e.g. the locality
  /// also stored in the address line) dropped whole. `''` when nothing is
  /// left. Commas inside one part stay `, `; [separator] only goes between
  /// parts.
  static String join(Iterable<dynamic> parts, {String separator = ', '}) {
    final List<String> kept = <String>[];
    final Set<String> seen = <String>{};
    for (final raw in parts) {
      final String? value = part(raw);
      if (value == null) continue;
      if (!seen.add(value.toLowerCase())) continue;
      kept.add(value);
    }
    return kept.join(separator);
  }

  /// Cleans one already-built address string: drops `null` / blank segments,
  /// repeated separators and the leading / trailing ones. `''` when nothing
  /// is left.
  static String clean(dynamic value, {String separator = ', '}) {
    final String? text = part(value);
    if (text == null) return '';
    return separator == ', ' ? text : text.split(', ').join(separator);
  }

  /// Convenience for the very common "show this address or a placeholder".
  static String orPlaceholder(dynamic value, {String placeholder = '—'}) {
    final String text = clean(value);
    return text.isEmpty ? placeholder : text;
  }

  static bool _isPlaceholder(String segment) {
    switch (segment.toLowerCase()) {
      case 'null':
      case 'nil':
      case 'undefined':
      case '-':
        return true;
      default:
        return false;
    }
  }
}
