/// One entry of a cancellation / rejection reason list: [label] is what the
/// store sees (and what is written as `cancelReason`), [code] the stable value
/// written as `cancelReasonCode`.
class CancelReasonOption {
  final String code;
  final String label;

  const CancelReasonOption({required this.code, required this.label});

  /// The free-text entry; it needs typed text and writes code "other".
  bool get isOther => code.toLowerCase() == otherCode;

  static const String otherCode = 'other';
  static const CancelReasonOption other = CancelReasonOption(code: otherCode, label: 'Other');

  @override
  bool operator ==(Object other) => other is CancelReasonOption && other.code == code && other.label == label;

  @override
  int get hashCode => Object.hash(code, label);

  @override
  String toString() => 'CancelReasonOption($code, $label)';
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is! String && value is! num) return null;
  final String text = value.toString().trim();
  final String lower = text.toLowerCase();
  if (text.isEmpty || lower == 'null' || lower == 'undefined') return null;
  return text;
}

/// One stored entry: a plain string (its text is both label and code, as the
/// app always wrote it) or a `{code, label}` map (`text` / `reason` / `name`
/// are read for the label as well). Null for anything unreadable.
CancelReasonOption? parseCancelReasonEntry(Object? raw) {
  if (raw is Map) {
    final String? label = _text(raw['label']) ?? _text(raw['text']) ?? _text(raw['reason']) ?? _text(raw['name']) ?? _text(raw['title']);
    final String? code = _text(raw['code']) ?? _text(raw['id']) ?? _text(raw['value']);
    if (label == null && code == null) return null;
    final String resolvedCode = code ?? label!;
    final bool isOther = resolvedCode.toLowerCase() == CancelReasonOption.otherCode || (label ?? '').toLowerCase() == CancelReasonOption.otherCode;
    return CancelReasonOption(code: isOther ? CancelReasonOption.otherCode : resolvedCode, label: label ?? resolvedCode);
  }
  final String? text = _text(raw);
  if (text == null) return null;
  return CancelReasonOption(code: text.toLowerCase() == CancelReasonOption.otherCode ? CancelReasonOption.otherCode : text, label: text);
}

/// The reason list from the `settings/cancellationReasons` document [data],
/// matching the admin and store panels: the first non-empty of `vendor`,
/// `store`, `reasons`, `list`, each an array of strings or `{code, label}`
/// maps. Falls back to [defaults] when none of them yields a reason.
///
/// "Other" (code `other`) is always offered, exactly once and last; a stored
/// "other" entry keeps its own label (e.g. "Something else").
List<CancelReasonOption> parseCancelReasons(Map<String, dynamic>? data, {required List<String> defaults}) {
  List<CancelReasonOption> options = [];
  if (data != null) {
    for (final String key in const ['vendor', 'store', 'reasons', 'list']) {
      final Object? raw = data[key];
      if (raw is Iterable) {
        options = raw.map(parseCancelReasonEntry).whereType<CancelReasonOption>().toList();
      }
      if (options.any((o) => !o.isOther)) break;
      options = [];
    }
  }
  if (options.isEmpty) {
    options = defaults.map(parseCancelReasonEntry).whereType<CancelReasonOption>().toList();
  }

  final CancelReasonOption other = options.firstWhere((o) => o.isOther, orElse: () => CancelReasonOption.other);
  final Set<String> seen = {};
  final List<CancelReasonOption> result = [];
  for (final CancelReasonOption option in options) {
    if (option.isOther) continue;
    // The same reason listed twice would be two identical radio buttons.
    if (!seen.add(option.code.toLowerCase())) continue;
    result.add(option);
  }
  result.add(other);
  return result;
}
