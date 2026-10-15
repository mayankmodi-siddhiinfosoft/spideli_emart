import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';

/// The writes of paying the platform (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 2.3), as data: unit tested in test/finance_direct_test.dart.
///
/// Money paid OUT of Spideli (card load, card fee, fund subscription,
/// insurance premium) is posted from the user's wallet to `platform_{CUR}`
/// at once; the admin then completes the request (loads the card, executes
/// the order, activates the policy) or posts a `reversal` back to the wallet.
///
/// A gateway payment cannot be posted `platform -> platform`: it lands in
/// the user's wallet first ([gatewayDeposit], the deposit of section 3.2 with
/// its `payment_receipts`), then pays from the wallet like a wallet payment.
/// If the second step fails, the money is safe and visible in the wallet.
abstract final class FinancePay {
  /// The deposit of a gateway payment of [amount] into the user's wallet:
  /// `wallet_operations/{receiptId}` (one per gateway payment), the receipt
  /// and the posting `platform -> wallet` (`deposit`, funding gateway).
  /// [purposeKind] / [purposeId] name the request it pays.
  static List<FinanceWrite> gatewayDeposit({
    required String uid,
    required String currency,
    required String walletId,
    required bool walletExists,
    required int amount,
    required FinanceFunding funding,
    required String purposeKind,
    required String purposeId,
    String? txId,
    String? reference,
  }) {
    final String id = funding.receiptId!;
    final posting = FinanceLedger.plan(
      type: 'deposit',
      currency: currency,
      from: FinanceLedger.platformId(currency),
      to: walletId,
      amount: amount,
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(uid, currency)},
      userIds: [uid],
      sourceKind: 'wallet_operations',
      sourceId: id,
      createdBy: uid,
      funding: funding,
      description: 'Deposit',
      txId: txId,
      reference: reference,
    );
    return [
      FinanceWrite('wallet_operations/$id', 'create', {
        'id': id,
        'userId': uid,
        'type': 'deposit',
        'status': 'completed',
        'amount': amount,
        // The same shape as a deposit made from the Wallet tab.
        'fee': 0,
        'total': amount,
        'accountId': walletId,
        'currency': currency,
        'gateway': funding.toMap(),
        'txId': posting.txId,
        'reference': posting.reference,
        'purpose': {'kind': purposeKind, 'id': purposeId},
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      }),
      ...posting.writes,
    ];
  }

  /// The posting of [amount] from the user's wallet [walletId] to the
  /// platform, for the request [sourceKind]/[sourceId]. A fee is part of
  /// [amount] (the platform receives it all; the request records the split).
  static FinancePosting toPlatform({
    required String type,
    required String uid,
    required String currency,
    required String walletId,
    required int amount,
    required String sourceKind,
    required String sourceId,
    String description = '',
    String? txId,
    String? reference,
  }) =>
      FinanceLedger.plan(
        type: type,
        currency: currency,
        from: walletId,
        to: FinanceLedger.platformId(currency),
        amount: amount,
        userIds: [uid],
        sourceKind: sourceKind,
        sourceId: sourceId,
        createdBy: uid,
        description: description,
        txId: txId,
        reference: reference,
      );
}

/// Direct Firestore writes of Spideli Finance: one batch per step, checked
/// by the security rules. Requests have deterministic ids
/// (`FinanceRequestKeys`), are created once (create-only), and a retry reads
/// them back first: an existing request is a request already made.
abstract final class FinanceDirect {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// A lost connection (offline, timed out) as the finance `network` error.
  static Object _connection(Object e) {
    if (e is TimeoutException) return const FinanceException('network');
    if (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded')) return const FinanceException('network');
    return e;
  }

  /// A refusal of the security rules, as the finance error the screens show.
  static Object _mapped(Object e) => e is FirebaseException && e.code == 'permission-denied' ? const FinanceException('permission_denied') : e;

  /// Commits [writes] all or nothing, online only ([FinanceLedger.commit]):
  /// offline, the step fails with a connection error instead of waiting
  /// forever or being sent later without the customer knowing.
  static Future<void> commit(Iterable<FinanceWrite> writes) async {
    try {
      await FinanceLedger.commit(writes, db: _db);
    } catch (e) {
      throw _connection(_mapped(e));
    }
  }

  /// The document at [path], or null when it does not exist.
  static Future<Map<String, dynamic>?> get(String path) async {
    try {
      return (await _db.doc(path).get()).data();
    } catch (e) {
      throw _mapped(e);
    }
  }

  /// The request at [path] when it was already made, else null. Request ids
  /// are random per user: a read the rules refuse can only be a request
  /// that does not exist yet.
  static Future<Map<String, dynamic>?> existing(String path) async {
    try {
      return (await _db.doc(path).get()).data();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// The user's wallet in [currency] when it holds at least [amount]
  /// (checked here so the user hears why; the rules refuse it anyway).
  static Future<String> walletWith(String uid, String currency, int amount) async {
    final ({String id, bool exists, int balance}) w;
    try {
      w = await FinanceLedger.wallet(uid, currency, db: _db);
    } catch (e) {
      throw _mapped(e);
    }
    if (!w.exists || w.balance < amount) throw const FinanceException('insufficient_funds');
    return w.id;
  }

  /// Pays [amount] to the platform for the request [sourceKind]/[sourceId]
  /// and writes the request with it, in one batch built by [writes] from the
  /// posting. A gateway payment is deposited into the wallet first (once per
  /// gateway payment). When [existing] finds the request already made (a
  /// retry after a lost answer), nothing more is written. Returns the reply
  /// of the payment sheet: `{status: succeeded, reference}`.
  static Future<Map<String, dynamic>> payPlatform({
    required FinanceFunding funding,
    required String type,
    required String currency,
    required int amount,
    required String sourceKind,
    required String sourceId,
    required String description,
    required Future<Map<String, dynamic>?> Function() existing,
    required List<FinanceWrite> Function(FinancePosting posting) writes,
  }) async {
    final String uid = FinanceService.uid;
    if (uid.isEmpty) throw const FinanceException('sign_in_required');
    if (amount <= 0) throw const FinanceException('amount_out_of_range');
    if (!funding.isWallet) await _deposit(uid, funding, currency, amount, sourceKind, sourceId);
    final done = await existing();
    if (done != null) return {'status': 'succeeded', 'reference': done['reference'] ?? ''};
    final String wallet = await walletWith(uid, currency, amount);
    final posting = FinancePay.toPlatform(
      type: type,
      uid: uid,
      currency: currency,
      walletId: wallet,
      amount: amount,
      sourceKind: sourceKind,
      sourceId: sourceId,
      description: description,
    );
    await commit(writes(posting));
    return {'status': 'succeeded', 'reference': posting.reference};
  }

  /// The gateway payment [funding] of [amount] into the user's wallet, once:
  /// `wallet_operations/{receiptId}` already there = deposited.
  static Future<void> _deposit(String uid, FinanceFunding funding, String currency, int amount, String purposeKind, String purposeId) async {
    final String? id = funding.receiptId;
    if (id == null) throw const FinanceException('provider_unavailable');
    if (await existing('wallet_operations/$id') != null) return;
    final ({String id, bool exists, int balance}) w;
    try {
      w = await FinanceLedger.wallet(uid, currency, db: _db);
    } catch (e) {
      throw _mapped(e);
    }
    await commit(FinancePay.gatewayDeposit(
      uid: uid,
      currency: currency,
      walletId: w.id,
      walletExists: w.exists,
      amount: amount,
      funding: funding,
      purposeKind: purposeKind,
      purposeId: purposeId,
    ));
  }
}
