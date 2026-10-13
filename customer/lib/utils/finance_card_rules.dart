/// Spideli Finance: virtual cards, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 14). Unit tested in
/// test/finance_card_rules_test.dart.
///
/// The ISSUER (through the server) decides card creation, balances, status,
/// limits applied and every transaction. The app stores nothing secret: only
/// the masked number and display metadata are in Firestore; the full number
/// and CVV are shown through the issuer's secure mechanism and never kept.
library;

import 'dart:math' as math;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

Map<String, int> _amounts(dynamic v) => {for (final e in _map(v).entries) if (_int(e.value) > 0) e.key: _int(e.value)};

/// How the issuer lets the app show the full card details.
abstract final class SecureDetailsMode {
  /// The issuer's hosted secure page (the app never receives the data).
  static const String hosted = 'hosted';

  /// Details returned once by the server's PCI-compliant relay, shown for a minute, never stored.
  static const String direct = 'direct';
  static const String none = 'none';
}

/// `platform_settings/cards` (admin). Null when missing or invalid.
class CardConfig {
  final List<String> currencies;
  final String issuerName;
  final String network;
  final int maxCardsPerUser;
  final Map<String, int> issuanceFee;
  final Map<String, int> monthlyFee;
  final Map<String, int> renewalFee;
  final List<String> fundingMethods;
  final Map<String, int> minFunding;
  final Map<String, int> maxFunding;
  final double fundingFeePercent;

  /// Upper bounds of the user's own limits, per currency.
  final Map<String, int> maxPerTransaction;
  final Map<String, int> maxDaily;
  final Map<String, int> maxMonthly;

  /// What the issuer supports (never assumed).
  final bool canWithdraw;
  final bool canRenew;
  final bool canToggleOnline;
  final bool canToggleInternational;
  final String secureDetails;
  final String terms;
  final int termsVersion;

  const CardConfig({
    required this.currencies,
    required this.issuerName,
    required this.network,
    required this.maxCardsPerUser,
    required this.issuanceFee,
    required this.monthlyFee,
    required this.renewalFee,
    required this.fundingMethods,
    required this.minFunding,
    required this.maxFunding,
    required this.fundingFeePercent,
    required this.maxPerTransaction,
    required this.maxDaily,
    required this.maxMonthly,
    required this.canWithdraw,
    required this.canRenew,
    required this.canToggleOnline,
    required this.canToggleInternational,
    required this.secureDetails,
    required this.terms,
    required this.termsVersion,
  });

  static CardConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final methods = _strings(raw['fundingMethods']);
    final int termsVersion = _int(raw['termsVersion']);
    final String terms = raw['terms']?.toString().trim() ?? '';
    if (currencies.isEmpty || methods.isEmpty || termsVersion < 1 || terms.isEmpty) return null;
    final caps = _map(raw['capabilities']);
    final limits = _map(raw['limits']);
    final String details = caps['secureDetails']?.toString() ?? SecureDetailsMode.none;
    final int max = _int(raw['maxCardsPerUser']);
    return CardConfig(
      currencies: currencies,
      issuerName: raw['issuerName']?.toString() ?? '',
      network: raw['network']?.toString() ?? 'visa',
      maxCardsPerUser: max < 1 ? 1 : math.min(max, 10),
      issuanceFee: _amounts(raw['issuanceFee']),
      monthlyFee: _amounts(raw['monthlyFee']),
      renewalFee: _amounts(raw['renewalFee']),
      fundingMethods: methods,
      minFunding: _amounts(raw['minFunding']),
      maxFunding: _amounts(raw['maxFunding']),
      fundingFeePercent: _num(raw['fundingFeePercent']).clamp(0, 100).toDouble(),
      maxPerTransaction: _amounts(limits['maxPerTransaction']),
      maxDaily: _amounts(limits['maxDaily']),
      maxMonthly: _amounts(limits['maxMonthly']),
      canWithdraw: caps['withdraw'] == true,
      canRenew: caps['renew'] == true,
      canToggleOnline: caps['onlineToggle'] == true,
      canToggleInternational: caps['internationalToggle'] == true,
      secureDetails: const [SecureDetailsMode.hosted, SecureDetailsMode.direct].contains(details) ? details : SecureDetailsMode.none,
      terms: terms,
      termsVersion: termsVersion,
    );
  }

  int feeFor(Map<String, int> fees, String currency) => fees[currency] ?? 0;
}

/// `virtual_cards/{cardId}`: display metadata only (never the full number or CVV).
class VirtualCard {
  final String id;
  final String label;
  final String network;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String cardholderName;
  final String currency;
  final int balance;

  /// `requested`, `active`, `frozen`, `terminated`, `expired` or `failed`.
  final String status;

  /// Who froze it: `user` (the user may unfreeze), `issuer` or `admin` (only they may).
  final String frozenBy;
  final String replacedBy;
  final String reason;

  const VirtualCard({
    required this.id,
    required this.label,
    required this.network,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cardholderName,
    required this.currency,
    required this.balance,
    required this.status,
    required this.frozenBy,
    required this.replacedBy,
    required this.reason,
  });

