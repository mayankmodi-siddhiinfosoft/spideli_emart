/// One entry of the driver's cancellation / rejection reason list: [label] is
/// shown to people (and written as the reason), [code] is the stable value
/// written as `driverRejections[].code` / `cancelReasonCode` ("other" for
/// free text).
class CancelReasonOption {
  final String label;
  final String code;

  const CancelReasonOption({required this.label, required this.code});

  static const String otherCode = 'other';
  static const CancelReasonOption other = CancelReasonOption(label: 'Other', code: otherCode);

  /// The free-text entry: it needs typed text and writes code "other".
  bool get isOther => code.toLowerCase() == otherCode;

  @override
  bool operator ==(Object other) => other is CancelReasonOption && other.label == label && other.code == code;

  @override
  int get hashCode => Object.hash(label, code);

  @override
  String toString() => 'CancelReasonOption($code, $label)';
}

/// Reads `settings/cancellationReasons` the way the web panels and the other
/// apps do (BUG-REPORT-01 §3, 02#15; `.claude/CANCEL-REASON-CONTRACT.md`):
///
/// - the first of [roleKeys] (`driver`), then `reasons`, then `list`, that
///   holds at least one reason other than "Other";
/// - each entry a string, or a map with the label in `label` / `text` /
///   `reason` / `name` / `title` and the code in `code` / `id` / `value` — a
///   map's code is the stored code, a string's code is its own text (what the
///   app always wrote);
/// - [defaults] when nothing usable is stored (blank, "null", or only Other);
/// - "Other" (code `other`) always offered exactly once, last; a stored
///   other entry keeps its own label (e.g. "Something else").
List<CancelReasonOption> parseCancelReasonList(Map<String, dynamic>? data, {required List<String> roleKeys, required List<String> defaults}) {
  List<CancelReasonOption> options = [];
  if (data != null) {
    for (final String key in [...roleKeys, 'reasons', 'list']) {
      options = _parseEntries(data[key]);
      if (options.any((o) => !o.isOther)) break;
      options = [];
    }
  }
  if (options.isEmpty) options = _parseEntries(defaults);

  CancelReasonOption? other;
  final Set<String> seen = {};
  final List<CancelReasonOption> out = [];
  for (final CancelReasonOption option in options) {
    if (option.isOther) {
      // Re-added once, last. The first entry with a label of its own ("Something
      // else") wins over a bare "other", which is shown as "Other".
      final CancelReasonOption candidate = option.label.toLowerCase() == CancelReasonOption.otherCode ? CancelReasonOption.other : option;
      if (other == null || other == CancelReasonOption.other) other = candidate;
      continue;
    }
    // The same reason listed twice would be two identical radio buttons.
    if (seen.add(option.code.toLowerCase())) out.add(option);
  }
  out.add(other ?? CancelReasonOption.other);
  return out;
}

/// One stored entry, or null when it holds nothing readable.
CancelReasonOption? parseCancelReasonEntry(Object? raw) {
  if (raw is Map) {
    final String? label = _text(raw['label']) ?? _text(raw['text']) ?? _text(raw['reason']) ?? _text(raw['name']) ?? _text(raw['title']);
    final String? code = _text(raw['code']) ?? _text(raw['id']) ?? _text(raw['value']);
    if (label == null) {
      // A bare {code: "other"} still means "Other"; any other bare code has
      // nothing to show and is dropped.
      return code?.toLowerCase() == CancelReasonOption.otherCode ? CancelReasonOption.other : null;
    }
    final bool isOther = code?.toLowerCase() == CancelReasonOption.otherCode || (code == null && label.toLowerCase() == CancelReasonOption.otherCode);
    return CancelReasonOption(label: label, code: isOther ? CancelReasonOption.otherCode : (code ?? label));
  }
  final String? text = _text(raw);
  if (text == null) return null;
  return CancelReasonOption(label: text, code: text.toLowerCase() == CancelReasonOption.otherCode ? CancelReasonOption.otherCode : text);
}

List<CancelReasonOption> _parseEntries(Object? raw) {
  if (raw is! Iterable) return [];
  return raw.map(parseCancelReasonEntry).whereType<CancelReasonOption>().toList();
}

String? _text(Object? value) {
  if (value is! String && value is! num) return null;
  final String text = value.toString().trim();
  final String lower = text.toLowerCase();
  if (text.isEmpty || lower == 'null' || lower == 'undefined') return null;
  return text;
}
