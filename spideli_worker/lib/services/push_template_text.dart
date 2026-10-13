/// Placeholders in `dynamic_notification` template text (same helper as the
/// Driver app's).
///
/// The admin writes a template's `subject` / `message` with `{name}`
/// placeholders - the same `{amount}` / `{username}` style the email
/// templates already use - and the app fills them in before sending
/// ([fill]). Names match case-insensitively (`{workerName}` = `{workername}`).
/// A placeholder the push has no value for is left as written, so a typo in
/// a template shows up instead of silently disappearing.
abstract final class PushTemplateText {
  static final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

  /// [text] with every `{name}` that [values] has (keys compared
  /// case-insensitively) replaced by its value; '' for a null [text].
  static String fill(String? text, Map<String, String> values) {
    final String source = text ?? '';
    if (source.isEmpty || values.isEmpty) return source;
    final Map<String, String> byName = {for (final MapEntry<String, String> e in values.entries) e.key.toLowerCase(): e.value};
    return source.replaceAllMapped(_placeholder, (Match m) => byName[m.group(1)!.toLowerCase()] ?? m.group(0)!);
  }

  /// Whether a template read for [type] is a real one: `getNotificationContent`
  /// answers a stub ("setup notification", no id, no type) when the admin has
  /// not created it, and a template with no text would send an empty push.
  static bool isSetUp({required String type, String? templateId, String? templateType, String? subject, String? message}) {
    final bool exists = (templateId ?? '').trim().isNotEmpty || (templateType ?? '').trim() == type.trim();
    return exists && ((subject ?? '').trim().isNotEmpty || (message ?? '').trim().isNotEmpty);
  }
}
