import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/home_screen_multiple_order_controller.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which delivery orders a driver can act on — "drivers cannot perform any
/// actions when an order is assigned to them".
void main() {
  const String me = 'driver-me';
  const String other = 'driver-other';

  OrderModel order(String status, {String? driverID, List<dynamic>? rejectedBy}) =>
      OrderModel(id: 'o1', status: status, driverID: driverID, rejectedByDrivers: rejectedBy ?? []);

  group('isWorkableFor', () {
    test('Store self-delivery: "In Transit" written directly, named', () {
      expect(AssignedDeliveryOrders.isWorkableFor(order(Constant.orderInTransit, driverID: me), me), isTrue);
    });

    test('every working status counts, named or (older writers) unnamed', () {
      for (final status in [Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit]) {
        expect(AssignedDeliveryOrders.isWorkableFor(order(status, driverID: me), me), isTrue, reason: status);
        expect(AssignedDeliveryOrders.isWorkableFor(order(status), me), isTrue, reason: '$status unnamed');
      }
    });

    test('an order handed to another driver is not workable', () {
      expect(AssignedDeliveryOrders.isWorkableFor(order(Constant.orderInTransit, driverID: other), me), isFalse);
    });

    test('finished, pending or unaccepted orders are not workable', () {
      for (final status in [Constant.orderCompleted, Constant.orderCancelled, Constant.orderRejected, Constant.driverPending, Constant.orderAccepted]) {
        expect(AssignedDeliveryOrders.isWorkableFor(order(status, driverID: me), me), isFalse, reason: status);
      }
    });

    test('a once-rejected order counts again only when handed over by name', () {
      expect(AssignedDeliveryOrders.isWorkableFor(order(Constant.driverAccepted, rejectedBy: [me]), me), isFalse);
      expect(AssignedDeliveryOrders.isWorkableFor(order(Constant.driverAccepted, driverID: me, rejectedBy: [me]), me), isTrue);
    });
  });

  group('isOfferFor', () {
    test('a pending order is an offer unless this driver rejected it', () {
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending), me), isTrue);
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending, rejectedBy: [me]), me), isFalse);
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverAccepted), me), isFalse);
    });

    test('a pending order named to this driver is an offer; one named to another driver is not', () {
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending, driverID: me), me), isTrue);
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending, driverID: '  '), me), isTrue);
      // Handed to another driver while still in this driver's requests:
      // accepting it took that driver's job.
      expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending, driverID: other), me), isFalse);
    });
  });

  group('isStaleInProgress', () {
    test('finished orders and orders another driver works are stale', () {
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.orderCompleted, driverID: me), me), isTrue);
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.orderCancelled), me), isTrue);
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.orderInTransit, driverID: other), me), isTrue);
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.driverRejected, rejectedBy: [me]), me), isTrue);
    });

    test('orders this driver may still work are kept', () {
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.orderInTransit, driverID: me), me), isFalse);
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.driverAccepted), me), isFalse);
      // A pending order is dispatch's business, never pruned here.
      expect(AssignedDeliveryOrders.isStaleInProgress(order(Constant.driverPending, driverID: other), me), isFalse);
    });
  });

  group('multiple-order New tab', () {
    OrderModel offer(String id, String status, {String? driverID, List<dynamic>? rejectedBy, String? regionId}) =>
        OrderModel(id: id, status: status, driverID: driverID, rejectedByDrivers: rejectedBy ?? [])..regionId = regionId;

    final UserModel freelance = UserModel(id: me, vendorID: '', isDocumentVerify: true, isAutoVerify: false, regionId: 'r1');

    test('shows only offers this driver may still answer', () {
      final Map<String, OrderModel> orders = {
        'open': offer('open', Constant.driverPending),
        'mine': offer('mine', Constant.driverPending, driverID: me),
        'cancelled': offer('cancelled', Constant.orderCancelled),
        'taken': offer('taken', Constant.orderInTransit, driverID: other),
        'handed': offer('handed', Constant.driverPending, driverID: other),
        'rejected': offer('rejected', Constant.driverPending, rejectedBy: [me]),
        'elsewhere': offer('elsewhere', Constant.driverPending, regionId: 'r2'),
      };
      final List<dynamic> shown = HomeScreenMultipleOrderController.offersToShow(
          requests: [...orders.keys, 'missing'], orders: orders, ordersLoaded: true, driver: freelance);
      expect(shown, ['open', 'mine']);
    });

    test('an id whose order has not loaded yet is kept until it does', () {
      expect(HomeScreenMultipleOrderController.offersToShow(requests: ['x'], orders: const {}, ordersLoaded: false, driver: freelance), ['x']);
      expect(HomeScreenMultipleOrderController.offersToShow(requests: ['x'], orders: const {}, ordersLoaded: true, driver: freelance), isEmpty);
    });

    test('an unverified freelance driver gets no offers; store drivers none either', () {
      expect(HomeScreenMultipleOrderController.canTakeOffers(freelance), isTrue);
      final UserModel unverified = UserModel(id: me, vendorID: '', isDocumentVerify: false, isAutoVerify: false);
      expect(HomeScreenMultipleOrderController.documentsPending(unverified), isTrue);
      expect(HomeScreenMultipleOrderController.canTakeOffers(unverified), isFalse);
      final UserModel autoVerified = UserModel(id: me, vendorID: '', isDocumentVerify: false, isAutoVerify: true);
      expect(HomeScreenMultipleOrderController.canTakeOffers(autoVerified), isTrue);
      final UserModel storeDriver = UserModel(id: me, vendorID: 'store-1', isDocumentVerify: false, isAutoVerify: false);
      expect(HomeScreenMultipleOrderController.documentsPending(storeDriver), isFalse);
      expect(HomeScreenMultipleOrderController.canTakeOffers(storeDriver), isFalse);
    });
  });
}
