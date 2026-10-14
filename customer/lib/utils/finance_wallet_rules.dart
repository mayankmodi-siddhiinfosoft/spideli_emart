/// Spideli Finance wallet operations written by the app
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.2): deposit through a
/// payment gateway, withdrawal to Mobile Money / Wave / a bank account
/// (completed by the admin), conversion between the user's currencies.
/// `platform_settings/wallet` parsing, fees and the write plans (one batch
/// each). Unit tested in test/finance_wallet_test.dart.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_transfer_rules.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

Map<String, int> _amounts(dynamic v) => {for (final e in _map(v).entries) if (_int(e.value) > 0) e.key: _int(e.value)};

bool _iso(String c) => RegExp(r'^[A-Z]{3}$').hasMatch(c);

/// Minimum / maximum amounts per currency (minor units).
class WalletLimits {
  final Map<String, int> min;
  final Map<String, int> max;

  const WalletLimits({this.min = const {}, this.max = const {}});

  static WalletLimits parse(Map<String, dynamic> m) => WalletLimits(min: _amounts(m['min']), max: _amounts(m['max']));

  int minFor(String c) => math.max(1, min[c] ?? 1);
  int? maxFor(String c) => max[c];

  /// Translation key of what is wrong with [amount], or null.
  String? problem(int? amount, String currency) {
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (amount < minFor(currency)) return 'The amount is below the minimum.';
    final int? m = maxFor(currency);
    if (m != null && amount > m) return 'The amount is above the maximum.';
    return null;
  }
}

class WalletDepositConfig {
  final bool enabled;
  final WalletLimits limits;

  /// Gateway families offered (`mobile_money`, `wave`, `card`, `paypal`).
  final List<String> methods;

  const WalletDepositConfig({required this.enabled, required this.limits, required this.methods});
}

class WalletWithdrawConfig {
  final bool enabled;

  /// Where the money can go (`mobile_money`, `wave`, `bank`).
  final List<String> methods;
  final WalletLimits limits;
  final FeeRule fee;

  /// Expected delay shown to the user ("Within 24 hours"...).
  final String delay;

  const WalletWithdrawConfig({required this.enabled, required this.methods, required this.limits, required this.fee, this.delay = ''});
}

class WalletConvertConfig {
  final bool enabled;
  final List<String> currencies;
  final double feePercent;

  /// A rate older than this is not used (default 48 hours).
  final Duration maxRateAge;

  const WalletConvertConfig({required this.enabled, required this.currencies, required this.feePercent, this.maxRateAge = const Duration(hours: 48)});
}

/// `platform_settings/wallet` (admin). Null when missing or without a valid currency.
class WalletConfig {
  final List<String> currencies;
  final WalletDepositConfig deposit;
  final WalletWithdrawConfig withdraw;
  final WalletConvertConfig convert;

  /// Re-authentication from this amount, per currency (a currency without one: always).
  final Map<String, int> reauthAbove;

  const WalletConfig({required this.currencies, required this.deposit, required this.withdraw, required this.convert, this.reauthAbove = const {}});

  static const List<String> _depositMethods = ['mobile_money', 'wave', 'card', 'paypal'];
  static const List<String> _withdrawMethods = ['mobile_money', 'wave', 'bank'];

  static WalletConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where(_iso).toList();
    if (currencies.isEmpty) return null;
    final d = _map(raw['deposit']);
    final w = _map(raw['withdraw']);
    final c = _map(raw['convert']);
    final depositMethods = d['methods'] is List ? _strings(d['methods']).where(_depositMethods.contains).toList() : _depositMethods;
    final withdrawMethods = _strings(w['methods']).where(_withdrawMethods.contains).toList();
    final convertCurrencies = _strings(c['currencies']).where(_iso).toList();
    final int ageHours = _int(c['maxRateAgeHours']);
    return WalletConfig(
      currencies: currencies,
      deposit: WalletDepositConfig(enabled: d['enabled'] == true && depositMethods.isNotEmpty, limits: WalletLimits.parse(d), methods: depositMethods),
      withdraw: WalletWithdrawConfig(
        enabled: w['enabled'] == true && withdrawMethods.isNotEmpty,
        methods: withdrawMethods,
        limits: WalletLimits.parse(w),
        fee: FeeRule.parse(w),
        delay: w['delay']?.toString() ?? '',
      ),
      convert: WalletConvertConfig(
        // Converting needs two currencies.
        enabled: c['enabled'] == true && convertCurrencies.length >= 2,
        currencies: convertCurrencies,
        feePercent: _num(c['feePercent']).clamp(0, 100).toDouble(),
        maxRateAge: Duration(hours: ageHours > 0 ? ageHours : 48),
      ),
      reauthAbove: _amounts(_map(raw['security'])['reauthAbove']),
    );
  }

  /// Re-authentication before a withdrawal of [amount].
  bool needsReauth(int amount, String currency) {
    final int? above = reauthAbove[currency];
    return above == null || amount >= above;
  }
}

