/// Spideli Finance account security, the pure rules
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.12): the blacklist
/// (`users/{uid}.financeRestriction`, written by the admin only) and the
/// customer's notification preferences (`users/{uid}.financeNotificationPrefs`,
/// written by the customer). Pure Dart (no Flutter, no Firebase), unit tested
/// in test/finance_security_test.dart.
library;

/// The admin's restriction of a user in a situation of insolvency
/// (blacklist): `{status: "restricted", reason, since, scopes: [...]}`.
abstract final class FinanceRestriction {
  /// The field of `users/{uid}`.
  static const String field = 'financeRestriction';

  /// Scopes the admin sets. Other modules may pass their own name (e.g.
  /// 'savings'): only a restriction listing it, or 'all', covers it.
  static const String loans = 'loans';
  static const String tontines = 'tontines';
  static const String all = 'all';

  /// The restriction on [userDoc] (the data of `users/{uid}`), or null when
  /// the user is not restricted. A restriction without scopes covers
  /// everything: when the admin did not say what is blocked, nothing is
  /// allowed rather than everything. [toDate] reads `since` when it is a
  /// Firestore Timestamp (DateTime, epoch millis and ISO text are read here).
  static FinanceRestrictionInfo? of(Map<String, dynamic>? userDoc, {DateTime? Function(Object? value)? toDate}) {
    final Object? raw = userDoc?[field];
    if (raw is! Map) return null;
    if (raw['status']?.toString().trim().toLowerCase() != 'restricted') return null;
    final Object? list = raw['scopes'];
    final List<String> scopes = <String>{
      if (list is List)
        for (final s in list)
          if ('${s ?? ''}'.trim().isNotEmpty) '$s'.trim().toLowerCase(),
    }.toList();
    return FinanceRestrictionInfo(
      reason: '${raw['reason'] ?? ''}'.trim(),
      since: _date(raw['since'], toDate),
      scopes: scopes.isEmpty ? const [all] : scopes,
    );
  }

  /// True when [userDoc]'s restriction covers [scope] ('loans', 'tontines'
  /// or any module name): a restriction on 'all' covers every scope. The
  /// app blocks the action; the Firestore rules refuse it too.
  static bool blocks(Map<String, dynamic>? userDoc, String scope) => of(userDoc)?.covers(scope) ?? false;

  static DateTime? _date(Object? v, DateTime? Function(Object? value)? toDate) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return toDate?.call(v);
  }
}

/// A restriction read by [FinanceRestriction.of].
class FinanceRestrictionInfo {
  /// The admin's reason (may be empty).
  final String reason;
  final DateTime? since;

  /// Lower-case scopes, never empty ('all' when the admin listed none).
  final List<String> scopes;

  const FinanceRestrictionInfo({required this.reason, required this.since, required this.scopes});

  /// Every Spideli Finance service is blocked.
  bool get isTotal => scopes.contains(FinanceRestriction.all);

  bool covers(String scope) => isTotal || scopes.contains(scope.trim().toLowerCase());
}

/// What Spideli Finance may send the user, per channel and category:
/// `{push: {...}, sms: {...}, email: {...}}`, each `{payments, groups, loans,
/// investments, insurance, news}` true / false. The admin's senders read it
/// (SMS and e-mail are sent by the admin side); security notices are always
/// sent and are not a preference.
abstract final class FinanceNotificationPrefs {
  /// The field of `users/{uid}`.
  static const String field = 'financeNotificationPrefs';

  static const String push = 'push';
  static const String sms = 'sms';
  static const String email = 'email';
  static const List<String> channels = [push, sms, email];

  /// Payments, transfers, bills, deposits, withdrawals and their receipts.
  static const String payments = 'payments';

  /// Savings goals and tontines.
  static const String groups = 'groups';
  static const String loans = 'loans';
  static const String investments = 'investments';
  static const String insurance = 'insurance';

  /// News and markets.
  static const String news = 'news';
  static const List<String> categories = [payments, groups, loans, investments, insurance, news];

  /// Sign-ins, password and two-step verification changes: always sent.
  static const String security = 'security';

  /// Before the user chooses: every push; SMS for payments and transfers
  /// only (they cost); e-mail receipts (payments) only.
  static const Map<String, Map<String, bool>> defaults = {
    push: {payments: true, groups: true, loans: true, investments: true, insurance: true, news: true},
    sms: {payments: true, groups: false, loans: false, investments: false, insurance: false, news: false},
    email: {payments: true, groups: false, loans: false, investments: false, insurance: false, news: false},
  };

  /// The complete preferences from the stored [raw] value: each choice the
  /// user made (a bool), the default for every other one. Unknown channels,
  /// categories and non-bool values are ignored.
  static Map<String, Map<String, bool>> resolve(Object? raw) {
    final Map stored = raw is Map ? raw : const {};
    Map<String, bool> channel(String ch) {
      final Object? chosen = stored[ch];
      return {for (final cat in categories) cat: (chosen is Map ? _bool(chosen[cat]) : null) ?? defaults[ch]![cat]!};
    }

    return {for (final ch in channels) ch: channel(ch)};
  }

  /// [prefs] (resolved) with [channel] / [category] set to [on]: a new,
  /// complete map, the value written to `financeNotificationPrefs`. An
  /// unknown channel or category changes nothing.
  static Map<String, Map<String, bool>> withChoice(Map<String, Map<String, bool>> prefs, String channel, String category, bool on) {
    final Map<String, Map<String, bool>> next = resolve(prefs);
    if (next.containsKey(channel) && categories.contains(category)) next[channel]![category] = on;
    return next;
  }

  /// Whether [category] may be sent on [channel] to the owner of [userDoc]
  /// (the data of `users/{uid}`). Security notices always may.
  static bool allows(Map<String, dynamic>? userDoc, String channel, String category) {
    if (category == security) return true;
    return resolve(userDoc?[field])[channel]?[category] ?? false;
  }

  static bool? _bool(Object? v) => v is bool ? v : null;
}
