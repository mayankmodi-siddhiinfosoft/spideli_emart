import 'package:vendor/constant/constant.dart';
import 'package:vendor/utils/cancellation.dart';

/// What the Store app may write on a `vendor_orders` document, and when.
///
/// The store is no longer the only writer of an order it has accepted: the
/// `deliveryDispatch` Cloud Function (DRIVER_DISPATCH_DOCUMENTATION.md §1)
/// writes `status` "Driver Pending" with `driverID` / `driverId` when it offers
/// the order to a platform driver, the driver writes "Driver Accepted" or
/// "Driver Rejected", and the Function then advances an accepted order to
/// "Order Shipped". Writing the store's whole in-memory copy back over that
/// (the old `updateOrder(orderModel)` on Accept / Assign / Reject / Cancel /
/// Complete)
/// could put "Order Accepted" with no driver over a live offer, which dropped
/// the offered driver and fired the dispatch a second time.
///
/// So every store transition runs in a transaction that re-reads the order,
/// goes ahead only under the rule below for that transition, and updates only
/// the fields that transition changes. The rules and the field maps are
/// here, pure, so they are unit tested.
abstract final class StoreOrderWrite {
  /// The order's stored status ('' when missing).
  static String statusOf(Map<String, dynamic>? stored) {
    final Object? status = stored?['status'];
    return isBlankText(status) ? '' : status.toString().trim();
  }

  /// The delivery man the stored order names: `driverID` (the apps' field),
  /// else `driverId` (written alongside it by the dispatch Function). '' when
  /// neither holds one - null, '' and "null" alike.
  static String driverIdOf(Map<String, dynamic>? stored) {
    if (stored == null) return '';
    for (final String key in const ['driverID', 'driverId']) {
      final Object? value = stored[key];
      if (!isBlankText(value)) return value.toString().trim();
    }
    return '';
  }

  /// The store accepts (Accept, Self Delivery, courier shipment) only an order
  /// that is still waiting for it. Anything else means another device, the
  /// customer, an administrator or the dispatch got there first.
  static bool canAccept(Map<String, dynamic>? stored) => stored != null && statusOf(stored) == Constant.orderPlaced;

  /// The store changes an order it is already working on (reassigns its own
  /// delivery man, cancels, rejects) only while the order is still in the
  /// [status] the store was shown - and, when [driverId] is given, still names
  /// that delivery man ('' / null: none).
  static bool unchangedSince(Map<String, dynamic>? stored, {required String? status, String? driverId}) {
    if (stored == null) return false;
    if (statusOf(stored) != (isBlankText(status) ? '' : status!.trim())) return false;
    if (driverId == null) return true;
    return driverIdOf(stored) == (isBlankText(driverId) ? '' : driverId.trim());
  }

  /// Accept: "Order Accepted" (which starts `deliveryDispatch` for an order a
  /// platform driver carries) and the preparation time when one was given.
  /// Never `driverID` / `driverId` / `driver`: those belong to the dispatch.
  static Map<String, dynamic> acceptFields({String? estimatedTimeToPrepare}) => {
    'status': Constant.orderAccepted,
    if (!isBlankText(estimatedTimeToPrepare)) 'estimatedTimeToPrepare': estimatedTimeToPrepare!.trim(),
  };

  /// The store's own delivery man takes the order (self delivery): straight
  /// to "In Transit" with him on it, so `deliveryDispatch` (which starts on
  /// "Order Accepted") is never involved. [driver] is the embedded snapshot
  /// the screens show.
  ///
  /// Both `driverID` and `driverId` name him: the dispatch Function writes the
  /// two together with an offer (D2), so a takeover of an order offered to a
  /// platform driver that set only `driverID` left `driverId` on that driver,
  /// and his app (which matches either field) still took the order as his.
  static Map<String, dynamic> assignFields({required String driverId, required Map<String, dynamic> driver, String? estimatedTimeToPrepare}) => {
    'status': Constant.orderInTransit,
    'driverID': driverId,
    'driverId': driverId,
    'driver': driver,
    if (!isBlankText(estimatedTimeToPrepare)) 'estimatedTimeToPrepare': estimatedTimeToPrepare!.trim(),
  };

