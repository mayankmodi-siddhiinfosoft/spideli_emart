import 'package:customer/constant/constant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dine-In opened a blank grey screen: the panel saves dine-in times as
/// "19:36", and only "07:36 PM" used to parse.
void main() {
  test('dine-in times parse in 24-hour and 12-hour form', () {
    expect(Constant.tryStringToDate('05:36'), DateTime(1970, 1, 1, 5, 36));
    expect(Constant.tryStringToDate('19:36'), DateTime(1970, 1, 1, 19, 36));
    expect(Constant.tryStringToDate('23:20'), DateTime(1970, 1, 1, 23, 20));
    expect(Constant.tryStringToDate('11:00 AM'), DateTime(1970, 1, 1, 11, 0));
    expect(Constant.tryStringToDate('11:30 PM'), DateTime(1970, 1, 1, 23, 30));
    expect(Constant.tryStringToDate('11:30 pm'), DateTime(1970, 1, 1, 23, 30));
  });

  test('empty or unreadable times never throw', () {
    expect(Constant.tryStringToDate(''), isNull);
    expect(Constant.tryStringToDate(null), isNull);
    expect(Constant.tryStringToDate('null'), isNull);
    expect(Constant.tryStringToDate('soon'), isNull);
    expect(Constant.stringToDate(''), DateTime(1970, 1, 1, 10, 0));
    expect(Constant.stringToDate('', fallback: '10:00 PM'), DateTime(1970, 1, 1, 22, 0));
  });
}
