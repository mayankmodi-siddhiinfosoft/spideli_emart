import 'dart:async';
import 'dart:developer' show log;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_direct.dart' show FinancePay;
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_security_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// Member-to-member lending for the customer app
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.8). The app writes each
/// member step directly to Firestore, checked by the security rules: the
/// writes are the pure plans of [LoanPlans], committed in one batch, or in
/// one transaction when they depend on the loan as it is now (closing the
/// vote, funding, the pay-out, repaying, collecting). Money moves only as
/// ledger postings. The ADMIN reviews requests, writes the credit
/// assessment, opens the vote, applies penalties and decides defaults.
///
/// A refusal of the rules becomes `FinanceException('permission_denied')`;
/// the other refusals use the reasons of [LoanChecks] (and [LoanErrors]).
abstract final class FinanceLendingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Future<LendingConfig?> config() async => LendingConfig.parse((await _db.collection('platform_settings').doc('lending').get()).data());

  static Loan? _parse(DocumentSnapshot<Map<String, dynamic>> s) => s.data() == null ? null : Loan.fromMap({...s.data()!, 'id': s.id}, FinanceGroupService.toDate);

  static Stream<List<Loan>> _query(Query<Map<String, dynamic>> q) =>
      q.orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => Loan.fromMap({...d.data(), 'id': d.id}, FinanceGroupService.toDate)).toList());

  /// The user's own requests and loans.
  static Stream<List<Loan>> borrowed() => _query(_db.collection('loan_applications').where('borrowerId', isEqualTo: _uid));

  /// Requests in the user's groups (to vote on or fund).
  static Stream<List<Loan>> groupRequests() => _query(_db.collection('loan_applications').where('eligibleVoterIds', arrayContains: _uid));

  /// Loans the user has funded.
  static Stream<List<Loan>> lent() => _query(_db.collection('loan_applications').where('lenderIds', arrayContains: _uid));

  static Stream<Loan?> loan(String id) => _db.collection('loan_applications').doc(id).snapshots().map(_parse);

  /// The user's vote on a loan (`loan_votes/{loanId}_{uid}`), or null.
  static Stream<Map<String, dynamic>?> myVote(String loanId) => _db.collection('loan_votes').doc(LoanPlans.voteId(loanId, _uid)).snapshots().map((s) => s.data());

  /// The binding schedule (`loan_schedules/{loanId}.installments`), once paid out.
  static Stream<List<Map<String, dynamic>>> schedule(String loanId) => _db.collection('loan_schedules').doc(loanId).snapshots().map((s) => _installments(s.data()));

  static List<Map<String, dynamic>> _installments(Map<String, dynamic>? schedule) {
    final list = schedule?['installments'];
    return list is List ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
  }

  static Stream<Map<String, dynamic>?> agreement(String loanId) => _db.collection('loan_agreements').doc(loanId).snapshots().map((s) => s.data());

  /// The borrower's credit assessment for this request (score and the main
  /// factors), written by the admin.
  static Stream<Map<String, dynamic>?> creditAssessment(String loanId) => _db.collection('credit_assessments').doc(loanId).snapshots().map((s) => s.data());

  static Stream<List<Map<String, dynamic>>> repayments(String loanId) =>
      _db.collection('loan_repayments').where('loanId', isEqualTo: loanId).orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => d.data()).toList());

  static Query<Map<String, dynamic>> _myFundingsQuery(String loanId) => _db.collection('loan_fundings').where('loanId', isEqualTo: loanId).where('lenderId', isEqualTo: _uid);

  /// The user's own fundings of a loan as a lender (with their `id`).
  static Stream<List<Map<String, dynamic>>> myFundings(String loanId) => _myFundingsQuery(loanId).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  /// The user's profile (`users/{uid}`), for the restriction shown on the screens.
  static Stream<Map<String, dynamic>> profile() => FinanceService.myProfile();

  // ── Steps ─────────────────────────────────────────────────────────────

  /// A new id for a request: kept by the screen, so a retry writes the same
  /// request (create-only) instead of a second one.
  static String newLoanId() => _db.collection('loan_applications').doc().id;

  /// Creates the request [loanId] in the tontine [groupId] (the borrower is
  /// one of its members; the others vote and may fund it).
  static Future<void> apply({
    required String loanId,
    required LendingConfig config,
    required int amount,
    required String currency,
    required String purpose,
    required int durationMonths,
    required String repaymentFrequency,
    required String groupId,
    required String description,
  }) => _guard(() async {
    final String uid = _signedIn();
    // A retry after a lost answer: the request is there already.
    final existing = await _existing('loan_applications/$loanId');
    if (existing != null) {
      if (existing['borrowerId'] == uid) return;
      throw const FinanceException('state_changed');
    }
    final group = (await _db.collection('tontines').doc(groupId).get()).data();
    if (group == null) throw const FinanceException('state_changed');
    final members = _strings(group['memberIds']);
    final String? problem = LoanChecks.apply(
      config: config,
      uid: uid,
      memberIds: members,
      amount: amount,
      currency: currency,
      durationMonths: durationMonths,
      frequency: repaymentFrequency,
      restricted: await _restricted(),
    );
    if (problem != null) throw FinanceException(problem);
    await _commit(
      LoanPlans.apply(
        loanId: loanId,
        uid: uid,
        groupId: groupId,
        groupName: group['name']?.toString() ?? '',
        memberIds: members,
        amount: amount,
        currency: currency,
        purpose: purpose,
        durationMonths: durationMonths,
        repaymentFrequency: repaymentFrequency,
        description: description,
      ),
    );
  });

  /// Uploads a supporting photo to `loan_documents/{uid}/{loanId}/` (never
  /// overwritten) and returns its path; [registerDocument] adds it to the loan.
  static Future<String> uploadDocument(String loanId, File file, int number) async {
    final String path = 'loan_documents/${_signedIn()}/$loanId/document-$number-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await FirebaseStorage.instance.ref(path).putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }

  /// Adds the uploaded [storagePath] to the request's `documents` (once:
  /// the same entry twice is one entry).
  static Future<void> registerDocument(String loanId, String storagePath, String name) =>
      _guard(() => _commit(LoanPlans.addDocument(loanId, name: name, storagePath: storagePath)));

  /// The borrower withdraws the request (before any money is committed).
  static Future<void> cancel(String loanId) => _guard(() async {
    final String uid = _signedIn();
    final loan = await _loanOnce(loanId);
    if (loan == null) throw const FinanceException('state_changed');
    if (loan.status == 'cancelled') return;
    final String? problem = LoanChecks.cancel(loan, uid);
    if (problem != null) throw FinanceException(problem);
    await _commit(LoanPlans.cancel(loan));
  });

  /// One vote of an eligible member (`loan_votes/{loanId}_{uid}`, once).
  static Future<void> vote(String loanId, bool approve, String comment) => _guard(() async {
    final String uid = _signedIn();
    final String path = 'loan_votes/${LoanPlans.voteId(loanId, uid)}';
    // A vote already recorded (a retry after a lost answer) counts once.
    if (await _existing(path) != null) return;
    final loan = await _loanOnce(loanId);
    if (loan == null) throw const FinanceException('state_changed');
    final String? problem = LoanChecks.vote(loan, uid, now: DateTime.now(), restricted: await _restricted());
    if (problem != null) throw FinanceException(problem);
    try {
      await _commit(LoanPlans.vote(loan, uid, approve: approve, comment: comment));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && await _existing(path) != null) return;
      rethrow;
    }
  });

  /// Closes the vote (a participant, once it ended or everyone voted):
  /// `funding` or `rejected`. Returns the loan's status after it.
  static Future<String> closeVote(String loanId) => _guard(() async {
    final String uid = _signedIn();
    final cfg = await config();
    if (cfg == null) throw const FinanceException('state_changed');
    final r = await _transaction((tx) async {
      final loan = _parse(await tx.get(_loanRef(loanId)));
      if (loan == null) throw const FinanceException('state_changed');
      // Closed already by another member: nothing to do.
      if (loan.status != 'voting') return (loan, loan.status, false);
      final String? problem = LoanChecks.closeVote(loan, uid, now: DateTime.now());
      if (problem != null) throw FinanceException(problem);
      final plan = LoanPlans.closeVote(loan, quorumPercent: cfg.quorumPercent, approvalPercent: cfg.approvalPercent);
      _write(tx, plan.writes);
      return (loan, plan.status, true);
    });
    if (r.$3) unawaited(_afterVote(r.$1, r.$2, uid));
    return r.$2;
  });

  /// A lender funds [amount] of the loan, paid from their wallet or by the
  /// gateway payment [funding]. [requestKey] (FinanceRequestKeys) makes a
  /// retry of the same request find the funding it already made. The last
  /// funder also issues the agreement. Returns the payment sheet's reply.
  static Future<Map<String, dynamic>> fund(String loanId, int amount, FinanceFunding funding, String requestKey) => _guard(() async {
    final String uid = _signedIn();
    Future<Map<String, dynamic>?> done() async {
      for (final f in await _myFundingsOnce(loanId)) {
        if (f['requestKey'] == requestKey) return {'status': 'succeeded', 'reference': f['reference'] ?? ''};
      }
      return null;
    }

    final before = await done();
    if (before != null) return before;
    final loan0 = await _loanOnce(loanId);
    if (loan0 == null) throw const FinanceException('state_changed');
    try {
      return await _fund(uid, loan0, amount, funding, requestKey, done);
    } on FinanceException catch (e) {
      // A gateway payment already taken is never lost: when the loan
      // can no longer take it, it goes to the user's wallet.
      if (!funding.isWallet && _final.contains(e.reason)) return _keepInWallet(uid, funding, loan0.currency, amount, 'loan_fundings', loanId);
      rethrow;
    }
  });

  static Future<Map<String, dynamic>> _fund(String uid, Loan loan0, int amount, FinanceFunding funding, String requestKey, Future<Map<String, dynamic>?> Function() done) async {
    final String loanId = loan0.id;
    if (await _restricted()) throw const FinanceException('finance_restricted');
    final cfg = await config();
    if (cfg == null) throw const FinanceException('state_changed');
    final wallet = await FinanceLedger.wallet(uid, loan0.currency, db: _db);
    if (funding.isWallet && !wallet.exists) throw const FinanceException('insufficient_funds');
    // The lender's next funding of this loan: `{loanId}_{uid}_{n}`.
    final int n = (await _myFundingsOnce(loanId)).length + 1;
    final DateTime now = DateTime.now();
    final ({Loan loan, FinancePosting posting, bool last}) r;
    try {
      r = await _transaction((tx) async {
        final loan = _parse(await tx.get(_loanRef(loanId)));
        if (loan == null) throw const FinanceException('state_changed');
        final int? balance = funding.isWallet ? _int((await tx.get(_db.doc('financial_accounts/${wallet.id}'))).data()?['balance']) : null;
        final String? problem = LoanChecks.fund(loan, uid, amount, restricted: false, walletBalance: balance);
        if (problem != null) throw FinanceException(problem);
        final bool last = loan.fundedAmount + amount >= loan.amount;
        final posting = LoanPlans.fund(
          loan: loan,
          uid: uid,
          amount: amount,
          n: n,
          requestKey: requestKey,
          funding: funding,
          walletId: wallet.id,
          // Only fundings credit the loan account: none yet = no account yet.
          loanAccountExists: loan.fundedAmount > 0,
          agreement: last ? LoanPlans.agreement(loan, cfg, now) : null,
        );
        _write(tx, posting.writes);
        return (loan: loan, posting: posting, last: last);
      });
    } on FirebaseException catch (e) {
      // The same funding made by a first attempt whose answer was lost.
      if (e.code == 'permission-denied') {
        final again = await done();
        if (again != null) return again;
      }
      rethrow;
    }
    if (r.last) unawaited(_afterFunded(r.loan));
    return {'status': 'succeeded', 'reference': r.posting.reference};
  }

  /// The borrower accepts the agreement [version] they were shown; the loan
  /// is paid out into their wallet in the same transaction.
  static Future<void> acceptAgreement(String loanId, int version) => _guard(() async {
    final String uid = _signedIn();
    if (await _restricted()) throw const FinanceException('finance_restricted');
    final loan0 = await _loanOnce(loanId);
    if (loan0 == null) throw const FinanceException('state_changed');
    final wallet = await FinanceLedger.wallet(uid, loan0.currency, db: _db);
    final r = await _transaction((tx) async {
      final loan = _parse(await tx.get(_loanRef(loanId)));
      final agreement = (await tx.get(_db.collection('loan_agreements').doc(loanId))).data();
      if (loan == null) throw const FinanceException('state_changed');
      // Accepted already (a retry after a lost answer).
      if (loan.status != 'agreement_pending' && agreement?['acceptedAt'] != null && _int(agreement?['version']) == version) return null;
      final String? problem = LoanChecks.accept(loan, uid, agreement, version, restricted: false, loanBalance: loan.fundedAmount);
      if (problem != null) throw FinanceException(problem);
      final posting = LoanPlans.accept(loan: loan, agreement: agreement!, uid: uid, walletId: wallet.id, walletExists: wallet.exists, now: DateTime.now());
      _write(tx, posting.writes);
      return loan;
    });
    if (r != null) unawaited(_notify('loan_disbursed', r.lenderIds, r, {'amount': FinanceMoney.format(r.fundedAmount, r.currency)}, except: uid));
  });

  /// The borrower repays [amount] from their wallet or by the gateway
  /// payment [funding] (`loan_repayments/{loanId}_{requestKey}`, once).
  static Future<Map<String, dynamic>> repay(String loanId, int amount, FinanceFunding funding, String requestKey) => _guard(() async {
    final String uid = _signedIn();
    final String path = 'loan_repayments/${LoanPlans.repaymentId(loanId, requestKey)}';
    Future<Map<String, dynamic>?> done() async {
      final d = await _existing(path);
      return d == null ? null : {'status': 'succeeded', 'reference': d['reference'] ?? ''};
    }

    final before = await done();
    if (before != null) return before;
    final loan0 = await _loanOnce(loanId);
    if (loan0 == null) throw const FinanceException('state_changed');
    try {
      return await _repay(uid, loan0, amount, funding, requestKey, done);
    } on FinanceException catch (e) {
      // A gateway payment already taken is never lost: when the loan
      // can no longer take it, it goes to the user's wallet.
      if (!funding.isWallet && _final.contains(e.reason)) return _keepInWallet(uid, funding, loan0.currency, amount, 'loan_repayments', loanId);
      rethrow;
    }
  });

  static Future<Map<String, dynamic>> _repay(String uid, Loan loan0, int amount, FinanceFunding funding, String requestKey, Future<Map<String, dynamic>?> Function() done) async {
    final String loanId = loan0.id;
    final wallet = await FinanceLedger.wallet(uid, loan0.currency, db: _db);
    if (funding.isWallet && !wallet.exists) throw const FinanceException('insufficient_funds');
    final ({Loan loan, FinancePosting posting}) r;
    try {
      r = await _transaction((tx) async {
        final loan = _parse(await tx.get(_loanRef(loanId)));
        if (loan == null) throw const FinanceException('state_changed');
        final int? balance = funding.isWallet ? _int((await tx.get(_db.doc('financial_accounts/${wallet.id}'))).data()?['balance']) : null;
        final installments = _installments((await tx.get(_db.collection('loan_schedules').doc(loanId))).data());
        final String? problem = LoanChecks.repay(loan, uid, amount, walletBalance: balance);
        if (problem != null) throw FinanceException(problem);
        final posting = LoanPlans.repay(loan: loan, uid: uid, amount: amount, requestKey: requestKey, funding: funding, walletId: wallet.id, installments: installments);
        _write(tx, posting.writes);
        return (loan: loan, posting: posting);
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final again = await done();
        if (again != null) return again;
      }
      rethrow;
    }
    unawaited(_afterRepaid(r.loan, amount, uid));
    return {'status': 'succeeded', 'reference': r.posting.reference};
  }

  /// Refusals a retry cannot change (the loan moved on, the amount no
  /// longer fits, the user is restricted).
  static const Set<String> _final = {'state_changed', 'amount_out_of_range', 'finance_restricted'};

  /// The gateway payment [funding] the loan could not take, deposited into
  /// the user's wallet (once per gateway payment: `wallet_operations/{receiptId}`).
  static Future<Map<String, dynamic>> _keepInWallet(String uid, FinanceFunding funding, String currency, int amount, String purposeKind, String purposeId) async {
    final String? id = funding.receiptId;
    if (id == null) throw const FinanceException('state_changed');
    String reference = (await _existing('wallet_operations/$id'))?['reference']?.toString() ?? '';
    if (reference.isEmpty) {
      final wallet = await FinanceLedger.wallet(uid, currency, db: _db);
      final writes = FinancePay.gatewayDeposit(
        uid: uid,
        currency: currency,
        walletId: wallet.id,
        walletExists: wallet.exists,
        amount: amount,
        funding: funding,
        purposeKind: purposeKind,
        purposeId: purposeId,
      );
      await _commit(writes);
      reference = writes.first.data['reference']?.toString() ?? '';
    }
    return {'status': 'succeeded', 'reference': reference, 'instructions': "The loan could no longer take this payment: the money was put in your Spideli Finance wallet.".tr};
  }

  /// A lender collects their share of the repayments received so far into
  /// their wallet: one posting per funding (each is checked against its own
  /// share). Returns `{status, reference, amount}`.
  static Future<Map<String, dynamic>> collect(String loanId) => _guard(() async {
    final String uid = _signedIn();
    final loan0 = await _loanOnce(loanId);
    if (loan0 == null) throw const FinanceException('state_changed');
    final wallet = await FinanceLedger.wallet(uid, loan0.currency, db: _db);
    bool walletExists = wallet.exists;
    int total = 0;
    String reference = '';
    for (final f in await _myFundingsOnce(loanId)) {
      final r = await _transaction((tx) async {
        final loan = _parse(await tx.get(_loanRef(loanId)));
        final snap = await tx.get(_db.collection('loan_fundings').doc(f['id'].toString()));
        if (loan == null || snap.data() == null) return null;
        final funding = {...snap.data()!, 'id': snap.id};
        if (funding['lenderId'] != uid || (funding['status'] ?? 'succeeded') != 'succeeded') return null;
        final int due = LenderShare.due(repaid: loan.repaidAmount, lent: _int(funding['amount']), loanAmount: loan.amount, collected: _int(funding['collected']));
        if (due <= 0) return null;
        final posting = LoanPlans.collect(loan: loan, funding: funding, uid: uid, amount: due, walletId: wallet.id, walletExists: walletExists);
        _write(tx, posting.writes);
        return (due, posting.reference);
      });
      if (r != null) {
        total += r.$1;
        reference = r.$2;
        walletExists = true;
      }
    }
    if (total == 0) throw const FinanceException('nothing_to_collect');
    return {'status': 'succeeded', 'reference': reference, 'amount': total};
  });

  // ── Notifications (template pushes, `dynamic_notification`) ────────────

  static Future<void> _afterVote(Loan l, String status, String by) async {
    final values = {'amount': FinanceMoney.format(l.amount, l.currency), 'groupName': l.groupName, 'borrowerName': await _name(l.borrowerId)};
    if (status == 'funding') {
      await _notify('loan_approved', [l.borrowerId], l, values, except: by);
      await _notify('loan_funding_open', l.eligibleVoterIds, l, values, except: by);
    } else {
      await _notify('loan_rejected', [l.borrowerId], l, {...values, 'reason': 'vote'}, except: by);
    }
  }

  static Future<void> _afterFunded(Loan l) async {
    final values = {'amount': FinanceMoney.format(l.amount, l.currency)};
    await _notify('loan_funded', [l.borrowerId], l, values);
    await _notify('loan_agreement_ready', [l.borrowerId], l, values);
  }

  static Future<void> _afterRepaid(Loan l, int amount, String by) async {
    final String name = await _name(l.borrowerId);
    final values = {'amount': FinanceMoney.format(amount, l.currency), 'borrowerName': name};
    // The borrower's receipt.
    await _notify('loan_repayment_received', [l.borrowerId], l, values);
    await _notify('loan_lender_repayment', l.lenderIds, l, values, except: by);
    if (l.outstandingAmount - amount <= 0) {
      await _notify('loan_repaid', [l.borrowerId, ...l.lenderIds], l, {'amount': FinanceMoney.format(l.amount, l.currency), 'borrowerName': name}, except: by);
    }
  }

  static Future<String> _name(String uid) async {
    try {
      final u = (await _db.collection('users').doc(uid).get()).data() ?? const {};
      return '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }

  /// [type] to each of [to] (but [except]) who has a device and has not
  /// turned loan pushes off (`financeNotificationPrefs.push.loans`). Never fails
  /// the step it follows.
  static Future<void> _notify(String type, Iterable<String> to, Loan l, Map<String, String> values, {String? except}) async {
    for (final id in to.toSet()) {
      if (id.isEmpty || id == except) continue;
      try {
        final u = (await _db.collection('users').doc(id).get()).data();
        if (u == null) continue;
        if (!FinanceNotificationPrefs.allows(u, FinanceNotificationPrefs.push, FinanceNotificationPrefs.loans)) continue;
        await SendNotification.sendFcmMessage(
          type,
          (u['fcmToken'] ?? '').toString(),
          {'source': 'finance', 'loanId': l.id},
          recipient: PushRecipient.customer,
          placeholders: values,
        );
      } catch (e) {
        log('finance push "$type" not sent (${e.runtimeType})');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static String _signedIn() {
    final String uid = _uid;
    if (uid.isEmpty) throw const FinanceException('sign_in_required');
    return uid;
  }

  static DocumentReference<Map<String, dynamic>> _loanRef(String id) => _db.collection('loan_applications').doc(id);

  static Future<Loan?> _loanOnce(String id) async => _parse(await _loanRef(id).get());

  static Future<List<Map<String, dynamic>>> _myFundingsOnce(String loanId) async => (await _myFundingsQuery(loanId).get()).docs.map((d) => {...d.data(), 'id': d.id}).toList();

  /// The admin's blacklist covers loans for the user.
  static Future<bool> _restricted() async => FinanceRestriction.blocks((await _db.collection('users').doc(_uid).get()).data(), FinanceRestriction.loans);

  /// The document at [path], or null when it does not exist (a document the
  /// rules let only its participants read cannot be read before it exists).
  static Future<Map<String, dynamic>?> _existing(String path) async {
    try {
      return (await _db.doc(path).get()).data();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  static Future<void> _commit(List<FinanceWrite> writes) async {
    final batch = _db.batch();
    FinanceLedger.apply(batch, writes, db: _db);
    await batch.commit();
  }

  /// [writes] in the transaction [tx] (as [FinanceLedger.apply] does in a batch).
  static void _write(Transaction tx, Iterable<FinanceWrite> writes) {
    for (final w in writes) {
      final ref = _db.doc(w.path);
      switch (w.op) {
        case 'create':
          tx.set(ref, w.data);
        case 'update':
          tx.update(ref, w.data);
        default:
          tx.set(ref, w.data, SetOptions(merge: true));
      }
    }
  }

  /// Runs [body] in a transaction (retried by Firestore when the loan
  /// changed meanwhile); a [FinanceException] it throws comes out as is,
  /// with nothing written.
  static Future<T> _transaction<T>(Future<T> Function(Transaction tx) body) async {
    FinanceException? refused;
    final T? result = await _db.runTransaction<T?>((tx) async {
      refused = null;
      try {
        return await body(tx);
      } on FinanceException catch (e) {
        refused = e;
        return null;
      }
    });
    if (refused != null) throw refused!;
    return result as T;
  }

  /// [action], with a refusal of the security rules as
  /// `FinanceException('permission_denied')`.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') Error.throwWithStackTrace(const FinanceException('permission_denied'), st);
      rethrow;
    }
  }
}
