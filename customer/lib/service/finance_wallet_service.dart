import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_payment_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_wallet_rules.dart';

/// The Spideli Finance wallet's own operations, written directly to
/// Firestore (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.2): deposit
/// (gateway -> wallet, completed at once), withdrawal (wallet -> platform,
/// pending until the admin pays it out), conversion (two postings in one
/// batch). A deposit's id is its gateway payment's receipt id, any other
/// operation's the request key of its intent: a retried batch can never
/// post twice, and a retry first reads the operation back.
abstract final class FinanceWalletService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// `platform_settings/wallet`, or null when the admin has not set it up.
  static Future<WalletConfig?> config() async => WalletConfig.parse((await _db.collection('platform_settings').doc('wallet').get()).data());

  static Stream<Map<String, dynamic>?> operation(String id) =>
      _db.collection('wallet_operations').doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  /// The user's operations still in progress (withdrawals waiting for the payout), newest first.
  static Stream<List<Map<String, dynamic>>> pendingOperations() => _db
      .collection('wallet_operations')
      .where('userId', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()
        ..sort((a, b) => (_date(b['createdAt']) ?? DateTime(9999)).compareTo(_date(a['createdAt']) ?? DateTime(9999))));

  static String _referenceOf(List<FinanceWrite> writes, String path) => writes.firstWhere((w) => w.path == path).data['reference']?.toString() ?? '';

  /// Deposits a gateway payment ([funding], [amount] charged) into the
  /// user's [currency] wallet, once per gateway payment: the operation's id
  /// is the payment's receipt id, so a retry finds it done. [purposeKind] /
  /// [purposeId] name the request the money then pays (a transfer, a bill).
  /// Returns the operation.
  static Future<Map<String, dynamic>> depositGateway({
    required FinanceFunding funding,
    required String currency,
    required int amount,
    String? purposeKind,
    String? purposeId,
  }) async {
    if (funding.isWallet || funding.receiptId == null) throw const FinanceException('gateway_unavailable');
    if (amount <= 0) throw const FinanceException('amount_out_of_range');
    final String path = 'wallet_operations/${WalletRules.depositId(funding)}';
    final already = await _existing(path);
    if (already != null) return already;
    final ({String id, bool exists, int balance}) wallet;
    try {
      wallet = await FinanceLedger.wallet(_uid, currency);
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
    final writes = WalletRules.depositWrites(
      uid: _uid,
      currency: currency,
      amount: amount,
      funding: funding,
      wallet: (id: wallet.id, exists: wallet.exists),
      purposeKind: purposeKind,
      purposeId: purposeId,
    );
    final done = await FinancePaymentService.commit(writes, guard: path);
    return done ?? {...writes.first.data, 'id': WalletRules.depositId(funding)};
  }

  /// The user's own document at [path], or null when it does not exist yet
  /// (the rules refuse reading a document that does not exist: same answer).
  static Future<Map<String, dynamic>?> _existing(String path) async {
    try {
      final snap = await _db.doc(path).get();
      return snap.data() == null ? null : {...snap.data()!, 'id': snap.id};
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      throw FinancePaymentService.mapError(e);
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
  }

  /// "Add money": records a deposit already paid by a gateway ([funding]).
  static Future<Map<String, dynamic>> deposit({required String currency, required int amount, required FinanceFunding funding}) async {
    final op = await depositGateway(funding: funding, currency: currency, amount: amount);
    return {'status': 'succeeded', 'reference': op['reference'] ?? '', 'operationId': op['id']};
  }

  /// Asks for [amount] to be paid out to [destination]; the wallet is
  /// debited of amount + fee now, the admin pays out (or refunds).
  static Future<Map<String, dynamic>> withdraw({required WalletConfig config, required String currency, required int amount, required Map<String, dynamic> destination}) async {
    final String method = destination['method']?.toString() ?? '';
    if (!config.withdraw.enabled || !config.withdraw.methods.contains(method)) throw const FinanceException('service_unavailable');
    if (config.withdraw.limits.problem(amount, currency) != null) throw const FinanceException('amount_out_of_range');
    await FinancePaymentService.requireAllowed('wallet');
    final int fee = WalletRules.withdrawFee(config, amount, currency);
    final String intent = 'wallet.withdraw:$currency:$amount:$method:${destination['number'] ?? destination['accountNumber'] ?? ''}';
    final String id = FinanceRequestKeys.of(intent);
    // A retry after a lost answer: the request (and its debit) is already there.
    final already = await _existing('wallet_operations/$id');
    if (already != null) {
      FinanceRequestKeys.done(intent);
      return {'status': 'pending', 'reference': already['reference'] ?? '', 'operationId': id};
    }
    final wallet = await FinancePaymentService.requireBalance(currency, amount + fee);
    final writes = WalletRules.withdrawWrites(
      uid: _uid,
      opId: id,
      currency: currency,
      amount: amount,
      fee: fee,
      destination: destination,
      walletId: wallet.id,
      txId: FinancePaymentService.txIdOf(id),
    );
    final done = await FinancePaymentService.commit(writes, guard: 'wallet_operations/$id');
    FinanceRequestKeys.done(intent);
    return {'status': 'pending', 'reference': done?['reference'] ?? _referenceOf(writes, 'wallet_operations/$id'), 'operationId': id};
  }

  /// The latest admin-published rate [from] -> [to] (the pair, else its
  /// inverse), or null when none is recent enough.
  static Future<({double rate, DateTime observedAt, String source, String id})?> rate(String from, String to, Duration maxAge) async {
    Future<List<Map<String, dynamic>>> pair(String a, String b) async => (await _db
            .collection('exchange_rate_snapshots')
            .where('pair', isEqualTo: '${a}_$b')
            .orderBy('observedAt', descending: true)
            .limit(1)
            .get())
        .docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList();
    try {
      final found = await Future.wait([pair(from, to), pair(to, from)]);
      return WalletRules.rateOf([...found[0], ...found[1]], from, to, DateTime.now(), maxAge, _date);
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
  }

  /// Converts [amount] of the [from] wallet into the [to] wallet at the
  /// latest rate ([expected]: the conversion the user confirmed; refused
  /// with `rate_unavailable` when the rate moved since).
  static Future<Map<String, dynamic>> convert({required WalletConfig config, required String from, required String to, required int amount, WalletConversion? expected}) async {
    final cc = config.convert;
    if (!cc.enabled || !cc.currencies.contains(from) || !cc.currencies.contains(to) || from == to) throw const FinanceException('service_unavailable');
    await FinancePaymentService.requireAllowed('wallet');
    final r = await rate(from, to, cc.maxRateAge);
    if (r == null) throw const FinanceException('rate_unavailable');
    final c = WalletRules.conversion(amount: amount, from: from, to: to, rate: r.rate, feePercent: cc.feePercent);
    if (c == null) throw const FinanceException('amount_out_of_range');
    if (expected != null && expected.receive != c.receive) throw const FinanceException('rate_unavailable');
    final String intent = 'wallet.convert:$from:$to:$amount:${c.receive}';
    final String id = FinanceRequestKeys.of(intent);
    final already = await _existing('wallet_operations/$id');
    if (already != null) {
      FinanceRequestKeys.done(intent);
      return {'status': 'succeeded', 'reference': already['reference'] ?? '', 'operationId': id};
    }
    final fromWallet = await FinancePaymentService.requireBalance(from, amount);
    final ({String id, bool exists, int balance}) toWallet;
    try {
      toWallet = await FinanceLedger.wallet(_uid, to);
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
    final String tx = FinancePaymentService.txIdOf(id);
    final writes = WalletRules.convertWrites(
      uid: _uid,
      opId: id,
      c: c,
      fromWalletId: fromWallet.id,
      toWallet: (id: toWallet.id, exists: toWallet.exists),
      txIdFrom: tx,
      txIdTo: '${tx}b',
      rateSource: r.source,
      rateObservedAt: r.observedAt,
      rateSnapshotId: r.id,
    );
    final done = await FinancePaymentService.commit(writes, guard: 'wallet_operations/$id');
    FinanceRequestKeys.done(intent);
    return {'status': 'succeeded', 'reference': done?['reference'] ?? _referenceOf(writes, 'wallet_operations/$id'), 'operationId': id};
  }

  /// The label of an operation's destination or source, for lists.
  static String describe(Map<String, dynamic> op) => switch (op['type']) {
        WalletOps.withdrawal => FinanceDestination.describe(op['destination'] is Map ? Map<String, dynamic>.from(op['destination'] as Map) : null),
        WalletOps.deposit => FinanceGateways.label('${(op['gateway'] is Map ? (op['gateway'] as Map)['method'] : null) ?? ''}'),
        WalletOps.conversion => '${op['currency'] ?? ''} → ${op['toCurrency'] ?? ''}',
        _ => '',
      };
}
