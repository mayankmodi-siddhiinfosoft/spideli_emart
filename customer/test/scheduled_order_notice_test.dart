import 'package:customer/service/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// An order for a later time sends the store nothing when it is placed: it is
/// written with `scheduledNotificationSent: false` and the
/// `scheduledOrderNotifier` Cloud Function pushes the store when it is due.
void main() {
  final DateTime now = DateTime.utc(2026, 10, 7, 12);

  group('ScheduledOrderNotice.isFutureSchedule', () {
    test('a time ahead of now is a scheduled order', () {
      expect(ScheduledOrderNotice.isFutureSchedule(now.add(const Duration(minutes: 1)), now), isTrue);
      expect(ScheduledOrderNotice.isFutureSchedule(now.add(const Duration(days: 2)), now), isTrue);
    });

    test('no time, now, or a time that has passed is an immediate order', () {
      expect(ScheduledOrderNotice.isFutureSchedule(null, now), isFalse);
      expect(ScheduledOrderNotice.isFutureSchedule(now, now), isFalse);
      expect(ScheduledOrderNotice.isFutureSchedule(now.subtract(const Duration(seconds: 1)), now), isFalse);
    });
  });

  group('ScheduledOrderNotice.orderFields', () {
    test('a future scheduled order is written with scheduledNotificationSent: false', () {
      expect(ScheduledOrderNotice.orderFields(scheduleTime: now.add(const Duration(hours: 3)), now: now), {'scheduledNotificationSent': false});
    });

    test('an immediate order gets no extra field', () {
      expect(ScheduledOrderNotice.orderFields(scheduleTime: null, now: now), isEmpty);
      expect(ScheduledOrderNotice.orderFields(scheduleTime: now.subtract(const Duration(minutes: 5)), now: now), isEmpty);
    });
  });
}
