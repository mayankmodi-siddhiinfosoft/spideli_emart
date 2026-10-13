/// Spideli Finance, customer side: the pure rules the screens show
/// (`finance/README.md`). Unit tested in test/finance_rules_test.dart.
///
/// The SERVER decides every status, balance and requirement; these helpers
/// only present what it stored, and mirror its checks so the app can say what
/// is missing before calling it.
library;

/// [s] as a left-to-right isolate (U+2066 ... U+2069): dates, amounts and
/// references keep their order inside right-to-left (Arabic) text.
String ltr(String s) => '\u2066$s\u2069';

/// A reference ("SPL-DEMO-0005") kept on one line and in order: non-breaking hyphens, left-to-right.
String ltrRef(Object? s) => ltr('${s ?? ''}'.replaceAll('-', '\u2011'));

/// Money as the ledger stores it: integer minor units + ISO code.
abstract final class FinanceMoney {
  /// ISO 4217 exponents (a standard, not a business value), as on the server.
  static const Map<String, int> _exponents = {
    'XAF': 0, 'XOF': 0, 'GNF': 0, 'RWF': 0, 'USD': 2, 'EUR': 2, 'GBP': 2, 'NGN': 2, 'GHS': 2, 'KES': 2,
  };

  static int exponent(String currency) => _exponents[currency] ?? 2;

  /// The amount as a left-to-right isolate (U+2066 ... U+2069), so it reads
  /// "245 000 XAF" inside right-to-left (Arabic) text instead of having its
  /// digit groups reordered. Invisible in left-to-right text.
  static String format(num minor, String currency) => ltr(plain(minor, currency));

  /// "+1 500 XAF" / "-1 500 XAF": the sign stays with the amount in right-to-left text.
  static String signed(num minor, String currency) => ltr('${minor > 0 ? '+' : ''}${plain(minor, currency)}');

  /// "1 500 000 XAF", "12.50 USD", "-0.05 EUR" (no direction marks: PDFs, tests).
  static String plain(num minor, String currency) {
    final int e = exponent(currency);
    final int value = minor.round();
    final bool negative = value < 0;
    final int abs = value.abs();
    int unit = 1;
    for (int i = 0; i < e; i++) {
      unit *= 10;
    }
    final String major = (abs ~/ unit).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    final String fraction = e == 0 ? '' : '.${(abs % unit).toString().padLeft(e, '0')}';
    return '${negative ? '-' : ''}$major$fraction $currency';
  }
}

/// KYC application statuses (server `kyc/states.ts`).
abstract final class KycStatus {
  static const String draft = 'draft';
  static const String submitted = 'submitted';
  static const String underReview = 'under_review';
  static const String additionalInfo = 'additional_info_required';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  /// Translation key of a status label.
  static String label(String? status) {
    switch (status) {
      case draft:
        return 'Not submitted';
      case submitted:
        return 'Submitted';
      case underReview:
        return 'Under review';
      case additionalInfo:
        return 'More information needed';
      case approved:
        return 'Verified';
      case rejected:
        return 'Not approved';
    }
    return 'Not verified';
  }

  /// The tone of a status: success / warning / danger / info / neutral.
  static String tone(String? status) {
    switch (status) {
      case approved:
        return 'success';
      case submitted:
      case underReview:
        return 'info';
      case additionalInfo:
        return 'warning';
      case rejected:
        return 'danger';
    }
    return 'neutral';
  }

  /// The owner may edit details and documents (draft, or a reviewer asked for more).
  static bool ownerMayEdit(String? status) => status == draft || status == additionalInfo;

  /// Still in progress (only one open application per level).
  static bool isOpen(String? status) => status != approved && status != rejected;
}

/// KYC requirements from `platform_settings/kyc` (server `parseKycConfig`).
class KycSettings {
  final Map<String, List<String>> documentSides;
  final Map<String, KycLevel> levels;
  final List<String> allowedContentTypes;
  final int maxFileBytes;

  const KycSettings({required this.documentSides, required this.levels, required this.allowedContentTypes, required this.maxFileBytes});

