/// One place that turns address pieces into text people can read.
///
/// Firestore rows written by the panels and by older app builds carry missing
/// parts as a real `null`, an empty string, or the *string* `"null"` (a
/// `"$value"` interpolation of a null), sometimes already joined into one
/// value (`locality: "18, null, Yaoundé, Région du Centre, null, Cameroun"`).
/// Rendering them straight produced lines such as "123 Yaounde St, null,
/// Tsinga" (client report 02#18).
///
/// [spideliCleanAddressPart] and [spideliFormatAddress] mirror, rule for rule,
/// the helpers of the same name in all four web panels
/// (`BUG-REPORT-01-APP.md` §3 "02#18"), so the app and the panels show the
/// same text for the same record:
/// - a part that is null, empty, or whose comma-separated segments are
///   `null` / `undefined` / `nil` (any case) loses those segments; whole
///   segments only, so "Nullarbor Road" survives;
/// - a part whose cleaned text (case-insensitive) was already shown is
///   skipped (the same text is often stored in two fields);
/// - `''` when nothing is left, so the caller can hide the row.
///
/// Every address the Store app shows or prints goes through these.
library;

/// The segments of [value] that carry text, re-joined with ", "; `''` when
/// none does. Mirrors the panels' `spideliCleanAddressPart`.
String spideliCleanAddressPart(Object? value) {
  if (value == null) return '';
  final String text = value.toString().trim();
  if (text.isEmpty) return '';
  return text
      .split(',')
      .map((p) => p.trim())
      .where((p) {
        final String l = p.toLowerCase();
        return p.isNotEmpty && l != 'null' && l != 'undefined' && l != 'nil';
      })
      .join(', ');
}

/// The default fields of a stored address, in display order.
const List<String> spideliAddressKeys = ['address', 'locality', 'landmark'];

/// The readable address of a stored address map: the [keys] (default
/// `address`, `locality`, `landmark`) cleaned, a repeat of an earlier part
/// dropped, joined with ", ". `''` when [address] is not a map or nothing is
/// left. Mirrors the panels' `spideliFormatAddress`.
String spideliFormatAddress(Object? address, [List<String>? keys]) {
  if (address is! Map) return '';
  return formatAddress((keys ?? spideliAddressKeys).map((key) => address[key]));
}

/// [spideliFormatAddress] for parts the caller already has in hand (an order
/// model's fields, a store's single `location` string): each part cleaned
/// with [spideliCleanAddressPart], a part whose cleaned text was already shown
/// (case-insensitive) skipped, the rest joined with ", ". `''` when nothing
/// is left.
String formatAddress(Iterable<Object?> parts) {
  final Set<String> seen = {};
  final List<String> out = [];
  for (final Object? part in parts) {
    final String cleaned = spideliCleanAddressPart(part);
    if (cleaned.isEmpty) continue;
    // The same text is often in two fields.
    if (!seen.add(cleaned.toLowerCase())) continue;
    out.add(cleaned);
  }
  return out.join(', ');
}

/// "12.97000, 77.59460" - the coordinates of a picked point, for the places
/// that show where a store sits as well as its address.
String formatLatLng(double? latitude, double? longitude, {int digits = 5}) {
  if (latitude == null || longitude == null) return '';
  return '${latitude.toStringAsFixed(digits)}, ${longitude.toStringAsFixed(digits)}';
}
