import 'package:driver/constant/constant.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client report (7 Oct 2026): a delivery assigned to a driver left the order
/// at "Order Accepted" with `driverID` set, and the driver had no button.
void main() {
  OrderModel order(String status, {String? driverID, List<dynamic>? rejected}) =>
      OrderModel(id: 'o1', status: status, driverID: driverID)..rejectedByDrivers = rejected;

  test('an Order Accepted order that names this driver is an offer to accept', () {
    expect(AssignedDeliveryOrders.awaitsDriver(order(Constant.orderAccepted, driverID: 'd1'), 'd1'), isTrue);
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.orderAccepted, driverID: 'd1'), 'd1'), isTrue);
  });

  test('Order Accepted without this driver named is not an offer', () {
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.orderAccepted), 'd1'), isFalse);
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.orderAccepted, driverID: 'd2'), 'd1'), isFalse);
  });

  test('Driver Pending stays an offer; a driver who rejected it is not offered it again', () {
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending), 'd1'), isTrue);
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverPending, rejected: ['d1']), 'd1'), isFalse);
  });

  test('accepted / in-progress orders are jobs, not offers', () {
    expect(AssignedDeliveryOrders.isOfferFor(order(Constant.driverAccepted, driverID: 'd1'), 'd1'), isFalse);
    expect(AssignedDeliveryOrders.isWorkableFor(order(Constant.driverAccepted, driverID: 'd1'), 'd1'), isTrue);
  });
}
