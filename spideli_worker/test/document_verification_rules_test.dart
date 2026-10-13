import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/document_service.dart';
import 'package:spideliworker/services/push_message.dart';
import 'package:spideliworker/services/push_template_text.dart';
import 'package:spideliworker/services/worker_document_push.dart';

/// Worker document verification end to end: the per-document and overall
/// status, the job gate, the merge-safe re-upload, the live settings read,
/// and the document pushes.
void main() {
  final DateTime now = DateTime(2026, 10, 13, 12);
  final Timestamp past = Timestamp.fromDate(DateTime(2026, 1, 1));
  final Timestamp future = Timestamp.fromDate(DateTime(2027, 1, 1));
  const String img = 'https://firebasestorage.googleapis.com/v0/b/x/o/workerDocument%2Fw1%2Ff.jpg?alt=media';

  WorkerDocumentModel uploads(List<Documents> docs) => WorkerDocumentModel(id: 'w1', type: 'worker', documents: docs);

  group('statusOf', () {
    test('nothing sent: not submitted', () {
      expect(DocumentService.statusOf(null, now: now), VerificationStatus.notSubmitted);
      expect(DocumentService.statusOf(Documents(documentId: 'a', status: 'uploaded'), now: now), VerificationStatus.notSubmitted);
    });

    test('rejected shows as rejected, even without an image', () {
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'rejected'), now: now), VerificationStatus.rejected);
      expect(DocumentService.statusOf(Documents(documentId: 'a', status: 'Rejected'), now: now), VerificationStatus.rejected);
    });

    test('expired: stored as such, or past its expiry date whether approved or waiting', () {
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'expired'), now: now), VerificationStatus.expired);
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'approved', expiryDate: past), now: now), VerificationStatus.expired);
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'uploaded', expiryDate: past), now: now), VerificationStatus.expired);
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'approved', expiryDate: future), now: now), VerificationStatus.approved);
    });

    test('approved / verified in any case; anything else sent is pending', () {
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'Approved'), now: now), VerificationStatus.approved);
      expect(DocumentService.statusOf(Documents(documentId: 'a', backImage: img, status: 'verified'), now: now), VerificationStatus.approved);
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img, status: 'uploaded'), now: now), VerificationStatus.pending);
      expect(DocumentService.statusOf(Documents(documentId: 'a', frontImage: img), now: now), VerificationStatus.pending);
    });
  });

  group('overallStatus', () {
    final types = [DocumentModel(id: 'id', title: 'ID card', enable: true), DocumentModel(id: 'cv', title: 'CV', enable: true)];

    test('Verified only when EVERY required document is approved; partly sent is Pending', () {
      final one = uploads([Documents(documentId: 'id', frontImage: img, status: 'approved')]);
      expect(DocumentService.overallStatus(types, one, now: now), WorkerOverallStatus.pending);
      final both = uploads([Documents(documentId: 'id', frontImage: img, status: 'approved'), Documents(documentId: 'cv', frontImage: img, status: 'approved')]);
      expect(DocumentService.overallStatus(types, both, now: now), WorkerOverallStatus.verified);
      expect(DocumentService.overallStatus(types, null, now: now), WorkerOverallStatus.notSubmitted);
    });

    test('a document type disabled later does not lock the worker', () {
      // "old" is no longer a required (enabled) type: its rejection is ignored.
      final docs = uploads([
        Documents(documentId: 'id', frontImage: img, status: 'approved'),
        Documents(documentId: 'cv', frontImage: img, status: 'approved'),
        Documents(documentId: 'old', frontImage: img, status: 'rejected'),
      ]);
      expect(DocumentService.overallStatus(types, docs, now: now), WorkerOverallStatus.verified);
    });

    test('rejected or expired: Action required, whatever else', () {
      expect(
          DocumentService.overallStatus(types, uploads([Documents(documentId: 'id', frontImage: img, status: 'rejected'), Documents(documentId: 'cv', frontImage: img, status: 'approved', expiryDate: past)]), now: now),
          WorkerOverallStatus.actionRequired);
      expect(DocumentService.overallStatus(types, uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded'), Documents(documentId: 'cv', frontImage: img, status: 'approved', expiryDate: past)]), now: now),
          WorkerOverallStatus.actionRequired);
      expect(DocumentService.overallStatus(types, uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded')]), now: now), WorkerOverallStatus.pending);
      expect(DocumentService.overallStatus(types, uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded'), Documents(documentId: 'cv', frontImage: img, status: 'approved')]), now: now),
          WorkerOverallStatus.pending);
    });

    test('isDocumentVerify true never verifies while a required document is pending, missing, rejected or expired', () {
      final pending = uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded')]);
      expect(DocumentService.overallStatus(types, pending, isDocumentVerify: true, now: now), WorkerOverallStatus.pending);
      expect(DocumentService.overallStatus(types, null, isDocumentVerify: true, now: now), WorkerOverallStatus.notSubmitted);
      final rejected = uploads([Documents(documentId: 'id', frontImage: img, status: 'rejected')]);
      expect(DocumentService.overallStatus(types, rejected, isDocumentVerify: true, now: now), WorkerOverallStatus.actionRequired);
    });

    test('verification switched off: the flag counts unless rejected / expired', () {
      final pending = uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded')]);
      expect(DocumentService.overallStatus(types, pending, isDocumentVerify: true, verificationRequired: false, now: now), WorkerOverallStatus.verified);
      final rejected = uploads([Documents(documentId: 'id', frontImage: img, status: 'rejected')]);
      expect(DocumentService.overallStatus(types, rejected, isDocumentVerify: true, verificationRequired: false, now: now), WorkerOverallStatus.actionRequired);
    });
  });

  group('canReceiveJobs', () {
    final types = [DocumentModel(id: 'id', title: 'ID card', enable: true)];
    final approved = uploads([Documents(documentId: 'id', frontImage: img, status: 'approved')]);

    test('a setting not read yet counts as ON', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: null, types: types, typesLoadFailed: false, now: now), isFalse);
      expect(DocumentService.canReceiveJobs(verificationRequired: null, types: types, typesLoadFailed: false, uploaded: approved, now: now), isTrue);
    });

    test('turning verification off releases every worker', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: false, types: types, typesLoadFailed: false, isDocumentVerify: false, now: now), isTrue);
    });

    test('the flag alone does not open the gate', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, isDocumentVerify: true, now: now), isFalse);
      final pending = uploads([Documents(documentId: 'id', frontImage: img, status: 'uploaded')]);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: pending, isDocumentVerify: true, now: now), isFalse);
    });

    test('a worker whose required documents are all approved is never blocked', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: true, uploaded: approved, now: now), isTrue);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: approved, now: now), isTrue);
    });

    test('a failed type read is not "no types": blocked until approved', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: true, now: now), isFalse);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: false, now: now), isTrue);
    });
  });

  group('live reads', () {
    test('settings: a cache miss is unknown, a server miss is off', () {
      expect(DocumentService.verificationRequiredFrom(exists: false, isFromCache: true), isNull);
      expect(DocumentService.verificationRequiredFrom(exists: false, isFromCache: false), isFalse);
      expect(DocumentService.verificationRequiredFrom(exists: true, isFromCache: true, data: {'isWorkerVerification': true}), isTrue);
      expect(DocumentService.verificationRequiredFrom(exists: true, isFromCache: false, data: {'isDriverVerification': true}), isFalse);
    });

    test('types: an empty cache answer is a failed read', () {
      expect(DocumentService.typesUnreadable(isEmpty: true, isFromCache: true), isTrue);
      expect(DocumentService.typesUnreadable(isEmpty: true, isFromCache: false), isFalse);
      expect(DocumentService.typesUnreadable(isEmpty: false, isFromCache: true), isFalse);
    });
  });

  group('entry shape', () {
    test('the reviewer reason is read from rejectReason (panel) or the older keys', () {
      expect(Documents.fromJson({'documentId': 'a', 'status': 'rejected', 'rejectReason': 'Blurry'}).rejectionReason, 'Blurry');
      expect(Documents.fromJson({'documentId': 'a', 'status': 'rejected', 'rejectionReason': 'Old'}).rejectionReason, 'Old');
      expect(Documents.fromJson({'documentId': 'a', 'status': 'rejected', 'reason': ' '}).rejectionReason, isNull);
    });

    test('expiry and submission dates: new keys written, old keys read', () {
      final d = Documents.fromJson({'documentId': 'a', 'expiryDate': future, 'uploadedAt': past});
      expect(d.expiryDate, future);
      expect(d.submittedAt, past);
      final json = d.toJson();
      expect(json['expireAt'], future);
      expect(json['submittedAt'], past);
      expect(json.containsKey('expiryDate'), isFalse);
      expect(json.containsKey('uploadedAt'), isFalse);
    });
  });

  group('mergeUpload (re-upload)', () {
    final Timestamp at = Timestamp.fromDate(now);
    final List<dynamic> stored = [
      {'documentId': 'other', 'frontImage': img, 'status': 'approved', 'reviewedBy': 'p1'},
      {
        'documentId': 'id',
        'frontImage': 'https://old/f.jpg',
        'status': 'rejected',
        'rejectReason': 'Blurry',
        'rejectionReason': 'Blurry',
        'reviewedAt': past,
        'reviewedBy': 'p1',
        'number': 'A-123',
        'expireAt': past,
      },
      {'documentId': 'id', 'frontImage': 'https://dup/f.jpg', 'status': 'uploaded'},
    ];

    test('replaces the entry in place, once, and keeps every other entry untouched', () {
      final out = DocumentService.mergeUpload(stored, Documents(documentId: 'id', frontImage: img, backImage: img), now: at);
      expect(out.length, 2);
      expect(out[0], stored[0]);
      final Map entry = out[1] as Map;
      expect(entry['documentId'], 'id');
      expect(entry['frontImage'], img);
      expect(entry['backImage'], img);
    });

    test('status back to uploaded, reason and previous review cleared, submittedAt set', () {
      final Map entry = DocumentService.mergeUpload(stored, Documents(documentId: 'id', frontImage: img), now: at)[1] as Map;
      expect(entry['status'], 'uploaded');
      expect(entry['submittedAt'], at);
      for (final key in Documents.reviewKeys) {
        expect(entry.containsKey(key), isFalse, reason: key);
      }
      // A field this app does not manage survives.
      expect(entry['number'], 'A-123');
    });

    test('an old expiry date is not carried over; a new one is written', () {
      final Map without = DocumentService.mergeUpload(stored, Documents(documentId: 'id', frontImage: img), now: at)[1] as Map;
      expect(without.containsKey('expireAt'), isFalse);
      final Map withDate = DocumentService.mergeUpload(stored, Documents(documentId: 'id', frontImage: img, expiryDate: future), now: at)[1] as Map;
      expect(withDate['expireAt'], future);
    });

    test('a first upload is appended', () {
      final out = DocumentService.mergeUpload([stored[0]], Documents(documentId: 'new', frontImage: img), now: at);
      expect(out.length, 2);
      expect((out[1] as Map)['documentId'], 'new');
      expect((out[1] as Map)['status'], 'uploaded');
    });
  });

  group('submit / resubmit (planSubmit)', () {
    final types = [DocumentModel(id: 'id', title: 'ID card', enable: true), DocumentModel(id: 'cv', title: 'CV', enable: true)];
    final Timestamp at = Timestamp.fromDate(now);
    final List<dynamic> verified = [
      {'documentId': 'id', 'frontImage': img, 'status': 'approved', 'reviewedBy': 'p1'},
      {'documentId': 'cv', 'frontImage': img, 'status': 'approved', 'reviewedBy': 'p1'},
    ];

    test('a resubmission returns the document to uploaded (never auto-approved) and lowers the flag', () {
      final plan = DocumentService.planSubmit(stored: verified, document: Documents(documentId: 'cv', frontImage: img), requiredTypes: types, currentFlag: true, at: at, now: now);
      final Map entry = plan.documents[1] as Map;
      expect(entry['status'], 'uploaded');
      expect(entry.containsKey('reviewedBy'), isFalse);
      expect(plan.setVerified, isFalse);
      final after = WorkerDocumentModel.fromJson({'type': 'worker', 'documents': plan.documents});
      expect(DocumentService.overallStatus(types, after, isDocumentVerify: true, now: now), WorkerOverallStatus.pending);
    });

    test('resubmitting a rejected document: reason cleared, Pending, flag already false is left alone', () {
      final List<dynamic> stored = [
        {'documentId': 'id', 'frontImage': img, 'status': 'approved'},
        {'documentId': 'cv', 'frontImage': img, 'status': 'rejected', 'rejectReason': 'Blurry'},
      ];
      final plan = DocumentService.planSubmit(stored: stored, document: Documents(documentId: 'cv', frontImage: img), requiredTypes: types, currentFlag: false, at: at, now: now);
      expect((plan.documents[1] as Map).containsKey('rejectReason'), isFalse);
      expect(plan.setVerified, isNull);
      expect(DocumentService.overallStatus(types, WorkerDocumentModel.fromJson({'documents': plan.documents}), now: now), WorkerOverallStatus.pending);
    });

    test('a first submission with no flag yet writes false; the worker never raises it', () {
      expect(DocumentService.planSubmit(stored: const [], document: Documents(documentId: 'id', frontImage: img), requiredTypes: types, at: at, now: now).setVerified, isFalse);
      // A document outside the required set leaves a verified worker verified.
      final plan = DocumentService.planSubmit(stored: verified, document: Documents(documentId: 'extra', frontImage: img), requiredTypes: types, currentFlag: true, at: at, now: now);
      expect(plan.setVerified, isNull);
    });
  });

  group('record type separation', () {
    test('only the worker\'s own record is read', () {
      final docs = [
        {'documentId': 'id', 'frontImage': img, 'status': 'approved'},
      ];
      expect(DocumentService.uploadedFrom({'type': 'worker', 'documents': docs})?.documents.length, 1);
      expect(DocumentService.uploadedFrom({'documents': docs})?.documents.length, 1, reason: 'legacy record without a type');
      for (final other in ['driver', 'owner', 'vendor', 'provider']) {
        expect(DocumentService.uploadedFrom({'type': other, 'documents': docs}), isNull, reason: other);
        expect(WorkerDocumentModel.fromJson({'type': other}).isWorkerRecord, isFalse, reason: other);
      }
      expect(DocumentService.uploadedFrom(null), isNull);
    });

    test('a driver record never opens the jobs gate', () {
      final types = [DocumentModel(id: 'id', title: 'ID card', enable: true)];
      final driver = DocumentService.uploadedFrom({'type': 'driver', 'documents': [{'documentId': 'id', 'frontImage': img, 'status': 'approved'}]});
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: driver, now: now), isFalse);
    });
  });

  group('display labels', () {
    test('overall and per-document labels; the statuses map 1:1', () {
      expect(WorkerOverallStatus.values.map((s) => s.label), ['Not submitted', 'Pending', 'Action required', 'Verified']);
      expect(VerificationStatus.values.map((s) => s.label), ['Not submitted', 'Pending review', 'Approved', 'Rejected', 'Expired']);
      for (final s in VerificationStatus.values) {
        expect(s.asWorkerDocumentState.asVerificationStatus, s);
        expect(s.asWorkerDocumentState.name, s.name);
      }
      expect(WorkerVerificationStatusRules.recordTypeLabel(DocumentService.workerType), 'Worker');
    });
  });

  group('document pushes', () {
    test('a decision on the worker\'s documents opens the Documents tab', () {
      expect(pushRouteFor({'type': 'worker_document_approved'}), PushRoute.documents);
      expect(pushRouteFor({'type': 'worker_documents_verified'}), PushRoute.documents);
      expect(pushRouteFor({'type': 'worker_document_rejected', 'documentId': 'id'}), PushRoute.documents);
    });

    test('the upload push to the provider names the worker and the document', () {
      expect(WorkerDocumentPush.submittedData(workerId: 'w1', providerId: 'p1', documentId: 'id'), {
        'type': 'worker_document_submitted',
        'workerId': 'w1',
        'providerId': 'p1',
        'documentId': 'id',
      });
      expect(WorkerDocumentPush.submittedValues(workerName: ' Ana B ', documentTitle: 'ID card'), {'workerName': 'Ana B', 'documentTitle': 'ID card'});
    });

    test('template placeholders are filled; a missing template sends nothing', () {
      expect(PushTemplateText.fill('{workerName} sent {DocumentTitle} ({x})', {'workername': 'Ana', 'documentTitle': 'ID card'}), 'Ana sent ID card ({x})');
      expect(PushTemplateText.isSetUp(type: 't', templateId: '', templateType: '', subject: 'setup notification', message: 'Notification setup is pending'), isFalse);
      expect(PushTemplateText.isSetUp(type: 't', templateId: 'abc', templateType: 't', subject: '', message: ''), isFalse);
      expect(PushTemplateText.isSetUp(type: 't', templateId: 'abc', templateType: 't', subject: 'Hi', message: ''), isTrue);
    });
  });
}
