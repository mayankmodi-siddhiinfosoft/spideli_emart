import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/utils/push_payload.dart';
import 'package:vendor/utils/scheduled_order.dart';

/// Orders for a later time: quiet (Scheduled tab, no Accept / Reject, no
/// ring) until they are due, then New and one alert.
void main() {
  final DateTime now = DateTime(2026, 10, 7, 12);

  group('ScheduledOrderRule.isScheduledFuture', () {
    test('Order Placed with a time ahead of now waits', () {
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: now.add(const Duration(seconds: 1)), now: now), isTrue);
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: now.add(const Duration(days: 1)), now: now), isTrue);
    });

    test('due now, past, or no time: actionable at once', () {
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: now, now: now), isFalse);
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: now.subtract(const Duration(minutes: 5)), now: now), isFalse);
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: null, now: now), isFalse);
    });

    test('any other status is never "scheduled"', () {
      final DateTime later = now.add(const Duration(hours: 2));
      for (final String status in [Constant.orderAccepted, Constant.orderRejected, Constant.orderCancelled, Constant.orderCompleted, Constant.driverPending]) {
        expect(
          ScheduledOrderRule.isScheduledFuture(status: status, scheduleTime: later, now: now),
          isFalse,
          reason: status,
        );
      }
      expect(ScheduledOrderRule.isScheduledFuture(status: null, scheduleTime: later, now: now), isFalse);
    });

    test('the admin lead time brings the due time forward', () {
      final DateTime at = now.add(const Duration(minutes: 20));
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: at, now: now, lead: const Duration(minutes: 10)), isTrue);
      expect(ScheduledOrderRule.isScheduledFuture(status: Constant.orderPlaced, scheduleTime: at, now: now, lead: const Duration(minutes: 20)), isFalse);
      expect(ScheduledOrderRule.dueAt(at, lead: const Duration(minutes: 30)), now.subtract(const Duration(minutes: 10)));
    });

    test('its status constant is the app\'s', () {
      expect(ScheduledOrderRule.orderPlaced, Constant.orderPlaced);
    });
  });

  group('ScheduledOrderRule.leadTime', () {
    test('minute / hour / day, from a number or a string', () {
      expect(ScheduledOrderRule.leadTime('15', 'minute'), const Duration(minutes: 15));
      expect(ScheduledOrderRule.leadTime(2, 'hour'), const Duration(hours: 2));
      expect(ScheduledOrderRule.leadTime('1', 'day'), const Duration(days: 1));
    });

    test('defaults as before: nothing set is 0, an unknown unit one minute, never negative', () {
      expect(ScheduledOrderRule.leadTime('0', 'minute'), Duration.zero);
      expect(ScheduledOrderRule.leadTime(null, 'minute'), Duration.zero);
      expect(ScheduledOrderRule.leadTime('abc', 'hour'), Duration.zero);
      expect(ScheduledOrderRule.leadTime('5', 'week'), const Duration(minutes: 1));
      expect(ScheduledOrderRule.leadTime('-3', 'hour'), Duration.zero);
    });

    test('Constant.checkScheduleTime uses the same rule (0 by default)', () {
      final DateTime at = DateTime(2026, 10, 8, 19);
      expect(Constant.checkScheduleTime(scheduleDate: at), at);
    });
  });

  group('ScheduledOrderRule.split', () {
    ({String id, String status, DateTime? at}) o(String id, String status, DateTime? at) => (id: id, status: status, at: at);

    test('New gets the actionable placed orders, Scheduled the waiting ones soonest first; others neither', () {
      final orders = [
        o('now', Constant.orderPlaced, null),
        o('late', Constant.orderPlaced, now.add(const Duration(hours: 3))),
        o('past', Constant.orderPlaced, now.subtract(const Duration(minutes: 1))),
        o('soon', Constant.orderPlaced, now.add(const Duration(minutes: 30))),
        o('accepted', Constant.orderAccepted, now.add(const Duration(hours: 1))),
      ];
      final split = ScheduledOrderRule.split(orders, status: (x) => x.status, scheduleTime: (x) => x.at, now: now);
      expect(split.actionable.map((x) => x.id), ['now', 'past']);
      expect(split.scheduled.map((x) => x.id), ['soon', 'late']);
      expect(split.nextDueAt, now.add(const Duration(minutes: 30)));
    });

    test('nothing waiting: no next due time', () {
      final split = ScheduledOrderRule.split([o('a', Constant.orderPlaced, null)], status: (x) => x.status, scheduleTime: (x) => x.at, now: now);
      expect(split.scheduled, isEmpty);
      expect(split.nextDueAt, isNull);
    });

    test('when its time comes the order moves to New', () {
      final orders = [o('s', Constant.orderPlaced, now.add(const Duration(minutes: 10)))];
      final before = ScheduledOrderRule.split(orders, status: (x) => x.status, scheduleTime: (x) => x.at, now: now);
      final after = ScheduledOrderRule.split(orders, status: (x) => x.status, scheduleTime: (x) => x.at, now: before.nextDueAt!.add(const Duration(milliseconds: 500)));
      expect(before.actionable, isEmpty);
      expect(after.actionable.map((x) => x.id), ['s']);
      expect(after.scheduled, isEmpty);
    });
  });

  group('HomeController tabs', () {
    setUp(() => Get.testMode = true);

    test('a future scheduled order is in Scheduled, not New (which is what rings)', () {
      final HomeController controller = HomeController();
      final DateTime later = DateTime.now().add(const Duration(hours: 2));
      controller.allOrderList.addAll([
        OrderModel(id: 'immediate', status: Constant.orderPlaced),
        OrderModel(id: 'past', status: Constant.orderPlaced, scheduleTime: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 1)))),
        OrderModel(id: 'later', status: Constant.orderPlaced, scheduleTime: Timestamp.fromDate(later)),
        OrderModel(id: 'accepted', status: Constant.orderAccepted, scheduleTime: Timestamp.fromDate(later)),
      ]);
      controller.showEndedOrder(OrderModel(id: 'x', status: Constant.orderCancelled));
      expect(controller.newOrderList.map((o) => o.id), ['immediate', 'past']);
      expect(controller.scheduledOrderList.map((o) => o.id), ['later']);
      expect(controller.preparingOrderList.map((o) => o.id), ['accepted']);
      expect(HomeController.dueAtOf(controller.scheduledOrderList.first), Timestamp.fromDate(later).toDate());
    });
  });

  group('ScheduledOrderDuePush', () {
    test('the Cloud Function\'s push: order id, and the server says it is due', () {
      final Map<String, dynamic> data = {'type': 'scheduled_order_due', 'orderId': ' o-1 '};
      expect(ScheduledOrderDuePush.orderIdOf(data), 'o-1');
      expect(ScheduledOrderDuePush.isServerDue(data), isTrue);
    });

    test('the schedule_order template type only re-splits (older customer builds sent it at placing time)', () {
      final Map<String, dynamic> data = {'type': 'schedule_order', 'orderId': 'o-1'};
      expect(ScheduledOrderDuePush.orderIdOf(data), 'o-1');
      expect(ScheduledOrderDuePush.isServerDue(data), isFalse);
    });

    test('anything else or unusable is null, never a throw', () {
      expect(ScheduledOrderDuePush.orderIdOf({'type': 'order_placed', 'orderId': 'o-1'}), isNull);
      expect(ScheduledOrderDuePush.orderIdOf({'type': 'scheduled_order', 'orderId': 'o-1'}), isNull);
      expect(ScheduledOrderDuePush.orderIdOf({'type': 'scheduled_order_due'}), isNull);
      expect(ScheduledOrderDuePush.orderIdOf({'type': 'scheduled_order_due', 'orderId': 'null'}), isNull);
      expect(ScheduledOrderDuePush.orderIdOf({}), isNull);
      expect(ScheduledOrderDuePush.isServerDue({'type': 'scheduled_order_due'}), isFalse);
    });

    test('it rings on the order channel and a tap opens the store\'s orders', () {
      expect(PushPayload.isStoreOrderAlert(type: 'scheduled_order_due'), isTrue);
      expect(NotificationRouting.targetFor(type: 'scheduled_order_due'), NotificationTarget.orders);
      expect(NotificationRouting.targetFor(type: 'schedule_order'), NotificationTarget.orders);
    });
  });

  group('HomeController and the due push', () {
    setUp(() => Get.testMode = true);

    test('a scheduled order announced due by the server is New at once', () {
      final HomeController controller = HomeController();
      final DateTime later = DateTime.now().add(const Duration(minutes: 3));
      controller.allOrderList.add(OrderModel(id: 'due-early', status: Constant.orderPlaced, scheduleTime: Timestamp.fromDate(later)));
      controller.showEndedOrder(OrderModel(id: 'x', status: Constant.orderCancelled));
      expect(controller.scheduledOrderList.map((o) => o.id), ['due-early']);

      HomeController.onScheduledOrderPush('due-early', serverDue: true);
      controller.showEndedOrder(OrderModel(id: 'x', status: Constant.orderCancelled));
      expect(controller.newOrderList.map((o) => o.id), ['due-early']);
      expect(controller.scheduledOrderList, isEmpty);
    });
  });
}
