/// Spideli Finance: money transfers and bill payments, the pure rules the
/// screens use (.claude/FINANCE-APP-CONTRACT.md section 15) and the writes
/// the app makes itself (.claude/FINANCE-DIRECT-FIRESTORE.md sections 3.3 /
/// 3.4: no server; the security rules check each batch). Unit tested in
/// test/finance_transfer_rules_test.dart and test/finance_transfer_direct_test.dart.
///
/// The app finds the recipient, computes the fee from the admin's settings,
/// and writes the request with its ledger posting in one batch: an internal
/// transfer is completed at once; an external one (Mobile Money, Wave, bank)
/// and a bill are `processing` until the admin pays them out.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

Map<String, int> _amounts(dynamic v) => {for (final e in _map(v).entries) if (_int(e.value) >= 0) e.key: _int(e.value)};

bool _currency(String c) => RegExp(r'^[A-Z]{3}$').hasMatch(c);

/// Fees of a channel or biller: a percentage plus a fixed part, optionally capped.
class FeeRule {
  final double percent;
  final Map<String, int> fixed;
  final Map<String, int> max;

  const FeeRule({this.percent = 0, this.fixed = const {}, this.max = const {}});

  static FeeRule parse(dynamic raw) {
    final m = _map(raw);
    return FeeRule(percent: _num(m['feePercent']).clamp(0, 100).toDouble(), fixed: _amounts(m['feeFixed']), max: _amounts(m['feeMax']));
  }

  int feeFor(int amount, String currency) {
    final int fee = (amount * percent / 100).round() + (fixed[currency] ?? 0);
    final int? cap = max[currency];
    return cap != null && cap > 0 ? math.min(fee, cap) : fee;
  }
}

/// Where money can be sent.
abstract final class TransferChannel {
  /// Another Spideli user, found by email or phone.
  static const String internal = 'internal';
  static const String mobileMoney = 'mobile_money';
  static const String wave = 'wave';
  static const String bank = 'bank';

  static const List<String> all = [internal, mobileMoney, wave, bank];

  static String label(String c) => const {
        internal: 'Spideli user',
        mobileMoney: 'Mobile Money',
        wave: 'Wave',
        bank: 'Bank account',
      }[c] ??
      c;
}

class BankOption {
  final String code;
  final String name;

  const BankOption(this.code, this.name);
}

class ChannelConfig {
  final String key;
  final FeeRule fee;
  final Map<String, int> min;
  final Map<String, int> max;

  /// Mobile Money operators the channel pays out to.
  final List<String> operators;

  /// Banks the channel pays out to (bank transfers).
  final List<BankOption> banks;

  /// Expected delay shown to the user ("Instant", "1-2 business days"...).
  final String delay;

  const ChannelConfig({required this.key, required this.fee, required this.min, required this.max, this.operators = const [], this.banks = const [], this.delay = ''});

  int minFor(String c) => math.max(1, min[c] ?? 1);
  int? maxFor(String c) => max[c] != null && max[c]! > 0 ? max[c] : null;
}

/// `finance_settings/{regionId}_transfers` (admin). Null when missing or invalid.
class TransferConfig {
  final List<String> currencies;
  final Map<String, ChannelConfig> channels;

  /// What pays a transfer (the wallet and/or the user's own Mobile Money).
  final List<String> sourceMethods;

  /// Re-authentication above this amount, per currency (none = always for external channels).
  final Map<String, int> reauthAbove;

  const TransferConfig({required this.currencies, required this.channels, required this.sourceMethods, required this.reauthAbove});

