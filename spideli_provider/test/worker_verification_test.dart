import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/booking_push.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/push_message.dart';
import 'package:spideliprovider/services/push_template_text.dart';
import 'package:spideliprovider/services/worker_document_push.dart';

/// The provider verifies its own workers: the required set, the verified
/// flag rules (approve never un-verifies, reject of a required document does,
/// approve-all only verifies when nothing is missing), the guard, the
/// pushes and their tap routes.
void main() {
  final DateTime now = DateTime(2026, 10, 13, 12);
  final Timestamp at = Timestamp.fromDate(now);
  final Timestamp past = Timestamp.fromDate(DateTime(2026, 1, 1));
  const String img = 'https://firebasestorage.googleapis.com/v0/b/x/o/workerDocument%2Fw1%2Ff.jpg?alt=media&token=t';

  final List<DocumentType> types = [DocumentType(id: 'id', title: 'ID card'), DocumentType(id: 'cv', title: 'CV')];

  Map<String, dynamic> entry(String id, String status, {String? front = img, Map<String, dynamic> more = const {}}) => {
        'documentId': id,
        'frontImage': front ?? '',
        'backImage': '',
        'status': status,
        ...more,
      };

  group('required set and status', () {
    test('only the required (enabled worker) types count; a disabled type cannot lock the worker', () {
      final uploads = WorkerVerificationRules.uploadsFrom([entry('id', 'approved'), entry('cv', 'approved'), entry('old', 'rejected')]);
      expect(WorkerVerificationRules.overall(types, uploads, now: now), DocumentStatus.approved);
      expect(WorkerVerificationRules.stateOf(types, uploads, now: now), WorkerVerificationState.verified);
      expect(WorkerVerificationRules.allRequiredApproved(types, uploads, now: now), isTrue);
    });

    test('list states: pending first, then rejected / expired, then not submitted', () {
      expect(WorkerVerificationRules.stateOf(types, WorkerVerificationRules.uploadsFrom([entry('id', 'uploaded'), entry('cv', 'rejected')]), now: now), WorkerVerificationState.pendingReview);
      expect(WorkerVerificationRules.stateOf(types, WorkerVerificationRules.uploadsFrom([entry('id', 'approved', more: {'expireAt': past})]), now: now), WorkerVerificationState.rejected);
      expect(WorkerVerificationRules.stateOf(types, WorkerVerificationRules.uploadsFrom([entry('id', 'approved')]), now: now), WorkerVerificationState.notSubmitted);
      expect(WorkerVerificationRules.stateOf(types, const {}, isDocumentVerify: true, now: now), WorkerVerificationState.verified);
    });

    test('same job gate as the Worker app', () {
      final approved = WorkerVerificationRules.uploadsFrom([entry('id', 'approved'), entry('cv', 'approved')]);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: false, types: types, typesLoadFailed: false, uploads: const {}, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: const {}, now: now), isFalse);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: null, types: types, typesLoadFailed: false, uploads: approved, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: false, uploads: const {}, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: true, uploads: const {}, now: now), isFalse);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: const {}, isDocumentVerify: true, now: now), isTrue);
    });

    test('settings: a cache miss is unknown', () {
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: false, isFromCache: true), isNull);
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: false, isFromCache: false), isFalse);
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: true, isFromCache: false, data: {'isWorkerVerification': true}), isTrue);
    });
  });

  group('approve one', () {
    test('never un-verifies: with a document still missing the flag is left alone', () {
      final out = WorkerVerificationRules.approve(types: types, stored: [entry('id', 'uploaded')], documentId: 'id', reviewerId: 'p1', at: at, now: now);
      expect(out.refused, isFalse);
      expect(out.setVerified, isNull);
      expect(out.missing.map((t) => t.id), ['cv']);
      expect(out.documents.single['status'], 'approved');
    });

    test('verifies once EVERY required document is approved', () {
      final out = WorkerVerificationRules.approve(types: types, stored: [entry('id', 'approved'), entry('cv', 'uploaded')], documentId: 'cv', reviewerId: 'p1', at: at, now: now);
      expect(out.setVerified, isTrue);
      expect(out.missing, isEmpty);
    });

    test('clears the old reason, records the review, keeps every other entry and field', () {
      final List<Map<String, dynamic>> stored = [
        entry('cv', 'approved', more: {'reviewedBy': 'admin'}),
        entry('id', 'rejected', more: {'rejectReason': 'Blurry', 'rejectionReason': 'Blurry', 'number': 'A-1', 'expireAt': Timestamp.fromDate(DateTime(2027))}),
      ];
      final out = WorkerVerificationRules.approve(types: types, stored: stored, documentId: 'id', reviewerId: 'p1', at: at, now: now);
      expect(out.documents[0], stored[0]);
      final e = out.documents[1];
      expect(e['status'], 'approved');
      expect(e.containsKey('rejectReason'), isFalse);
      expect(e.containsKey('rejectionReason'), isFalse);
      expect(e['number'], 'A-1');
      expect(e['frontImage'], img, reason: 'the Storage URL is kept exactly as stored');
      expect(e['reviewedBy'], 'p1');
      expect(e['reviewedAt'], at);
      expect(e['reviewedByRole'], 'provider');
    });

    test('nothing to decide when the document was not sent, or has expired', () {
      expect(WorkerVerificationRules.approve(types: types, stored: const [], documentId: 'id', reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.notSent);
      expect(WorkerVerificationRules.approve(types: types, stored: [entry('id', 'uploaded', front: null)], documentId: 'id', reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.notSent);
      expect(WorkerVerificationRules.approve(types: types, stored: [entry('id', 'uploaded', more: {'expireAt': past})], documentId: 'id', reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.expired);
    });
  });

  group('reject', () {
    test('needs a reason', () {
      expect(WorkerVerificationRules.reject(types: types, stored: [entry('id', 'uploaded')], documentId: 'id', reason: '  ', reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.reasonRequired);
    });

    test('a required document: rejected with rejectReason, and the worker is un-verified', () {
      final out = WorkerVerificationRules.reject(
          types: types, stored: [entry('id', 'approved', more: {'rejectionReason': 'old', 'reason': 'old'}), entry('cv', 'approved')], documentId: 'id', reason: ' Blurry photo ', reviewerId: 'p1', at: at, now: now);
      expect(out.setVerified, isFalse);
      expect(out.documents[0]['status'], 'rejected');
      expect(out.documents[0]['rejectReason'], 'Blurry photo');
      expect(out.documents[0].containsKey('rejectionReason'), isFalse);
      expect(out.documents[0].containsKey('reason'), isFalse);
      expect(out.documents[1]['status'], 'approved');
    });

    test('a document that is no longer required leaves the flag alone', () {
      final out = WorkerVerificationRules.reject(types: types, stored: [entry('old', 'uploaded')], documentId: 'old', reason: 'No', reviewerId: 'p1', at: at, now: now);
      expect(out.setVerified, isNull);
    });
  });

  group('approve all uploaded', () {
    test('approves only uploaded documents waiting for review; verifies when nothing is missing', () {
      final out = WorkerVerificationRules.approveAll(types: types, stored: [entry('id', 'uploaded'), entry('cv', 'uploaded')], reviewerId: 'p1', at: at, now: now);
      expect(out.changedIds, ['id', 'cv']);
      expect(out.setVerified, isTrue);
    });

    test('something missing: approves what was sent, does not verify, names what is missing', () {
      final out = WorkerVerificationRules.approveAll(types: types, stored: [entry('id', 'uploaded'), entry('cv', 'rejected', more: {'rejectReason': 'x'})], reviewerId: 'p1', at: at, now: now);
      expect(out.changedIds, ['id']);
      expect(out.setVerified, isNull);
      expect(out.missing.map((t) => t.title), ['CV']);
      // A rejected document is not approved by "approve all".
      expect(out.documents[1]['status'], 'rejected');
    });

    test('nothing uploaded: refused with the missing documents', () {
      final out = WorkerVerificationRules.approveAll(types: types, stored: [entry('id', 'approved')], reviewerId: 'p1', at: at, now: now);
      expect(out.refusal, WorkerReviewRefusal.nothingToApprove);
      expect(out.missing.map((t) => t.id), ['cv']);
    });

    test('no types read: refused', () {
      expect(WorkerVerificationRules.approveAll(types: const [], stored: const [], reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.typesUnknown);
    });
  });

  test('guard: only the provider\'s own workers', () {
    expect(WorkerVerificationRules.canReview({'providerId': 'p1'}, 'p1'), isTrue);
    expect(WorkerVerificationRules.canReview({'providerId': 'p2'}, 'p1'), isFalse);
    expect(WorkerVerificationRules.canReview({}, 'p1'), isFalse);
    expect(WorkerVerificationRules.canReview(null, 'p1'), isFalse);
    expect(WorkerVerificationRules.canReview({'providerId': ''}, ''), isFalse);
  });

  test('a new worker starts unverified', () {
    expect(FireStoreUtils.newWorkerRecord({'id': 'w1', 'isDocumentVerify': true})['isDocumentVerify'], isFalse);
  });

  group('pushes', () {
    const WorkerReviewOutcome approvedOne = WorkerReviewOutcome(changedIds: ['id']);
    const WorkerReviewOutcome verifiedNow = WorkerReviewOutcome(changedIds: ['cv'], setVerified: true);

    test('approval, verification and rejection templates with their placeholders', () {
      final a = workerDocumentPushes(action: WorkerReviewAction.approve, outcome: approvedOne, types: types, workerId: 'w1', providerId: 'p1', providerName: 'Acme');
      expect(a.single.type, 'worker_document_approved');
      expect(a.single.values, {'documentTitle': 'ID card', 'providerName': 'Acme'});
      expect(a.single.data, {'type': 'worker_document_approved', 'workerId': 'w1', 'providerId': 'p1', 'documentId': 'id'});

      final v = workerDocumentPushes(action: WorkerReviewAction.approve, outcome: verifiedNow, types: types, workerId: 'w1', providerId: 'p1', providerName: 'Acme', wasVerified: false);
      expect(v.single.type, 'worker_documents_verified');
      expect(v.single.values, {'providerName': 'Acme'});

      // Already verified (e.g. by the admin): a plain approval.
      final again = workerDocumentPushes(action: WorkerReviewAction.approve, outcome: verifiedNow, types: types, workerId: 'w1', providerId: 'p1', providerName: 'Acme', wasVerified: true);
      expect(again.single.type, 'worker_document_approved');

      final r = workerDocumentPushes(action: WorkerReviewAction.reject, outcome: approvedOne, types: types, workerId: 'w1', providerId: 'p1', providerName: 'Acme', reason: 'Blurry');
      expect(r.single.type, 'worker_document_rejected');
      expect(r.single.values, {'documentTitle': 'ID card', 'providerName': 'Acme', 'reason': 'Blurry'});
    });

    test('nothing for a refused action', () {
      expect(workerDocumentPushes(action: WorkerReviewAction.approveAll, outcome: const WorkerReviewOutcome(refusal: WorkerReviewRefusal.nothingToApprove), types: types, workerId: 'w1', providerId: 'p1', providerName: 'A'), isEmpty);
    });

    test('the worker\'s pushes go to the Worker app', () {
      expect(recipientForKind('worker_document_approved'), PushApp.worker);
      expect(recipientForKind('worker_documents_verified'), PushApp.worker);
      expect(recipientForKind('worker_document_rejected'), PushApp.worker);
    });

    test('placeholders are filled from the values', () {
      expect(PushTemplateText.fill('{documentTitle} rejected by {providerName}: {reason}', {'documentTitle': 'ID card', 'providerName': 'Acme', 'reason': 'Blurry'}), 'ID card rejected by Acme: Blurry');
    });

    test('a worker upload push opens that worker\'s review screen', () {
      expect(providerTapTarget({'type': 'worker_document_submitted', 'workerId': 'w1'}), const ProviderTapTarget(ProviderTapKind.workerDocuments, '', 'w1'));
      expect(providerTapTarget({'type': 'worker_document_submitted'}), const ProviderTapTarget(ProviderTapKind.none));
      expect(providerTapTarget({'type': 'worker_document_submitted', 'workerId': 'a/b'}), const ProviderTapTarget(ProviderTapKind.none));
    });
  });
}
