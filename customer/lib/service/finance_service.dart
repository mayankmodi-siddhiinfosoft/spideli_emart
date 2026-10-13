import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_statement_pdf.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A refusal from the finance backend: `reason` is the server's stable key
/// (`FinanceErrors.messageKey` turns it into a message).
class FinanceException implements Exception {
  final String reason;
  final Map<String, dynamic> details;

  const FinanceException(this.reason, [this.details = const {}]);

  @override
  String toString() => 'FinanceException($reason)';
}

/// Spideli Finance for the customer app: the callable functions of the
/// `finance` codebase and the Firestore records the rules let the user read
/// (`finance/README.md`). Every money movement and every status is decided by
/// the server; this class only asks and reads.
abstract final class FinanceService {
  /// The finance functions run in us-central1 (finance/functions/src/index.ts).
  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-central1');
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get uid => _uid;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// A finance callable; a refusal becomes a [FinanceException] with the server's reason.
  static Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) => _call(name, data);

  static Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final value = result.data;
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : <String, dynamic>{};
      throw FinanceException(details['reason']?.toString() ?? e.code, details);
    }
  }

  // ── KYC ───────────────────────────────────────────────────────────────

  /// `platform_settings/kyc`, or null when not configured.
  static Future<KycSettings?> kycSettings() async {
    final snap = await _db.collection('platform_settings').doc('kyc').get();
    return KycSettings.parse(snap.data());
  }

  /// The user's verification state mirrored on users/{uid} by the server.
  static Stream<Map<String, dynamic>> myProfile() =>
      _db.collection('users').doc(_uid).snapshots().map((s) => s.data() ?? <String, dynamic>{});

  /// The user's applications, newest first (sorted here: one equality filter, no extra index).
  static Stream<List<Map<String, dynamic>>> myApplications() => _db
      .collection('kyc_applications')
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList()
        ..sort((a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt']))));

  /// An application's documents. Filtered on userId too: the rules only let
  /// the owner read them, and Firestore checks a query against the rules.
  static Stream<List<Map<String, dynamic>>> documents(String applicationId) => _db
      .collection('kyc_documents')
      .where('applicationId', isEqualTo: applicationId)
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// The review history, oldest first.
  static Stream<List<Map<String, dynamic>>> history(String applicationId) => _db
      .collection('kyc_reviews')
      .where('applicationId', isEqualTo: applicationId)
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList()..sort((a, b) => _millis(a['at']).compareTo(_millis(b['at']))));

  static Future<String> createApplication({required String level, required String accountType}) async {
    final r = await _call('kycCreateApplication', {'level': level, 'accountType': accountType});
    return r['applicationId'].toString();
  }

  static Future<void> updateApplication(String applicationId, {Map<String, String>? personal, Map<String, String>? business}) =>
      _call('kycUpdateApplication', {
        'applicationId': applicationId,
        if (personal != null) 'personal': personal,
        if (business != null) 'business': business,
      });

  /// Uploads [file] to kyc/{uid}/{applicationId}/ (the only path the rules
  /// allow; never overwritten) and registers it. The server re-checks the
  /// file's type and size.
  static Future<void> uploadDocument({required String applicationId, required String type, required String side, required File file}) async {
    final String path = 'kyc/$_uid/$applicationId/$type-$side-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await FirebaseStorage.instance.ref(path).putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    await _call('kycRegisterDocument', {'applicationId': applicationId, 'type': type, 'side': side, 'storagePath': path});
  }

  static Future<void> submit(String applicationId) => _call('kycSubmit', {'applicationId': applicationId});

  static Future<void> reopen(String applicationId) => _call('kycReopen', {'applicationId': applicationId});

  // ── Ledger ────────────────────────────────────────────────────────────

  /// The user's accounts (wallets per currency, ...).
  static Stream<List<Map<String, dynamic>>> myAccounts() =>
      _db.collection('financial_accounts').where('userId', isEqualTo: _uid).snapshots().map((s) => s.docs.map((d) => d.data()).toList());

  /// One page of the user's transactions, newest first; [type] and the date
  /// range are applied by Firestore (indexed).
  static Future<QuerySnapshot<Map<String, dynamic>>> transactionsPage({
    DocumentSnapshot? after,
    String? type,
    DateTime? from,
    DateTime? to,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('ledger_transactions').where('userIds', arrayContains: _uid);
    if (type != null) q = q.where('type', isEqualTo: type);
    if (from != null) q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (to != null) q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
    q = q.orderBy('createdAt', descending: true).limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    return q.get();
  }

  // ── Dashboard ─────────────────────────────────────────────────────────

  /// `finance_summaries/{uid}`: the totals the server maintains for the
  /// dashboard; null until the server has written one.
  static Stream<FinanceSummary?> summary() => _db
      .collection('finance_summaries')
      .doc(_uid)
      .snapshots()
      .map((s) => FinanceSummary.parse(s.data(), toDate: (v) => v is Timestamp ? v.toDate() : null));

  /// The most transactions one statement holds (the period is narrowed beyond).
  static const int statementMax = 2000;

  /// The statement of [from]..[to] (inclusive days): the user's transactions,
  /// paged from Firestore. `truncated` when the period has more than [statementMax].
  static Future<({List<StatementRow> rows, bool truncated})> statementRows(DateTime from, DateTime to) async {
    final accounts = await myAccounts().first;
    final sides = {for (final a in accounts) a['id'].toString(): a['normalSide'].toString()};
    final DateTime end = DateTime(to.year, to.month, to.day + 1);
    final List<Map<String, dynamic>> all = [];
    DocumentSnapshot? after;
    bool truncated = false;
    for (;;) {
      final page = await transactionsPage(after: after, from: DateTime(from.year, from.month, from.day), to: end, limit: 200);
      all.addAll(page.docs.map((d) => d.data()));
      if (page.docs.length < 200) break;
      if (all.length >= statementMax) {
        truncated = true;
        break;
      }
      after = page.docs.last;
    }
    return (rows: FinanceStatement.rows(all, sides, (v) => v is Timestamp ? v.toDate() : null), truncated: truncated);
  }

  /// Writes the statement PDF of [rows] and opens the share sheet.
  static Future<void> shareStatement(DateTime from, DateTime to, List<StatementRow> rows) async {
    final bytes = FinanceStatementPdf.build(
      customerName: Constant.userModel?.fullName() ?? '',
      from: from,
      to: to,
      rows: rows,
      label: (k) => k.tr,
      typeLabel: (t) => LedgerView.typeLabel(t).tr,
    );
    final dir = await getTemporaryDirectory();
    String d(DateTime x) => '${x.year}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/spideli-finance-statement-${d(from)}-${d(to)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: "Account statement".tr));
  }

  static int _millis(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 0;
}