  static TransferConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where(_currency).toList();
    final sources = _strings(raw['sourceMethods']);
    final rawChannels = _map(raw['channels']);
    final channels = <String, ChannelConfig>{};
    for (final key in TransferChannel.all) {
      final c = _map(rawChannels[key]);
      if (c['enabled'] != true) continue;
      final operators = _strings(c['operators']);
      final banks = [
        for (final b in (c['banks'] is List ? c['banks'] as List : const []).whereType<Map>())
          if ('${b['code'] ?? ''}'.isNotEmpty && '${b['name'] ?? ''}'.isNotEmpty) BankOption(b['code'].toString(), b['name'].toString()),
      ];
      if (key == TransferChannel.mobileMoney && operators.isEmpty) continue;
      if (key == TransferChannel.bank && banks.isEmpty) continue;
      channels[key] = ChannelConfig(
        key: key,
        fee: FeeRule.parse(c),
        min: _amounts(c['min']),
        max: _amounts(c['max']),
        operators: operators,
        banks: banks,
        delay: c['delay']?.toString() ?? '',
      );
    }
    if (currencies.isEmpty || sources.isEmpty || channels.isEmpty) return null;
    return TransferConfig(currencies: currencies, channels: channels, sourceMethods: sources, reauthAbove: _amounts(_map(raw['security'])['reauthAbove']));
  }

  /// A confirmation of identity is asked before sending [amount].
  bool needsReauth(int amount, String currency) {
    final int? above = reauthAbove[currency];
    return above == null || amount >= above;
  }
}

/// Recipient checks done before asking the server (which re-checks them).
abstract final class RecipientCheck {
  static bool email(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v.trim());

  /// International or local number: 8 to 15 digits, optional leading +.
  static bool phone(String v) => RegExp(r'^\+?\d{8,15}$').hasMatch(v.replaceAll(RegExp(r'[\s\-().]'), ''));

  static String normalizePhone(String v) => v.replaceAll(RegExp(r'[\s\-().]'), '');

  /// IBAN check digits (ISO 13616, mod 97).
  static bool iban(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$').hasMatch(s)) return false;
    final rearranged = s.substring(4) + s.substring(0, 4);
    int rest = 0;
    for (final ch in rearranged.split('')) {
      final int code = ch.codeUnitAt(0);
      final String digits = code >= 65 ? '${code - 55}' : ch;
      for (final d in digits.split('')) {
        rest = (rest * 10 + int.parse(d)) % 97;
      }
    }
    return rest == 1;
  }

  /// A bank account: a valid IBAN when it starts with two letters, otherwise 6-34 letters or digits.
  static bool bankAccount(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (RegExp(r'^[A-Z]{2}\d{2}').hasMatch(s)) return iban(s);
    return RegExp(r'^[A-Z0-9]{6,34}$').hasMatch(s);
  }

  static bool holderName(String v) => v.trim().length >= 3;
}

/// Statuses of a transfer (`money_transfers`) or a bill payment (`utility_payment_requests`).
abstract final class PaymentFlow {
  static const List<String> steps = ['awaiting_confirmation', 'pending', 'processing', 'completed'];

  static String label(String? s) => const {
        'awaiting_confirmation': 'To confirm',
        'pending': 'Waiting for payment',
        'processing': 'Processing',
        'completed': 'Completed',
        'failed': 'Failed',
        'cancelled': 'Cancelled',
        'expired': 'Expired',
        'reversed': 'Refunded',
      }[s] ??
      (s ?? '-');

  static bool ended(String? s) => const ['failed', 'cancelled', 'expired', 'reversed'].contains(s);

  /// The sender can still cancel (no money has moved yet).
  static bool canCancel(String? s) => s == 'awaiting_confirmation' || s == 'pending';

  static bool canConfirm(String? s, DateTime? expiresAt, DateTime now) => s == 'awaiting_confirmation' && (expiresAt == null || now.isBefore(expiresAt));
}

// ------------------------------------------------------------------- bills

/// `finance_settings/{regionId}_bills` (admin). Null when missing or invalid.
class BillsConfig {
  final List<String> currencies;
  final List<String> categories;
  final List<String> paymentMethods;

  /// Re-authentication from this amount, per currency (a currency without one: always, as the rules require).
  final Map<String, int> reauthAbove;

  const BillsConfig({required this.currencies, required this.categories, required this.paymentMethods, this.reauthAbove = const {}});

  static BillsConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where(_currency).toList();
    final categories = _strings(raw['categories']);
    final methods = _strings(raw['paymentMethods']);
    if (currencies.isEmpty || categories.isEmpty || methods.isEmpty) return null;
    return BillsConfig(currencies: currencies, categories: categories, paymentMethods: methods, reauthAbove: _amounts(_map(raw['security'])['reauthAbove']));
  }

  /// A confirmation of identity is asked before paying [amount] (the total, fee included).
  bool needsReauth(int amount, String currency) {
    final int? above = reauthAbove[currency];
    return above == null || amount >= above;
  }
}

