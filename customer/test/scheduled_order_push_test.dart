import 'package:customer/service/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// An order for a later time must not ring at the store when it is placed:
/// the store owner gets a SILENT data-only push (no `notification` block) and
/// the store app alarms at the scheduled time. These are the rules the cart
/// uses to pick the push, and the exact messages sent on both paths.
void main() {
  final DateTime now = DateTime.utc(2026, 10, 7, 12);

  group('PushPayload.isFutureSchedule', () {
    test('a time ahead of now is a scheduled order', () {
      expect(PushPayload.isFutureSchedule(now.add(const Duration(minutes: 1)), now), isTrue);
      expect(PushPayload.isFutureSchedule(now.add(const Duration(days: 2)), now), isTrue);
    });

    test('no time, now, or a time that has passed is an immediate order', () {
      expect(PushPayload.isFutureSchedule(null, now), isFalse);
      expect(PushPayload.isFutureSchedule(now, now), isFalse);
      expect(PushPayload.isFutureSchedule(now.subtract(const Duration(seconds: 1)), now), isFalse);
    });
  });

  group('PushPayload.scheduledOrderData', () {
    test('type, order id and the time in epoch milliseconds, all strings', () {
      final DateTime at = DateTime.utc(2026, 10, 8, 19, 30);
      final Map<String, String> data = PushPayload.scheduledOrderData(orderId: 'o-1', scheduleAt: at);
      expect(data, {'type': 'scheduled_order', 'orderId': 'o-1', 'scheduleAt': '${at.millisecondsSinceEpoch}'});
      expect(DateTime.fromMillisecondsSinceEpoch(int.parse(data['scheduleAt']!), isUtc: true), at);
    });

    test('stringData keeps it as is and adds no channel', () {
      final Map<String, String> data = PushPayload.stringData(
        PushPayload.scheduledOrderData(orderId: 'o-1', scheduleAt: now),
        type: PushPayload.scheduledOrderType,
      );
      expect(data, {'type': 'scheduled_order', 'orderId': 'o-1', 'scheduleAt': '${now.millisecondsSinceEpoch}'});
      expect(data.containsKey('channelId'), isFalse);
    });
  });

  group('data-only messages', () {
    final Map<String, String> data = PushPayload.scheduledOrderData(orderId: 'o-1', scheduleAt: now);

    test('legacy FCM v1: no notification, Android high priority, APNs background push without alert or sound', () {
      final Map<String, dynamic> message = PushPayload.fcmV1DataMessage(token: ' tok ', data: data);
      expect(message['token'], 'tok');
      expect(message.containsKey('notification'), isFalse);
      expect(message['data'], data);
      expect(message['android'], {'priority': 'high'});
      expect((message['android'] as Map).containsKey('notification'), isFalse);
      final Map apns = message['apns'] as Map;
      expect(apns['headers'], {'apns-priority': '5', 'apns-push-type': 'background'});
      expect(apns['payload'], {
        'aps': {'content-available': 1},
      });
      final Map aps = (apns['payload'] as Map)['aps'] as Map;
      expect(aps.containsKey('alert'), isFalse);
      expect(aps.containsKey('sound'), isFalse);
      expect(aps.containsKey('badge'), isFalse);
    });

    test('server path: no title, body, channel or sound, so the function sends it data-only', () {
      final Map<String, dynamic> request = PushPayload.serverDataRequest(token: ' tok ', data: data, kind: PushPayload.scheduledOrderType);
      expect(request, {'token': 'tok', 'data': data, 'kind': 'scheduled_order'});
      expect(PushPayload.serverDataRequest(token: 'tok', data: data).containsKey('kind'), isFalse);
    });

    test('the loud order push is unchanged for immediate orders', () {
      final PushChannelSpec spec = PushChannels.forRecipient(PushRecipient.store, kind: 'order_placed');
      final Map<String, dynamic> message = PushPayload.fcmV1Message(token: 'tok', title: 'T', body: 'B', data: const {'type': 'order_placed'}, spec: spec);
      expect(message['notification'], {'title': 'T', 'body': 'B'});
      expect((message['android'] as Map)['notification'], {'channel_id': 'new_order', 'sound': 'order_alert'});
    });
  });
}
