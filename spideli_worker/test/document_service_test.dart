import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/document_service.dart';

/// Report Doc 36/41: worker uploads go only against admin-created document
/// types (`documents` with `type == "worker"`, `enable == true`), never a
/// built-in key; no type -> empty list (empty state), nothing verified, and
/// the job gate does not lock the worker out.
void main() {
  group('documentTypesFrom', () {
    test('keeps enabled worker types, keyed by their Firestore id', () {
      final types = DocumentService.documentTypesFrom([
        const MapEntry('abc123', <String, dynamic>{'type': 'worker', 'enable': true, 'title': 'ID Card', 'frontSide': true}),
        const MapEntry('drv1', <String, dynamic>{'type': 'driver', 'enable': true, 'title': 'Driving License'}),
        const MapEntry('off1', <String, dynamic>{'type': 'worker', 'enable': false, 'title': 'Old'}),
      ]);
      expect(types.map((t) => t.id), ['abc123']);
      expect(types.single.title, 'ID Card');
    });

    test('the Firestore id wins over a stale stored "id" field', () {
      final types = DocumentService.documentTypesFrom([
        const MapEntry('abc123', <String, dynamic>{'id': 'xyz', 'type': 'worker', 'enable': true, 'title': 'ID Card'}),
      ]);
      expect(types.single.id, 'abc123');
      expect(DocumentModel.fromJson(const {'id': 'xyz'}, docId: 'abc123').id, 'abc123');
      expect(DocumentModel.fromJson(const {'id': 'xyz'}).id, 'xyz');
      expect(DocumentModel.fromJson(const {'id': 'xyz'}, docId: '').id, 'xyz');
      expect(DocumentModel.fromJson(const {}).id, isNull);
    });

    test('empty when the admin created no worker type -- no built-in fallback', () {
      expect(DocumentService.documentTypesFrom(const []), isEmpty);
      expect(DocumentService.documentTypesFrom(const [MapEntry('p1', <String, dynamic>{'type': 'provider', 'enable': true})]), isEmpty);
    });
  });

  group('overallStatus', () {
    final types = [DocumentModel(id: 'abc123', title: 'ID Card', enable: true)];

    test('no types: not submitted unless the admin verified the worker', () {
      expect(DocumentService.overallStatus(const [], null), VerificationStatus.notSubmitted);
      expect(DocumentService.overallStatus(const [], null, isDocumentVerify: false), VerificationStatus.notSubmitted);
      expect(DocumentService.overallStatus(const [], null, isDocumentVerify: true), VerificationStatus.approved);
    });

    test('an upload is matched to its type by the type id', () {
      final uploaded = WorkerDocumentModel(id: 'w1', type: 'worker', documents: [Documents(documentId: 'abc123', frontImage: 'https://x/f.jpg', status: 'uploaded')]);
      expect(DocumentService.overallStatus(types, uploaded), VerificationStatus.pending);
      final legacy = WorkerDocumentModel(id: 'w1', type: 'worker', documents: [Documents(documentId: 'worker_identity_document', frontImage: 'https://x/f.jpg', status: 'uploaded')]);
      expect(DocumentService.overallStatus(types, legacy), VerificationStatus.notSubmitted);
    });
  });

  group('canReceiveJobs', () {
    final types = [DocumentModel(id: 'abc123', title: 'ID Card', enable: true)];
    final approvedUpload = WorkerDocumentModel(id: 'w1', type: 'worker', documents: [Documents(documentId: 'abc123', frontImage: 'https://x/f.jpg', status: 'approved')]);
    final pendingUpload = WorkerDocumentModel(id: 'w1', type: 'worker', documents: [Documents(documentId: 'abc123', frontImage: 'https://x/f.jpg', status: 'uploaded')]);

    test('verification off: always', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: false, types: types, typesLoadFailed: false), isTrue);
      expect(DocumentService.canReceiveJobs(verificationRequired: false, types: const [], typesLoadFailed: true), isTrue);
    });

    test('verification on, no worker type configured: not locked out', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: false), isTrue);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: false, isDocumentVerify: false), isTrue);
      // The displayed status is unchanged: nothing has been verified.
      expect(DocumentService.overallStatus(const [], null), VerificationStatus.notSubmitted);
    });

    test('verification on, types could not be read: blocked unless approved', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: true), isFalse);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: const [], typesLoadFailed: true, isDocumentVerify: true), isTrue);
    });

    test('verification on, types configured: only once approved', () {
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false), isFalse);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: pendingUpload), isFalse);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: approvedUpload), isTrue);
      expect(DocumentService.canReceiveJobs(verificationRequired: true, types: types, typesLoadFailed: false, uploaded: pendingUpload, isDocumentVerify: true), isTrue);
    });
  });

  test('an uploaded entry carries the type id and status "uploaded"', () {
    final json = Documents(documentId: 'abc123', frontImage: 'https://x/f.jpg', status: 'uploaded').toJson();
    expect(json['documentId'], 'abc123');
    expect(json['status'], 'uploaded');
    expect(json['backImage'], '');
  });
}