class BillPackage {
  final String code;
  final String name;
  final int amount;

  const BillPackage(this.code, this.name, this.amount);
}

/// `utility_billers/{billerId}`.
class Biller {
  final String id;
  final String name;
  final String category;
  final String country;
  final String currency;
  final String accountLabel;
  final String accountHint;
  final RegExp? accountPattern;

  /// `due` (the amount owed, from a lookup), `open` (any amount: prepaid) or `packages`.
  final String amountType;
  final bool lookup;
  final bool partialPayment;
  final List<BillPackage> packages;
  final int min;
  final int? max;
  final FeeRule fee;

  const Biller({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.currency,
    required this.accountLabel,
    required this.accountHint,
    required this.accountPattern,
    required this.amountType,
    required this.lookup,
    required this.partialPayment,
    required this.packages,
    required this.min,
    required this.max,
    required this.fee,
  });

  static Biller? fromMap(Map<String, dynamic> m) {
    final String name = m['name']?.toString() ?? '';
    final String currency = m['currency']?.toString() ?? '';
    String type = m['amountType']?.toString() ?? 'open';
    if (name.isEmpty || !_currency(currency) || !const ['due', 'open', 'packages'].contains(type)) return null;
    RegExp? pattern;
    try {
      final p = m['accountPattern']?.toString() ?? '';
      if (p.isNotEmpty) pattern = RegExp('^(?:$p)\$');
    } catch (_) {
      pattern = null;
    }
    final packages = [
      for (final p in (m['packages'] is List ? m['packages'] as List : const []).whereType<Map>())
        if ('${p['code'] ?? ''}'.isNotEmpty && _int(p['amount']) > 0) BillPackage(p['code'].toString(), p['name']?.toString() ?? p['code'].toString(), _int(p['amount'])),
    ];
    if (type == 'packages' && packages.isEmpty) return null;
    final bool lookup = m['lookup'] == true || type == 'due';
    final int max = _int(m['max']);
    return Biller(
      id: m['id']?.toString() ?? '',
      name: name,
      category: m['category']?.toString() ?? 'other',
      country: m['country']?.toString() ?? '',
      currency: currency,
      accountLabel: m['accountLabel']?.toString() ?? '',
      accountHint: m['accountHint']?.toString() ?? '',
      accountPattern: pattern,
      amountType: type,
      lookup: lookup,
      partialPayment: m['partialPayment'] == true,
      packages: packages,
      min: math.max(1, _int(m['min'])),
      max: max > 0 ? max : null,
      fee: FeeRule.parse(m),
    );
  }

  bool accountValid(String account) {
    final a = account.trim();
    if (a.isEmpty) return false;
    return accountPattern == null || accountPattern!.hasMatch(a);
  }

  /// Translation key of the problem with paying [amount], or null.
  /// [due] is the amount owed from the lookup (for `due` billers).
  String? amountProblem(int? amount, {int? due}) {
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (amountType == 'due') {
      if (due == null || due <= 0) return 'Nothing to pay on this account.';
      if (!partialPayment && amount != due) return 'This bill must be paid in full.';
      if (amount > due) return 'The amount is more than what is due.';
      return null;
    }
    if (amountType == 'packages') return packages.any((p) => p.amount == amount) ? null : 'Choose a package.';
    if (amount < min) return 'The amount is below the minimum.';
    if (max != null && amount > max!) return 'The amount is above the maximum.';
    return null;
  }
}

abstract final class BillLabels {
  static String category(String? c) => const {
        'electricity': 'Electricity',
        'water': 'Water',
        'tv': 'Television',
        'internet': 'Internet',
        'phone': 'Phone credit',
        'gas': 'Gas',
        'education': 'School fees',
        'taxes': 'Taxes',
        'products': 'Products',
        'other': 'Other',
      }[c] ??
      (c ?? '-');
}

// ------------------------------------------------------- direct writes

/// A Spideli user found as a transfer's recipient.
class TransferRecipient {
  final String uid;
  final String name;
  final String fcmToken;

  const TransferRecipient(this.uid, this.name, this.fcmToken);
}