/// A conversion: what is debited, the fee, and what arrives.
class WalletConversion {
  final String from;
  final String to;

  /// Debited from the [from] wallet (fee included).
  final int amount;
  final int fee;

  /// Credited to the [to] wallet.
  final int receive;
  final double rate;

  const WalletConversion({required this.from, required this.to, required this.amount, required this.fee, required this.receive, required this.rate});
}

/// Statuses of `wallet_operations`.
abstract final class WalletOps {
  static const String deposit = 'deposit';
  static const String withdrawal = 'withdrawal';
  static const String conversion = 'conversion';

  static String typeLabel(String? t) => const {deposit: 'Deposit', withdrawal: 'Withdrawal', conversion: 'Conversion'}[t] ?? 'Operation';

  static String statusLabel(String? s) => const {
        'pending': 'In progress',
        'completed': 'Completed',
        'failed': 'Failed',
        'reversed': 'Refunded',
      }[s] ??
      (s ?? '-');

  static bool ended(String? s) => s == 'failed' || s == 'reversed';
}

abstract final class WalletRules {
  /// The withdrawal fee of [amount] (added to it: the destination receives [amount]).
  static int withdrawFee(WalletConfig c, int amount, String currency) => c.withdraw.fee.feeFor(amount, currency);

  /// The conversion of [amount] [from] -> [to] at [rate] (1 [from] = [rate]
  /// [to]) with [feePercent] taken in [from]. What arrives is rounded down
  /// to the [to] currency's minor unit. Null when nothing would arrive.
  static WalletConversion? conversion({required int amount, required String from, required String to, required double rate, required double feePercent}) {
    if (amount <= 0 || rate <= 0 || from == to) return null;
    final int fee = (amount * feePercent / 100).round();
    final int net = amount - fee;
    if (net <= 0) return null;
    final int shift = FinanceMoney.exponent(to) - FinanceMoney.exponent(from);
    final double raw = net * rate * math.pow(10, shift);
    // A hair under the exact value for binary rounding, never more than due.
    final int receive = (raw + 1e-9).floor();
    if (receive <= 0) return null;
    return WalletConversion(from: from, to: to, amount: amount, fee: fee, receive: receive, rate: rate);
  }

  /// The latest usable rate for [from] -> [to] from snapshots
  /// (`exchange_rate_snapshots`: `{from, to, rate, observedAt}`, 1 from =
  /// rate to): the direct pair, else the inverse one. Null when none is
  /// fresher than [maxAge] at [now].
  static ({double rate, DateTime observedAt, String source, String id})? rateOf(List<Map<String, dynamic>> snapshots, String from, String to, DateTime now, Duration maxAge,
      DateTime? Function(dynamic) toDate) {
    ({double rate, DateTime observedAt, String source, String id})? best;
    for (final s in snapshots) {
      final double r = _num(s['rate']);
      final DateTime? at = toDate(s['observedAt']);
      if (r <= 0 || at == null || now.difference(at) > maxAge) continue;
      double? rate;
      if (s['from'] == from && s['to'] == to) rate = r;
      if (s['from'] == to && s['to'] == from) rate = 1 / r;
      if (rate == null) continue;
      // `id`: the snapshot document, named on the conversion so the rules
      // can check the amount received against its rate.
      if (best == null || at.isAfter(best.observedAt)) best = (rate: rate, observedAt: at, source: s['source']?.toString() ?? '', id: s['id']?.toString() ?? '');
    }
    return best;
  }

  /// The id of the deposit of a gateway payment: its receipt id
  /// (`{method}_{reference}`), so a gateway payment is deposited once.
  static String depositId(FinanceFunding funding) => funding.receiptId!;

