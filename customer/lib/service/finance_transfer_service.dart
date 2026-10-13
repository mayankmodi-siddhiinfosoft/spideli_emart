import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_receipt_pdf.dart';
import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Money transfers and bill payments for the customer app
/// (.claude/FINANCE-APP-CONTRACT.md section 15). The server validates the
/// recipient, computes the binding fee and stores the request
/// `awaiting_confirmation`; the user confirms it with a payment method;
/// the providers' verified callbacks drive the rest.
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

  static Future<void> deleteBeneficiary(String id) => FinanceService.call('transferDeleteBeneficiary', {'beneficiaryId': id});

  /// Asks the server to validate the recipient and price the transfer.
  /// Returns the transfer id; its document holds the verified recipient
  /// name, the fee and the total to confirm.
  static Future<String> create({
    required String channel,
    required int amount,
    required String currency,
    required Map<String, dynamic> recipient,
    required String note,
    required bool saveBeneficiary,
  }) async {
    final r = await FinanceService.call('transferCreate', {
      'channel': channel,
      'amount': amount,
      'currency': currency,
      'recipient': recipient,
      if (note.isNotEmpty) 'note': note,
      'saveBeneficiary': saveBeneficiary,
    });
    return r['transferId'].toString();
  }

  static Future<Map<String, dynamic>> confirm(String transferId, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('transferConfirm', {'transferId': transferId, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<void> cancel(String transferId) => FinanceService.call('transferCancel', {'transferId': transferId});

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

  static Future<void> deleteSavedAccount(String id) => FinanceService.call('billDeleteSavedAccount', {'savedAccountId': id});

  /// The biller's answer for [account]: `{ lookupId, customerName, amountDue, dueDate }`.
  static Future<Map<String, dynamic>> lookup(String billerId, String account) => FinanceService.call('billLookup', {'billerId': billerId, 'account': account});

  static Future<String> createPayment({
    required String billerId,
    required String account,
    required int amount,
    String? packageCode,
    String? lookupId,
    required bool save,
  }) async {
    final r = await FinanceService.call('billCreatePayment', {
      'billerId': billerId,
      'account': account,
      'amount': amount,
      'packageCode': ?packageCode,
      'lookupId': ?lookupId,
      'saveAccount': save,
    });
    return r['requestId'].toString();
  }

  static Stream<List<Map<String, dynamic>>> billPayments() =>
      _list(_db.collection('utility_payment_requests').where('userId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(50));

  static Stream<Map<String, dynamic>?> billPayment(String id) => _doc('utility_payment_requests', id);

  static Future<Map<String, dynamic>> confirmBill(String requestId, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('billConfirmPayment', {'requestId': requestId, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<void> cancelBill(String requestId) => FinanceService.call('billCancelPayment', {'requestId': requestId});

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