/// Finding the recipient of an internal transfer in `users` (by email or
/// phone: `countryCode` + `phoneNumber`, the number stored without it).
abstract final class RecipientMatch {
  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// The `phoneNumber` values a typed [phone] may be stored as: the number
  /// as typed (digits, with and without +) and, when it starts with a
  /// country code, without its first 1, 2 or 3 digits. At most 10 (a
  /// Firestore `in` filter).
  static List<String> phoneCandidates(String phone) {
    final String d = _digits(phone);
    if (d.isEmpty) return const [];
    final out = <String>{d, '+$d', if (d.startsWith('0')) d.substring(1)};
    for (int n = 1; n <= 3; n++) {
      if (d.length - n >= 6) out.add(d.substring(n));
    }
    return out.take(10).toList();
  }

  /// The users (id, data) that match [phone]: with a country code, the
  /// whole number must match `countryCode + phoneNumber`; without one, the
  /// stored number, preferring the sender's [countryCode].
  static List<(String, Map<String, dynamic>)> phoneMatches(List<(String, Map<String, dynamic>)> users, String phone, {String? countryCode}) {
    final String typed = _digits(phone);
    final bool international = phone.trim().startsWith('+') || phone.trim().startsWith('00');
    final String full = phone.trim().startsWith('00') ? typed.substring(2) : typed;
    String whole(Map<String, dynamic> u) => _digits('${u['countryCode'] ?? ''}${u['phoneNumber'] ?? ''}');
    String local(Map<String, dynamic> u) => _digits('${u['phoneNumber'] ?? ''}').replaceFirst(RegExp(r'^0+'), '');
    final matches = users.where((u) {
      if (international) return whole(u.$2) == full;
      return whole(u.$2) == typed || local(u.$2) == typed.replaceFirst(RegExp(r'^0+'), '');
    }).toList();
    if (matches.length <= 1 || international) return matches;
    final mine = _digits(countryCode ?? '');
    final same = matches.where((u) => mine.isNotEmpty && _digits('${u.$2['countryCode'] ?? ''}') == mine).toList();
    return same.isEmpty ? matches : same;
  }

  /// The recipient among [found] (users matching the email or phone), or a
  /// refusal: `recipient_not_found` (none, inactive, not a customer),
  /// `recipient_ambiguous` (several), `self_transfer`.
  static ({TransferRecipient? recipient, String? reason}) pick(List<(String, Map<String, dynamic>)> found, String senderUid) {
    final usable = found.where((u) => u.$2['active'] != false && (u.$2['role'] == null || u.$2['role'] == 'customer' || u.$2['role'] == 'user')).toList();
    final ids = usable.map((u) => u.$1).toSet();
    if (ids.isEmpty) return (recipient: null, reason: 'recipient_not_found');
    if (ids.length > 1) return (recipient: null, reason: 'recipient_ambiguous');
    final u = usable.first;
    if (u.$1 == senderUid) return (recipient: null, reason: 'self_transfer');
    final String name = '${u.$2['firstName'] ?? ''} ${u.$2['lastName'] ?? ''}'.trim();
    return (recipient: TransferRecipient(u.$1, name.isEmpty ? '-' : name, u.$2['fcmToken']?.toString() ?? ''), reason: null);
  }
}

/// A transfer as the user confirms it: the app's own figures.
class TransferDraft {
  final String channel;
  final String currency;
  final int amount;
  final int fee;

  /// The recipient as stored (`email` | `phone` | `operator` + `number` |
  /// `number` | `bankCode` + `bankName` + `holderName` + `accountNumber` + `accountMasked`).
  final Map<String, dynamic> recipient;
  final String recipientName;

  /// Internal transfers: the Spideli user who receives it.
  final String? recipientId;
  final String recipientToken;
  final String note;
  final bool saveBeneficiary;

  const TransferDraft({
    required this.channel,
    required this.currency,
    required this.amount,
    required this.fee,
    required this.recipient,
    required this.recipientName,
    this.recipientId,
    this.recipientToken = '',
    this.note = '',
    this.saveBeneficiary = false,
  });

  int get total => amount + fee;
  bool get internal => channel == TransferChannel.internal;

  /// What identifies the recipient within the channel (the request key, the beneficiary).
  String get recipientKey => switch (channel) {
        TransferChannel.internal => recipientId ?? '',
        TransferChannel.bank => '${recipient['bankCode'] ?? recipient['bankName'] ?? ''}:${recipient['accountNumber'] ?? ''}',
        _ => '${recipient['operator'] ?? ''}:${recipient['number'] ?? ''}',
      };

