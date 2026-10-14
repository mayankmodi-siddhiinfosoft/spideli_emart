import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_kyc_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The KYC writes the customer app makes itself
/// (.claude/FINANCE-DIRECT-FIRESTORE.md 3.1): every batch as data.
void main() {
  final settings = KycSettings.parse({
    'documentTypes': {
      'national_id': {
        'sides': ['front', 'back'],
      },
      'passport': {
        'sides': ['front'],
      },
      'selfie': {
        'sides': ['front'],
      },
      'business_registration': {
        'sides': ['front'],
      },
    },
    'levels': {
      'basic': {
        'accountTypes': ['individual'],
        'requiredDocuments': [
          {
            'anyOf': ['national_id', 'passport'],
          },
          {
            'anyOf': ['selfie'],
          },
        ],
      },
      'business': {
        'accountTypes': ['business'],
        'requiredDocuments': [
          {
            'anyOf': ['business_registration'],
          },
        ],
      },
    },
    'allowedContentTypes': ['image/jpeg'],
    'maxFileBytes': 1000,
  })!;

  FinanceWrite one(List<FinanceWrite> ws, String path) => ws.singleWhere((w) => w.path == path);

  group('the status shown is the latest application\'s', () {
    test('newest createdAt wins; one being created (no server time yet) is the newest', () {
      expect(KycWrites.latestStatus(const []), isNull);
      final old = {'status': 'rejected', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1))};
      final recent = {'status': 'under_review', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1))};
      expect(KycWrites.latestStatus([old, recent]), 'under_review');
      expect(KycWrites.latestStatus([recent, old]), 'under_review');
      expect(KycWrites.latestStatus([recent, old, {'status': 'draft', 'createdAt': null}]), 'draft');
    });
  });

  group('start', () {
    test('one open application at a time; an approved level is not started again', () {
      expect(KycWrites.createBlocker(const [], settings, 'basic', 'individual'), isNull);
      expect(KycWrites.createBlocker([{'status': 'submitted', 'level': 'basic'}], settings, 'business', 'business'), 'kyc_application_open');
      expect(KycWrites.createBlocker([{'status': 'approved', 'level': 'basic'}], settings, 'basic', 'individual'), 'kyc_level_approved');
      expect(KycWrites.createBlocker([{'status': 'rejected', 'level': 'basic'}], settings, 'basic', 'individual'), isNull);
      expect(KycWrites.createBlocker(const [], settings, 'basic', 'business'), 'kyc_not_configured', reason: 'a level is offered to its account types only');
      expect(KycWrites.createBlocker(const [], settings, 'gold', 'individual'), 'kyc_not_configured');
    });

    test('a draft, revision 1, owned by the user', () {
      final ws = KycWrites.create(applicationId: 'a1', uid: 'u1', level: 'basic', accountType: 'individual');
      expect(ws.length, 1);
      final w = ws.single;
      expect(w.path, 'kyc_applications/a1');
      expect(w.op, 'create');
      expect(w.data['userId'], 'u1');
      expect(w.data['status'], 'draft');
      expect(w.data['revision'], 1);
      expect(w.data['reason'], isNull);
      expect(w.data.containsKey('business'), isFalse);
      expect(w.data['createdAt'], FieldValue.serverTimestamp());
      expect(KycWrites.create(applicationId: 'a2', uid: 'u1', level: 'business', accountType: 'business').single.data['business'], isEmpty);
    });
  });

  test('details: only the known fields, trimmed and capped; each group replaces the stored one', () {
    final w = KycWrites.updateDetails(
      applicationId: 'a1',
      personal: {'fullName': '  Awa Diop ', 'city': '', 'kycLevel': 'full', 'address': 'x' * 300},
    ).single;
    expect(w.op, 'update');
    expect(w.data['personal'], {'fullName': 'Awa Diop', 'address': 'x' * KycWrites.maxFieldLength});
    expect(w.data.containsKey('business'), isFalse);
    expect(w.data.containsKey('status'), isFalse, reason: 'the status is never part of the details');
  });

  group('documents', () {
    test('the upload path and record id are new each time', () {
      expect(KycWrites.storagePath('u1', 'a1', 'passport', 'front', 42), 'kyc/u1/a1/passport-front-42.jpg');
      expect(KycWrites.documentId('a1', 'passport', 'front', 42), 'a1_passport_front_42');
    });

    test('a new upload supersedes every earlier live one of the same type and side', () {
      final docs = [
        {'id': 'd1', 'type': 'passport', 'side': 'front', 'status': 'uploaded'},
        {'id': 'd2', 'type': 'passport', 'side': 'front', 'status': 'rejected'},
        {'id': 'd3', 'type': 'passport', 'side': 'front', 'status': 'superseded'},
        {'id': 'd4', 'type': 'national_id', 'side': 'front', 'status': 'uploaded'},
      ];
      final older = KycWrites.toSupersede(docs, 'passport', 'front', except: 'd9');
      expect(older, ['d1', 'd2']);
      final ws = KycWrites.registerDocument(
        documentId: 'd9',
        applicationId: 'a1',
        uid: 'u1',
        type: 'passport',
        side: 'front',
        storagePath: 'kyc/u1/a1/passport-front-42.jpg',
        contentType: 'image/jpeg',
        size: 900,
        revision: 2,
        supersede: older,
      );
      final created = one(ws, 'kyc_documents/d9');
      expect(created.op, 'create');
      expect(created.data['status'], 'uploaded');
      expect(created.data['userId'], 'u1');
      expect(created.data['storagePath'], 'kyc/u1/a1/passport-front-42.jpg');
      for (final id in ['d1', 'd2']) {
        final w = one(ws, 'kyc_documents/$id');
        expect(w.op, 'update');
        expect(w.data['status'], 'superseded');
        expect(w.data['supersededBy'], 'd9');
      }
      expect(ws.length, 3);
    });
  });

  group('submit and start again', () {
    Map<String, dynamic> app({String status = 'draft', String name = 'Awa', String type = 'individual', Map<String, dynamic>? business}) => {
          'id': 'a1',
          'status': status,
          'level': type == 'business' ? 'business' : 'basic',
          'accountType': type,
          'personal': {'fullName': name},
          'business': ?business,
        };
    const docs = [KycDocumentRef('passport', 'front', 'uploaded'), KycDocumentRef('selfie', 'front', 'accepted')];

    test('details, documents and an editable status are needed', () {
      expect(KycWrites.submitBlocker(app(), settings, docs), isNull);
      expect(KycWrites.submitBlocker(app(status: 'additional_info_required'), settings, docs), isNull);
      expect(KycWrites.submitBlocker(app(status: 'submitted'), settings, docs), 'kyc_invalid_transition');
      expect(KycWrites.submitBlocker(app(name: ' '), settings, docs), 'kyc_personal_details_missing');
      expect(KycWrites.submitBlocker(app(), settings, const [KycDocumentRef('passport', 'front', 'uploaded')]), 'kyc_documents_missing');
      expect(KycWrites.submitBlocker(app(), settings, const [KycDocumentRef('national_id', 'front', 'uploaded'), KycDocumentRef('selfie', 'front', 'uploaded')]),
          'kyc_documents_missing',
          reason: 'both sides of a national id');
      expect(KycWrites.submitBlocker(app(type: 'business', business: {'companyName': 'SARL'}), settings, const [KycDocumentRef('business_registration', 'front', 'uploaded')]),
          'kyc_business_details_missing');
      expect(
          KycWrites.submitBlocker(app(type: 'business', business: {'companyName': 'SARL', 'registrationNumber': 'RC1'}), settings, const [KycDocumentRef('business_registration', 'front', 'uploaded')]),
          isNull);
    });

    test('submit: submitted with its time, and a "submit" history entry', () {
      final ws = KycWrites.submit(applicationId: 'a1', uid: 'u1', reviewId: 'r1', revision: 1);
      final a = one(ws, 'kyc_applications/a1');
      expect(a.op, 'update');
      expect(a.data['status'], 'submitted');
      expect(a.data['submittedAt'], FieldValue.serverTimestamp());
      final r = one(ws, 'kyc_reviews/r1');
      expect(r.op, 'create');
      expect(r.data, containsPair('action', 'submit'));
      expect(r.data, containsPair('userId', 'u1'));
      expect(r.data, containsPair('applicationId', 'a1'));
    });

    test('reopen: draft again, the next revision, no reason, and a "reopen" entry', () {
      final ws = KycWrites.reopen(applicationId: 'a1', uid: 'u1', reviewId: 'r2', revision: 2);
      final a = one(ws, 'kyc_applications/a1');
      expect(a.data['status'], 'draft');
      expect(a.data['revision'], 3);
      expect(a.data.containsKey('reason'), isTrue);
      expect(a.data['reason'], isNull);
      expect(one(ws, 'kyc_reviews/r2').data['action'], 'reopen');
    });
  });

  test('no KYC write touches users/{uid} (kycStatus and kycLevel are the admin\'s)', () {
    final all = [
      ...KycWrites.create(applicationId: 'a', uid: 'u', level: 'basic', accountType: 'individual'),
      ...KycWrites.updateDetails(applicationId: 'a', personal: {'fullName': 'A'}),
      ...KycWrites.submit(applicationId: 'a', uid: 'u', reviewId: 'r', revision: 1),
      ...KycWrites.reopen(applicationId: 'a', uid: 'u', reviewId: 'r', revision: 1),
    ];
    expect(all.where((w) => w.path.startsWith('users/')), isEmpty);
    expect(all.expand((w) => w.data.keys).where((k) => k == 'kycLevel' || k == 'kycStatus'), isEmpty);
  });
}
