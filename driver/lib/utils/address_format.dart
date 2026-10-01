/// One place that turns address parts into something a human reads.
///
/// Client point 17: addresses were built with plain string interpolation, so a
/// missing part came out as the literal `null` ("123 Yaounde St, null, Tsinga")
/// and an empty part left a dangling comma. Every screen that shows an address
/// goes through here instead.
class AddressFormat {
  AddressFormat._();

  /// A single part, or `null` when there is nothing worth showing: empty,
  /// whitespace only, or one of the strings a `toString()` of a missing value
  /// produces (`null`, `Null`, `nil`, `undefined`).
  static String? part(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    final String lower = text.toLowerCase();
    if (lower == 'null' || lower == 'nil' || lower == 'undefined' || lower == '-') return null;
    return text;
  }

  /// True when [value] has nothing worth showing.
  static bool isBlank(dynamic value) => part(value) == null;

  /// Joins [parts], dropping the blank ones, and collapses the separators that
  /// a dropped part would otherwise leave behind.
  static String join(Iterable<dynamic> parts, {String separator = ', '}) {
    final List<String> kept = [];
    for (final raw in parts) {
      final String? value = part(raw);
      if (value == null) continue;
      final String cleaned = clean(value, separator: separator);
      if (cleaned.isEmpty) continue;
      // The same part twice in a row (e.g. locality repeated in the address)
      // reads as a mistake; keep the first one.
      if (kept.isNotEmpty && kept.last.toLowerCase() == cleaned.toLowerCase()) continue;
      kept.add(cleaned);
    }
    return kept.join(separator);
  }

  /// Cleans one already-built address string: drops `null` segments, repeated
  /// separators and the leading / trailing ones.
  static String clean(dynamic value, {String separator = ', '}) {
    final String? text = part(value);
    if (text == null) return '';
    final List<String> segments = text
        .split(RegExp(r'\s*,\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && part(s) != null)
        .toList();
    if (segments.isEmpty) return '';
    return segments.join(separator).replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Convenience for the very common "show this address or a placeholder".
  static String orPlaceholder(dynamic value, {String placeholder = '—'}) {
    final String text = clean(value);
    return text.isEmpty ? placeholder : text;
  }
}
