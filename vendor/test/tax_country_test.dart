import 'package:vendor/utils/tax_country.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doc 61: taxes are saved with the English country name; the device may
/// geocode in another language ("Cameroun").
void main() {
  group('englishName', () {
    test('by ISO code, any case', () {
      expect(TaxCountry.englishName('CM'), 'Cameroon');
      expect(TaxCountry.englishName('cm'), 'Cameroon');
      expect(TaxCountry.englishName(' FR '), 'France');
      expect(TaxCountry.englishName('NG'), 'Nigeria');
      expect(TaxCountry.englishName('US'), 'United States');
      expect(TaxCountry.englishName('CI'), "Cote D'Ivoire");
    });
    test('local name when the ISO code is missing', () {
      expect(TaxCountry.englishName(null, detectedName: 'Cameroun'), 'Cameroon');
      expect(TaxCountry.englishName('', detectedName: ' cameroun '), 'Cameroon');
      expect(TaxCountry.englishName(null, detectedName: 'Tchad'), 'Chad');
      expect(TaxCountry.englishName(null, detectedName: 'Côte d’Ivoire'), "Cote D'Ivoire");
    });
    test('an English name is recognised as itself', () {
      expect(TaxCountry.englishName(null, detectedName: 'Cameroon'), 'Cameroon');
    });
    test('unknown / empty -> null', () {
      expect(TaxCountry.englishName(null), isNull);
      expect(TaxCountry.englishName('ZZ'), isNull);
      expect(TaxCountry.englishName(null, detectedName: 'Atlantis'), isNull);
    });
    test('the ISO code wins over the name', () {
      expect(TaxCountry.englishName('CM', detectedName: 'Gabon'), 'Cameroon');
    });
  });

  group('queryNames', () {
    test('French device in Cameroon asks for both names', () {
      expect(TaxCountry.queryNames(detectedName: 'Cameroun', isoCode: 'CM'), ['Cameroun', 'Cameroon']);
    });
    test('English device: one name, no duplicates', () {
      expect(TaxCountry.queryNames(detectedName: 'Cameroon', isoCode: 'CM'), ['Cameroon']);
    });
    test('aliases are included', () {
      expect(TaxCountry.queryNames(detectedName: 'Royaume-Uni', isoCode: 'GB'), ['Royaume-Uni', 'United Kingdom', 'UK', 'Great Britain']);
    });
    test('unknown country keeps the detected name only (today\'s behaviour)', () {
      expect(TaxCountry.queryNames(detectedName: 'Atlantis', isoCode: null), ['Atlantis']);
    });
    test('nothing known -> nothing to ask for', () {
      expect(TaxCountry.queryNames(detectedName: null, isoCode: null), isEmpty);
      expect(TaxCountry.queryNames(detectedName: '  ', isoCode: ''), isEmpty);
    });
    test('only the ISO code', () {
      expect(TaxCountry.queryNames(detectedName: null, isoCode: 'CM'), ['Cameroon']);
    });
    test('never more than Firestore whereIn allows', () {
      for (final code in TaxCountry.isoEnglishNames.keys) {
        expect(TaxCountry.queryNames(detectedName: 'x', isoCode: code).length, lessThanOrEqualTo(TaxCountry.maxQueryValues));
      }
    });
    test('every ISO entry has a primary name', () {
      for (final e in TaxCountry.isoEnglishNames.entries) {
        expect(e.key, matches(RegExp(r'^[A-Z]{2}$')));
        expect(e.value, isNotEmpty);
      }
    });
  });
}
