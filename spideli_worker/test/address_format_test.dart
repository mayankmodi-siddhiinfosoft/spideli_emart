import 'package:spideliworker/model/address_model.dart';
import 'package:spideliworker/utils/address_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 02#18 — "null" in addresses, with the web panels' rule
/// (spideliCleanAddressPart / spideliFormatAddress): whole segments only,
/// repeated fields dropped, '' when nothing is left.
void main() {
  test('the report example: before -> after', () {
    // "before" is what the old join displayed for address = "null",
    // locality = "18, null, Yaoundé, Région du Centre, null, Cameroun",
    // landmark = "null".
    final Map<String, dynamic> stored = <String, dynamic>{
      'address': 'null',
      'locality': '18, null, Yaoundé, Région du Centre, null, Cameroun',
      'landmark': 'null',
    };
    expect(formatAddressMap(stored), '18, Yaoundé, Région du Centre, Cameroun');
    expect(formatAddressParts(<Object?>['null', '18, null, Yaoundé, Région du Centre, null, Cameroun', 'null']), '18, Yaoundé, Région du Centre, Cameroun');
    expect(formatAddressText('null,18, null, Yaoundé, Région du Centre, null, Cameroun'), '18, Yaoundé, Région du Centre, Cameroun');
  });

  test('cleanAddressPart drops placeholder segments case-insensitively', () {
    expect(cleanAddressPart(null), '');
    expect(cleanAddressPart('   '), '');
    expect(cleanAddressPart('NULL, Undefined, nil, Nil'), '');
    expect(cleanAddressPart(' 123 Yaounde St ,null, Tsinga '), '123 Yaounde St, Tsinga');
    expect(cleanAddressPart(18), '18');
  });

  test('keeps words that merely contain "null"', () {
    expect(formatAddressParts(<Object?>['Nullarbor Road', 'Annullata Street']), 'Nullarbor Road, Annullata Street');
  });

  test('drops a field repeating an earlier one, case-insensitively', () {
    expect(formatAddressParts(<Object?>['Tsinga, Yaoundé', 'tsinga, YAOUNDÉ', 'Near the market']), 'Tsinga, Yaoundé, Near the market');
    expect(formatAddressParts(<Object?>['Tsinga, null, Yaoundé', 'Tsinga, Yaoundé']), 'Tsinga, Yaoundé');
  });

  test('never de-duplicates single segments across different fields', () {
    expect(formatAddressParts(<Object?>['Tsinga', '18, Tsinga, Yaoundé']), 'Tsinga, 18, Tsinga, Yaoundé');
  });

  test('empty when nothing is left', () {
    expect(formatAddressParts(<Object?>[null, ' ', 'null', 'undefined']), '');
    expect(formatAddressText(null), '');
    expect(formatAddressMap(null), '');
    expect(formatAddressMap(<String, dynamic>{'address': null, 'locality': 'null', 'landmark': ''}), '');
  });

  test('AddressModel.getFullAddress goes through the rule', () {
    expect(AddressModel(address: '123 Yaounde St', locality: 'null, Tsinga', landmark: '123 yaounde st').getFullAddress(), '123 Yaounde St, Tsinga');
    expect(AddressModel().getFullAddress(), '');
  });
}
