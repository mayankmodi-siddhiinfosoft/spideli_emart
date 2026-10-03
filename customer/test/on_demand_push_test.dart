import 'package:customer/constant/constant.dart';
import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/service/on_demand_notifier.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/utils/on_demand_push.dart';
import 'package:customer/utils/push_tap.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONDEMAND-NOTIFICATIONS: the data every on-demand push carries, and where a
/// tapped one takes the customer.
void main() {
  group('OnDemandPush.payload', () {
    test('carries every contract key as a string, sender customer', () {
      final data = OnDemandPush.payload(
        event: OnDemandPush.bookingPlaced,
        orderId: 'o1',
        status: Constant.orderPlaced,
        serviceId: 's1',
        serviceName: 'Plumbing',
        customerId: 'c1',
        providerId: 'p1',
        workerId: 'w1',
      );
      expect(data, {
        'type': 'provider_order',
        'event': 'booking_placed',
        'orderId': 'o1',
        'status': 'Order Placed',
        'serviceId': 's1',
        'serviceName': 'Plumbing',
        'customerId': 'c1',
        'providerId': 'p1',
        'workerId': 'w1',
        'senderRole': 'customer',
      });
    });

    test('never sends nulls, empty or "null" values', () {
      final data = OnDemandPush.payload(event: OnDemandPush.bookingCancelledByCustomer, orderId: 'o1', status: null, serviceId: '', workerId: 'null', providerId: '  ');
      expect(data.keys, unorderedEquals(['type', 'event', 'orderId', 'senderRole']));
      expect(data.values.every((v) => v.isNotEmpty), isTrue);
    });

    test('goes to the provider app unchanged, on its channel', () {
      final data = OnDemandPush.payload(event: OnDemandPush.bookingPlaced, orderId: 'o1');
      final spec = PushChannels.forRecipient(PushRecipient.provider, kind: OnDemandPush.templateBookingPlaced);
      final sent = PushPayload.stringData(data, type: OnDemandPush.templateBookingPlaced, spec: spec);
      expect(sent['type'], 'provider_order');
      expect(sent['event'], 'booking_placed');
      expect(sent['orderId'], 'o1');
      expect(sent['channelId'], '01');
      expect(PushChannels.forRecipient(PushRecipient.worker).androidChannelId, '01');
    });
  });

  group('OnDemandNotifier.payloadFor', () {
    OnProviderOrderModel order({String? workerId, String status = Constant.orderPlaced}) => OnProviderOrderModel(
      id: 'o1',
      authorID: 'c1',
      status: status,
      workerId: workerId,
      provider: ProviderServiceModel(id: 's1', title: 'Cleaning', author: 'p1'),
    );

    test('booking placed: the booking, its service and the parties', () {
      expect(OnDemandNotifier.payloadFor(order(), OnDemandPush.bookingPlaced), {
        'type': 'provider_order',
        'event': 'booking_placed',
        'orderId': 'o1',
        'status': 'Order Placed',
        'serviceId': 's1',
        'serviceName': 'Cleaning',
        'customerId': 'c1',
        'providerId': 'p1',
        'senderRole': 'customer',
      });
    });

    test('cancelled with a worker: status after the action and the worker id', () {
      final data = OnDemandNotifier.payloadFor(order(workerId: 'w1', status: Constant.orderCancelled), OnDemandPush.bookingCancelledByCustomer);
      expect(data['event'], 'booking_cancelled_by_customer');
      expect(data['status'], 'Order Cancelled');
      expect(data['workerId'], 'w1');
    });

    test('payment events', () {
      expect(OnDemandNotifier.payloadFor(order(), OnDemandPush.bookingPaid)['event'], 'booking_paid');
      expect(OnDemandNotifier.payloadFor(order(), OnDemandPush.extraChargesPaid)['event'], 'extra_charges_paid');
    });
  });

  group('tap target', () {
    test('a booking push with an order id opens that booking', () {
      expect(PushTap.targetOf({'type': 'provider_order', 'orderId': 'o1'}), PushTapTarget.onDemandBooking);
      expect(PushTap.targetOf(OnDemandPush.payload(event: OnDemandPush.serviceCompleted, orderId: 'o1')), PushTapTarget.onDemandBooking);
      expect(OnDemandPush.orderIdOf({'type': 'provider_order', 'orderId': ' o1 '}), 'o1');
    });

    test('every contract event is recognised, by event or by an older sender\'s type', () {
      for (final event in OnDemandPush.events) {
        expect(PushTap.targetOf({'event': event, 'orderId': 'o1'}), PushTapTarget.onDemandBooking, reason: event);
        expect(PushTap.targetOf({'type': event, 'orderId': 'o1'}), PushTapTarget.onDemandBooking, reason: event);
      }
    });

    test('a missing or invalid order id opens the bookings list', () {
      expect(PushTap.targetOf({'type': 'provider_order'}), PushTapTarget.onDemandBookings);
      expect(PushTap.targetOf({'type': 'provider_order', 'orderId': ''}), PushTapTarget.onDemandBookings);
      expect(PushTap.targetOf({'type': 'provider_order', 'orderId': 'null'}), PushTapTarget.onDemandBookings);
      expect(PushTap.targetOf({'type': 'provider_order', 'orderId': 'a/b'}), PushTapTarget.onDemandBookings);
      expect(PushTap.targetOf({'type': 'provider_order', 'orderId': null}), PushTapTarget.onDemandBookings);
      expect(PushTap.targetOf({'event': 'provider_accepted', 'orderId': 7}), PushTapTarget.onDemandBooking);
    });

    test('other pushes are not booking pushes', () {
      expect(PushTap.targetOf({'type': 'order_placed', 'orderId': 'o1'}), isNull);
      expect(PushTap.targetOf({'type': 'restaurant_accepted'}), isNull);
      expect(PushTap.targetOf({'type': 'orderChat', 'chatType': 'provider', 'orderId': 'o1'}), PushTapTarget.providerInbox);
      expect(OnDemandPush.isOnDemand(const {}), isFalse);
    });

    test('only the signed-in customer\'s own booking is opened', () {
      expect(OnDemandPush.isOwnBooking(orderAuthorId: 'c1', uid: 'c1'), isTrue);
      expect(OnDemandPush.isOwnBooking(orderAuthorId: 'c2', uid: 'c1'), isFalse);
      expect(OnDemandPush.isOwnBooking(orderAuthorId: '', uid: ''), isFalse);
      expect(OnDemandPush.isOwnBooking(orderAuthorId: 'c1', uid: null), isFalse);
    });

    test('a booking push is shown in the foreground (title / body)', () {
      final text = PushTap.displayText(title: 'Booking accepted', body: 'Your booking was accepted', data: {'type': 'provider_order', 'orderId': 'o1'});
      expect(text?.title, 'Booking accepted');
      expect(text?.body, 'Your booking was accepted');
    });
  });

  test('every push the customer sends uses its Firestore template', () {
    expect(OnDemandPush.templateFor, {
      'booking_placed': 'booking_placed',
      'booking_cancelled_by_customer': 'service_cancelled',
      'booking_paid': 'booking_paid',
      'extra_charges_paid': 'extra_charges_paid',
    });
  });
}
