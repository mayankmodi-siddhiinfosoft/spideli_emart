import 'package:customer/service/parcel_sms_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

// PARCEL-SMS-OUTBOX.md: OBITSMS needs plain digits with the country code, and a
// number that cannot be normalised must never be queued.
void main() {
  String? to(String? raw) => ParcelSmsOutbox.normalise(raw, fallbackDialCode: '+237')?.to;

  test('the booking form shape "(+237) 6 12 34 56 78"', () {
    expect(to('(+237) 6 12 34 56 78'), '237612345678');
    expect(ParcelSmsOutbox.normalise('(+237) 612345678', fallbackDialCode: '+237')?.countryCode, '237');
  });

  test('a national trunk zero is dropped', () {
    expect(to('(+33) 06 12 34 56 78'), '33612345678');
  });

  test('a bare national number takes the platform dial code', () {
    expect(to('6 12 34 56 78'), '237612345678');
  });

  test('E.164 is kept when the country code is the platform one', () {
    expect(to('+237612345678'), '237612345678');
  });

  test('numbers that cannot be normalised are skipped', () {
    expect(to(null), isNull);
    expect(to(''), isNull);
    expect(to('()'), isNull);
    expect(to('(+237)'), isNull);
    expect(to('+441234567890'), isNull, reason: 'a foreign country code cannot be split off');
    expect(to('1234'), isNull, reason: 'too short for E.164');
    expect(ParcelSmsOutbox.normalise('612345678', fallbackDialCode: ''), isNull, reason: 'no country code to assume');
  });
}