  /// A gateway payment deposited into the user's wallet: the operation
  /// `wallet_operations/{receiptId}` (completed), the posting `platform ->
  /// wallet` (`deposit`, gateway-funded) and its payment receipt. The same
  /// shape as `FinancePay.gatewayDeposit` (lib/service/finance_direct.dart):
  /// "Add money", and the first step of any payment made by a gateway
  /// (transfer, bill), which then pays from the wallet; [purposeKind] /
  /// [purposeId] name that request.
  static List<FinanceWrite> depositWrites({
    required String uid,
    required String currency,
    required int amount,
    required FinanceFunding funding,
    required ({String id, bool exists}) wallet,
    String? purposeKind,
    String? purposeId,
    String? txId,
    String? reference,
  }) {
    assert(!funding.isWallet && funding.receiptId != null, 'a deposit is paid by a gateway, with its reference');
    final String opId = depositId(funding);
    final posting = FinanceLedger.plan(
      type: 'deposit',
      currency: currency,
      from: FinanceLedger.platformId(currency),
      to: wallet.id,
      amount: amount,
      newAccounts: wallet.exists ? const {} : {wallet.id: FinanceLedger.walletFields(uid, currency)},
      userIds: [uid],
      sourceKind: 'wallet_operations',
      sourceId: opId,
      createdBy: uid,
      funding: funding,
      // Language-neutral: the list shows it as typed (the type label is translated).
      description: FinanceGateways.label(funding.method),
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('wallet_operations/$opId', 'create', {
        'id': opId,
        'userId': uid,
        'type': WalletOps.deposit,
        'status': 'completed',
        'currency': currency,
        'amount': amount,
        'fee': 0,
        'total': amount,
        'accountId': wallet.id,
        'gateway': funding.toMap(),
        'txId': posting.txId,
        'reference': posting.reference,
        if (purposeKind != null && purposeId != null) 'purpose': {'kind': purposeKind, 'id': purposeId},
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      }),
      ...posting.writes,
    ];
  }

  /// A withdrawal request: the operation (pending, for the admin to pay
  /// out) and the posting `wallet -> platform` of amount + fee
  /// (`withdrawal`; the fee stays with the platform, so one credit line).
  static List<FinanceWrite> withdrawWrites({
    required String uid,
    required String opId,
    required String currency,
    required int amount,
    required int fee,
    required Map<String, dynamic> destination,
    required String walletId,
    required String txId,
    String? reference,
  }) {
    final int total = amount + fee;
    final posting = FinanceLedger.plan(
      type: 'withdrawal',
      currency: currency,
      from: walletId,
      to: FinanceLedger.platformId(currency),
      amount: total,
      userIds: [uid],
      sourceKind: 'wallet_operations',
      sourceId: opId,
      createdBy: uid,
      description: FinanceDestination.describe(destination),
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('wallet_operations/$opId', 'create', {
        'id': opId,
        'userId': uid,
        'type': WalletOps.withdrawal,
        'status': 'pending',
        'currency': currency,
        'amount': amount,
        'fee': fee,
        'total': total,
        'accountId': walletId,
        'destination': destination,
        'txId': posting.txId,
        'reference': posting.reference,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      ...posting.writes,
    ];
  }

  /// A conversion, in ONE batch of two postings over four accounts:
  /// `wallet_A -> platform_A` ([c].amount) and `platform_B -> wallet_B`
  /// ([c].receive), plus the operation (completed).
  static List<FinanceWrite> convertWrites({
    required String uid,
    required String opId,
    required WalletConversion c,
    required String fromWalletId,
    required ({String id, bool exists}) toWallet,
    required String txIdFrom,
    required String txIdTo,
    required String rateSource,
    required DateTime rateObservedAt,
    required String rateSnapshotId,
    String? reference,
  }) {
    final String ref = reference ?? FinanceLedger.newReference();
    final out = FinanceLedger.plan(
      type: 'conversion',
      currency: c.from,
      from: fromWalletId,
      to: FinanceLedger.platformId(c.from),
      amount: c.amount,
      userIds: [uid],
      sourceKind: 'wallet_operations',
      sourceId: opId,
      createdBy: uid,
      description: '${c.from} -> ${c.to}',
      txId: txIdFrom,
      reference: ref,
    );
    final into = FinanceLedger.plan(
      type: 'conversion',
      currency: c.to,
      from: FinanceLedger.platformId(c.to),
      to: toWallet.id,
      amount: c.receive,
      newAccounts: toWallet.exists ? const {} : {toWallet.id: FinanceLedger.walletFields(uid, c.to)},
      userIds: [uid],
      sourceKind: 'wallet_operations',
      sourceId: opId,
      createdBy: uid,
      description: '${c.from} -> ${c.to}',
      txId: txIdTo,
      reference: ref,
    );
    return [
      FinanceWrite('wallet_operations/$opId', 'create', {
        'id': opId,
        'userId': uid,
        'type': WalletOps.conversion,
        'status': 'completed',
        'currency': c.from,
        'amount': c.amount,
        'fee': c.fee,
        'total': c.amount,
        'accountId': fromWalletId,
        'toCurrency': c.to,
        'toAccountId': toWallet.id,
        'rate': c.rate,
        'rateSource': rateSource,
        'rateObservedAt': Timestamp.fromDate(rateObservedAt),
        'rateSnapshotId': rateSnapshotId,
        'receiveAmount': c.receive,
        'txId': out.txId,
        'txIds': [out.txId, into.txId],
        'reference': ref,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      }),
      ...out.writes,
      ...into.writes,
    ];
  }
}
