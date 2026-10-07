import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/utils/booking_status_tabs.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:get/get.dart';

/// What [ParcelCancellation.cancel] did: [error] is a message for the
/// customer (null on success); [before] is the order as it was read inside the
/// transaction, just before it was cancelled (what any refund is computed on).
class ParcelCancelResult {
  final String? error;
  final ParcelOrderModel? before;

  const ParcelCancelResult.failed(String this.error) : before = null;

  const ParcelCancelResult.done(ParcelOrderModel this.before) : error = null;

  bool get ok => error == null;
}

/// The customer's cancellation of a parcel, shared by the order screen and
/// the bookings list.
///
/// A field update inside a transaction that re-reads the order, like
/// `CabRideCancellation`: only `status`, the reason fields
/// (CANCEL-REASON-CONTRACT) and the `Cancelled` tracking event are written.
/// The whole model is never written back, so nothing the dispatch Cloud
/// Function, the driver or the SMS trigger wrote since the screen opened
/// (`driverId`, `rejectedByDrivers`, `smsSent`, `smsOptOut`, ...) is replaced
/// by a stale copy.
class ParcelCancellation {
  ParcelCancellation._();

  /// The order statuses a customer may cancel at: placed or an unpaid quote,
  /// and while `parcelDispatch` is offering it to a driver ("Driver Pending")
  /// or looking for the next one ("Driver Rejected"). Not once a driver has
  /// accepted it.
  static const Set<String> cancellableStatuses = {Constant.orderPlaced, ParcelShipping.quoteRequestedStatus, Constant.driverPending, Constant.driverRejected};

  /// Cancellable: one of [cancellableStatuses] and the parcel is still with
  /// the sender (not collected / dropped off).
  static bool canCancel(String? status, String? parcelStatus) => cancellableStatuses.contains(status) && ParcelShipping.beforeHandOver(parcelStatus);

  /// Whether the receiver-SMS fee (point 54) of [order] is kept on a cancel:
  /// only once a text actually went out (`smsSent`, written by the server-side
  /// trigger). Sending is conditional - the admin's `eventsEnabled`, the
  /// receiver's `smsOptOut`, the gateway (out of credit, bad number) or a
  /// trigger that has not run yet - so a fee for a text that was never sent
  /// is refunded with the rest.
  static bool keepsReceiverSmsFee(ParcelOrderModel order) => order.receiverSmsWasSent;

  /// Whether [order] was paid online, so a cancel refunds it to the wallet:
  /// not an unpaid quote request, a payment method was chosen, and it is not
  /// cash (the receiver-pays option is recorded as cash too).
  static bool wasPaidOnline(ParcelOrderModel order) {
    if (order.status == ParcelShipping.quoteRequestedStatus) return false;
    final String method = (order.paymentMethod ?? '').trim().toLowerCase();
    if (method.isEmpty || method == 'cod') return false;
    return order.paymentCollectByReceiver != true;
  }

  /// The wallet refund for cancelling [order] (as it was read just before the
  /// cancel): everything that was charged ([ParcelAmounts.total]: price after
  /// coupon, platform fee, taxes, scope tax and the SMS fee), less the SMS fee
  /// when a text was already sent ([keepsReceiverSmsFee]); 0 when nothing was
  /// paid online.
  static double refundAmount(ParcelOrderModel order) {
    if (!wasPaidOnline(order)) return 0;
    final double total = ParcelAmounts.of(order).total - (keepsReceiverSmsFee(order) ? order.smsChargeAmount : 0);
    return total > 0 ? total : 0;
  }

  /// Why [status] / [parcelStatus] can no longer be cancelled, for the
  /// customer.
  static String refusal(String? status, String? parcelStatus) {
    if (status == Constant.orderCancelled || status == Constant.orderRejected) return "This parcel order is no longer active".tr;
    if (!ParcelShipping.beforeHandOver(parcelStatus) || status == Constant.orderShipped || status == Constant.orderInTransit || status == Constant.orderCompleted) {
      return "This parcel has already been handed over and can no longer be cancelled.".tr;
    }
    return "A driver has already accepted this parcel".tr;
  }

  /// Cancels order [orderId] with the reason [reasonFields] (from
  /// `CancelReasonResult.toFields`). Never throws.
  static Future<ParcelCancelResult> cancel(String orderId, Map<String, dynamic> reasonFields) async {
    final ref = FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(orderId);
    try {
      return await FireStoreUtils.fireStore.runTransaction<ParcelCancelResult>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return ParcelCancelResult.failed("Booking not found".tr);
        final ParcelOrderModel before = ParcelOrderModel.fromJson(data);
        if (!canCancel(before.status, before.parcelStatus)) return ParcelCancelResult.failed(refusal(before.status, before.parcelStatus));
        tx.update(ref, {
          'status': Constant.orderCancelled,
          // No driver accepted it yet: the one the dispatch was only offering
          // it to comes off the order.
          ...BookingStatusTabs.offeredDriverCleared(before.status),
          ...reasonFields,
          // Tracked parcels also get the `Cancelled` tracking event.
          if (before.isTrackable) ...ParcelShippingService.appendFields(ParcelShippingService.event(ParcelShipping.cancelled)),
        });
        return ParcelCancelResult.done(before);
      });
    } catch (e) {
      log('ParcelCancellation failed: $e');
      return ParcelCancelResult.failed("Something went wrong. Please try again.".tr);
    }
  }
}
