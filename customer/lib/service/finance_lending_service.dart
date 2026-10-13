import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Member-to-member lending for the customer app
/// (.claude/FINANCE-APP-CONTRACT.md section 11). Reads what the server
/// stored; every step is a request to a callable function.
abstract final class FinanceLendingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Future<LendingConfig?> config() async => LendingConfig.parse((await _db.collection('platform_settings').doc('lending').get()).data());

  static Stream<List<Loan>> _query(Query<Map<String, dynamic>> q) =>
      q.orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => Loan.fromMap(d.data(), FinanceGroupService.toDate)).toList());

  /// The user's own requests and loans.
  static Stream<List<Loan>> borrowed() => _query(_db.collection('loan_applications').where('borrowerId', isEqualTo: _uid));

  /// Requests in the user's groups (to vote on or fund).
  static Stream<List<Loan>> groupRequests() => _query(_db.collection('loan_applications').where('eligibleVoterIds', arrayContains: _uid));

  /// Loans the user has funded.
  static Stream<List<Loan>> lent() => _query(_db.collection('loan_applications').where('lenderIds', arrayContains: _uid));

  static Stream<Loan?> loan(String id) =>
      _db.collection('loan_applications').doc(id).snapshots().map((s) => s.data() == null ? null : Loan.fromMap(s.data()!, FinanceGroupService.toDate));

  /// The user's vote on a loan (`loan_votes/{loanId}_{uid}`), or null.
  static Stream<Map<String, dynamic>?> myVote(String loanId) => _db.collection('loan_votes').doc('${loanId}_$_uid').snapshots().map((s) => s.data());

  /// The binding schedule (`loan_schedules/{loanId}.installments`), once agreed.
  static Stream<List<Map<String, dynamic>>> schedule(String loanId) => _db.collection('loan_schedules').doc(loanId).snapshots().map((s) {
        final list = s.data()?['installments'];
        return list is List ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
      });

  static Stream<Map<String, dynamic>?> agreement(String loanId) => _db.collection('loan_agreements').doc(loanId).snapshots().map((s) => s.data());

  /// The borrower's credit assessment for this request (score and the main factors).
  static Stream<Map<String, dynamic>?> creditAssessment(String loanId) => _db.collection('credit_assessments').doc(loanId).snapshots().map((s) => s.data());

  static Stream<List<Map<String, dynamic>>> repayments(String loanId) => _db
      .collection('loan_repayments')
      .where('loanId', isEqualTo: loanId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// The user's own contributions to a loan as a lender.
  static Stream<List<Map<String, dynamic>>> myFundings(String loanId) => _db
      .collection('loan_fundings')
      .where('loanId', isEqualTo: loanId)
      .where('lenderId', isEqualTo: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Future<String> apply({
    required int amount,
    required String currency,
    required String purpose,
    required int durationMonths,
    required String repaymentFrequency,
    required String groupId,
    required String description,
  }) async {
    final r = await FinanceService.call('loanApply', {
      'amount': amount,
      'currency': currency,
      'purpose': purpose,
      'durationMonths': durationMonths,
      'repaymentFrequency': repaymentFrequency,
      'groupId': groupId,
      if (description.isNotEmpty) 'description': description,
    });
    return r['loanId'].toString();
  }

  /// Uploads a supporting document to loan_documents/{uid}/{loanId}/ and registers it.
  static Future<void> addDocument(String loanId, File file, String name) async {
    final String path = 'loan_documents/$_uid/$loanId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await FirebaseStorage.instance.ref(path).putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    await FinanceService.call('loanRegisterDocument', {'loanId': loanId, 'storagePath': path, 'name': name});
  }

  static Future<void> cancel(String loanId) => FinanceService.call('loanCancel', {'loanId': loanId});

  static Future<void> vote(String loanId, bool approve, String comment) =>
      FinanceService.call('loanVote', {'loanId': loanId, 'approve': approve, if (comment.isNotEmpty) 'comment': comment});

  static Future<Map<String, dynamic>> fund(String loanId, int amount, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('loanFund', {'loanId': loanId, 'amount': amount, 'payment': payment, 'idempotencyKey': requestKey});

  /// Accepts the agreement [version] the user was shown (the server refuses an outdated one).
  static Future<void> acceptAgreement(String loanId, int version) => FinanceService.call('loanAcceptAgreement', {'loanId': loanId, 'agreementVersion': version});

  static Future<Map<String, dynamic>> repay(String loanId, int amount, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('loanRepay', {'loanId': loanId, 'amount': amount, 'payment': payment, 'idempotencyKey': requestKey});
}