  /// Null when the configuration is missing or malformed (the server refuses too).
  static KycSettings? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final types = raw['documentTypes'];
    final levels = raw['levels'];
    if (types is! Map || levels is! Map) return null;
    final Map<String, List<String>> sides = {};
    for (final e in types.entries) {
      final s = (e.value is Map) ? (e.value as Map)['sides'] : null;
      if (s is! List || s.isEmpty) return null;
      sides[e.key.toString()] = s.map((x) => x.toString()).toList();
    }
    final Map<String, KycLevel> parsed = {};
    for (final e in levels.entries) {
      final v = e.value;
      if (v is! Map || v['accountTypes'] is! List || v['requiredDocuments'] is! List) return null;
      final groups = <List<String>>[];
      for (final g in v['requiredDocuments'] as List) {
        final any = g is Map ? g['anyOf'] : null;
        if (any is! List || any.isEmpty || any.any((t) => !sides.containsKey(t.toString()))) return null;
        groups.add(any.map((t) => t.toString()).toList());
      }
      parsed[e.key.toString()] = KycLevel(
        id: e.key.toString(),
        accountTypes: (v['accountTypes'] as List).map((t) => t.toString()).toList(),
        requiredDocuments: groups,
      );
    }
    final ct = raw['allowedContentTypes'];
    final max = raw['maxFileBytes'];
    if (ct is! List || ct.isEmpty || max is! num || max <= 0) return null;
    return KycSettings(documentSides: sides, levels: parsed, allowedContentTypes: ct.map((x) => x.toString()).toList(), maxFileBytes: max.toInt());
  }

  /// The levels offered to an account type, in configuration order.
  List<KycLevel> levelsFor(String accountType) => levels.values.where((l) => l.accountTypes.contains(accountType)).toList();

  /// The any-of groups not yet met (server `missingDocuments`): a group is met
  /// when one of its types has every side uploaded or accepted.
  List<List<String>> missingGroups(String level, List<KycDocumentRef> docs) {
    final lvl = levels[level];
    if (lvl == null) return const [];
    final live = docs.where((d) => d.status == 'uploaded' || d.status == 'accepted').toList();
    bool complete(String type) => (documentSides[type] ?? const []).every((side) => live.any((d) => d.type == type && d.side == side));
    return lvl.requiredDocuments.where((g) => !g.any(complete)).toList();
  }
}

class KycLevel {
  final String id;
  final List<String> accountTypes;
  final List<List<String>> requiredDocuments;

  const KycLevel({required this.id, required this.accountTypes, required this.requiredDocuments});
}

class KycDocumentRef {
  final String type;
  final String side;
  final String status;

  const KycDocumentRef(this.type, this.side, this.status);
}

