import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/account_verification.dart';
import 'package:vendor/utils/cancellation.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/store_order_write.dart';

/// The store's order writes next to the dispatch Cloud Function
/// (DRIVER_DISPATCH_DOCUMENTATION.md §1, §5C; decisions D1 / D2).
void main() {
  group('StoreOrderWrite.canAccept (Accept / Self Delivery / courier)', () {
    test('only an order still waiting for the store', () {
      expect(StoreOrderWrite.canAccept({'status': Constant.orderPlaced}), isTrue);
      expect(StoreOrderWrite.canAccept({'status': ' Order Placed '}), isTrue);
    });

    test('never over what another device, the dispatch or a driver wrote', () {
      for (final String status in [
        Constant.orderAccepted,
        Constant.driverPending,
        Constant.driverRejected,
        Constant.driverAccepted,
        Constant.orderShipped,
        Constant.orderInTransit,
        Constant.orderCompleted,
        Constant.orderCancelled,
        Constant.orderRejected,
      ]) {
        expect(StoreOrderWrite.canAccept({'status': status, 'driverID': 'd1'}), isFalse, reason: status);
      }
      expect(StoreOrderWrite.canAccept(null), isFalse, reason: 'a deleted order');
      expect(StoreOrderWrite.canAccept({}), isFalse);
    });
  });

  group('StoreOrderWrite.canComplete (Delivered / Mark Deliver / Mark as Completed)', () {
    test('an accepted order that is not finished: whatever the dispatch or a driver made of it meanwhile', () {
      for (final String status in [
        Constant.orderAccepted,
        Constant.driverPending,
        Constant.driverRejected,
        Constant.driverAccepted,
        Constant.orderShipped,
        Constant.orderInTransit,
      ]) {
        expect(StoreOrderWrite.canComplete({'status': status, 'driverID': 'd1'}), isTrue, reason: status);
      }
    });

    test('never one completed, cancelled or rejected meanwhile, nor one not accepted', () {
      for (final String status in [Constant.orderCompleted, Constant.orderCancelled, Constant.orderRejected, Constant.orderPlaced, '']) {
        expect(StoreOrderWrite.canComplete({'status': status}), isFalse, reason: status);
      }
      expect(StoreOrderWrite.canComplete(null), isFalse, reason: 'a deleted order');
    });

    test('the live statuses are exactly the Preparing and Ready tabs, where the completion buttons are', () {
      expect(StoreOrderWrite.liveStatuses, {...HomeController.preparingStatuses, ...HomeController.readyStatuses});
    });
  });

  group('StoreOrderWrite.unchangedSince (reassign / reject / cancel)', () {
    test('same status: allowed', () {
      expect(StoreOrderWrite.unchangedSince({'status': Constant.orderAccepted}, status: Constant.orderAccepted), isTrue);
    });

    test('the status moved on: refused', () {
      expect(StoreOrderWrite.unchangedSince({'status': Constant.driverPending}, status: Constant.orderAccepted), isFalse);
      expect(StoreOrderWrite.unchangedSince({'status': Constant.orderShipped}, status: Constant.driverAccepted), isFalse);
      expect(StoreOrderWrite.unchangedSince(null, status: Constant.orderAccepted), isFalse);
    });

    test('with a delivery man to compare: another one on the order is refused', () {
      final Map<String, dynamic> stored = {'status': Constant.driverPending, 'driverID': 'd2', 'driverId': 'd2'};
      expect(StoreOrderWrite.unchangedSince(stored, status: Constant.driverPending, driverId: 'd2'), isTrue);
      expect(StoreOrderWrite.unchangedSince(stored, status: Constant.driverPending, driverId: 'd1'), isFalse);
      expect(StoreOrderWrite.unchangedSince({'status': Constant.orderAccepted, 'driverID': null}, status: Constant.orderAccepted, driverId: ''), isTrue);
      expect(StoreOrderWrite.unchangedSince({'status': Constant.orderAccepted, 'driverID': 'null'}, status: Constant.orderAccepted, driverId: null), isTrue);
    });
  });

  test('driverIdOf reads driverID, then driverId, and treats null / "" / "null" as none', () {
    expect(StoreOrderWrite.driverIdOf({'driverID': 'a', 'driverId': 'b'}), 'a');
    expect(StoreOrderWrite.driverIdOf({'driverID': null, 'driverId': 'b'}), 'b');
    expect(StoreOrderWrite.driverIdOf({'driverID': '', 'driverId': null}), '');
    expect(StoreOrderWrite.driverIdOf({'driverID': 'null'}), '');
    expect(StoreOrderWrite.driverIdOf(null), '');
  });

  group('the fields each transition writes', () {
    test('accept: the status (and the preparation time), never a driver', () {
      expect(StoreOrderWrite.acceptFields(), {'status': Constant.orderAccepted});
      expect(StoreOrderWrite.acceptFields(estimatedTimeToPrepare: ' 00:20 '), {'status': Constant.orderAccepted, 'estimatedTimeToPrepare': '00:20'});
      final Map<String, dynamic> fields = StoreOrderWrite.acceptFields(estimatedTimeToPrepare: '00:20');
      for (final String key in ['driverID', 'driverId', 'driver', 'notes', 'triggerDelivery', 'rejectedByDrivers']) {
        expect(fields.containsKey(key), isFalse, reason: key);
      }
    });

    test("self delivery: straight to In Transit with the store's delivery man (no dispatch)", () {
      final Map<String, dynamic> fields = StoreOrderWrite.assignFields(driverId: 'd1', driver: {'id': 'd1', 'firstName': 'Ali'}, estimatedTimeToPrepare: '00:15');
      expect(fields['status'], Constant.orderInTransit);
      expect(fields['status'], isNot(Constant.orderAccepted), reason: 'Order Accepted would start deliveryDispatch');
      expect(fields['driverID'], 'd1');
      expect(fields['driverId'], 'd1', reason: 'both fields name him, as the dispatch writes them together');
      expect(fields['driver'], {'id': 'd1', 'firstName': 'Ali'});
      expect(fields['estimatedTimeToPrepare'], '00:15');
      expect(fields.containsKey('notes'), isFalse, reason: "the customer's remarks are kept");
      expect(StoreOrderWrite.assignFields(driverId: 'd1', driver: const {}).containsKey('estimatedTimeToPrepare'), isFalse);
    });

    test("taking over a platform driver's offer leaves no field naming that driver", () {
      final Map<String, dynamic> offered = {'status': Constant.driverPending, 'driverID': 'x', 'driverId': 'x'};
      final Map<String, dynamic> after = {...offered, ...StoreOrderWrite.assignFields(driverId: 'm1', driver: const {'id': 'm1'})};
      expect(after['driverID'], 'm1');
      expect(after['driverId'], 'm1');
      expect(StoreOrderWrite.driverIdOf(after), 'm1');
    });

    test('complete: the status only, never the card copy of the delivery man or the remarks', () {
      expect(StoreOrderWrite.completeFields(), {'status': Constant.orderCompleted});
    });

    test('courier shipment', () {
      expect(StoreOrderWrite.courierFields(companyName: ' DHL ', trackingId: ' 123 '), {'status': Constant.orderShipped, 'courierCompanyName': 'DHL', 'courierTrackingId': '123'});
    });

    test('cancel / reject: the status and the reason fields only, cancelledAt from the server', () {
      final OrderModel ended = OrderModel(status: Constant.orderCancelled)..markEndedByVendor(action: CancelAction.cancelled, reason: 'Out of stock', code: 'out_of_stock', byName: 'My store');
      final Map<String, dynamic> fields = ended.endedByVendorFields();
      expect(fields['status'], Constant.orderCancelled);
      expect(fields['cancelReason'], 'Out of stock');
      expect(fields['cancelReasonCode'], 'out_of_stock');
      expect(fields['cancelledBy'], 'vendor');
      expect(fields['cancelledByName'], 'My store');
      expect(fields['cancelAction'], CancelAction.cancelled);
      expect(fields['cancelledAt'], isA<FieldValue>());
      expect(fields.keys.toSet(), {'status', 'cancelReason', 'cancelReasonCode', 'cancelledBy', 'cancelledByName', 'cancelAction', 'cancelledAt'});
    });
  });

  group('who the store says has the order', () {
    test('an offer (Driver Pending) or a pass (Driver Rejected) is waiting for a driver, even with driverID', () {
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.driverPending, 'd1'), isFalse);
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.driverRejected, 'd1'), isFalse);
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.orderAccepted, 'd1'), isFalse);
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.driverAccepted, ''), isFalse);
    });

    test('Driver Accepted, Order Shipped and In Transit are with the delivery man', () {
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.driverAccepted, 'd1'), isTrue);
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.orderShipped, 'd1'), isTrue);
      expect(StoreOrderWrite.isWithDeliveryMan(Constant.orderInTransit, 'd1'), isTrue);
    });

    test('the order detail shows the delivery man once one accepted, and after delivery', () {
      bool shows(String status, {String? driverId = 'd1', bool takeAway = false, bool pos = false}) =>
          StoreOrderWrite.showsDeliveryMan(status: status, driverId: driverId, takeAway: takeAway, isPosOrder: pos);
      expect(shows(Constant.driverAccepted), isTrue);
      expect(shows(Constant.orderShipped), isTrue);
      expect(shows(Constant.orderInTransit), isTrue);
      expect(shows(Constant.orderCompleted), isTrue);
      expect(shows(Constant.driverPending), isFalse);
      expect(shows(Constant.driverRejected), isFalse);
      expect(shows(Constant.orderAccepted), isFalse);
      expect(shows(Constant.orderShipped, driverId: null), isFalse);
      expect(shows(Constant.orderCompleted, takeAway: true), isFalse);
      expect(shows(Constant.orderCompleted, pos: true), isFalse);
    });
  });

  test('OrderWriteOutcome tells a moved-on order from a failed write', () {
    final OrderWriteOutcome moved = OrderWriteOutcome.refused({'status': Constant.driverPending});
    expect(moved.written, isFalse);
    expect(moved.changedMeanwhile, isTrue);
    expect(moved.storedStatus, Constant.driverPending);
    expect(OrderWriteOutcome.refused(null).changedMeanwhile, isFalse, reason: 'a deleted order');
    expect(OrderWriteOutcome.failure().changedMeanwhile, isFalse);
    expect(OrderWriteOutcome.failure().failed, isTrue);
    expect(OrderWriteOutcome.written({'status': Constant.orderPlaced}).written, isTrue);
  });

  group('Doc 37: a new account is never created verified', () {
    test('a store owner: isDocumentVerify false; verification switched off is isAutoVerify', () {
      final off = AccountVerification.newStoreOwner(storeVerificationOn: false);
      expect(off.isDocumentVerify, isFalse);
      expect(off.isAutoVerify, isTrue);
      final on = AccountVerification.newStoreOwner(storeVerificationOn: true);
      expect(on.isDocumentVerify, isFalse);
      expect(on.isAutoVerify, isFalse);
    });

    test('a store needing no verification is not held by the pending gate (both flags false)', () {
      bool pending(({bool isDocumentVerify, bool isAutoVerify}) f) => f.isAutoVerify == false && f.isDocumentVerify == false;
      expect(pending(AccountVerification.newStoreOwner(storeVerificationOn: false)), isFalse);
      expect(pending(AccountVerification.newStoreOwner(storeVerificationOn: true)), isTrue);
    });

    test('an employee', () {
      expect(AccountVerification.newEmployeeDocumentVerify, isFalse);
    });
  });

  group("Doc 37: the administrator's verdict is never written over", () {
    UserModel owner() => UserModel(id: 'u1', role: Constant.userRoleVendor, vendorID: 's1', isDocumentVerify: false, isAutoVerify: false, firstName: 'A');

    test('a save of an existing user leaves isDocumentVerify and isAutoVerify alone', () {
      final Map<String, dynamic> data = FireStoreUtils.userWriteData(owner());
      expect(data.containsKey('isDocumentVerify'), isFalse);
      expect(data.containsKey('isAutoVerify'), isFalse);
      expect(data['firstName'], 'A');
      expect(data.containsKey('wallet_amount'), isFalse);
    });

    test('a new account gets its starting value', () {
      final Map<String, dynamic> data = FireStoreUtils.userWriteData(owner(), isNew: true);
      expect(data['isDocumentVerify'], isFalse);
      expect(data['isAutoVerify'], isFalse);
    });
  });
}
