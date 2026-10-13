import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// The overall document status of a (company) driver: one pure function,
/// the flag sync on submit / review, record-type separation and labels.
/// `.claude/DOCUMENT-VERIFICATION-DRIVER.md`.

DocumentModel req(String id, {String type = 'driver', bool enable = true}) => DocumentModel(id: id, title: 'Title $id', enable: enable, frontSide: true, type: type);

Documents doc(String id, {String status = 'uploaded', DateTime? expiry, Map<String, dynamic>? extra, String front = 'https://img/x.jpg'}) => Documents.fromJson({
      'documentId': id,
      'status': status,
      'frontImage': front,
      'backImage': '',
      if (expiry != null) 'expireAt': Timestamp.fromDate(expiry),
      ...?extra,
    });

UserModel companyDriver({String id = 'd1', bool? verified, List<String>? services, bool autoVerify = false}) => UserModel.fromJson({
      'id': id,
      'firstName': 'Dan',
      'role': 'driver',
      'ownerId': 'owner1',
      'isOwner': false,
      'isAutoVerify': autoVerify,
      'serviceTypes': ?services,
      'isDocumentVerify': ?verified,
    });

UserModel platformDriver({bool? verified}) => UserModel.fromJson({'id': 'p1', 'role': 'driver', 'isAutoVerify': false, 'isDocumentVerify': ?verified});

DocumentOverallStatus overall(List<DocumentModel> required, List<Documents> docs, {bool? flag}) => DriverDocumentStatus.overall(required: required, docs: docs, flag: flag);