  /// The detail shown under the recipient's name (a bank account only by its end).
  String get detail => switch (channel) {
        TransferChannel.internal => '${recipient['email'] ?? recipient['phone'] ?? ''}',
        TransferChannel.mobileMoney => '${recipient['operator'] ?? ''} · ${recipient['number'] ?? ''}',
        TransferChannel.wave => '${recipient['number'] ?? ''}',
        TransferChannel.bank => '${recipient['bankName'] ?? ''} · ${recipient['accountMasked'] ?? ''}',
        _ => '',
      };
}

abstract final class TransferPlans {
  /// The transfer document of [d], before its status fields.
  static Map<String, dynamic> _transfer(String id, TransferDraft d, {required String senderId, required String senderName, required FinanceFunding funding}) => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        if (d.internal) 'recipientId': d.recipientId,
        'participantIds': [senderId, if (d.internal && d.recipientId != null) d.recipientId],
        'channel': d.channel,
        'recipient': d.recipient,
        'recipientName': d.recipientName,
        'recipientVerified': d.internal,
        'currency': d.currency,
        'amount': d.amount,
        'fee': d.fee,
        'total': d.total,
        'receiveAmount': d.amount,
        if (d.note.isNotEmpty) 'note': d.note,
        'funding': funding.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// An internal transfer: `money_transfers` (completed) and the posting
  /// sender wallet -> recipient wallet (+ fee line to the platform). The
  /// recipient's wallet is created when [recipientWallet] does not exist.
  /// Paid by a gateway, the payment was deposited into the sender's wallet
  /// first; [funding] records how it was paid.
  static List<FinanceWrite> internal({
    required String id,
    required TransferDraft d,
    required String senderId,
    required String senderName,
    required FinanceFunding funding,
    required String senderWalletId,
    required ({String id, bool exists}) recipientWallet,
    required String txId,
    String? reference,
  }) {
    assert(d.internal && d.recipientId != null);
    final posting = FinanceLedger.plan(
      type: 'transfer',
      currency: d.currency,
      from: senderWalletId,
      to: recipientWallet.id,
      amount: d.amount,
      fee: d.fee,
      newAccounts: recipientWallet.exists ? const {} : {recipientWallet.id: FinanceLedger.walletFields(d.recipientId!, d.currency)},
      userIds: [senderId, d.recipientId!],
      sourceKind: 'money_transfers',
      sourceId: id,
      createdBy: senderId,
      description: '$senderName -> ${d.recipientName}',
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('money_transfers/$id', 'create', {
        ..._transfer(id, d, senderId: senderId, senderName: senderName, funding: funding),
        'status': 'completed',
        'reference': posting.reference,
        'txId': posting.txId,
        'completedAt': FieldValue.serverTimestamp(),
      }),
      ...posting.writes,
    ];
  }

  /// An external transfer (Mobile Money, Wave, bank): `money_transfers`
  /// (processing, for the admin to pay out) and the posting wallet ->
  /// platform of the total, fee included (`transfer_out`).
  static List<FinanceWrite> external({
    required String id,
    required TransferDraft d,
    required String senderId,
    required String senderName,
    required FinanceFunding funding,
    required String senderWalletId,
    required String txId,
    String? reference,
  }) {
    assert(!d.internal);
    final posting = FinanceLedger.plan(
      type: 'transfer_out',
      currency: d.currency,
      from: senderWalletId,
      to: FinanceLedger.platformId(d.currency),
      amount: d.total,
      userIds: [senderId],
      sourceKind: 'money_transfers',
      sourceId: id,
      createdBy: senderId,
      description: '${TransferChannel.label(d.channel)} · ${d.recipientName}',
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('money_transfers/$id', 'create', {
        ..._transfer(id, d, senderId: senderId, senderName: senderName, funding: funding),
        'status': 'processing',
        'reference': posting.reference,
        'txId': posting.txId,
      }),
      ...posting.writes,
    ];
  }

