import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/carrier_parcel_service.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel driver(String id, {bool? verified, bool? autoVerify = false, bool online = true, String name = 'D'}) => UserModel.fromJson({
      'id': id,
      'firstName': name,
      'lastName': id,
      'role': 'driver',
      'ownerId': 'owner1',
      'isOwner': false,
      'active': true,
      'isActive': online,
      if (verified != null) 'isDocumentVerify': verified,
      if (autoVerify != null) 'isAutoVerify': autoVerify,
    });

void main() {
  group('owner assignment: only verified company drivers', () {
    test('a driver whose documents are pending cannot take an assignment', () {
      // Registered with verification on (isAutoVerify false), not verified yet.
      expect(CarrierParcelRules.canTakeAssignment(driver('a', verified: false)), isFalse);
    });
    test('a verified driver can', () {
      expect(CarrierParcelRules.canTakeAssignment(driver('b', verified: true)), isTrue);
    });
    test('a driver registered while verification was off can', () {
      expect(CarrierParcelRules.canTakeAssignment(driver('c', verified: false, autoVerify: true)), isTrue);
    });
    test('no driver -> no', () {
      expect(CarrierParcelRules.canTakeAssignment(null), isFalse);
    });
    test('the assign sheet lists verified drivers first, then online, then by name', () {
      final list = CarrierParcelService.assignableDrivers([
        driver('p', verified: false, name: 'Ann'),
        driver('v2', verified: true, online: false, name: 'Bob'),
        driver('v1', verified: true, online: true, name: 'Cid'),
      ], 'owner1');
      expect(list.map((d) => d.id), ['v1', 'v2', 'p']);
    });
    test('the refusal has its own check value', () {
      expect(CarrierAssignCheck.values, contains(CarrierAssignCheck.driverNotVerified));
    });
  });

  group('why an owner assignment is refused', () {
    test('a message per overall document status', () {
      expect(CarrierParcelRules.notVerifiedMessageKey(DocumentOverallStatus.notSubmitted), contains('not uploaded the required documents'));
      expect(CarrierParcelRules.notVerifiedMessageKey(DocumentOverallStatus.pending), contains('missing or waiting for your review'));
      expect(CarrierParcelRules.notVerifiedMessageKey(DocumentOverallStatus.actionRequired), contains('rejected or has expired'));
      expect(CarrierParcelRules.notVerifiedMessageKey(null), contains('not verified yet'));
    });
    test('an unreadable required list has its own refusal', () {
      expect(CarrierAssignCheck.values, contains(CarrierAssignCheck.verificationUnavailable));
    });
  });
}
