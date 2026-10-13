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
      expect(WorkerVerificationRules.overall(types, uploads, now: now), WorkerOverallStatus.verified);
      expect(WorkerVerificationRules.allRequiredApproved(types, uploads, now: now), isTrue);
    });

    test('overall: action required beats pending; partly uploaded is pending; nothing uploaded is not submitted', () {
      expect(WorkerVerificationRules.overall(types, WorkerVerificationRules.uploadsFrom([entry('id', 'uploaded'), entry('cv', 'rejected')]), now: now), WorkerOverallStatus.actionRequired);
      expect(WorkerVerificationRules.overall(types, WorkerVerificationRules.uploadsFrom([entry('id', 'approved', more: {'expireAt': past})]), now: now), WorkerOverallStatus.actionRequired);
      expect(WorkerVerificationRules.overall(types, WorkerVerificationRules.uploadsFrom([entry('id', 'approved')]), now: now), WorkerOverallStatus.pending);
      expect(WorkerVerificationRules.overall(types, const {}, now: now), WorkerOverallStatus.notSubmitted);
    });

    test('isDocumentVerify true alone never verifies while verification is on', () {
      final pending = WorkerVerificationRules.uploadsFrom([entry('id', 'approved'), entry('cv', 'uploaded')]);
      expect(WorkerVerificationRules.overall(types, pending, isDocumentVerify: true, verificationRequired: true, now: now), WorkerOverallStatus.pending);
      expect(WorkerVerificationRules.overall(types, const {}, isDocumentVerify: true, now: now), WorkerOverallStatus.notSubmitted);
      final rejected = WorkerVerificationRules.uploadsFrom([entry('id', 'rejected'), entry('cv', 'approved')]);
      expect(WorkerVerificationRules.overall(types, rejected, isDocumentVerify: true, verificationRequired: false, now: now), WorkerOverallStatus.actionRequired);
      // Verification switched off: the admin's flag counts (unless rejected / expired).
      expect(WorkerVerificationRules.overall(types, pending, isDocumentVerify: true, verificationRequired: false, now: now), WorkerOverallStatus.verified);
    });

    test('same job gate as the Worker app', () {
      final approved = WorkerVerificationRules.uploadsFrom([entry('id', 'approved'), entry('cv', 'approved')]);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: false, types: types, typesLoadFailed: false, uploads: const {}, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: const {}, now: now), isFalse);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: null, types: types, typesLoadFailed: false, uploads: approved, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: false, uploads: const {}, now: now), isTrue);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: true, uploads: const {}, now: now), isFalse);
      // The flag alone does not open the gate; the documents do.
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: const {}, isDocumentVerify: true, now: now), isFalse);
      final pending = WorkerVerificationRules.uploadsFrom([entry('id', 'approved'), entry('cv', 'uploaded')]);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: pending, isDocumentVerify: true, now: now), isFalse);
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: approved, isDocumentVerify: false, now: now), isTrue);
    });

    test('settings: a cache miss is unknown', () {
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: false, isFromCache: true), isNull);
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: false, isFromCache: false), isFalse);
      expect(WorkerVerificationRules.verificationRequiredFrom(exists: true, isFromCache: false, data: {'isWorkerVerification': true}), isTrue);
    });
  });

  group('approve one', () {
    test('flag recalculated: a document still missing -> false (unless already false)', () {
      final out = WorkerVerificationRules.approve(types: types, stored: [entry('id', 'uploaded')], documentId: 'id', reviewerId: 'p1', at: at, currentFlag: true, now: now);
      expect(out.refused, isFalse);
      expect(out.setVerified, isFalse);
      expect(WorkerVerificationRules.approve(types: types, stored: [entry('id', 'uploaded')], documentId: 'id', reviewerId: 'p1', at: at, currentFlag: false, now: now).setVerified, isNull);
      expect(out.missing.map((t) => t.id), ['cv']);
      expect(out.documents.single['status'], 'approved');
    });

    test('verifies once EVERY required document is approved', () {
      final out = WorkerVerificationRules.approve(types: types, stored: [entry('id', 'approved'), entry('cv', 'uploaded')], documentId: 'cv', reviewerId: 'p1', at: at, now: now);
      expect(out.setVerified, isTrue);
      expect(out.missing, isEmpty);
      // Already true: nothing to write.
      expect(WorkerVerificationRules.approve(types: types, stored: [entry('id', 'approved'), entry('cv', 'uploaded')], documentId: 'cv', reviewerId: 'p1', at: at, currentFlag: true, now: now).setVerified, isNull);
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

    test('a document that is no longer required: the flag follows the required ones', () {
      final verified = WorkerVerificationRules.reject(
          types: types, stored: [entry('id', 'approved'), entry('cv', 'approved'), entry('old', 'uploaded')], documentId: 'old', reason: 'No', reviewerId: 'p1', at: at, currentFlag: true, now: now);
      expect(verified.setVerified, isNull);
      final missing = WorkerVerificationRules.reject(types: types, stored: [entry('old', 'uploaded')], documentId: 'old', reason: 'No', reviewerId: 'p1', at: at, currentFlag: true, now: now);
      expect(missing.setVerified, isFalse);
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
      expect(out.setVerified, isFalse);
      expect(out.missing.map((t) => t.title), ['CV']);
      // A rejected document is not approved by "approve all".
      expect(out.documents[1]['status'], 'rejected');
    });

    test('nothing uploaded: refused with the missing documents', () {
      final out = WorkerVerificationRules.approveAll(types: types, stored: [entry('id', 'approved')], reviewerId: 'p1', at: at, now: now);
      expect(out.refusal, WorkerReviewRefusal.nothingToApprove);
      expect(out.missing.map((t) => t.id), ['cv']);
    });

    test('everything already approved but the flag is false: synced to true', () {
      final out = WorkerVerificationRules.approveAll(types: types, stored: [entry('id', 'approved'), entry('cv', 'approved')], reviewerId: 'p1', at: at, currentFlag: false, now: now);
      expect(out.refused, isFalse);
      expect(out.changedIds, isEmpty);
      expect(out.setVerified, isTrue);
    });

    test('no types read: refused', () {
      expect(WorkerVerificationRules.approveAll(types: const [], stored: const [], reviewerId: 'p1', at: at, now: now).refusal, WorkerReviewRefusal.typesUnknown);
    });
  });

  group('record type separation', () {
    test('only worker records are read as a worker\'s uploads', () {
      final docs = [entry('id', 'approved'), entry('cv', 'approved')];
      expect(WorkerVerificationRules.uploadsFromRecord({'type': 'worker', 'documents': docs}).keys, ['id', 'cv']);
      expect(WorkerVerificationRules.uploadsFromRecord({'documents': docs}).keys, ['id', 'cv'], reason: 'a legacy record without a type is the worker\'s');
      for (final other in ['driver', 'owner', 'vendor', 'provider']) {
        expect(WorkerVerificationRules.uploadsFromRecord({'type': other, 'documents': docs}), isEmpty, reason: other);
        expect(WorkerVerificationRules.isWorkerRecord({'type': other}), isFalse, reason: other);
      }
      expect(WorkerVerificationRules.uploadsFromRecord(null), isEmpty);
    });

    test('a driver record never makes a worker assignable', () {
      final uploads = WorkerVerificationRules.uploadsFromRecord({'type': 'driver', 'documents': [entry('id', 'approved'), entry('cv', 'approved')]});
      expect(WorkerVerificationRules.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploads: uploads, now: now), isFalse);
    });

    test('only enabled worker types are required', () {
      final required = WorkerVerificationRules.requiredTypesFrom(const [
        MapEntry('w1', <String, dynamic>{'type': 'worker', 'enable': true, 'title': 'ID card'}),
        MapEntry('p1', <String, dynamic>{'type': 'provider', 'enable': true, 'title': 'Register'}),
        MapEntry('d1', <String, dynamic>{'type': 'driver', 'enable': true, 'title': 'Licence'}),
        MapEntry('w2', <String, dynamic>{'type': 'worker', 'enable': false, 'title': 'Old'}),
      ]);
      expect(required.map((t) => t.id), ['w1']);
    });
  });

  group('assignment validation (every assign / reassign)', () {
    final Map<String, dynamic> mine = {'providerId': 'p1', 'isDocumentVerify': false};
    final Map<String, dynamic> flagged = {'providerId': 'p1', 'isDocumentVerify': true};
    Map<String, dynamic> record(List<Map<String, dynamic>> docs, {String type = 'worker'}) => {'id': 'w1', 'type': type, 'documents': docs};
    WorkerAssignmentRefusal? check(Map<String, dynamic>? worker, Map<String, dynamic>? rec, {bool? required = true, List<DocumentType>? ts, bool typesFailed = false, bool recFailed = false}) =>
        WorkerVerificationRules.assignmentRefusal(
          workerData: worker,
          providerId: 'p1',
          verificationRequired: required,
          types: ts ?? types,
          typesLoadFailed: typesFailed,
          record: rec,
          recordLoadFailed: recFailed,
          now: now,
        );

    test('every required document approved: allowed', () {
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'approved')])), isNull);
    });

    test('a required document missing: refused (documents missing)', () {
      expect(check(mine, record([entry('id', 'approved')])), WorkerAssignmentRefusal.documentsMissing);
      expect(check(mine, null), WorkerAssignmentRefusal.documentsMissing);
    });

    test('a required document pending verification: refused (pending review)', () {
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'uploaded')])), WorkerAssignmentRefusal.pendingReview);
    });

    test('a required document rejected or expired: refused (rejected)', () {
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'rejected', more: {'rejectReason': 'Blurry'})])), WorkerAssignmentRefusal.rejected);
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'approved', more: {'expireAt': past})])), WorkerAssignmentRefusal.rejected);
    });

    test('isDocumentVerify true but a document rejected / pending / missing: still refused', () {
      expect(check(flagged, record([entry('id', 'approved'), entry('cv', 'rejected')])), WorkerAssignmentRefusal.rejected);
      expect(check(flagged, record([entry('id', 'approved'), entry('cv', 'uploaded')])), WorkerAssignmentRefusal.pendingReview);
      expect(check(flagged, null), WorkerAssignmentRefusal.documentsMissing);
    });

    test('another provider\'s worker, or no worker record: refused', () {
      expect(check({'providerId': 'p2', 'isDocumentVerify': true}, record([entry('id', 'approved'), entry('cv', 'approved')])), WorkerAssignmentRefusal.notYourWorker);
      expect(check(null, null), WorkerAssignmentRefusal.notYourWorker);
    });

    test('a driver / owner record is never the worker\'s documents', () {
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'approved')], type: 'driver')), WorkerAssignmentRefusal.documentsMissing);
    });

    test('verification off: allowed; no required type: allowed; types or record unreadable: refused', () {
      expect(check(mine, null, required: false), isNull);
      expect(check(mine, null, ts: const []), isNull);
      expect(check(mine, null, ts: const [], typesFailed: true), WorkerAssignmentRefusal.unknown);
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'approved')]), recFailed: true), WorkerAssignmentRefusal.unknown);
      // The setting not read yet counts as ON.
      expect(check(mine, record([entry('id', 'approved')]), required: null), WorkerAssignmentRefusal.documentsMissing);
    });

    test('a disabled (no longer required) document does not block', () {
      expect(check(mine, record([entry('id', 'approved'), entry('cv', 'approved'), entry('old', 'rejected')])), isNull);
    });

    test('every refusal has a message and a short label', () {
      for (final r in WorkerAssignmentRefusal.values) {
        expect(WorkerVerificationRules.assignmentRefusalMessage(r), startsWith('Cannot assign'), reason: '$r');
        expect(WorkerVerificationRules.assignmentRefusalLabel(r), isNotEmpty, reason: '$r');
      }
      expect(WorkerVerificationRules.assignmentRefusalLabel(WorkerAssignmentRefusal.pendingReview), 'Pending review');
      expect(WorkerVerificationRules.assignmentRefusalLabel(WorkerAssignmentRefusal.documentsMissing), 'Documents missing');
      expect(WorkerVerificationRules.assignmentRefusalLabel(WorkerAssignmentRefusal.rejected), 'Documents rejected');
    });
  });

  group('labels', () {
    test('overall statuses and the document type label', () {
      expect(WorkerOverallStatus.values.map(WorkerVerificationStatusRules.overallLabel), ['Not submitted', 'Pending', 'Action required', 'Verified']);
      expect(WorkerVerificationStatusRules.recordTypeLabel('worker'), 'Worker');
      expect(WorkerVerificationStatusRules.recordTypeLabel(WorkerVerificationRules.workerType), 'Worker');
    });

    test('per-document states map 1:1 onto DocumentStatus', () {
      expect(WorkerDocumentState.values.map((s) => s.asDocumentStatus), [
        DocumentStatus.notSubmitted,
        DocumentStatus.pendingReview,
        DocumentStatus.approved,
        DocumentStatus.rejected,
        DocumentStatus.expired,
      ]);
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
