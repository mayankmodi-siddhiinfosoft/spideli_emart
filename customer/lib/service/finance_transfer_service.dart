import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_payment_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_wallet_service.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_receipt_pdf.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Money transfers and bill payments for the customer app, written directly
/// to Firestore (.claude/FINANCE-DIRECT-FIRESTORE.md sections 3.3 / 3.4).
/// The app finds the recipient in `users`, computes the fee from the
/// admin's settings and writes the request with its ledger posting in one
/// batch (the security rules check it): an internal transfer is completed
/// at once; an external transfer and a bill are `processing` until the
/// admin pays them out (or refunds them). Each request's id is the request
/// key of its intent, so a retried batch can never post twice.
abstract final class FinanceTransferService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Stream<List<Map<String, dynamic>>> _list(Query<Map<String, dynamic>> q) => q.snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<Map<String, dynamic>?> _doc(String collection, String id) =>
      _db.collection(collection).doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  // ── Transfers ──────────────────────────────────────────────────────────

  static Future<TransferConfig?> config() async => TransferConfig.parse((await _db.collection('platform_settings').doc('transfers').get()).data());

  /// Transfers the user sent or received.
  static Stream<List<Map<String, dynamic>>> transfers() =>
      _list(_db.collection('money_transfers').where('participantIds', arrayContains: _uid).orderBy('createdAt', descending: true).limit(50));

  static Stream<Map<String, dynamic>?> transfer(String id) => _doc('money_transfers', id);

  static Stream<List<Map<String, dynamic>>> beneficiaries() =>
      _list(_db.collection('transfer_beneficiaries').where('userId', isEqualTo: _uid).orderBy('lastUsedAt', descending: true).limit(20));

  static Future<void> deleteBeneficiary(String id) async {
    try {
      await _db.collection('transfer_beneficiaries').doc(id).delete();
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
  }

  /// Saves the recipient of [d] once (create-only; best effort: never fails a transfer).
  static Future<void> _saveBeneficiary(TransferDraft d) async {
    try {
      final ref = _db.collection('transfer_beneficiaries').doc(TransferPlans.beneficiaryId(_uid, d.channel, d.recipientKey));
      if ((await ref.get()).exists) return;
      await ref.set(TransferPlans.beneficiary(_uid, d));
    } catch (e) {
      log('finance: beneficiary not saved: $e');
    }
  }

  /// The Spideli user an internal transfer goes to, found by [email] or
  /// [phone] in `users`. Refuses an unknown or inactive account
  /// (`recipient_not_found`), several matches (`recipient_ambiguous`) and
  /// the user themself (`self_transfer`).
  static Future<TransferRecipient> findRecipient({String? email, String? phone}) async {
    final List<(String, Map<String, dynamic>)> found = [];
    try {
      if ((email ?? '').trim().isNotEmpty) {
        final typed = email!.trim();
        final snap = await _db.collection('users').where('email', whereIn: {typed, typed.toLowerCase()}.toList()).limit(5).get();
        found.addAll(snap.docs.map((d) => (d.id, d.data())));
      } else if ((phone ?? '').trim().isNotEmpty) {
        final candidates = RecipientMatch.phoneCandidates(phone!);
        if (candidates.isEmpty) throw const FinanceException('recipient_not_found');
        final snap = await _db.collection('users').where('phoneNumber', whereIn: candidates).limit(10).get();
        found.addAll(RecipientMatch.phoneMatches(snap.docs.map((d) => (d.id, d.data())).toList(), phone, countryCode: Constant.userModel?.countryCode));
      }
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
    final r = RecipientMatch.pick(found, _uid);
    if (r.reason != null) throw FinanceException(r.reason!);
    return r.recipient!;
  }

  static String get _senderName {
    final String name = (Constant.userModel?.fullName() ?? '').trim();
    return name.isEmpty ? (Constant.userModel?.email ?? '') : name;
  }

  /// Sends [d] paid with [funding] (the pay sheet's choice) and returns the
  /// pay sheet's reply: `succeeded` for an internal transfer (completed),
  /// `processing` for an external one; `transferId` names the document.
  static Future<Map<String, dynamic>> send(TransferConfig config, TransferDraft d, FinanceFunding funding) async {
    final ch = config.channels[d.channel];
    if (ch == null || !config.currencies.contains(d.currency)) throw const FinanceException('service_unavailable');
    if (d.amount < ch.minFor(d.currency) || (ch.maxFor(d.currency) != null && d.amount > ch.maxFor(d.currency)!)) throw const FinanceException('amount_out_of_range');
    if (ch.fee.feeFor(d.amount, d.currency) != d.fee) throw const FinanceException('request_expired');
    if (!_fundingAllowed(config.sourceMethods, funding)) throw const FinanceException('gateway_unavailable');
    if (d.internal && (d.recipientId ?? '').isEmpty) throw const FinanceException('recipient_not_found');
    if (d.recipientId == _uid) throw const FinanceException('self_transfer');
    if (funding.isWallet) await FinancePaymentService.requireAllowed('transfers');
    final String intent = 'transfer:${d.channel}:${d.recipientKey}:${d.currency}:${d.amount}:${funding.method}:${funding.reference ?? ''}';
    final String id = FinanceRequestKeys.of(intent);
    final String tx = FinancePaymentService.txIdOf(id);
    final String guard = 'money_transfers/$id';
    // A gateway payment lands in the sender's wallet first (once), then pays
    // like the wallet: if the transfer then fails, the money is in the wallet.
    if (!funding.isWallet) await FinanceWalletService.depositGateway(funding: funding, currency: d.currency, amount: d.total, purposeKind: 'money_transfers', purposeId: id);
    final already = await FinancePaymentService.read(guard).catchError((_) => null);
    if (already != null && already['senderId'] == _uid) {
      FinanceRequestKeys.done(intent);
      return {'status': d.internal ? 'succeeded' : 'processing', 'reference': already['reference'] ?? '', 'transferId': id};
    }
    final String walletId = (await FinancePaymentService.requireBalance(d.currency, d.total)).id;
    Map<String, dynamic>? done;
    List<FinanceWrite> writes;
    if (d.internal) {
      // The sender cannot read the recipient's accounts: when the rules do
      // not say whether the wallet exists, post to it, then create it.
      final String recipientWallet = FinanceLedger.walletId(d.recipientId!, d.currency);
      bool? exists;
      try {
        exists = await FinanceLedger.exists(recipientWallet);
      } catch (_) {
        exists = null;
      }
      List<FinanceWrite> plan(bool walletExists) => TransferPlans.internal(
            id: id,
            d: d,
            senderId: _uid,
            senderName: _senderName,
            funding: funding,
            senderWalletId: walletId,
            recipientWallet: (id: recipientWallet, exists: walletExists),
            txId: tx,
          );
      writes = plan(exists ?? true);
      try {
        done = await FinancePaymentService.commit(writes, guard: guard, owner: 'senderId');
      } on FinanceException catch (e) {
        if (exists != null || (e.reason != 'permission_denied' && e.reason != 'not-found')) rethrow;
        writes = plan(false);
        done = await FinancePaymentService.commit(writes, guard: guard, owner: 'senderId');
      }
    } else {
      writes = TransferPlans.external(id: id, d: d, senderId: _uid, senderName: _senderName, funding: funding, senderWalletId: walletId, txId: tx);
      done = await FinancePaymentService.commit(writes, guard: guard, owner: 'senderId');
    }
    FinanceRequestKeys.done(intent);
    final String reference = done?['reference']?.toString() ?? writes.first.data['reference']?.toString() ?? '';
    if (done == null) {
      if (d.saveBeneficiary) unawaited(_saveBeneficiary(d));
      if (d.internal && d.recipientToken.isNotEmpty) {
        unawaited(SendNotification.sendFcmMessage(
          'transfer_received',
          d.recipientToken,
          {'type': 'transfer_received', 'transferId': id},
          recipient: PushRecipient.customer,
          placeholders: {'amount': FinanceMoney.plain(d.amount, d.currency), 'senderName': _senderName},
        ).catchError((_) => false));
      }
    }
    return {'status': d.internal ? 'succeeded' : 'processing', 'reference': reference, 'transferId': id};
  }

  /// Whether [funding] is one of the [methods] the admin allows.
  static bool _fundingAllowed(List<String> methods, FinanceFunding funding) =>
      funding.isWallet ? methods.contains('wallet') : (FinanceGateways.of(funding.method)?.families.any(methods.contains) ?? false);

  /// Asks the admin to cancel an external transfer still `processing` and
  /// not taken yet (`cancelRequested`); the admin cancels and refunds it.
  static Future<void> requestCancel(String transferId) async {
    final t = await FinancePaymentService.read('money_transfers/$transferId');
    if (t == null || !TransferPlans.canRequestCancel(t, _uid)) throw const FinanceException('not_cancellable');
    try {
      await _db.collection('money_transfers').doc(transferId).update(TransferPlans.cancelRequest());
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
  }

  // ── Bills ──────────────────────────────────────────────────────────────

  static Future<BillsConfig?> billsConfig() async => BillsConfig.parse((await _db.collection('platform_settings').doc('bills').get()).data());

  static Stream<List<Biller>> billers(String category) =>
      _db.collection('utility_billers').where('published', isEqualTo: true).where('category', isEqualTo: category).limit(100).snapshots().map((s) {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final int o = _order(a.data()).compareTo(_order(b.data()));
            return o != 0 ? o : '${a.data()['name']}'.compareTo('${b.data()['name']}');
          });
        return docs.map((d) => Biller.fromMap({...d.data(), 'id': d.id})).whereType<Biller>().toList();
      });

  static Stream<Biller?> biller(String id) =>
      _db.collection('utility_billers').doc(id).snapshots().map((s) => s.data() == null ? null : Biller.fromMap({...s.data()!, 'id': s.id}));

  static Stream<List<Map<String, dynamic>>> savedAccounts() =>
      _list(_db.collection('utility_saved_accounts').where('userId', isEqualTo: _uid).orderBy('lastUsedAt', descending: true).limit(20));

  static Future<void> deleteSavedAccount(String id) async {
    try {
      await _db.collection('utility_saved_accounts').doc(id).delete();
    } catch (e) {
      throw FinancePaymentService.mapError(e);
    }
  }

  /// Saves the bill account of [d] once (create-only; best effort).
  static Future<void> _saveAccount(BillDraft d) async {
    try {
      final ref = _db.collection('utility_saved_accounts').doc(BillPlans.savedAccountId(_uid, d.biller.id, d.account));
      if ((await ref.get()).exists) return;
      await ref.set(BillPlans.savedAccount(_uid, d));
    } catch (e) {
      log('finance: bill account not saved: $e');
    }
  }

  /// Pays the bill [d] with [funding]: the request is `processing` until
  /// the admin pays the biller (or refunds it). Returns the pay sheet's
  /// reply, with `requestId`.
  static Future<Map<String, dynamic>> payBill(BillsConfig config, BillDraft d, FinanceFunding funding) async {
    final b = d.biller;
    if (!config.currencies.contains(b.currency)) throw const FinanceException('service_unavailable');
    if (!b.accountValid(d.account) || BillPlans.amountProblem(b, d.amount) != null) throw const FinanceException('amount_out_of_range');
    if (!_fundingAllowed(config.paymentMethods, funding)) throw const FinanceException('gateway_unavailable');
    if (funding.isWallet) await FinancePaymentService.requireAllowed('payments');
    final String intent = 'bill:${b.id}:${d.account}:${d.package?.code ?? ''}:${d.amount}:${funding.method}:${funding.reference ?? ''}';
    final String id = FinanceRequestKeys.of(intent);
    final String guard = 'utility_payment_requests/$id';
    // A gateway payment lands in the wallet first (once), then pays like the wallet.
    if (!funding.isWallet) await FinanceWalletService.depositGateway(funding: funding, currency: b.currency, amount: d.total, purposeKind: 'utility_payment_requests', purposeId: id);
    final already = await FinancePaymentService.read(guard).catchError((_) => null);
    if (already != null && already['userId'] == _uid) {
      FinanceRequestKeys.done(intent);
      return {'status': 'processing', 'reference': already['reference'] ?? '', 'requestId': id};
    }
    final String walletId = (await FinancePaymentService.requireBalance(b.currency, d.total)).id;
    final writes = BillPlans.payment(id: id, uid: _uid, d: d, funding: funding, walletId: walletId, txId: FinancePaymentService.txIdOf(id));
    final done = await FinancePaymentService.commit(writes, guard: guard);
    FinanceRequestKeys.done(intent);
    if (done == null && d.saveAccount) unawaited(_saveAccount(d));
    return {'status': 'processing', 'reference': done?['reference'] ?? writes.first.data['reference'], 'requestId': id};
  }

  static Stream<List<Map<String, dynamic>>> billPayments() =>
      _list(_db.collection('utility_payment_requests').where('userId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(50));

  static Stream<Map<String, dynamic>?> billPayment(String id) => _doc('utility_payment_requests', id);

  // ── Receipts ───────────────────────────────────────────────────────────

  /// Writes a receipt PDF and opens the share sheet.
  static Future<void> shareReceipt({required String title, required String reference, required List<(String, String)> lines, String? highlight}) async {
    final bytes = FinanceReceiptPdf.build(title: title, lines: lines, highlight: highlight, label: (k) => k.tr);
    final dir = await getTemporaryDirectory();
    final safe = reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File('${dir.path}/spideli-receipt-${safe.isEmpty ? DateTime.now().millisecondsSinceEpoch : safe}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: title));
  }
}

/// The admin's display order (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;
