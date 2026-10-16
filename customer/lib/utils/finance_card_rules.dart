/// Spideli Finance: virtual cards, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 14) and the writes of each
/// request (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.5). Unit tested in
/// test/finance_card_rules_test.dart and test/finance_card_direct_test.dart.
///
/// The ISSUER (through the Spideli admin) decides card creation, balances,
/// status, limits applied and every transaction: the app writes requests.
/// The app stores nothing secret: only the masked number and display
/// metadata are in Firestore; the full number and CVV are shown through the
/// issuer's secure mechanism and never kept.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/service/finance_ledger.dart';

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

/// The cards settings of a region (`finance_settings/{regionId}_cards`, admin). Null when missing or invalid.
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

  /// Card-to-card transfers between Spideli cards (`capabilities.cardTransfer`).
  final bool canTransfer;
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
    this.canTransfer = false,
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
      canTransfer: caps['cardTransfer'] == true,
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

  /// `requested`, `active`, `frozen`, `termination_requested`,
  /// `terminated`, `expired` or `failed`.
  final String status;

  /// Who froze it: `user` (the user may unfreeze), `issuer` or `admin` (only they may).
  final String frozenBy;
  final String replacedBy;
  final String reason;

  /// The user asked for a renewal (`renewalRequestedAt`); the admin issues
  /// the new card and sets [replacedBy].
  final bool renewalRequested;

  /// The region it was requested in (`regionId`): its settings apply.
  final String regionId;

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
    this.renewalRequested = false,
    this.regionId = '',
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
      renewalRequested: m['renewalRequestedAt'] != null,
      regionId: m['regionId']?.toString() ?? '',
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

  /// Sending part of the balance to another Spideli user's card.
  static bool canTransfer(VirtualCard c, CardConfig cfg) => cfg.canTransfer && c.status == 'active' && c.balance > 0;

  static bool canFreeze(VirtualCard c) => c.status == 'active';

  static bool canUnfreeze(VirtualCard c) => c.status == 'frozen' && c.frozenBy == 'user';

  static bool canRevealDetails(VirtualCard c, CardConfig cfg) => cfg.secureDetails != SecureDetailsMode.none && c.status == 'active';

  static bool canSetLimits(VirtualCard c) => c.status == 'active' || c.status == 'frozen';

  static bool canRenew(VirtualCard c, CardConfig cfg, DateTime now) =>
      cfg.canRenew && c.replacedBy.isEmpty && !c.renewalRequested && (c.status == 'expired' || ((c.status == 'active' || c.status == 'frozen') && c.expiresWithin(now, 30)));

  static bool canTerminate(VirtualCard c) => c.status == 'active' || c.status == 'expired' || (c.status == 'frozen' && c.frozenBy == 'user');
}

/// Money of a card already asked for.
abstract final class CardFunds {
  /// What withdrawals and transfers still waiting for the admin take from
  /// the card balance ([requests]: its `card_funding_requests`).
  static int promised(List<Map<String, dynamic>> requests) => requests
      .where((r) => (r['type'] == 'withdraw' || r['type'] == 'transfer') && (r['status'] == 'pending' || r['status'] == 'processing'))
      .fold(0, (sum, r) => sum + _int(r['amount']));
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
        'termination_requested': 'Being deleted',
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

  /// A request of the card (`card_funding_requests.type`).
  static String request(String? type) => const {'fund': 'Top-up', 'withdraw': 'Withdrawal', 'transfer': 'Sent to a card'}[type] ?? 'Top-up';
}

/// "4111 1111 1111 1111" from digits, for the secure details view.
String groupCardNumber(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  return [for (int i = 0; i < d.length; i += 4) d.substring(i, math.min(i + 4, d.length))].join(' ');
}

/// A Spideli user to send card money to, found by e-mail or phone number in
/// `users` (as an internal transfer, design section 3.3).
abstract final class CardRecipient {
  /// The `users` field to search and the values to look for: an e-mail as
  /// typed and in lower case; a phone number as digits, with "+" and
  /// without leading zeros. Null when [input] is neither.
  static (String, List<String>)? query(String input) {
    final String t = input.trim();
    if (t.contains('@')) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return null;
      return ('email', {t, t.toLowerCase()}.toList());
    }
    if (RegExp(r'[^\d\s+\-().]').hasMatch(t)) return null;
    final String digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6 || digits.length > 15) return null;
    final String national = digits.replaceFirst(RegExp(r'^0+'), '');
    return ('phoneNumber', {digits, '+$digits', national}.where((v) => v.isNotEmpty).toList());
  }

  /// "Jane D.": what the sender sees of the recipient.
  static String displayName(String? first, String? last) {
    final String f = (first ?? '').trim();
    final String l = (last ?? '').trim();
    if (f.isEmpty) return l;
    return l.isEmpty ? f : '$f ${l[0].toUpperCase()}.';
  }
}

/// The writes of each card request (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.5), as data. A request that costs money carries its posting to
/// the platform (`FinancePay.toPlatform`) in the same batch; the admin then
/// does the issuer's part and sets the result.
abstract final class CardWrites {
  static Object get _now => FieldValue.serverTimestamp();

