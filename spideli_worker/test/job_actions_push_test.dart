import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/model/provider_service_model.dart';
import 'package:spideliworker/services/push_message.dart';
import 'package:spideliworker/ui/booking_list/job_actions.dart';

void main() {
  OnProviderOrderModel order({String? workerId = 'w1', String status = 'Order Assigned'}) => OnProviderOrderModel(
        id: 'o1',
        authorID: 'c1',
        status: status,
        workerId: workerId,
        provider: ProviderServiceModel(id: 's1', title: 'Deep cleaning', author: 'p1'),
      );

  group('JobActions.pushData (worker actions, contract payload)', () {
    test('start: service_intransit with the status after the action', () {
      expect(JobActions.pushData(order(), OnDemandEvent.serviceInTransit, status: 'Order Ongoing'), {
        'type': 'provider_order',
        'event': 'service_intransit',
        'orderId': 'o1',
        'status': 'Order Ongoing',
        'serviceId': 's1',
        'serviceName': 'Deep cleaning',
        'customerId': 'c1',
        'providerId': 'p1',
        'workerId': 'w1',
        'senderRole': 'worker',
      });
    });

    test('stop time / extra charges keep the order status', () {
      expect(JobActions.pushData(order(status: 'Order Ongoing'), OnDemandEvent.stopTime)['status'], 'Order Ongoing');
      expect(JobActions.pushData(order(status: 'Order Ongoing'), OnDemandEvent.serviceCharges)['event'], 'service_charges');
    });

    test('the signed-in worker stands in for a booking without workerId', () {
      expect(JobActions.pushData(order(workerId: null), OnDemandEvent.serviceCompleted, currentWorkerId: 'w9')['workerId'], 'w9');
      expect(JobActions.pushData(order(workerId: ''), OnDemandEvent.serviceCompleted)['workerId'], isNull);
      expect(JobActions.pushData(order(), OnDemandEvent.serviceCompleted, currentWorkerId: 'w9')['workerId'], 'w1');
    });

    test('a tapped worker push opens the booking it is about', () {
      final Map<String, String> data = JobActions.pushData(order(), OnDemandEvent.serviceCompleted, status: 'Order Completed');
      expect(pushRouteFor(data), PushRoute.booking);
      expect(decodeNotificationPayload(null), isEmpty);
    });
  });
}
