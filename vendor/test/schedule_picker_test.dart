import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/schedule_picker.dart';

void main() {
  group('clampPickerDate', () {
    final DateTime first = DateTime(2026, 1, 10);
    final DateTime last = DateTime(2026, 12, 31);

    test('keeps a date already inside the window', () {
      expect(clampPickerDate(DateTime(2026, 6, 5), first, last), DateTime(2026, 6, 5));
    });

    test('pulls a past date up to the first allowed day', () {
      expect(clampPickerDate(DateTime(2024, 3, 1), first, last), first);
    });

    test('pulls a future date down to the last allowed day', () {
      expect(clampPickerDate(DateTime(2030, 1, 1), first, last), last);
    });

    test('ignores the time of day, so "today at 00:00" stays today', () {
      final DateTime firstWithTime = DateTime(2026, 6, 5, 14, 30);
      expect(clampPickerDate(DateTime(2026, 6, 5), firstWithTime, last), DateTime(2026, 6, 5));
    });
  });

  group('parseTimeOfDay', () {
    test('reads the 24-hour form stored for working hours', () {
      expect(parseTimeOfDay('06:00'), const TimeOfDay(hour: 6, minute: 0));
      expect(parseTimeOfDay('23:59'), const TimeOfDay(hour: 23, minute: 59));
    });

    test('reads the 12-hour form the dine-in fields hold', () {
      expect(parseTimeOfDay('9:00 PM'), const TimeOfDay(hour: 21, minute: 0));
      expect(parseTimeOfDay('12:00 AM'), const TimeOfDay(hour: 0, minute: 0));
      expect(parseTimeOfDay('12:30 PM'), const TimeOfDay(hour: 12, minute: 30));
    });

    test('is null for anything it cannot read', () {
      expect(parseTimeOfDay(null), isNull);
      expect(parseTimeOfDay(''), isNull);
      expect(parseTimeOfDay('24:00'), isNull);
      expect(parseTimeOfDay('not a time'), isNull);
    });
  });
}