  /// A new card, `virtual_cards/{cardId}` `requested`. The admin issues it
  /// (`active` with `last4`, `expiryMonth`, `expiryYear`, `cardholderName`
  /// from the verified identity, `balance`) or sets `failed` with `reason`
  /// and reverses the fee. [feePosting]: the creation fee (`card_fee`).
  static List<FinanceWrite> request({
    required String cardId,
    required String uid,
    required String label,
    required String currency,
    required String network,
    required int termsVersion,
    required int fee,
    FinancePosting? feePosting,
    Map<String, dynamic>? paidWith,
    String reference = '',
  }) =>
      [
        FinanceWrite('virtual_cards/$cardId', 'create', {
          'id': cardId,
          'userId': uid,
          'label': label,
          'currency': currency,
          'network': network,
          'status': 'requested',
          'balance': 0,
          'termsVersion': termsVersion,
          'acceptedAt': _now,
          'issuanceFee': fee,
          if (feePosting != null) 'feeTxId': feePosting.txId,
          'payment': ?paidWith,
          'reference': feePosting?.reference ?? reference,
          'createdAt': _now,
          'updatedAt': _now,
        }),
        ...?feePosting?.writes,
      ];

  /// A top-up: `card_funding_requests/{requestId}` `fund` `pending`, paid by
  /// [posting] (`card_funding`, amount + fee to the platform). The admin
  /// loads the card (`succeeded`, `virtual_cards.balance`), or `failed` and
  /// a reversal of the posting.
  static List<FinanceWrite> fund({
    required String requestId,
    required String uid,
    required String cardId,
    required String currency,
    required int amount,
    required int fee,
    required FinancePosting posting,
    required Map<String, dynamic> paidWith,
  }) =>
      [
        FinanceWrite('card_funding_requests/$requestId', 'create', {
          'id': requestId,
          'userId': uid,
          'cardId': cardId,
          'type': 'fund',
          'amount': amount,
          'fee': fee,
          'total': amount + fee,
          'currency': currency,
          'status': 'pending',
          'txId': posting.txId,
          'reference': posting.reference,
          'payment': paidWith,
          'createdAt': _now,
          'updatedAt': _now,
        }),
        ...posting.writes,
      ];

  /// Card balance back to the user's wallet: `withdraw` `pending`, no money
  /// moves yet. The admin unloads the card at the issuer and posts
  /// `platform -> wallet` (`succeeded`), or `failed`.
  static List<FinanceWrite> withdraw({required String requestId, required String uid, required String cardId, required String currency, required int amount, required String reference}) => [
        FinanceWrite('card_funding_requests/$requestId', 'create', {
          'id': requestId,
          'userId': uid,
          'cardId': cardId,
          'type': 'withdraw',
          'amount': amount,
          'fee': 0,
          'currency': currency,
          'destination': {'method': 'wallet'},
          'status': 'pending',
          'reference': reference,
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// Card to card: [amount] of this card's balance to the active card of
  /// another Spideli user in the same currency, `transfer` `pending`. The
  /// admin moves it at the issuer (`succeeded`), or `failed` with `reason`.
  static List<FinanceWrite> transfer({
    required String requestId,
    required String uid,
    required String cardId,
    required String currency,
    required int amount,
    required String recipientId,
    required String recipientName,
    required String recipientContact,
    required String reference,
  }) =>
      [
        FinanceWrite('card_funding_requests/$requestId', 'create', {
          'id': requestId,
          'userId': uid,
          'cardId': cardId,
          'type': 'transfer',
          'amount': amount,
          'fee': 0,
          'currency': currency,
          'recipientId': recipientId,
          'recipient': {'userId': recipientId, 'name': recipientName, 'contact': recipientContact},
          'status': 'pending',
          'reference': reference,
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// `active -> frozen` by the user (instant, no re-authentication).
  static List<FinanceWrite> freeze(String cardId) => [
        FinanceWrite('virtual_cards/$cardId', 'update', {'status': 'frozen', 'frozenBy': 'user', 'frozenAt': _now, 'updatedAt': _now}),
      ];

  /// `frozen` (by the user) `-> active` (after re-authentication).
  static List<FinanceWrite> unfreeze(String cardId) => [
        FinanceWrite('virtual_cards/$cardId', 'update', {'status': 'active', 'frozenBy': null, 'unfrozenAt': _now, 'updatedAt': _now}),
      ];

  /// The user's limits, `pending` until the admin applies them at the
  /// issuer (`applied`). Null limits = the issuer's maximum.
  static List<FinanceWrite> limits({required String cardId, required String uid, required CardLimits limits, bool? allowOnline, bool? allowInternational}) => [
        FinanceWrite('card_limit_settings/$cardId', 'merge', {
          'userId': uid,
          'cardId': cardId,
          'perTransaction': limits.perTransaction,
          'daily': limits.daily,
          'monthly': limits.monthly,
          'allowOnline': ?allowOnline,
          'allowInternational': ?allowInternational,
          'status': 'pending',
          'updatedAt': _now,
        }),
      ];

  /// Deleting the card: `termination_requested`. The admin closes it at the
  /// issuer, posts any balance back to the wallet and sets `terminated`.
  static List<FinanceWrite> terminate(VirtualCard card) => [
        FinanceWrite('virtual_cards/${card.id}', 'update', {
          'status': 'termination_requested',
          'statusBefore': card.status,
          'terminationRequestedAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// A renewal: `renewalRequestedAt` on the card, with the renewal fee
  /// [feePosting] (`card_fee`) when there is one. The admin issues the new
  /// card and sets `replacedBy` on this one.
  static List<FinanceWrite> renew({required String cardId, required int fee, FinancePosting? feePosting, Map<String, dynamic>? paidWith}) => [
        FinanceWrite('virtual_cards/$cardId', 'update', {
          'renewalRequestedAt': _now,
          'renewalFee': fee,
          if (feePosting != null) 'renewalTxId': feePosting.txId,
          if (feePosting != null) 'renewalReference': feePosting.reference,
          'renewalPayment': ?paidWith,
          'updatedAt': _now,
        }),
        ...?feePosting?.writes,
      ];
}
