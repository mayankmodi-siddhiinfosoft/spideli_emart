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
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_sign_in.dart';
import 'package:driver/utils/login_validation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driver report (3 Oct): signing in with email and password could spin for
/// ever. These cover the pieces that decided it without a device.
void main() {
  group('UserModel.fromJson reads documents written by any app or the panel', () {
    test('a well-formed driver document is read as before', () {
      final UserModel user = UserModel.fromJson({
        'id': 'd1',
        'email': 'driver@example.com',
        'role': 'driver',
        'active': true,
        'isActive': false,
        'isDocumentVerify': true,
        'wallet_amount': 12.5,
        'rotation': 90,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
        'serviceTypes': ['delivery-service'],
        'sectionIds': ['s1'],
        'inProgressOrderID': ['o1'],
        'vendorID': 'v1',
      });
      expect(user.id, 'd1');
      expect(user.role, 'driver');
      expect(user.active, isTrue);
      expect(user.isActive, isFalse);
      expect(user.isDocumentVerify, isTrue);
      expect(user.walletAmount, 12.5);
      expect(user.rotation, 90);
      expect(user.createdAt, isA<Timestamp>());
      expect(user.serviceTypes, ['delivery-service']);
      expect(user.sectionIds, ['s1']);
      expect(user.inProgressOrderID, ['o1']);
      expect(user.vendorID, 'v1');
    });

    test('values of an unexpected type no longer throw', () {
      final UserModel user = UserModel.fromJson({
        'id': 'd2',
        'role': 'driver',
        'active': 'true',
        'isActive': 1,
        'isDocumentVerify': 'false',
        'wallet_amount': '40',
        'rotation': '15.5',
        'phoneNumber': 670000000,
        'createdAt': '2026-10-01T10:00:00Z',
        'subscriptionExpiryDate': 'not a date',
        'serviceTypes': ['cab-service', null, ''],
        'sectionNames': {'s1': 7},
        'serviceDetails': 'bad',
        'location': 'not a map',
        'shippingAddress': 'not a list',
        'inProgressOrderID': 'o1',
        'ordercabRequestData': 5,
        'isOwner': 'false',
      });
      expect(user.active, isTrue);
      expect(user.isActive, isTrue);
      expect(user.isDocumentVerify, isFalse);
      expect(user.walletAmount, 40);
      expect(user.rotation, 15.5);
      expect(user.phoneNumber, '670000000');
      expect(user.createdAt, isA<Timestamp>());
      expect(user.subscriptionExpiryDate, isNull);
      expect(user.serviceTypes, ['cab-service']);
      expect(user.sectionNames, {'s1': '7'});
      expect(user.location, isNull);
      expect(user.shippingAddress, isNull);
      expect(user.inProgressOrderID, isEmpty);
      expect(user.orderCabRequestData, isNull);
      expect(user.isOwner, isFalse);
    });

    test('legacy single-value fields still become lists', () {
      final UserModel user = UserModel.fromJson({'serviceType': 'parcel_delivery', 'sectionId': 'sec9'});
      expect(user.serviceTypes, ['parcel_delivery']);
      expect(user.sectionIds, ['sec9']);
    });

    test('an empty service list stays empty (the dashboard falls back to delivery)', () {
      final UserModel user = UserModel.fromJson({'serviceTypes': <String>[]});
      expect(user.serviceTypes, isEmpty);
      expect(user.serviceTypes?.firstOrNull, isNull);
    });

    test('missing fields keep their old defaults', () {
      final UserModel user = UserModel.fromJson({});
      expect(user.role, 'user');
      expect(user.walletAmount, 0);
      expect(user.isDocumentVerify, isFalse);
      expect(user.vendorID, '');
      expect(user.zoneId, '');
      expect(user.inProgressOrderID, isEmpty);
      expect(user.reviewsCount, '0');
    });
  });

  group('DriverSignIn.authErrorMessage', () {
    String message(String code) => DriverSignIn.authErrorMessage(FirebaseAuthException(code: code));

    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in ['invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'wrong-password', 'user-not-found']) {
        expect(message(code), 'Invalid email or password.', reason: code);
      }
    });

    test('every other code still produces a message', () {
      expect(message('invalid-email'), 'Please enter a valid email address.');
      expect(message('network-request-failed'), contains('internet'));
      expect(message('too-many-requests'), contains('Too many attempts'));
      expect(message('user-disabled'), 'This user is disable please contact to administrator');
      expect(message('something-new'), 'Something went wrong. Please try again.');
    });
  });

  group('LoginValidation.validate (before any request)', () {
    test('empty fields', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('  ', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('driver@example.com', ''), 'Please enter your password.');
    });

    test('email format', () {
      for (final email in ['driver', 'driver@', '@example.com', 'driver@example', 'dri ver@example.com']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
      expect(LoginValidation.validate('driver.one+x@example.co.in', 'secret1'), isNull);
    });
  });

  test('every login message is translated in every language', () {
    const keys = [
      LoginValidation.emailAndPasswordRequired,
      LoginValidation.emailRequired,
      LoginValidation.passwordRequired,
      LoginValidation.emailInvalid,
      LoginValidation.invalidCredentials,
      LoginValidation.tooManyAttempts,
      LoginValidation.noConnection,
      LoginValidation.accountDisabled,
      LoginValidation.genericError,
    ];
    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    for (final entry in maps.entries) {
      expect(keys.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
    }
  });
}
