import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/company_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Doc 38 — company details on the users doc', () {
    test('companyAddress and zoneIds are read and written under the panel keys', () {
      final user = UserModel.fromJson({
        'id': 'c1',
        'role': 'driver',
        'isOwner': true,
        'driverType': 'company',
        'companyName': 'best company',
        'companyAddress': '12 Rue A, Douala',
        'commercialRegister': 'RC-1',
        'operatingLicence': 'OL-1',
        'uniqueIdNumber': 'UID-1',
        'commercialRegisterFile': 'https://x/rc.jpg',
        'zoneId': 'z1',
        'zoneIds': ['z1', 'z2'],
      });
      expect(user.companyAddress, '12 Rue A, Douala');
      expect(user.zoneIds, ['z1', 'z2']);
      final json = user.toJson();
      expect(json['companyAddress'], '12 Rue A, Douala');
      expect(json['zoneIds'], ['z1', 'z2']);
      expect(json['zoneId'], 'z1');
      for (final field in [...CompanyProfile.numberFields, 'companyName']) {
        expect(json[field], CompanyProfile.valueOf(user, field));
      }
    });

    test('a company is recognised by driverType, isOwner or the older isCompany flag', () {
      expect(UserModel.fromJson({'driverType': 'company'}).isCompany, isTrue);
      expect(UserModel.fromJson({'isOwner': true}).isCompany, isTrue);
      expect(UserModel.fromJson({'isCompany': true}).isCompany, isTrue);
      expect(UserModel.fromJson({'driverType': 'individual', 'isOwner': false}).isCompany, isFalse);
      expect(UserModel.fromJson({'isCompany': true}).toJson().containsKey('isCompany'), isFalse);
    });

    test('an absent address / zone list is not written (no clearing)', () {
      final json = UserModel(id: 'd', role: 'driver').toJson();
      expect(json.containsKey('companyAddress'), isFalse);
      expect(json.containsKey('zoneIds'), isFalse);
    });

    test('setValue trims and turns blank into null', () {
      final user = UserModel();
      CompanyProfile.setValue(user, 'companyAddress', '  Tsinga  ');
      expect(user.companyAddress, 'Tsinga');
      CompanyProfile.setValue(user, 'companyAddress', '   ');
      expect(user.companyAddress, isNull);
      CompanyProfile.setValue(user, 'uniqueIdNumberFile', 'https://x/u.png');
      expect(CompanyProfile.valueOf(user, 'uniqueIdNumberFile'), 'https://x/u.png');
    });

    test('missingFiles lists the documents not picked, in panel order', () {
      expect(CompanyProfile.missingFiles({}), CompanyProfile.fileFields);
      expect(CompanyProfile.missingFiles({'operatingLicenceFile': '/tmp/a.jpg', 'commercialRegisterFile': ' '}),
          ['commercialRegisterFile', 'uniqueIdNumberFile']);
      expect(
          CompanyProfile.missingFiles({
            'operatingLicenceFile': '/a.jpg',
            'commercialRegisterFile': '/b.jpg',
            'uniqueIdNumberFile': '/c.jpg',
          }),
          isEmpty);
    });

    group('opening a stored file', () {
      const String storage =
          'https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/driverDocument%2Fc1%2Fcompany%2FcommercialRegisterFile_x.jpg?alt=media&token=ab%2Bcd-12';

      test('the Storage URL is used exactly as stored — never encoded again', () {
        final Uri? uri = CompanyProfile.fileUri(storage);
        expect(uri, isNotNull);
        expect(uri.toString(), storage);
        expect(uri!.query, contains('token=ab%2Bcd-12'));
        expect(uri.toString(), isNot(contains('%252F')));
      });

      test('images are previewed, anything else is opened outside', () {
        expect(CompanyProfile.isImage(storage), isTrue);
        expect(CompanyProfile.isImage(storage.replaceFirst('.jpg', '.PNG')), isTrue);
        expect(CompanyProfile.isImage(storage.replaceFirst('.jpg', '.pdf')), isFalse);
        expect(CompanyProfile.isImage('https://x/o/file'), isFalse);
      });

      test('blank or non-http values cannot be opened', () {
        expect(CompanyProfile.fileUri(null), isNull);
        expect(CompanyProfile.fileUri('  '), isNull);
        expect(CompanyProfile.fileUri('/local/path.jpg'), isNull);
        expect(CompanyProfile.isImage('/local/path.jpg'), isFalse);
      });
    });
  });

  group('Doc 43 — a company serves several zones', () {
    final zones = [
      ZoneModel(id: 'z1', name: 'Tsinga', regionId: 'r1'),
      ZoneModel(id: 'z2', name: 'Bastos', regionId: 'r1'),
      ZoneModel(id: 'z3', name: 'Akwa', regionId: 'r2'),
      ZoneModel(id: 'z4', name: 'Everywhere'),
    ];

    test('normalize / primary: trimmed, de-duplicated, first kept as zoneId', () {
      expect(CompanyZones.normalize([' z2', 'z1', '', null, 'z2']), ['z2', 'z1']);
      expect(CompanyZones.primary(['z2', 'z1']), 'z2');
      expect(CompanyZones.primary(const []), isNull);
    });

    test('of: zoneIds, or the legacy zoneId of an older company', () {
      expect(CompanyZones.of(UserModel(zoneIds: ['z1', 'z3'], zoneId: 'z1')), ['z1', 'z3']);
      expect(CompanyZones.of(UserModel(zoneId: 'z2')), ['z2']);
      expect(CompanyZones.of(UserModel(zoneId: '')), isEmpty);
      expect(CompanyZones.of(null), isEmpty);
    });

    test('a driver gets one zone out of the company zones', () {
      final picked = CompanyZones.forDriverPicker(allZones: zones, companyZoneIds: ['z3', 'z1'], regionId: 'r1');
      expect(picked.map((z) => z.id), ['z1', 'z3']);
    });

    test('a company without zoneIds keeps the region rule', () {
      expect(CompanyZones.forDriverPicker(allZones: zones, companyZoneIds: const [], regionId: 'r1').map((z) => z.id), ['z1', 'z2', 'z4']);
      expect(CompanyZones.forDriverPicker(allZones: zones, companyZoneIds: const [], regionId: null).length, 4);
    });
  });

  group('Doc 43 — carrier pricing per region', () {
    final carrier = DeliveryCarrierModel(id: 'c', raw: {
      'regionIds': ['r1', 'r2'],
      'baseCharge': 500,
      'perKmCharge': 75,
      'regionPricing': {
        'r1': {'baseCharge': 500, 'perKmCharge': 75, 'perKgCharge': 200, 'minimumCharge': 1000},
        'r2': {'baseCharge': '900', 'perKmCharge': 120},
        'bad': 'not a map',
      },
    });

    test('regionPricing first, the flat field as the fallback', () {
      expect(carrier.chargeFor('r2', 'baseCharge'), 900);
      expect(carrier.chargeFor('r2', 'perKmCharge'), 120);
      expect(carrier.chargeFor('r2', 'minimumCharge'), isNull);
      expect(carrier.chargeFor('r2', 'perKgCharge'), isNull);
      expect(carrier.chargeFor('r9', 'baseCharge'), 500, reason: 'no entry for the region: flat price');
      expect(carrier.chargeFor(null, 'perKmCharge'), 75);
      expect(carrier.regionPricing.containsKey('bad'), isFalse);
      expect(carrier.pricedPerRegion, isTrue);
    });

    test('a carrier with no regionIds is priced flat, everywhere', () {
      final flat = DeliveryCarrierModel(id: 'f', raw: {'baseCharge': 300});
      expect(flat.pricedPerRegion, isFalse);
      expect(flat.chargeFor('r1', 'baseCharge'), 300);
    });

    test('the write touches only the changed regional prices; region 1 is mirrored flat', () {
      final update = carrier.regionPricingUpdate({
        'r2': {'baseCharge': 950, 'minimumCharge': null},
        'r1': {'perKmCharge': 80},
        'r9': {'baseCharge': 1}, // not served: dropped
      });
      expect(update.data['regionPricing'], {
        'r2': {'baseCharge': 950, 'minimumCharge': null},
        'r1': {'perKmCharge': 80},
      });
      expect(update.data['perKmCharge'], 80);
      expect(update.data.containsKey('baseCharge'), isFalse, reason: 'r2 is not the first region');
      expect(update.paths, containsAll([
        ['regionPricing', 'r2', 'baseCharge'],
        ['regionPricing', 'r2', 'minimumCharge'],
        ['regionPricing', 'r1', 'perKmCharge'],
        ['perKmCharge'],
      ]));
      expect(update.paths.length, 4);
    });

    test('non-charge fields never reach regionPricing', () {
      final update = carrier.regionPricingUpdate({
        'r1': {'maxWeight': 10},
      });
      expect(update.data, isEmpty);
      expect(update.paths, isEmpty);
    });
  });
}