  /// The sender may ask to cancel an external transfer still `processing`
  /// that the admin has not taken yet (the admin then reverses it).
  static bool canRequestCancel(Map<String, dynamic> t, String uid) =>
      t['senderId'] == uid &&
      t['channel'] != TransferChannel.internal &&
      t['status'] == 'processing' &&
      t['adminLockedAt'] == null &&
      t['cancelRequested'] != true;

  static Map<String, dynamic> cancelRequest() => {'cancelRequested': true, 'cancelRequestedAt': FieldValue.serverTimestamp()};

  /// A deterministic beneficiary id: one per user, channel and recipient.
  static String beneficiaryId(String uid, String channel, String recipientKey) =>
      'ben_${uid}_${channel}_${recipientKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._+-]'), '_')}';

  static Map<String, dynamic> beneficiary(String uid, TransferDraft d) => {
        'userId': uid,
        'channel': d.channel,
        'displayName': d.recipientName,
        'detail': d.channel == TransferChannel.bank ? '${d.recipient['bankName'] ?? ''} · ${d.recipient['accountMasked'] ?? ''}' : d.detail,
        'recipient': d.recipient,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
      };
}

/// A bill payment as the user confirms it.
class BillDraft {
  final Biller biller;
  final String account;
  final int amount;
  final BillPackage? package;
  final bool saveAccount;

  const BillDraft({required this.biller, required this.account, required this.amount, this.package, this.saveAccount = false});

  int get fee => biller.fee.feeFor(amount, biller.currency);
  int get total => amount + fee;
}

abstract final class BillPlans {
  /// Without the biller lookup (it needs a partner API), the user types the
  /// amount of the bill: a `due` biller then takes any amount from its
  /// minimum up to its maximum, like an `open` one; packages stay packages.
  /// Translation key of the problem with [amount], or null.
  static String? amountProblem(Biller b, int? amount) {
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (b.amountType == 'packages') return b.packages.any((p) => p.amount == amount) ? null : 'Choose a package.';
    if (amount < b.min) return 'The amount is below the minimum.';
    if (b.max != null && amount > b.max!) return 'The amount is above the maximum.';
    return null;
  }

  /// `utility_payment_requests` (processing, for the admin to pay the
  /// biller) and the posting wallet -> platform of the total, fee included
  /// (`bill_payment`). Paid by a gateway, the payment was deposited into
  /// the wallet first; [funding] records how it was paid.
  static List<FinanceWrite> payment({
    required String id,
    required String uid,
    required BillDraft d,
    required FinanceFunding funding,
    required String walletId,
    required String txId,
    String? reference,
  }) {
    final b = d.biller;
    final posting = FinanceLedger.plan(
      type: 'bill_payment',
      currency: b.currency,
      from: walletId,
      to: FinanceLedger.platformId(b.currency),
      amount: d.total,
      userIds: [uid],
      sourceKind: 'utility_payment_requests',
      sourceId: id,
      createdBy: uid,
      description: '${b.name} · ${d.account}',
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('utility_payment_requests/$id', 'create', {
        'id': id,
        'userId': uid,
        'billerId': b.id,
        'billerName': b.name,
        'category': b.category,
        'account': d.account,
        if (d.package != null) 'packageCode': d.package!.code,
        if (d.package != null) 'packageName': d.package!.name,
        'currency': b.currency,
        'amount': d.amount,
        'fee': d.fee,
        'total': d.total,
        'status': 'processing',
        'reference': posting.reference,
        'txId': posting.txId,
        'funding': funding.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }),
      ...posting.writes,
    ];
  }

  /// A deterministic saved-account id: one per user, biller and account.
  static String savedAccountId(String uid, String billerId, String account) =>
      'acc_${uid}_${billerId}_${account.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._+-]'), '_')}';

  static Map<String, dynamic> savedAccount(String uid, BillDraft d) => {
        'userId': uid,
        'billerId': d.biller.id,
        'billerName': d.biller.name,
        'category': d.biller.category,
        'account': d.account,
        'nickname': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
      };
}

/// Where a transfer or bill payment written by the app is: paid, then
/// processing (external: until the admin pays out), then completed.
abstract final class DirectFlow {
  static const List<String> steps = ['paid', 'processing', 'completed'];

  static String label(String s) => const {'paid': 'Paid', 'processing': 'Processing', 'completed': 'Completed'}[s] ?? s;
}