  static VirtualCard fromMap(Map<String, dynamic> m) {
    final String last4 = m['last4']?.toString() ?? '';
    return VirtualCard(
      id: m['id']?.toString() ?? '',
      label: m['label']?.toString() ?? '',
      network: m['network']?.toString() ?? 'visa',
      last4: RegExp(r'^\d{4}$').hasMatch(last4) ? last4 : '',
      expiryMonth: _int(m['expiryMonth']),
      expiryYear: _int(m['expiryYear']),
      cardholderName: m['cardholderName']?.toString() ?? '',
      currency: m['currency']?.toString() ?? '',
      balance: _int(m['balance']),
      status: m['status']?.toString() ?? 'requested',
      frozenBy: m['frozenBy']?.toString() ?? '',
      replacedBy: m['replacedBy']?.toString() ?? '',
      reason: m['reason']?.toString() ?? '',
    );
  }

  String get masked => '•••• •••• •••• ${last4.isEmpty ? '••••' : last4}';

  String get expiry => expiryMonth < 1 || expiryMonth > 12 || expiryYear < 2000 ? '--/--' : '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}';

  /// The last day the card can be used (end of its expiry month).
  DateTime? get validUntil => expiryMonth < 1 || expiryMonth > 12 || expiryYear < 2000 ? null : DateTime(expiryYear, expiryMonth + 1, 0);

  bool expiresWithin(DateTime now, int days) => validUntil != null && !validUntil!.isAfter(now.add(Duration(days: days)));

  /// Counts towards the user's card limit.
  bool get counts => const ['requested', 'active', 'frozen'].contains(status);
}

/// What the app offers on a card (the server and the issuer re-check each).
abstract final class CardActions {
  static bool canCreate(List<VirtualCard> cards, CardConfig c) => cards.where((x) => x.counts).length < c.maxCardsPerUser;

  static bool canFund(VirtualCard c) => c.status == 'active';

  static bool canWithdraw(VirtualCard c, CardConfig cfg) => cfg.canWithdraw && (c.status == 'active' || c.status == 'frozen') && c.balance > 0;

  static bool canFreeze(VirtualCard c) => c.status == 'active';

  static bool canUnfreeze(VirtualCard c) => c.status == 'frozen' && c.frozenBy == 'user';

  static bool canRevealDetails(VirtualCard c, CardConfig cfg) => cfg.secureDetails != SecureDetailsMode.none && c.status == 'active';

  static bool canSetLimits(VirtualCard c) => c.status == 'active' || c.status == 'frozen';

  static bool canRenew(VirtualCard c, CardConfig cfg, DateTime now) =>
      cfg.canRenew && c.replacedBy.isEmpty && (c.status == 'expired' || ((c.status == 'active' || c.status == 'frozen') && c.expiresWithin(now, 30)));

  static bool canTerminate(VirtualCard c) => c.status == 'active' || c.status == 'expired' || (c.status == 'frozen' && c.frozenBy == 'user');
}

/// Funding: the fee is added on top; the card receives the amount asked.
class FundingQuote {
  final int amount;
  final int fee;

  const FundingQuote(this.amount, this.fee);

  int get total => amount + fee;

  static FundingQuote of(int amount, double feePercent) => FundingQuote(amount, (amount * feePercent / 100).round());
}

/// The user's limits; null fields = the issuer's maximum.
class CardLimits {
  final int? perTransaction;
  final int? daily;
  final int? monthly;

  const CardLimits({this.perTransaction, this.daily, this.monthly});

  /// Translation key of the first problem, or null when valid against the
  /// maxima of [currency].
  String? problem(CardConfig c, String currency) {
    final maxTx = c.maxPerTransaction[currency];
    final maxDay = c.maxDaily[currency];
    final maxMonth = c.maxMonthly[currency];
    for (final v in [perTransaction, daily, monthly]) {
      if (v != null && v <= 0) return 'Limits must be more than zero.';
    }
    if (perTransaction != null && maxTx != null && perTransaction! > maxTx) return 'The limit per payment is above the maximum allowed.';
    if (daily != null && maxDay != null && daily! > maxDay) return 'The daily limit is above the maximum allowed.';
    if (monthly != null && maxMonth != null && monthly! > maxMonth) return 'The monthly limit is above the maximum allowed.';
    if (perTransaction != null && daily != null && perTransaction! > daily!) return 'The limit per payment cannot be above the daily limit.';
    if (daily != null && monthly != null && daily! > monthly!) return 'The daily limit cannot be above the monthly limit.';
    return null;
  }
}

abstract final class CardLabels {
  static String status(String? s) => const {
        'requested': 'Being created',
        'active': 'Active',
        'frozen': 'Frozen',
        'terminated': 'Deleted',
        'expired': 'Expired',
        'failed': 'Not created',
      }[s] ??
      (s ?? '-');

  static String transaction(String? t) => const {
        'purchase': 'Payment',
        'refund': 'Refund',
        'funding': 'Top-up',
        'withdrawal': 'Withdrawal',
        'fee': 'Fee',
        'reversal': 'Reversal',
        'authorization': 'Authorization',
      }[t] ??
      (t ?? '-');

  static String transactionStatus(String? s) => const {
        'pending': 'Pending',
        'completed': 'Completed',
        'declined': 'Declined',
        'reversed': 'Reversed',
      }[s] ??
      (s ?? '-');

  /// Money coming INTO the card.
  static bool credit(String? type) => type == 'refund' || type == 'funding' || type == 'reversal';
}

/// "4111 1111 1111 1111" from digits, for the secure details view.
String groupCardNumber(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  return [for (int i = 0; i < d.length; i += 4) d.substring(i, math.min(i + 4, d.length))].join(' ');
}
