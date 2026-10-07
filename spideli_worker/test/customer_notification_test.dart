import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/services/customer_notification.dart';
import 'package:spideliworker/services/push_message.dart';

void main() {
  group('shouldRecordCustomerNotification', () {
    test('a customer push with text and an id is recorded', () {
      expect(shouldRecordCustomerNotification(recipient: PushRecipient.customer, customerId: 'c1', title: 'Started', body: ''), isTrue);
      expect(shouldRecordCustomerNotification(recipient: PushRecipient.customer, customerId: 'c1', title: '', body: 'Hello'), isTrue);
    });

    test('other recipients, missing ids and empty pushes are not', () {
      expect(shouldRecordCustomerNotification(recipient: PushRecipient.provider, customerId: 'c1', title: 'A', body: 'B'), isFalse);
      expect(shouldRecordCustomerNotification(recipient: PushRecipient.worker, customerId: 'c1', title: 'A', body: 'B'), isFalse);
      for (final String? id in <String?>[null, '', '  ', 'null', 'a/b']) {
        expect(shouldRecordCustomerNotification(recipient: PushRecipient.customer, customerId: id, title: 'A', body: 'B'), isFalse, reason: '$id');
      }
      expect(shouldRecordCustomerNotification(recipient: PushRecipient.customer, customerId: 'c1', title: ' ', body: ''), isFalse);
    });
  });

  group('existingNotificationId', () {
    test('reads a usable id from the payload', () {
      expect(existingNotificationId(<String, dynamic>{'notificationId': ' n1 '}), 'n1');
    });
    test('null for missing or unusable ids', () {
      expect(existingNotificationId(null), isNull);
      expect(existingNotificationId(<String, dynamic>{}), isNull);
      expect(existingNotificationId(<String, dynamic>{'notificationId': 'null'}), isNull);
      expect(existingNotificationId(<String, dynamic>{'notificationId': 'a/b'}), isNull);
      expect(existingNotificationId(<String, dynamic>{'notificationId': null}), isNull);
    });
  });

  group('customerNotificationRecord', () {
    test('job status push: template type, booking category, order and status', () {
      final Map<String, String> data = withNotificationId(
        onDemandPushData(event: OnDemandEvent.serviceInTransit, orderId: 'o1', status: 'Order Ongoing', customerId: 'c1'),
        'n1',
      );
      final Map<String, dynamic> record = customerNotificationRecord(id: 'n1', title: 'Job started', body: 'Your worker is on the way', kind: OnDemandEvent.serviceInTransit, data: data);
      expect(record['id'], 'n1');
      expect(record['title'], 'Job started');
      expect(record['body'], 'Your worker is on the way');
      expect(record['type'], 'service_intransit');
      expect(record['category'], 'booking');
      expect(record['orderId'], 'o1');
      expect(record['status'], 'Order Ongoing');
      expect(record['read'], isFalse);
      expect(record['source'], 'worker');
      expect(record['data'], containsPair('notificationId', 'n1'));
      expect(record['data'], containsPair('type', 'provider_order'));
      expect(record.containsKey('createdAt'), isFalse);
    });

    test('extra charges push has no status when the data has none', () {
      final Map<String, dynamic> record = customerNotificationRecord(
        id: 'n2',
        title: 'Extra charges',
        body: 'Pay',
        kind: OnDemandEvent.serviceCharges,
        data: <String, String>{'type': 'provider_order', 'orderId': 'o1'},
      );
      expect(record['type'], 'service_charges');
      expect(record['category'], 'booking');
      expect(record['status'], '');
    });

    test('chat push: data type, chat category, no status', () {
      final Map<String, dynamic> record = customerNotificationRecord(
        id: 'n3',
        title: 'Ravi',
        body: 'On my way',
        kind: chatPushKind,
        data: <String, String>{'type': 'orderChat', 'chatType': 'worker', 'orderId': 'o9', 'senderId': 'w1', 'notificationId': 'n3'},
      );
      expect(record['type'], 'orderChat');
      expect(record['category'], 'chat');
      expect(record['orderId'], 'o9');
      expect(record['status'], '');
    });

    test('title and body are clipped like the push', () {
      final Map<String, dynamic> record = customerNotificationRecord(id: 'n', title: 'x' * 500, body: 'y' * 5000, kind: chatPushKind, data: const <String, String>{});
      expect((record['title'] as String).length, maxPushTitleLength);
      expect((record['body'] as String).length, maxPushBodyLength);
      expect(record['type'], 'chat');
      expect(record['orderId'], '');
    });

    test('the record keeps its own copy of the data', () {
      final Map<String, String> data = <String, String>{'type': 'orderChat'};
      final Map<String, dynamic> record = customerNotificationRecord(id: 'n', title: 't', body: 'b', kind: chatPushKind, data: data);
      data['type'] = 'changed';
      expect((record['data'] as Map)['type'], 'orderChat');
    });
  });

  test('withNotificationId adds the id and keeps the rest', () {
    final Map<String, String> data = <String, String>{'type': 'provider_order', 'orderId': 'o1'};
    final Map<String, String> out = withNotificationId(data, 'n1');
    expect(out, <String, String>{'type': 'provider_order', 'orderId': 'o1', 'notificationId': 'n1'});
    expect(data.containsKey('notificationId'), isFalse);
  });
}
