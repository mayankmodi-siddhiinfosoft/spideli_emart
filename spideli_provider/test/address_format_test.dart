import 'package:spideliprovider/model/address_model.dart';
import 'package:spideliprovider/utils/address_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 02#18 — "null" in addresses, with the web panels' rule
/// (spideliFormatAddress): whole segments only, repeated fields dropped,
/// '' when nothing is left.
void main() {
  test('the panel example', () {
    expect(formatAddressParts(<Object?>['null', '18, null, Yaoundé, Région du Centre, null, Cameroun', 'null']), '18, Yaoundé, Région du Centre, Cameroun');
  });

  test('keeps words that merely contain "null"', () {
    expect(formatAddressParts(<Object?>['Nullarbor Road', 'Annullata Street']), 'Nullarbor Road, Annullata Street');
  });

  test('drops a field repeating an earlier one, case-insensitively', () {
    expect(formatAddressParts(<Object?>['Tsinga, Yaoundé', 'tsinga, YAOUNDÉ', 'Near the market']), 'Tsinga, Yaoundé, Near the market');
  });

  test('never de-duplicates single segments across different fields', () {
    expect(formatAddressParts(<Object?>['Tsinga', '18, Tsinga, Yaoundé']), 'Tsinga, 18, Tsinga, Yaoundé');
  });

  test('empty when nothing is left', () {
    expect(formatAddressParts(<Object?>[null, ' ', 'null', 'undefined']), '');
    expect(formatAddressText(null), '');
  });

  test('AddressModel.getFullAddress goes through the rule', () {
    expect(AddressModel(address: '123 Yaounde St', locality: 'null, Tsinga', landmark: '123 yaounde st').getFullAddress(), '123 Yaounde St, Tsinga');
  });

  test('the report before/after, as the old join rendered it', () {
    // address = null, locality = the stored string, landmark = null, joined
    // by the old hasOwnProperty guard into
    // "null,18, null, Yaoundé, Région du Centre, null, Cameroun null".
    expect(
      AddressModel(address: null, locality: '18, null, Yaoundé, Région du Centre, null, Cameroun', landmark: null).getFullAddress(),
      '18, Yaoundé, Région du Centre, Cameroun',
    );
  });

  test('cleanAddressPart mirrors spideliCleanAddressPart', () {
    expect(cleanAddressPart(null), '');
    expect(cleanAddressPart('   '), '');
    expect(cleanAddressPart('NULL, Undefined ,nil,'), '');
    expect(cleanAddressPart(' 18 ,null, Yaoundé '), '18, Yaoundé');
    expect(cleanAddressPart('Nullarbor Road, null'), 'Nullarbor Road');
    expect(cleanAddressPart(42), '42');
  });

  test('geocoder components: missing ones are left out of the stored string', () {
    expect(formatAddressParts(<Object?>['18', null, 'Yaoundé', 'Région du Centre', '', 'Cameroun']), '18, Yaoundé, Région du Centre, Cameroun');
  });
}
