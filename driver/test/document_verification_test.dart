import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report Doc 37: `isDocumentVerify` is set only by the administrator.
void main() {
  setUp(() {
    Constant.isDriverVerification = null;
    Constant.isOwnerVerification = null;
  });

  group('a new account is never verified by the app', () {
    test('verification on: not verified, documents checked', () {
      final driver = DocumentVerification.initialFlags(isCompany: false, driverSetting: true);
      expect(driver.isDocumentVerify, isFalse);
      expect(driver.isAutoVerify, isFalse);
      final company = DocumentVerification.initialFlags(isCompany: true, ownerSetting: true);
      expect(company.isDocumentVerify, isFalse);
      expect(company.isAutoVerify, isFalse);
    });

    test('verification off: still not verified, but auto-verified', () {
      // This is the case that used to write `isDocumentVerify: true`.
      final driver = DocumentVerification.initialFlags(isCompany: false, driverSetting: false);
      expect(driver.isDocumentVerify, isFalse);
      expect(driver.isAutoVerify, isTrue);
      final company = DocumentVerification.initialFlags(isCompany: true, ownerSetting: false);
      expect(company.isDocumentVerify, isFalse);
      expect(company.isAutoVerify, isTrue);
    });

    test('settings not loaded: documents are asked for', () {
      final flags = DocumentVerification.initialFlags(isCompany: false);
      expect(flags.isDocumentVerify, isFalse);
      expect(flags.isAutoVerify, isFalse);
    });

    test('a company uses the owner setting, a driver the driver setting', () {
      Constant.isDriverVerification = true;
      Constant.isOwnerVerification = false;
      expect(DocumentVerification.initialFlags(isCompany: true).isAutoVerify, isTrue);
      expect(DocumentVerification.initialFlags(isCompany: false).isAutoVerify, isFalse);
    });
  });

  group('isPending (every gate in the app)', () {
    UserModel user({bool? verified, bool? auto, bool owner = false}) =>
        UserModel(id: 'u', isDocumentVerify: verified, isAutoVerify: auto, isOwner: owner);

    test('waiting for the admin', () {
      expect(DocumentVerification.isPending(user(verified: false, auto: false)), isTrue);
    });

    test("a store's own delivery man is never held back (created unverified)", () {
      final UserModel storeDriver = UserModel(id: 'u', isDocumentVerify: false, isAutoVerify: false, vendorID: 'store1');
      expect(DocumentVerification.isPending(storeDriver), isFalse);
      // The expired / rejected check on going online still applies.
      expect(DocumentVerification.checksDocuments(storeDriver), isTrue);
      expect(DocumentVerification.isPending(UserModel(id: 'u', isDocumentVerify: false, isAutoVerify: false, vendorID: '')), isTrue);
    });

    test('approved by the admin', () {
      expect(DocumentVerification.isPending(user(verified: true, auto: false)), isFalse);
    });

    test('auto-verified (verification was off at registration)', () {
      expect(DocumentVerification.isPending(user(verified: false, auto: true)), isFalse);
    });

    test('verification switched OFF in the panel since: released', () {
      Constant.isDriverVerification = false;
      expect(DocumentVerification.isPending(user(verified: false, auto: false)), isFalse);
      expect(DocumentVerification.checksDocuments(user(verified: false, auto: false)), isFalse);
      Constant.isOwnerVerification = false;
      expect(DocumentVerification.isPending(user(verified: false, auto: false, owner: true)), isFalse);
    });

    test('verification on in the panel: the stored flags decide', () {
      Constant.isDriverVerification = true;
      expect(DocumentVerification.isPending(user(verified: false, auto: false)), isTrue);
      expect(DocumentVerification.checksDocuments(user(verified: true, auto: false)), isTrue);
    });

    test('the owner setting does not release a driver, nor the reverse', () {
      Constant.isOwnerVerification = false;
      expect(DocumentVerification.isPending(user(verified: false, auto: false)), isTrue);
      Constant.isOwnerVerification = true;
      Constant.isDriverVerification = false;
      expect(DocumentVerification.isPending(user(verified: false, auto: false, owner: true)), isTrue);
    });

    test('no stored isAutoVerify (older records): never blocked, as before', () {
      expect(DocumentVerification.isPending(user(verified: false)), isFalse);
      expect(DocumentVerification.isPending(null), isFalse);
    });
  });

  group('documents_verify holder type (report §3 02#26)', () {
    test('a company files its documents as an owner', () {
      expect(FireStoreUtils.documentHolderType(UserModel(isOwner: true, driverType: 'company')), 'owner');
      expect(FireStoreUtils.documentHolderType(UserModel(isOwner: false)), 'driver');
      expect(FireStoreUtils.documentHolderType(null), 'driver');
    });
  });
}
