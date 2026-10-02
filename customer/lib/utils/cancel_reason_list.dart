/// One entry of the cancellation reason list: [label] is shown to people,
/// [code] is written as `cancelReasonCode` ("other" for free text).
class CancelReasonOption {
  final String label;
  final String code;

  const CancelReasonOption({required this.label, required this.code});

  bool get isOther => code.toLowerCase() == 'other';

  @override
  bool operator ==(Object other) => other is CancelReasonOption && other.label == label && other.code == code;

  @override
  int get hashCode => Object.hash(label, code);

  @override
  String toString() => 'CancelReasonOption($code, $label)';
}

/// Reads `settings/cancellationReasons` the way the web panels do
/// (BUG-REPORT-01 §3, 02#15), plus the app's per-role key:
///
/// - the first of [roleKeys], then `reasons`, then `list`, that holds a
///   usable array;
/// - each entry a string, or a map with `code` and `label` (or `text` /
///   `reason` / `name`) — a map's `code` is the stored code, a string's code
///   is its own text (the app's existing behaviour);
/// - [defaults] when nothing usable is stored;
/// - "Other" (code `other`) always offered exactly once, last; a stored
///   other entry keeps its own label.
List<CancelReasonOption> parseCancelReasonList(Map<String, dynamic>? data, {required List<String> roleKeys, required List<String> defaults}) {
  List<CancelReasonOption> options = [];
  if (data != null) {
    for (final key in [...roleKeys, 'reasons', 'list']) {
      options = _parseEntries(data[key]);
      if (options.any((e) => !e.isOther)) break;
      options = [];
    }
  }
  if (options.isEmpty) options = _parseEntries(defaults);

  CancelReasonOption other = const CancelReasonOption(label: 'Other', code: 'other');
  final seen = <String>{};
  final out = <CancelReasonOption>[];
  for (final option in options) {
    if (option.isOther) {
      other = option;
      continue;
    }
    if (seen.add(option.code.toLowerCase())) out.add(option);
  }
  out.add(other);
  return out;
}

List<CancelReasonOption> _parseEntries(dynamic raw) {
  if (raw is! Iterable) return [];
  final out = <CancelReasonOption>[];
  for (final entry in raw) {
    if (entry is Map) {
      String label = '';
      for (final k in const ['label', 'text', 'reason', 'name']) {
        label = _clean(entry[k]);
        if (label.isNotEmpty) break;
      }
      final code = _clean(entry['code']);
      if (label.isEmpty) {
        // A bare {code: "other"} still means "Other".
        if (code.toLowerCase() == 'other') out.add(const CancelReasonOption(label: 'Other', code: 'other'));
        continue;
      }
      final isOther = code.toLowerCase() == 'other' || (code.isEmpty && label.toLowerCase() == 'other');
      out.add(CancelReasonOption(label: label, code: isOther ? 'other' : (code.isEmpty ? label : code)));
    } else {
      final label = _clean(entry);
      if (label.isEmpty) continue;
      out.add(CancelReasonOption(label: label, code: label.toLowerCase() == 'other' ? 'other' : label));
    }
  }
  return out;
}

String _clean(dynamic value) {
  if (value == null || value is Map || value is Iterable) return '';
  final text = value.toString().trim();
  final lower = text.toLowerCase();
  return lower == 'null' || lower == 'undefined' ? '' : text;
}