void main() {
  final DateTime past = DateTime(2000);
  final DateTime future = DateTime.now().add(const Duration(days: 365));

  setUp(() {
    Constant.isDriverVerification = null;
    Constant.isOwnerVerification = null;
    DocumentStatusCache.clear();
  });

  group('overall status (the one function)', () {
    final required = [req('a'), req('b')];

    test('nothing uploaded: not submitted', () {
      expect(overall(required, []), DocumentOverallStatus.notSubmitted);
      // An entry without any file is not an upload.
      expect(overall(required, [doc('a', front: '')]), DocumentOverallStatus.notSubmitted);
    });

    test('some uploaded, waiting for review: pending', () {
      expect(overall(required, [doc('a')]), DocumentOverallStatus.pending);
      expect(overall(required, [doc('a'), doc('b')]), DocumentOverallStatus.pending);
    });

    test('some approved, one still missing: pending (never verified)', () {
      expect(overall(required, [doc('a', status: 'approved')]), DocumentOverallStatus.pending);
    });

    test('every required document approved: verified', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'approved', expiry: future)]), DocumentOverallStatus.verified);
    });

    test('any required document rejected: action required, even when the others are approved', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'rejected')]), DocumentOverallStatus.actionRequired);
      // A rejection counts without a file too.
      expect(overall(required, [doc('a', status: 'rejected', front: '')]), DocumentOverallStatus.actionRequired);
    });

    test('an expired (once approved) required document: action required', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'approved', expiry: past)]), DocumentOverallStatus.actionRequired);
    });

    test('rejected beats pending', () {
      expect(overall(required, [doc('a'), doc('b', status: 'rejected')]), DocumentOverallStatus.actionRequired);
    });

    test('a resubmitted document (uploaded again, or an admin "resubmitted" status) is pending', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'uploaded')]), DocumentOverallStatus.pending);
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'resubmitted')]), DocumentOverallStatus.pending);
    });

    test('entries of documents that are not required are ignored', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'approved'), doc('old', status: 'rejected')]), DocumentOverallStatus.verified);
    });

    test('isDocumentVerify does not decide: flag true with a rejected / expired / pending document is NOT verified', () {
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'rejected')], flag: true), DocumentOverallStatus.actionRequired);
      expect(overall(required, [doc('a', status: 'approved'), doc('b', status: 'approved', expiry: past)], flag: true), DocumentOverallStatus.actionRequired);
      expect(overall(required, [doc('a', status: 'approved'), doc('b')], flag: true), DocumentOverallStatus.pending);
      expect(overall(required, [], flag: true), DocumentOverallStatus.notSubmitted);
      final view = DriverDocumentsView.of(user: companyDriver(verified: true), required: required, record: {
        'type': 'driver',
        'documents': [doc('a', status: 'approved').toJson(), doc('b', status: 'rejected').toJson()],
      });
      expect(view.overall, DocumentOverallStatus.actionRequired);
    });

    test('nothing required at all: only then the stored flag says', () {
      expect(overall([], [doc('a')], flag: true), DocumentOverallStatus.verified);
      expect(overall([], [doc('a')], flag: false), DocumentOverallStatus.notSubmitted);
    });

    test('per-entry status', () {
      expect(DriverDocumentStatus.entryStatus(null), 'not_submitted');
      expect(DriverDocumentStatus.entryStatus(doc('a')), 'pending');
      expect(DriverDocumentStatus.entryStatus(doc('a', status: 'approved')), 'approved');
      expect(DriverDocumentStatus.entryStatus(doc('a', status: 'approved', expiry: past)), 'expired');
      expect(DriverDocumentStatus.entryStatus(doc('a', status: 'rejected', front: '')), 'rejected');
    });

    test('counts per status (owner list)', () {
      final counts = DriverDocumentStatus.counts([DocumentOverallStatus.pending, DocumentOverallStatus.pending, DocumentOverallStatus.verified]);
      expect(counts[DocumentOverallStatus.pending], 2);
      expect(counts[DocumentOverallStatus.verified], 1);
      expect(counts[DocumentOverallStatus.actionRequired], 0);
      expect(counts[DocumentOverallStatus.notSubmitted], 0);
    });
  });

  group('vehicle documents for cab / rental drivers', () {
    final all = [req('lic'), req('car', type: 'vehicle'), req('w', type: 'worker'), req('o', type: 'owner'), req('off', enable: false)];

    test('required = enabled driver + vehicle documents; never worker / owner / disabled ones', () {
      final cab = DriverDocumentStatus.requiredOf(all, FireStoreUtils.documentTypesFor(companyDriver(services: ['cab-service'])));
      expect(cab.map((d) => d.id), ['lic', 'car']);
      final rental = DriverDocumentStatus.requiredOf(all, FireStoreUtils.documentTypesFor(companyDriver(services: ['rental-service'])));
      expect(rental.map((d) => d.id), ['lic', 'car']);
      final delivery = DriverDocumentStatus.requiredOf(all, FireStoreUtils.documentTypesFor(companyDriver(services: ['delivery-service'])));
      expect(delivery.map((d) => d.id), ['lic']);
    });

    test('a cab driver with only the driver document approved is pending; with the vehicle one too, verified', () {
      final cab = DriverDocumentStatus.requiredOf(all, ['driver', 'vehicle']);
      expect(overall(cab, [doc('lic', status: 'approved')]), DocumentOverallStatus.pending);
      expect(overall(cab, [doc('lic', status: 'approved'), doc('car', status: 'rejected')]), DocumentOverallStatus.actionRequired);
      expect(overall(cab, [doc('lic', status: 'approved'), doc('car', status: 'approved')]), DocumentOverallStatus.verified);
    });
  });

  group('driver submits / resubmits', () {
    final required = [req('a'), req('b')];

    Map<String, dynamic> record(List<Documents> docs, {String? type = 'driver'}) => {
          'id': 'd1',
          'type': ?type,
          'documents': docs.map((d) => d.toJson()).toList(),
        };

    test('a resubmission returns to "uploaded": never approved, reason and reviewer cleared, extra fields and position kept', () {
      final rec = record([
        doc('a', status: 'approved'),
        doc('b', status: 'rejected', extra: {'rejectReason': 'blurry', 'reviewedBy': 'owner1', 'reviewedAt': 'yesterday', 'adminNote': 'keep'}),
      ]);
      final Documents again = doc('b', status: 'approved', front: 'https://img/new.jpg');
      final plan = DriverDocumentStatus.submit(record: rec, entry: again, recordType: 'driver', required: required, currentFlag: false, companyDriver: true);
      expect(plan.refused, isFalse);
      expect(plan.documents.map((d) => d.documentId), ['a', 'b']);
      final json = plan.documents[1].toJson();
      expect(json['status'], 'uploaded');
      expect(json['frontImage'], 'https://img/new.jpg');
      for (final k in const ['rejectReason', 'rejectionReason', 'reason', 'reviewedBy', 'reviewedAt']) {
        expect(json.containsKey(k), isFalse, reason: k);
      }
      expect(json['adminNote'], 'keep');
      expect(plan.overall, DocumentOverallStatus.pending);
    });

    test('verified company driver resubmits: flag lowered to false in the same write', () {
      final rec = record([doc('a', status: 'approved'), doc('b', status: 'approved', expiry: past)]);
      final plan = DriverDocumentStatus.submit(record: rec, entry: doc('b', expiry: future), recordType: 'driver', required: required, currentFlag: true, companyDriver: true);
      expect(plan.overall, DocumentOverallStatus.pending);
      expect(plan.setVerified, isFalse);
    });

    test('flag already false: left as it is; the driver never raises it', () {
      final rec = record([doc('a', status: 'approved')]);
      final plan = DriverDocumentStatus.submit(record: rec, entry: doc('b'), recordType: 'driver', required: required, currentFlag: false, companyDriver: true);
      expect(plan.setVerified, isNull);
      for (final s in DocumentOverallStatus.values) {
        for (final flag in [true, false]) {
          expect(DriverDocumentStatus.flagAfterSubmit(companyDriver: true, currentFlag: flag, after: s), isNot(true));
        }
      }
    });

    test('a platform driver: the flag stays the administrator\'s', () {
      final plan = DriverDocumentStatus.submit(record: record([]), entry: doc('a'), recordType: 'driver', required: required, currentFlag: true, companyDriver: false);
      expect(plan.setVerified, isNull);
    });

    test('a document that is not required keeps a verified driver verified', () {
      final rec = record([doc('a', status: 'approved'), doc('b', status: 'approved')]);
      final plan = DriverDocumentStatus.submit(record: rec, entry: doc('extra'), recordType: 'driver', required: required, currentFlag: true, companyDriver: true);
      expect(plan.overall, DocumentOverallStatus.verified);
      expect(plan.setVerified, isNull);
      expect(plan.documents.map((d) => d.documentId), ['a', 'b', 'extra']);
    });

    test('required list unreadable: the upload counts as required, the flag is lowered', () {
      final rec = record([doc('a', status: 'approved')]);
      final plan = DriverDocumentStatus.submit(record: rec, entry: doc('a'), recordType: 'driver', required: null, currentFlag: true, companyDriver: true);
      expect(plan.setVerified, isFalse);
    });

    test('first upload: a new record entry', () {
      final plan = DriverDocumentStatus.submit(record: null, entry: doc('a'), recordType: 'driver', required: required, currentFlag: false, companyDriver: true);
      expect(plan.documents.single.status, 'uploaded');
      expect(plan.overall, DocumentOverallStatus.pending);
    });

    test('another holder\'s record (worker / owner / provider) is refused, never overwritten', () {
      for (final type in ['worker', 'owner', 'provider', 'vendor']) {
        final plan = DriverDocumentStatus.submit(record: record([doc('w1')], type: type), entry: doc('a'), recordType: 'driver', required: required, currentFlag: true, companyDriver: true);
        expect(plan.refused, isTrue, reason: type);
        expect(plan.documents, isEmpty);
      }
      // A legacy record without a type is the driver's.
      expect(DriverDocumentStatus.submit(record: record([doc('a')], type: null), entry: doc('b'), recordType: 'driver', required: required, currentFlag: false, companyDriver: true).refused, isFalse);
    });
  });

  group('owner review sync', () {
    test('isDocumentVerify after a review == overall is verified; nothing required: untouched', () {
      final required = [req('a'), req('b')];
      expect(DriverDocumentStatus.flagAfterReview(required: required, docs: [doc('a', status: 'approved'), doc('b', status: 'approved')]), isTrue);
      expect(DriverDocumentStatus.flagAfterReview(required: required, docs: [doc('a', status: 'approved'), doc('b')]), isFalse);
      expect(DriverDocumentStatus.flagAfterReview(required: required, docs: [doc('a', status: 'approved'), doc('b', status: 'rejected')]), isFalse);
      expect(DriverDocumentStatus.flagAfterReview(required: const [], docs: [doc('a')]), isNull);
    });
  });

  group('record type separation', () {
    test('drivers file "driver", a company "owner"', () {
      expect(DocumentRecordType.forUser(companyDriver()), 'driver');
      expect(DocumentRecordType.forUser(platformDriver()), 'driver');
      expect(DocumentRecordType.forUser(UserModel(id: 'o', isOwner: true)), 'owner');
      expect(FireStoreUtils.documentHolderType(companyDriver()), 'driver');
    });

    test('which stored record belongs to whom', () {
      expect(DocumentRecordType.belongsTo('driver', 'driver'), isTrue);
      expect(DocumentRecordType.belongsTo(null, 'driver'), isTrue);
      expect(DocumentRecordType.belongsTo('', 'driver'), isTrue);
      expect(DocumentRecordType.belongsTo('worker', 'driver'), isFalse);
      expect(DocumentRecordType.belongsTo('owner', 'driver'), isFalse);
      expect(DocumentRecordType.belongsTo('provider', 'driver'), isFalse);
      expect(DocumentRecordType.belongsTo('worker', 'owner'), isFalse);
      // A company's record was filed as "driver" before.
      expect(DocumentRecordType.belongsTo('driver', 'owner'), isTrue);
    });

    test('a worker record is never read as a driver\'s documents', () {
      final view = DriverDocumentsView.of(user: companyDriver(), required: [req('a')], record: {
        'type': 'worker',
        'documents': [doc('a', status: 'approved').toJson()],
      });
      expect(view.foreignRecord, isTrue);
      expect(view.docs, isEmpty);
      expect(view.overall, DocumentOverallStatus.notSubmitted);
    });
  });

  group('display labels', () {
    test('document types: driver and vehicle, never worker', () {
      expect(DocumentTypeLabel.of('driver'), 'Driver');
      expect(DocumentTypeLabel.of('vehicle'), 'Vehicle');
      expect(DocumentTypeLabel.of('worker'), isNot('Worker'));
      expect(DocumentTypeLabel.of(null), 'Driver');
    });

    test('statuses: keys for the panel, labels for the screens', () {
      expect(DocumentOverallStatus.values.map((s) => s.key), ['not_submitted', 'pending', 'action_required', 'verified']);
      expect(DocumentOverallStatus.values.map((s) => s.label), ['Not submitted', 'Pending', 'Action required', 'Verified']);
      expect(DocumentOverallStatus.fromKey('action_required'), DocumentOverallStatus.actionRequired);
      expect(DocumentOverallStatus.fromKey('nope'), isNull);
      expect(['approved', 'rejected', 'expired', 'pending', 'not_submitted'].map(DocumentEntryStatus.label), ['Approved', 'Rejected', 'Expired', 'Pending review', 'Not submitted']);
    });

    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    final labels = <String>{
      ...DocumentOverallStatus.values.map((s) => s.label),
      ...['approved', 'rejected', 'expired', 'pending', 'not_submitted'].map(DocumentEntryStatus.label),
      DocumentTypeLabel.of('driver'),
      DocumentTypeLabel.of('vehicle'),
      DocumentTypeLabel.of('owner'),
      'Front Side',
      'Back Side',
      'No image',
      'Close',
      'Verification status',
      'A document was rejected or has expired. Upload it again to be verified.',
      'Re-upload',
      'Not loaded',
      'These documents belong to another account type and cannot be reviewed here.',
      'One of your documents was rejected or has expired. Please upload it again to go online.',
      'No company drivers in this category.',
      'Fleet Verification Overview',
      'Company Drivers',
      'Review Documents',
      'Driver Document Verification',
      'Refresh',
      'Expired on',
      'Expires on',
      'Driver Documents',
      'Document Verification Checklist',
      'Rejection reason: @reason',
    };
    for (final entry in maps.entries) {
      test('${entry.key}: every label translated', () {
        for (final k in labels) {
          expect(entry.value.containsKey(k), isTrue, reason: k);
          expect(entry.value[k]!.trim(), isNotEmpty, reason: k);
        }
      });
    }
  });

  group('jobs gate for company drivers uses the computed status', () {
    test('flag true but a required document rejected / pending: blocked', () {
      final d = companyDriver(verified: true);
      expect(DocumentVerification.isPending(d, overall: DocumentOverallStatus.actionRequired), isTrue);
      expect(DocumentVerification.isPending(d, overall: DocumentOverallStatus.pending), isTrue);
      expect(CarrierParcelRules.canTakeAssignment(d, overall: DocumentOverallStatus.actionRequired), isFalse);
      DocumentStatusCache.put('d1', DocumentOverallStatus.actionRequired);
      expect(DocumentVerification.isPending(d), isTrue);
      expect(CarrierParcelRules.canTakeAssignment(d), isFalse);
      expect(DocumentVerification.showsVerified(d), isFalse);
    });

    test('computed verified: may work', () {
      final d = companyDriver(verified: true);
      expect(DocumentVerification.isPending(d, overall: DocumentOverallStatus.verified), isFalse);
      DocumentStatusCache.put('d1', DocumentOverallStatus.verified);
      expect(CarrierParcelRules.canTakeAssignment(d), isTrue);
      expect(DocumentVerification.showsVerified(d), isTrue);
    });

    test('nothing computed yet: the flag decides', () {
      expect(DocumentVerification.isPending(companyDriver(verified: true)), isFalse);
      expect(DocumentVerification.isPending(companyDriver(verified: false)), isTrue);
    });

    test('verification off (auto-verified): never held back', () {
      expect(DocumentVerification.isPending(companyDriver(autoVerify: true), overall: DocumentOverallStatus.actionRequired), isFalse);
    });

    test('a platform driver keeps the administrator\'s flag', () {
      DocumentStatusCache.put('p1', DocumentOverallStatus.actionRequired);
      expect(DocumentVerification.isPending(platformDriver(verified: true), overall: DocumentOverallStatus.actionRequired), isFalse);
      expect(DocumentVerification.isPending(platformDriver(verified: false), overall: DocumentOverallStatus.verified), isTrue);
    });

    test('company driver detection', () {
      expect(DriverDocumentStatus.isCompanyDriver(companyDriver()), isTrue);
      expect(DriverDocumentStatus.isCompanyDriver(platformDriver()), isFalse);
      expect(DriverDocumentStatus.isCompanyDriver(UserModel(id: 'o', ownerId: 'o', isOwner: true)), isFalse);
      expect(DriverDocumentStatus.isCompanyDriver(null), isFalse);
    });
  });
}
