import 'package:customer/constant/constant.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:get/get.dart';

/// Which tab of the Ride, Rental and Parcel booking histories an order's
/// `status` is filed under.
///
/// Driver dispatch runs in the Cloud Functions (`cabDispatch`,
/// `rentalDispatch`, `parcelDispatch`): they move a new booking to
/// "Driver Pending" while a driver is being offered it, and a driver's
/// reject or timeout writes "Driver Rejected", which re-triggers the dispatch
/// for the next driver. Neither is terminal, so both are listed with the new
/// bookings that are still waiting for a driver - never as cancelled.
abstract final class BookingStatusTabs {
  /// Rides (cab and intercity): waiting for a driver.
  static const Set<String> rideNew = {Constant.orderPlaced, Constant.driverPending, Constant.driverRejected};

  /// Rides and rentals: a driver has the booking.
  static const Set<String> onGoing = {Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit};

  /// Rentals: waiting for a driver ("Order Accepted" is the legacy admin step).
  static const Set<String> rentalNew = {Constant.orderPlaced, Constant.orderAccepted, Constant.driverPending, Constant.driverRejected};

  /// Parcels: waiting for a price (quote request) or for a driver.
  static const Set<String> parcelNew = {Constant.orderPlaced, ParcelShipping.quoteRequestedStatus, Constant.driverPending, Constant.driverRejected};

  /// Parcels: a driver has accepted it, or it is on its way.
  static const Set<String> parcelInTransit = {Constant.orderAccepted, Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit};

  static const Set<String> completed = {Constant.orderCompleted};

  /// The only terminal "stopped" statuses of a booking.
  static const Set<String> cancelled = {Constant.orderRejected, Constant.orderCancelled};

  /// The dispatch is offering the booking to a driver, or looking for the
  /// next one after a reject / timeout: no driver is on it yet.
  static bool isWaitingForDriver(String? status) => status == Constant.driverPending || status == Constant.driverRejected;

  /// A status chip's text: the two dispatch states read as what they mean to
  /// the customer ("Looking for a driver" - never "Rejected"); any other
  /// status as it is.
  static String label(String? status) => isWaitingForDriver(status) ? 'Looking for a driver'.tr : (status ?? '').tr;

  /// The statuses where a booking's `driverId` is not (or not yet) its
  /// driver: before dispatch, while a driver is only being offered it, and
  /// after one declined (the dispatch nulls `driverId` then).
  static const Set<String> noDriverYet = {Constant.orderPlaced, Constant.driverPending, Constant.driverRejected, ParcelShipping.quoteRequestedStatus};

  /// Whether a driver accepted a booking in [status] whose `driverId` is
  /// [driverId] and whose `driver` snapshot has the id [acceptedDriverId].
  ///
  /// Never in [noDriverYet]. "Driver Accepted" or later: yes. A booking that
  /// ended ([cancelled]) may have ended while the dispatch was only OFFERING
  /// it, with the offered driver's id still in `driverId`; there the
  /// acceptance must be proven by the `driver` snapshot, which only the
  /// Driver app's accept writes (and its hand-back deletes): it must name
  /// that same driver.
  static bool driverAccepted(String? status, String? driverId, String? acceptedDriverId) {
    if (noDriverYet.contains(status)) return false;
    if (!cancelled.contains(status)) return true;
    final String accepted = (acceptedDriverId ?? '').trim();
    return accepted.isNotEmpty && accepted == (driverId ?? '').trim();
  }

  /// Whether [driverId] is the driver of a booking in [status]: a driver
  /// accepted it ([driverAccepted]; [acceptedDriverId] is the id in the
  /// order's `driver` snapshot). The Cloud Function writes the offered
  /// driver's id at "Driver Pending", before anyone accepted.
  static bool hasAssignedDriver(String? status, String? driverId, {required String? acceptedDriverId}) =>
      (driverId ?? '').trim().isNotEmpty && driverAccepted(status, driverId, acceptedDriverId);

  /// What a customer's cancel writes besides the status and the reason: from
  /// a status in which no driver accepted the booking yet, the driver the
  /// dispatch was only offering it to is taken off it (`driverId` and
  /// `driverID` set to null, as the Driver app's reject does), so the ended
  /// booking never names a driver who never had it. Nothing once a driver
  /// accepted.
  static Map<String, dynamic> offeredDriverCleared(String? status) =>
      noDriverYet.contains(status) ? const <String, dynamic>{'driverId': null, 'driverID': null} : const <String, dynamic>{};
}