/// Translation keys of the server's error reasons (`details.reason`).
abstract final class FinanceErrors {
  static const Map<String, String> _messages = {
    'kyc_not_configured': 'Identity verification is not available yet. Please try again later.',
    'kyc_application_open': 'You already have a verification in progress.',
    'kyc_level_approved': 'This verification level is already approved.',
    'kyc_not_editable': 'Your verification is being reviewed and cannot be changed now.',
    'kyc_documents_missing': 'Please add every required document before submitting.',
    'kyc_personal_details_missing': 'Please enter your full name before submitting.',
    'kyc_business_details_missing': 'Please enter the company name and registration number before submitting.',
    'kyc_file_type': 'This file type is not accepted. Please use a photo.',
    'kyc_file_size': 'This file is too large.',
    'kyc_file_missing': 'The upload did not finish. Please try again.',
    'kyc_invalid_transition': 'This action is no longer possible. Please refresh.',
    'insufficient_funds': 'Insufficient balance.',
    'fund_closed': 'This fund does not accept new investments at the moment.',
    'terms_outdated': 'The fund terms changed. Please read and accept the new version.',
    'below_minimum': 'The amount is below the minimum.',
    'not_eligible': 'You are not eligible for this fund.',
    'locked_up': 'Part of this investment is still in its lock-up period.',
    'redemption_not_allowed': 'This fund does not accept redemptions at the moment.',
    'insufficient_units': 'You do not hold enough units for this redemption.',
    'quote_expired': 'This quote is no longer valid. Request a new one.',
    'product_closed': 'This insurance is not offered at the moment.',
    'policy_not_active': 'This policy is not active.',
    'claim_not_editable': 'This claim can no longer be changed.',
    'insurer_unavailable': 'The insurer cannot be reached right now. Please try again later.',
    'reauth_required': 'For your security, confirm your identity and try again.',
    'card_limit_reached': 'You already have the maximum number of cards.',
    'card_not_active': 'This card cannot be used for this action right now.',
    'issuer_unavailable': 'The card issuer cannot be reached right now. Please try again later.',
    'amount_out_of_range': 'This amount is outside the allowed range.',
    'not_supported': 'The card issuer does not support this action.',
    'recipient_not_found': 'We could not find a Spideli account with these details.',
    'recipient_invalid': 'The recipient\'s account could not be verified. Check the details.',
    'self_transfer': 'You cannot send money to yourself.',
    'daily_limit_exceeded': 'This amount is above your limit for today.',
    'request_expired': 'This request expired. Please start again.',
    'biller_unavailable': 'The biller cannot be reached right now. Please try again later.',
    'account_not_found': 'This account number was not found by the biller.',
    'provider_unavailable': 'The payment service cannot be reached right now. Please try again later.',
    'financing_documents_missing': 'Please add every required document before submitting.',
    'financing_not_editable': 'This application can no longer be changed.',
    'business_kyc_required': 'A business verification is needed to apply for financing.',
    'coach_consent_required': 'Please accept the coach terms first.',
    'coach_limit_reached': 'You have reached today\'s limit of questions. Please come back tomorrow.',
    'coach_unavailable': 'The coach is not available right now. Please try again later.',
    'opportunity_closed': 'This opportunity is closed.',
    'sign_in_required': 'Please sign in again.',
    'unauthenticated': 'Please sign in again.',
  };

  static String messageKey(String? reason) => _messages[reason] ?? 'Something went wrong. Please try again.';
}

/// A ledger transaction from the user's side: how it moved THEIR money.
abstract final class LedgerView {
  /// The signed amount for the user's accounts in [accountSides]
  /// (accountId -> normal side): positive = money in, negative = money out.
  static int signedAmount(List<Map<String, dynamic>> lines, Map<String, String> accountSides) {
    int total = 0;
    for (final l in lines) {
      final String? side = accountSides[l['accountId']?.toString()];
      if (side == null) continue;
      final int amount = (l['amount'] as num?)?.toInt() ?? 0;
      total += l['direction'] == side ? amount : -amount;
    }
    return total;
  }

  /// Translation key of a ledger transaction type.
  static String typeLabel(String? type) {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'withdrawal':
        return 'Withdrawal';
      case 'transfer':
        return 'Transfer';
      case 'manual_adjustment':
        return 'Adjustment';
      case 'reversal':
        return 'Reversal';
    }
    return 'Transaction';
  }
}

/// `finance_summaries/{uid}`: the dashboard totals, maintained by the SERVER
/// (.claude/FINANCE-APP-CONTRACT.md section 4). The app never adds amounts up
/// itself; a missing section means the user has not used that module yet.
/// Amounts are integer minor units in `currency`.
class FinanceSummary {
  final String currency;
  final DateTime? updatedAt;
  final Map<String, int>? investments;
  final Map<String, dynamic>? tontines;
  final Map<String, dynamic>? savings;
  final Map<String, dynamic>? loans;
  final Map<String, dynamic>? insurance;
  final Map<String, int> last30Days;
  final List<MonthlyFlow> monthly;

  const FinanceSummary({
    required this.currency,
    this.updatedAt,
    this.investments,
    this.tontines,
    this.savings,
    this.loans,
    this.insurance,
    this.last30Days = const {},
    this.monthly = const [],
  });

  static int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

