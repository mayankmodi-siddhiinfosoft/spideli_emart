import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/services/customer_notification.dart';
import 'package:spideliprovider/services/push_message.dart';

/// The pure parts of the customer Notification Center record written by this
/// app's sends, and of the chat unread badges (lib/services/customer_notification.dart).
void main() {
  group('record', () {
    test('a booking push: template type, booking category, order and status from the data', () {
      final Map<String, String> data = <String, String>{'type': 'provider_order', 'event': 'provider_accepted', 'orderId': 'o1', 'status': 'Order Accepted'};
      final Map<String, dynamic> r = buildCustomerNotificationRecord(id: 'n1', title: 'Accepted', body: 'Your booking was accepted', kind: 'provider_accepted', data: data);
      expect(r['id'], 'n1');
      expect(r['title'], 'Accepted');
      expect(r['body'], 'Your booking was accepted');
      expect(r['type'], 'provider_accepted');
      expect(r['category'], 'booking');
      expect(r['orderId'], 'o1');
      expect(r['status'], 'Order Accepted');
      expect(r['read'], false);
      expect(r['source'], 'provider');
      expect(r.containsKey('createdAt'), isFalse, reason: 'the writer adds a server timestamp');
      expect(r['data'], <String, String>{...data, 'notificationId': 'n1'});
      expect(data.containsKey('notificationId'), isFalse, reason: 'the push data passed in is not changed');
    });

    test('a chat push: data type, chat category, no status', () {
      final Map<String, dynamic> r = buildCustomerNotificationRecord(
        id: 'n2',
        title: 'Provider',
        body: 'On my way',
        kind: 'chat',
        data: <String, String>{'type': 'orderChat', 'chatType': 'provider', 'orderId': 'o2', 'senderId': 'p1'},
      );
      expect(r['type'], 'orderChat');
      expect(r['category'], 'chat');
      expect(r['orderId'], 'o2');
      expect(r['status'], '');
    });

    test('a chat push without a data type is still an orderChat', () {
      expect(customerNotificationType('chat', const <String, String>{}), 'orderChat');
      expect(customerNotificationCategory('chat', const <String, String>{}), 'chat');
    });

    test('no kind: the data type, else other', () {
      expect(customerNotificationType('', const <String, String>{'type': 'provider_order'}), 'provider_order');
      expect(customerNotificationType('', const <String, String>{}), 'other');
    });

    test('title and body are clipped like the push', () {
      final Map<String, dynamic> r = buildCustomerNotificationRecord(id: 'n3', title: 'a' * 500, body: 'b' * 2000, kind: 'chat', data: const <String, String>{});
      expect((r['title'] as String).length, maxPushTitleLength);
      expect((r['body'] as String).length, maxPushBodyLength);
    });
  });

  group('when a push is recorded', () {
    test('only to a customer with a uid and some text', () {
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: 'c1', title: 'T', body: ''), isTrue);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: 'c1', title: '', body: 'B'), isTrue);
      expect(shouldRecordCustomerNotification(recipient: PushApp.worker, customerId: 'w1', title: 'T', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: '', title: 'T', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: ' null ', title: 'T', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: 'admin', title: 'T', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: 'a/b', title: 'T', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushApp.customer, customerId: 'c1', title: ' ', body: ''), isFalse);
    });
  });

  group('unread badge', () {
    test('nothing for none, the count, then 99+', () {
      expect(unreadBadgeLabel(0), '');
      expect(unreadBadgeLabel(-1), '');
      expect(unreadBadgeLabel(1), '1');
      expect(unreadBadgeLabel(99), '99');
      expect(unreadBadgeLabel(100), '99+');
      expect(unreadBadgeLabel(unreadBadgeQueryLimit), '99+');
    });

    test('the listener limit is enough to tell 99 from 99+', () {
      expect(unreadBadgeQueryLimit, greaterThan(99));
    });
  });
}