  /// Statuses of an order the store has accepted and that is not finished
  /// yet: preparing, offered to / passed on by / taken by a driver, shipped,
  /// on its way.
  static const Set<String> liveStatuses = {
    Constant.orderAccepted,
    Constant.driverPending,
    Constant.driverRejected,
    Constant.driverAccepted,
    Constant.orderShipped,
    Constant.orderInTransit,
  };

  /// The store completes an order (Delivered / Mark Deliver / Mark as
  /// Completed) only while it is still live ([liveStatuses]): never one that
  /// was completed, cancelled or rejected meanwhile, nor one that is no longer
  /// accepted. Not tied to the exact status the card showed: reading out the
  /// customer's code can take minutes while the order moves on (an offer
  /// passed on to another driver, "Order Shipped" to "In Transit"), and the
  /// verified code is what says the order was handed over.
  static bool canComplete(Map<String, dynamic>? stored) => stored != null && liveStatuses.contains(statusOf(stored));

  /// Completion writes the status only - never the card's copy of the
  /// delivery man, the remarks or anything else the dispatch, a driver or the
  /// verification wrote meanwhile.
  static Map<String, dynamic> completeFields() => const {'status': Constant.orderCompleted};

  /// An e-commerce order handed to a courier company.
  static Map<String, dynamic> courierFields({required String companyName, required String trackingId}) => {
    'status': Constant.orderShipped,
    'courierCompanyName': companyName.trim(),
    'courierTrackingId': trackingId.trim(),
  };

  /// Statuses in which a platform driver holds the order: offered and taken
  /// ("Driver Accepted"), then on its way. "Driver Pending" / "Driver
  /// Rejected" are an offer, not a driver: the dispatch Function writes
  /// `driverID` with the offer, so `driverID` alone does not mean someone has
  /// the order.
  static const Set<String> withDriverStatuses = {Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit};

  /// Whether a store card says the order is with a delivery man (rather than
  /// waiting for one).
  static bool isWithDeliveryMan(String? status, String? driverId) => !isBlankText(driverId) && withDriverStatuses.contains((status ?? '').trim());

  /// Whether the order detail shows the delivery man: one has the order
  /// ([withDriverStatuses]) or delivered it, and it is neither a takeaway nor
  /// a POS sale.
  static bool showsDeliveryMan({required String? status, required String? driverId, required bool takeAway, required bool isPosOrder}) {
    if (takeAway || isPosOrder || isBlankText(driverId)) return false;
    final String s = (status ?? '').trim();
    return withDriverStatuses.contains(s) || s == Constant.orderCompleted;
  }
}

/// The outcome of a guarded order write ([StoreOrderWrite]).
class OrderWriteOutcome {
  /// The fields were written.
  final bool written;

  /// The write itself failed (offline, permission, ...): nothing is known
  /// about the order.
  final bool failed;

  /// The order as stored when the write was decided - before it - or null
  /// when there is no such order or it could not be read.
  final Map<String, dynamic>? stored;

  const OrderWriteOutcome._({required this.written, required this.failed, this.stored});

  /// Written; [stored] is the order as it was just before.
  factory OrderWriteOutcome.written(Map<String, dynamic> stored) => OrderWriteOutcome._(written: true, failed: false, stored: stored);

  /// Not written: the order no longer allows it ([stored] says what it is
  /// now; null when it no longer exists).
  factory OrderWriteOutcome.refused(Map<String, dynamic>? stored) => OrderWriteOutcome._(written: false, failed: false, stored: stored);

  /// Not written: the write could not be made.
  factory OrderWriteOutcome.failure() => const OrderWriteOutcome._(written: false, failed: true);

  /// Refused because the order moved on (it still exists, in another state).
  bool get changedMeanwhile => !written && !failed && stored != null;

  /// The stored status of a refused order ('' when unknown).
  String get storedStatus => StoreOrderWrite.statusOf(stored);
}