  static Map<String, dynamic>? _section(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

  /// Null when there is no summary yet (or no currency to read it in).
  static FinanceSummary? parse(Map<String, dynamic>? raw, {DateTime? Function(dynamic)? toDate}) {
    if (raw == null) return null;
    final String currency = raw['currency']?.toString() ?? '';
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) return null;
    final inv = _section(raw['investments']);
    final payments = _section(raw['payments']);
    final last30 = payments == null ? null : _section(payments['last30Days']);
    final List<MonthlyFlow> monthly = [];
    if (raw['monthly'] is List) {
      for (final m in raw['monthly'] as List) {
        if (m is! Map) continue;
        final String month = m['month']?.toString() ?? '';
        if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) continue;
        monthly.add(MonthlyFlow(month, _int(m['moneyIn']), _int(m['moneyOut'])));
      }
      monthly.sort((a, b) => a.month.compareTo(b.month));
    }
    return FinanceSummary(
      currency: currency,
      updatedAt: toDate?.call(raw['updatedAt']),
      investments: inv == null
          ? null
          : {for (final k in const ['investedCapital', 'currentValuation', 'realizedGains', 'unrealizedGains']) k: _int(inv[k])},
      tontines: _section(raw['tontines']),
      savings: _section(raw['savings']),
      loans: _section(raw['loans']),
      insurance: _section(raw['insurance']),
      last30Days: last30 == null ? const {} : {for (final e in last30.entries) e.key: _int(e.value)},
      monthly: monthly.length > 12 ? monthly.sublist(monthly.length - 12) : monthly,
    );
  }

  /// Savings progress 0..1 (amount actually saved over the target), null without a target.
  double? get savingsProgress {
    final s = savings;
    if (s == null) return null;
    final int target = _int(s['targetAmount']);
    if (target <= 0) return null;
    return (_int(s['savedAmount']) / target).clamp(0, 1).toDouble();
  }

  /// Investment gain (realized + unrealized) in minor units.
  int get totalGains => (investments?['realizedGains'] ?? 0) + (investments?['unrealizedGains'] ?? 0);

  /// The largest monthly flow, to scale the chart (at least 1).
  int get chartMax => monthly.fold<int>(1, (m, f) => [m, f.moneyIn, f.moneyOut].reduce((a, b) => a > b ? a : b));

  static int intOf(dynamic v) => _int(v);
}

class MonthlyFlow {
  final String month;
  final int moneyIn;
  final int moneyOut;

  const MonthlyFlow(this.month, this.moneyIn, this.moneyOut);
}

/// One statement line: a ledger transaction from the user's side.
class StatementRow {
  final DateTime? at;
  final String reference;
  final String type;
  final String status;
  final int signedAmount;
  final String currency;

  const StatementRow({required this.at, required this.reference, required this.type, required this.status, required this.signedAmount, required this.currency});
}

abstract final class FinanceStatement {
  /// Rows from `ledger_transactions` documents (oldest first) for the user's
  /// accounts in [accountSides]. [toDate] converts the stored timestamp.
  static List<StatementRow> rows(List<Map<String, dynamic>> transactions, Map<String, String> accountSides, DateTime? Function(dynamic) toDate) {
    final out = transactions.map((t) {
      final lines = ((t['lines'] as List?) ?? const []).whereType<Map>().map((l) => Map<String, dynamic>.from(l)).toList();
      return StatementRow(
        at: toDate(t['createdAt']),
        reference: t['reference']?.toString() ?? '',
        type: t['type']?.toString() ?? '',
        status: t['status']?.toString() ?? '',
        signedAmount: LedgerView.signedAmount(lines, accountSides),
        currency: t['currency']?.toString() ?? '',
      );
    }).toList();
    out.sort((a, b) => (a.at ?? DateTime(0)).compareTo(b.at ?? DateTime(0)));
    return out;
  }

  /// Money in and money out per currency (a reversed transaction and its
  /// reversal both appear, and cancel each other out).
  static Map<String, ({int moneyIn, int moneyOut})> totals(List<StatementRow> rows) {
    final Map<String, ({int moneyIn, int moneyOut})> t = {};
    for (final r in rows) {
      final cur = t[r.currency] ?? (moneyIn: 0, moneyOut: 0);
      t[r.currency] = r.signedAmount >= 0 ? (moneyIn: cur.moneyIn + r.signedAmount, moneyOut: cur.moneyOut) : (moneyIn: cur.moneyIn, moneyOut: cur.moneyOut - r.signedAmount);
    }
    return t;
  }
}
