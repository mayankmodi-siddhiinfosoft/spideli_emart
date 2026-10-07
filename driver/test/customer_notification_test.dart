import 'package:driver/services/customer_notification.dart';
import 'package:driver/services/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerNotification.shouldRecord', () {
    test('customer push with an id and text is recorded', () {
      expect(CustomerNotification.shouldRecord(toCustomer: true, customerId: 'c1', title: 'T', body: ''), isTrue);
      expect(CustomerNotification.shouldRecord(toCustomer: true, customerId: 'c1', title: '', body: 'B'), isTrue);
    });

    test('not for another app, without a customer or without text', () {
      expect(CustomerNotification.shouldRecord(toCustomer: false, customerId: 'c1', title: 'T', body: 'B'), isFalse);
      expect(CustomerNotification.shouldRecord(toCustomer: true, customerId: null, title: 'T', body: 'B'), isFalse);
      expect(CustomerNotification.shouldRecord(toCustomer: true, customerId: '  ', title: 'T', body: 'B'), isFalse);
      expect(CustomerNotification.shouldRecord(toCustomer: true, customerId: 'c1', title: ' ', body: null), isFalse);
    });
  });

  group('CustomerNotification.categoryFor', () {
    test('chat types', () {
      expect(CustomerNotification.categoryFor('orderChat', orderId: 'o1'), 'chat');
      expect(CustomerNotification.categoryFor('chat'), 'chat');
      expect(CustomerNotification.categoryFor('admin_chat'), 'chat');
    });

    test('order pushes', () {
      for (final String type in ['driver_accepted', 'driver_completed', 'parcel_accepted', 'parcel_completed', 'rental_completed', 'delivery_otp']) {
        expect(CustomerNotification.categoryFor(type, orderId: 'o1'), 'order', reason: type);
      }
    });

    test('no order id and not chat is other', () {
      expect(CustomerNotification.categoryFor('driver_accepted'), 'other');
      expect(CustomerNotification.categoryFor(null), 'other');
    });
  });

  group('CustomerNotification ids in push data', () {
    test('withId adds notificationId without touching the input', () {
      final Map<String, String> data = <String, String>{'type': 'driver_accepted', 'orderId': 'o1'};
      final Map<String, String> out = CustomerNotification.withId(data, 'n1');
      expect(out, <String, String>{'type': 'driver_accepted', 'orderId': 'o1', 'notificationId': 'n1'});
      expect(data.containsKey('notificationId'), isFalse);
    });

    test('withId ignores an empty id; withoutId drops it', () {
      expect(CustomerNotification.withId(<String, String>{'type': 'x'}, ' ').containsKey('notificationId'), isFalse);
      expect(CustomerNotification.withoutId(<String, String>{'type': 'x', 'notificationId': 'n1'}), <String, String>{'type': 'x'});
    });

    test('stringData then withId stays string-only', () {
      final Map<String, String> data = CustomerNotification.withId(PushMessage.stringData({'orderId': 'o1', 'n': 3, 'skip': null}, type: 'driver_completed'), 'n9');
      expect(data, <String, String>{'orderId': 'o1', 'n': '3', 'type': 'driver_completed', 'notificationId': 'n9'});
    });
  });

  group('CustomerNotification.document', () {
    test('templated order push', () {
      final Object ts = Object();
      final Map<String, dynamic> doc = CustomerNotification.document(
        id: 'n1',
        title: 'Driver accepted',
        body: 'Your order is on its way',
        type: 'parcel_accepted',
        data: <String, String>{'type': 'parcel_order', 'orderId': ' o1 ', 'notificationId': 'n1'},
        status: 'Driver Accepted',
        createdAt: ts,
      );
      expect(doc['id'], 'n1');
      expect(doc['title'], 'Driver accepted');
      expect(doc['body'], 'Your order is on its way');
      expect(doc['type'], 'parcel_accepted');
      expect(doc['category'], 'order');
      expect(doc['orderId'], 'o1');
      expect(doc['status'], 'Driver Accepted');
      expect(doc['data'], <String, String>{'type': 'parcel_order', 'orderId': ' o1 ', 'notificationId': 'n1'});
      expect(doc['read'], isFalse);
      expect(identical(doc['createdAt'], ts), isTrue);
      expect(doc['source'], 'driver');
    });

    test('chat push takes the data type and has no status', () {
      final Map<String, dynamic> doc = CustomerNotification.document(
        id: 'n2',
        title: 'Ravi',
        body: 'At the gate',
        type: '',
        data: <String, String>{'type': 'orderChat', 'chatType': 'driver', 'orderId': 'o1', 'senderId': 'd1', 'notificationId': 'n2'},
        createdAt: 0,
      );
      expect(doc['type'], 'orderChat');
      expect(doc['category'], 'chat');
      expect(doc['status'], '');
      expect(doc['orderId'], 'o1');
    });

    test('missing order id is empty, never null', () {
      final Map<String, dynamic> doc =
          CustomerNotification.document(id: 'n3', title: 't', body: 'b', type: 'delivery_otp', data: const <String, String>{}, createdAt: 0);
      expect(doc['orderId'], '');
      expect(doc['category'], 'other');
    });
  });
}
