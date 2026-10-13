/// Spideli Finance: money transfers and bill payments, the pure rules the
/// screens use (.claude/FINANCE-APP-CONTRACT.md section 15). Unit tested in
/// test/finance_transfer_rules_test.dart.
///
/// The SERVER validates recipients and balances, computes the binding fee
/// (shown for confirmation before any money moves), runs the payment state
/// machine with the providers and issues receipts. The fee computed here is
/// only the estimate shown while typing.
library;

import 'dart:math' as math;

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

/// `platform_settings/transfers` (admin). Null when missing or invalid.
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

/// `platform_settings/bills` (admin). Null when missing or invalid.
class BillsConfig {
  final List<String> currencies;
  final List<String> categories;
  final List<String> paymentMethods;

  /// Re-authentication from this amount, per currency (none = never asked by the app).
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

  bool needsReauth(int amount, String currency) => reauthAbove[currency] != null && amount >= reauthAbove[currency]!;
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
        'other': 'Other',
      }[c] ??
      (c ?? '-');
}
