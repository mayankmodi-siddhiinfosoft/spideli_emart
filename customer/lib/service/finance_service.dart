import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_summary_service.dart';
import 'package:customer/utils/finance_kyc_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_statement_pdf.dart';
import 'package:customer/utils/shared_latest.dart';
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

  /// The user's profile (users/{uid}) with `kycStatus` set to the status of
  /// the latest verification application (.claude/FINANCE-DIRECT-FIRESTORE.md
  /// 3.1: `users.kycStatus` is the admin's mirror; `kycLevel`, which says the
  /// user is verified, stays the admin's). When the applications cannot be
  /// read, the mirrored value is kept.
  static Stream<Map<String, dynamic>> myProfile() => _shared(
        _profiles,
        () => _withKycStatus(_db.collection('users').doc(_uid).snapshots().map((s) => s.data() ?? <String, dynamic>{}), myApplications()),
      );

  static Stream<Map<String, dynamic>> _withKycStatus(Stream<Map<String, dynamic>> profile, Stream<List<Map<String, dynamic>>> applications) {
    late final StreamController<Map<String, dynamic>> out;
    StreamSubscription<Map<String, dynamic>>? users;
    StreamSubscription<List<Map<String, dynamic>>>? apps;
    Map<String, dynamic>? user;
    List<Map<String, dynamic>>? latest;
    bool appsFailed = false;
    void emit() {
      final u = user;
      if (u == null || (latest == null && !appsFailed)) return;
      out.add(appsFailed ? u : {...u, 'kycStatus': KycWrites.latestStatus(latest!)});
    }

    out = StreamController<Map<String, dynamic>>(
      onListen: () {
        users = profile.listen((v) {
          user = v;
          emit();
        }, onError: out.addError);
        apps = applications.listen((v) {
          latest = v;
          appsFailed = false;
          emit();
        }, onError: (Object _) {
          appsFailed = true;
          emit();
        });
      },
      onCancel: () async {
        await users?.cancel();
        await apps?.cancel();
      },
    );
    return out.stream;
  }

  /// The user's applications, newest first (sorted here: one equality filter, no extra index).
  static Stream<List<Map<String, dynamic>>> myApplications() => _db
      .collection('kyc_applications')
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()
        ..sort((a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt']))));

  /// An application's documents. Filtered on userId too: the rules only let
  /// the owner read them, and Firestore checks a query against the rules.
  static Stream<List<Map<String, dynamic>>> documents(String applicationId) => _db
      .collection('kyc_documents')
      .where('applicationId', isEqualTo: applicationId)
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()..sort((a, b) => _millis(a['createdAt']).compareTo(_millis(b['createdAt']))));

  /// The review history, oldest first.
  static Stream<List<Map<String, dynamic>>> history(String applicationId) => _db
      .collection('kyc_reviews')
      .where('applicationId', isEqualTo: applicationId)
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList()..sort((a, b) => _millis(a['at']).compareTo(_millis(b['at']))));

  // The writes below are the user's own (FINANCE-DIRECT-FIRESTORE.md 3.1),
  // planned by KycWrites and checked by the security rules; the reviewer's
  // decisions are the admin panel's.

  /// Starts an application (`draft`) of [level]. One open application at a
  /// time: a retry after a lost answer finds the one it created.
  static Future<String> createApplication({required String level, required String accountType}) => _kycWrite(() async {
        final String uid = _signedIn();
        final settings = await kycSettings();
        if (settings == null) throw const FinanceException('kyc_not_configured');
        final apps = await _db.collection('kyc_applications').where('userId', isEqualTo: uid).get();
        final same = apps.docs.where((d) => d.data()['level'] == level && d.data()['accountType'] == accountType && KycStatus.isOpen(d.data()['status']?.toString()));
        if (same.isNotEmpty) return same.first.id;
        final String? blocker = KycWrites.createBlocker([for (final d in apps.docs) d.data()], settings, level, accountType);
        if (blocker != null) throw FinanceException(blocker);
        final String id = _db.collection('kyc_applications').doc().id;
        await _kycCommit(KycWrites.create(applicationId: id, uid: uid, level: level, accountType: accountType));
        return id;
      });

  /// Saves the details form while the application is editable.
  static Future<void> updateApplication(String applicationId, {Map<String, String>? personal, Map<String, String>? business}) => _kycWrite(() async {
        final app = await _kycApplication(applicationId);
        if (!KycStatus.ownerMayEdit(app['status']?.toString())) throw const FinanceException('kyc_not_editable');
        await _kycCommit(KycWrites.updateDetails(applicationId: applicationId, personal: personal, business: business));
      });

  /// Uploads [file] to `kyc/{uid}/{applicationId}/` (the only path the
  /// Storage rules allow; never overwritten), then records it
  /// (`kyc_documents`, `uploaded`) and supersedes the earlier uploads of the
  /// same type and side, in one batch.
  static Future<void> uploadDocument({required String applicationId, required String type, required String side, required File file}) => _kycWrite(() async {
        final String uid = _signedIn();
        final app = await _kycApplication(applicationId);
        if (!KycStatus.ownerMayEdit(app['status']?.toString())) throw const FinanceException('kyc_not_editable');
        final settings = await kycSettings();
        if (settings == null) throw const FinanceException('kyc_not_configured');
        if (!(settings.documentSides[type] ?? const <String>[]).contains(side)) throw const FinanceException('kyc_invalid_transition');
        const String contentType = 'image/jpeg';
        if (!settings.allowedContentTypes.contains(contentType)) throw const FinanceException('kyc_file_type');
        final int size = await file.length();
        if (size > settings.maxFileBytes) throw const FinanceException('kyc_file_size');
        final int millis = DateTime.now().millisecondsSinceEpoch;
        final String path = KycWrites.storagePath(uid, applicationId, type, side, millis);
        try {
          await FirebaseStorage.instance.ref(path).putFile(file, SettableMetadata(contentType: contentType));
        } on FirebaseException catch (e) {
          throw FinanceException(e.code == 'unauthorized' ? 'permission_denied' : 'kyc_file_missing');
        }
        final existing = await _db.collection('kyc_documents').where('applicationId', isEqualTo: applicationId).where('userId', isEqualTo: uid).get();
        final String id = KycWrites.documentId(applicationId, type, side, millis);
        await _kycCommit(KycWrites.registerDocument(
          documentId: id,
          applicationId: applicationId,
          uid: uid,
          type: type,
          side: side,
          storagePath: path,
          contentType: contentType,
          size: size,
          revision: (app['revision'] as num?)?.toInt() ?? 1,
          supersede: KycWrites.toSupersede([for (final d in existing.docs) {...d.data(), 'id': d.id}], type, side, except: id),
        ));
      });

  /// Sends the application for review once the details and every required
  /// document are there (checked again here from what is stored).
  static Future<void> submit(String applicationId) => _kycWrite(() async {
        final String uid = _signedIn();
        final app = await _kycApplication(applicationId);
        // Already sent (a retry after a lost answer).
        if (app['status'] == KycStatus.submitted) return;
        final settings = await kycSettings();
        if (settings == null) throw const FinanceException('kyc_not_configured');
        final docs = await _db.collection('kyc_documents').where('applicationId', isEqualTo: applicationId).where('userId', isEqualTo: uid).get();
        final refs = [for (final d in docs.docs) KycDocumentRef('${d.data()['type']}', '${d.data()['side']}', '${d.data()['status']}')];
        final String? blocker = KycWrites.submitBlocker(app, settings, refs);
        if (blocker != null) throw FinanceException(blocker);
        await _kycCommit(KycWrites.submit(
          applicationId: applicationId,
          uid: uid,
          reviewId: _db.collection('kyc_reviews').doc().id,
          revision: (app['revision'] as num?)?.toInt() ?? 1,
        ));
      });

  /// Starts a `rejected` application again as its next revision (`draft`).
  static Future<void> reopen(String applicationId) => _kycWrite(() async {
        final String uid = _signedIn();
        final app = await _kycApplication(applicationId);
        // Already started again (a retry after a lost answer).
        if (app['status'] == KycStatus.draft) return;
        if (app['status'] != KycStatus.rejected) throw const FinanceException('kyc_invalid_transition');
        final others = await _db.collection('kyc_applications').where('userId', isEqualTo: uid).get();
        if (others.docs.any((d) => d.id != applicationId && KycStatus.isOpen(d.data()['status']?.toString()))) throw const FinanceException('kyc_application_open');
        await _kycCommit(KycWrites.reopen(
          applicationId: applicationId,
          uid: uid,
          reviewId: _db.collection('kyc_reviews').doc().id,
          revision: (app['revision'] as num?)?.toInt() ?? 1,
        ));
      });

  static String _signedIn() => _uid.isEmpty ? throw const FinanceException('sign_in_required') : _uid;

  /// One of the user's own applications, as stored now.
  static Future<Map<String, dynamic>> _kycApplication(String applicationId) async {
    final snap = await _db.collection('kyc_applications').doc(applicationId).get();
    final data = snap.data();
    if (data == null || data['userId'] != _uid) throw const FinanceException('kyc_invalid_transition');
    return {...data, 'id': snap.id};
  }

  static Future<void> _kycCommit(List<FinanceWrite> writes) async {
    final batch = _db.batch();
    FinanceLedger.apply(batch, writes, db: _db);
    await batch.commit();
  }

  /// A write the security rules refuse becomes `permission_denied`.
  static Future<T> _kycWrite<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const FinanceException('permission_denied');
      rethrow;
    }
  }

  // ── Ledger ────────────────────────────────────────────────────────────

  /// The user's accounts (wallets per currency, ...).
  static Stream<List<Map<String, dynamic>>> myAccounts() => _shared(
      _accounts, () => _db.collection('financial_accounts').where('userId', isEqualTo: _uid).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()));

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

  /// The id and status of the user's newest posting, live: lists of
  /// transactions reload when it changes (a new payment, a refund).
  static Stream<String?> latestTransaction() => _db
      .collection('ledger_transactions')
      .where('userIds', arrayContains: _uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? '' : '${s.docs.first.id}:${s.docs.first.data()['status'] ?? ''}');

  // ── Dashboard ─────────────────────────────────────────────────────────

  /// The dashboard totals, worked out on the device from the user's own
  /// records (FinanceSummaryService); null while the user has none.
  static Stream<FinanceSummary?> summary() => FinanceSummaryService.stream();

  // The dashboard's live records (profile, wallets, summary) are read on many
  // screens and tabs at once: one shared subscription per signed-in user,
  // the latest value handed to each new reader (SharedLatest).
  static final Map<String, SharedLatest<Map<String, dynamic>>> _profiles = {};
  static final Map<String, SharedLatest<List<Map<String, dynamic>>>> _accounts = {};

  static Stream<T> _shared<T>(Map<String, SharedLatest<T>> cache, Stream<T> Function() open) => cache.putIfAbsent(_uid, () => SharedLatest<T>(open)).stream;

  /// Reads the profile, the accounts and the summary again after one of them
  /// failed (the Retry of the dashboard).
  static void retry() {
    for (final cache in <Map<String, SharedLatest<dynamic>>>[_profiles, _accounts]) {
      cache[_uid]?.retry();
    }
    FinanceSummaryService.retry();
  }

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
