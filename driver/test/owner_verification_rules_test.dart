import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/services/push_template_text.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel driver({String id = 'd1', String? ownerId = 'owner1', List<String>? services, bool? verified, bool? isOwner}) => UserModel.fromJson({
      'id': id,
      'firstName': 'Dan',
      'lastName': 'Driver',
      'role': 'driver',
      'ownerId': ?ownerId,
      'isOwner': ?isOwner,
      'serviceTypes': ?services,
      'isDocumentVerify': ?verified,
    });

DocumentModel req(String id) => DocumentModel(id: id, title: 'Title $id', enable: true, frontSide: true, type: 'driver');

Documents uploaded(String id, {String status = 'uploaded', DateTime? expiry, Map<String, dynamic>? extra}) => Documents.fromJson({
      'documentId': id,
      'status': status,
      'frontImage': 'https://img/$id.jpg',
      'backImage': '',
      if (expiry != null) 'expireAt': Timestamp.fromDate(expiry),
      ...?extra,
    });

void main() {
  group('required documents = what THIS driver must upload', () {
    test('a delivery / parcel driver: driver documents only', () {
      expect(FireStoreUtils.documentTypesFor(driver(services: ['delivery-service'])), ['driver']);
      expect(FireStoreUtils.documentTypesFor(driver(services: ['parcel_delivery'])), ['driver']);
      expect(FireStoreUtils.documentTypesFor(driver()), ['driver']);
    });
    test('a cab driver also provides vehicle documents', () {
      expect(FireStoreUtils.documentTypesFor(driver(services: ['cab-service'])), ['driver', 'vehicle']);
    });
    test('a rental driver also provides vehicle documents', () {
      expect(FireStoreUtils.documentTypesFor(driver(services: ['rental-service', 'delivery-service'])), ['driver', 'vehicle']);
    });
    test('an owner account provides owner documents', () {
      expect(FireStoreUtils.documentTypesFor(driver(isOwner: true, ownerId: null)), ['owner']);
    });
    test('null user: driver', () {
      expect(FireStoreUtils.documentTypesFor(null), ['driver']);
    });
  });

  group('owner guard: only the owner\'s own company drivers', () {
    test('own driver', () {
      expect(OwnerVerificationRules.isOwnersDriver(driver(), 'owner1'), isTrue);
    });
    test('another company\'s driver, a platform driver, the owner itself, no owner uid', () {
      expect(OwnerVerificationRules.isOwnersDriver(driver(ownerId: 'owner2'), 'owner1'), isFalse);
      expect(OwnerVerificationRules.isOwnersDriver(driver(ownerId: null), 'owner1'), isFalse);
      expect(OwnerVerificationRules.isOwnersDriver(driver(id: 'owner1', ownerId: 'owner1'), 'owner1'), isFalse);
      expect(OwnerVerificationRules.isOwnersDriver(driver(), ''), isFalse);
      expect(OwnerVerificationRules.isOwnersDriver(null, 'owner1'), isFalse);
    });
    test('raw users fields (the transaction re-check)', () {
      expect(OwnerVerificationRules.isOwnersDriverData('d1', 'owner1', 'owner1'), isTrue);
      expect(OwnerVerificationRules.isOwnersDriverData('d1', null, 'owner1'), isFalse);
      expect(OwnerVerificationRules.isOwnersDriverData('d1', 'owner2', 'owner1'), isFalse);
    });
  });

  group('approve one document', () {
    test('never sets isDocumentVerify to false (an admin\'s verification stays)', () {
      final docs = [uploaded('a'), uploaded('b')];
      final plan = OwnerVerificationRules.approveOne(required: [req('a'), req('b'), req('c')], docs: docs, documentId: 'a');
      expect(plan.outcome, OwnerVerificationOutcome.done);
      expect(plan.setVerified, isNull);
      expect(docs.first.status, 'approved');
      expect(plan.outstanding.map((d) => d.id), ['b', 'c']);
    });
    test('verifies only when it completes every required document', () {
      final docs = [uploaded('a', status: 'approved'), uploaded('b')];
      final plan = OwnerVerificationRules.approveOne(required: [req('a'), req('b')], docs: docs, documentId: 'b');
      expect(plan.setVerified, isTrue);
      expect(plan.outstanding, isEmpty);
    });
    test('across every state, approving yields true or untouched, never false', () {
      final List<List<Documents>> states = [
        [uploaded('a')],
        [uploaded('a'), uploaded('b', status: 'rejected')],
        [uploaded('a'), uploaded('b', expiry: DateTime(2000))],
        [uploaded('a'), uploaded('b', status: 'approved')],
      ];
      for (final docs in states) {
        final plan = OwnerVerificationRules.approveOne(required: [req('a'), req('b')], docs: docs, documentId: 'a');
        expect(plan.setVerified, isNot(false));
      }
    });
    test('a document that was not uploaded (or expired) cannot be approved', () {
      expect(OwnerVerificationRules.approveOne(required: [req('a')], docs: [], documentId: 'a').outcome, OwnerVerificationOutcome.notUploaded);
      final noImage = Documents.fromJson({'documentId': 'a', 'status': 'uploaded', 'frontImage': '', 'backImage': ''});
      expect(OwnerVerificationRules.approveOne(required: [req('a')], docs: [noImage], documentId: 'a').writes, isFalse);
      final expired = uploaded('a', expiry: DateTime(2000));
      expect(OwnerVerificationRules.approveOne(required: [req('a')], docs: [expired], documentId: 'a').writes, isFalse);
    });
    test('no required documents configured: never verifies', () {
      final plan = OwnerVerificationRules.approveOne(required: [], docs: [uploaded('a')], documentId: 'a');
      expect(plan.setVerified, isNull);
    });
    test('keeps other entries and their extra fields, clears the old rejection', () {
      final docs = [
        uploaded('a', status: 'rejected', extra: {'rejectReason': 'blurry', 'reviewedBy': 'admin'}),
        uploaded('x', extra: {'adminNote': 'keep me'}),
      ];
      final plan = OwnerVerificationRules.approveOne(required: [req('a')], docs: docs, documentId: 'a');
      final json = plan.documents.map((d) => d.toJson()).toList();
      expect(json, hasLength(2));
      expect(json[0]['status'], 'approved');
      expect(json[0].containsKey('rejectReason'), isFalse);
      expect(json[0]['reviewedBy'], 'admin');
      expect(json[1]['adminNote'], 'keep me');
    });
  });

  group('approve all', () {
    test('refuses missing uploads: approves what was uploaded, does not verify, names the missing ones', () {
      final docs = [uploaded('a')];
      final plan = OwnerVerificationRules.approveAll(required: [req('a'), req('b')], docs: docs);
      expect(plan.outcome, OwnerVerificationOutcome.incomplete);
      expect(plan.setVerified, isNull);
      expect(plan.approvedIds, ['a']);
      expect(plan.outstanding.map((d) => d.title), ['Title b']);
      // No entry is invented for the document that was never uploaded.
      expect(plan.documents.map((d) => d.documentId), ['a']);
    });
    test('verifies only when every required document is uploaded and approved', () {
      final docs = [uploaded('a'), uploaded('b', status: 'approved')];
      final plan = OwnerVerificationRules.approveAll(required: [req('a'), req('b')], docs: docs);
      expect(plan.outcome, OwnerVerificationOutcome.done);
      expect(plan.setVerified, isTrue);
      expect(plan.approvedIds, ['a']);
    });
    test('does not re-approve a rejected or expired document', () {
      final docs = [uploaded('a'), uploaded('b', status: 'rejected'), uploaded('c', expiry: DateTime(2000))];
      final plan = OwnerVerificationRules.approveAll(required: [req('a'), req('b'), req('c')], docs: docs);
      expect(plan.outcome, OwnerVerificationOutcome.incomplete);
      expect(plan.setVerified, isNull);
      expect(docs[1].status, 'rejected');
      expect(plan.outstanding.map((d) => d.id), ['b', 'c']);
    });
    test('nothing required: nothing to verify against', () {
      expect(OwnerVerificationRules.approveAll(required: [], docs: [uploaded('a')]).outcome, OwnerVerificationOutcome.noRequiredDocuments);
    });
  });

  group('reject', () {
    test('a rejected required document revokes verification and stores the reason', () {
      final docs = [uploaded('a', status: 'approved')];
      final plan = OwnerVerificationRules.reject(required: [req('a')], docs: docs, documentId: 'a', reason: '  blurry ');
      expect(plan.outcome, OwnerVerificationOutcome.done);
      expect(plan.setVerified, isFalse);
      expect(plan.documents.single.toJson()['rejectReason'], 'blurry');
      expect(plan.documents.single.status, 'rejected');
    });
    test('an entry that is not required leaves the flag untouched', () {
      final plan = OwnerVerificationRules.reject(required: [req('a')], docs: [uploaded('old')], documentId: 'old', reason: 'x');
      expect(plan.setVerified, isNull);
    });
    test('nothing uploaded or no reason: nothing written', () {
      expect(OwnerVerificationRules.reject(required: [req('a')], docs: [], documentId: 'a', reason: 'x').writes, isFalse);
      expect(OwnerVerificationRules.reject(required: [req('a')], docs: [uploaded('a')], documentId: 'a', reason: ' ').writes, isFalse);
    });
  });

  group('owner list category uses the per-driver required set', () {
    test('verified / rejected / pending / missing / not submitted', () {
      final required = [req('a'), req('b')];
      expect(OwnerVerificationRules.category(driver(verified: true), required, []), 'verified');
      expect(OwnerVerificationRules.category(driver(), required, [uploaded('a', status: 'rejected')]), 'rejected');
      expect(OwnerVerificationRules.category(driver(), required, [uploaded('a')]), 'pending');
      expect(OwnerVerificationRules.category(driver(), required, [uploaded('a', status: 'approved')]), 'missing');
      expect(OwnerVerificationRules.category(driver(), required, []), 'not_submitted');
      // An upload for a type this driver does not need does not count.
      expect(OwnerVerificationRules.category(driver(), required, [uploaded('vehicle1')]), 'not_submitted');
      expect(OwnerVerificationRules.uploadedCount(required, [uploaded('a'), uploaded('vehicle1')]), 1);
    });
  });

  group('templates', () {
    test('four templates, placeholders filled', () {
      expect(OwnerVerificationPush.templates, ['driver_document_approved', 'driver_documents_verified', 'driver_document_rejected', 'driver_document_submitted']);
      final values = OwnerVerificationPush.values(documentTitle: 'Driving licence', companyName: 'FastCarrier', reason: 'Blurred photo');
      expect(values, {'documentTitle': 'Driving licence', 'companyName': 'FastCarrier', 'reason': 'Blurred photo'});
      expect(PushTemplateText.fill('{companyName} rejected your {documentTitle}: {reason}', values), 'FastCarrier rejected your Driving licence: Blurred photo');
      final owner = OwnerVerificationPush.values(driverName: 'Dan Driver', documentTitle: 'ID card');
      expect(PushTemplateText.fill('{driverName} submitted {documentTitle}', owner), 'Dan Driver submitted ID card');
    });
    test('an empty value is left out (its placeholder stays visible)', () {
      final values = OwnerVerificationPush.values(documentTitle: ' ', companyName: 'C');
      expect(values.containsKey('documentTitle'), isFalse);
      expect(PushTemplateText.fill('{documentTitle} by {companyName}', values), '{documentTitle} by C');
    });
    test('pushes to the driver and the owner go on the general driver channel', () {
      for (final t in OwnerVerificationPush.templates) {
        expect(PushChannels.forRecipient(PushRecipient.driver, kind: t).androidChannelId, PushChannels.driver);
        expect(PushChannels.driverChannelFor(type: t), PushChannels.driver);
      }
      expect(PushChannels.driverChannelFor(type: OwnerVerificationPush.driverDataType), PushChannels.driver);
    });
    test('the notification record is unread and shaped like the others', () {
      final record = OwnerVerificationPush.record(id: 'n1', title: 'T', body: 'B', template: 'driver_document_approved', data: {'type': 'document_verification'}, createdAt: 0, status: 'approved');
      expect(record['read'], isFalse);
      expect(record.keys.toSet(), {'id', 'title', 'body', 'type', 'category', 'orderId', 'status', 'data', 'read', 'createdAt', 'source'});
      expect(record['id'], 'n1');
    });
  });

  group('tap route', () {
    test('owner: document submitted opens the review of that driver', () {
      expect(OwnerVerificationRules.tapRoute(type: 'driver_document_submitted', driverId: 'd1', isOwner: true), DocumentTapRoute.ownerReview);
      expect(OwnerVerificationRules.tapRoute(type: 'driver_document_submitted', driverId: '', isOwner: true), DocumentTapRoute.ownerList);
    });
    test('owner: the old document_verification push with a driverId also opens the review', () {
      expect(OwnerVerificationRules.tapRoute(type: 'document_verification', driverId: 'd1', isOwner: true), DocumentTapRoute.ownerReview);
    });
    test('driver: document_verification opens its own documents', () {
      expect(OwnerVerificationRules.tapRoute(type: 'document_verification', isOwner: false), DocumentTapRoute.ownDocuments);
      expect(OwnerVerificationRules.tapRoute(type: 'document_verification', driverId: 'd1', isOwner: false), DocumentTapRoute.ownDocuments);
      expect(OwnerVerificationRules.tapRoute(type: 'document_verification', isOwner: true), DocumentTapRoute.ownDocuments);
    });
    test('a driver never opens the owner review; other types are not routed here', () {
      expect(OwnerVerificationRules.tapRoute(type: 'driver_document_submitted', driverId: 'd1', isOwner: false), DocumentTapRoute.none);
      expect(OwnerVerificationRules.tapRoute(type: 'orderChat', isOwner: true), DocumentTapRoute.none);
    });
  });

  group('translations', () {
    const keys = <String>[
      'Driver not verified yet',
      'The uploaded documents were approved. These required documents are still missing or must be uploaded again: @documents',
      'This driver is not part of your company.',
      'This document has not been uploaded, or it has expired.',
      'No required driver documents found.',
      'Provide the reason for rejecting "@document" for @driver:',
      'Approve every uploaded document of @driver? Once all required documents are approved, the driver is verified to take deliveries.',
      'Approve the uploaded documents of @driver? These required documents are still missing or must be uploaded again, so the driver will not be verified yet: @documents',
      'The documents could not be loaded. Please try again.',
      'Required documents: @uploaded of @count uploaded',
      'Rejection reason: @reason',
      'Documents Missing',
      'Retry',
      'Approve All',
    ];
    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    final placeholder = RegExp(r'@[a-z]+');
    for (final entry in maps.entries) {
      test('${entry.key}: every label translated, placeholders kept', () {
        for (final k in keys) {
          expect(entry.value.containsKey(k), isTrue, reason: k);
          final want = placeholder.allMatches(k).map((m) => m.group(0)).toList()..sort();
          final got = placeholder.allMatches(entry.value[k]!).map((m) => m.group(0)).toList()..sort();
          expect(got, want, reason: k);
        }
      });
    }
  });
}
