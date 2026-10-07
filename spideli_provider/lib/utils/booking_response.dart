// Provider Accept / Decline of a new booking. Pure: no Flutter, no Firebase,
// so it is unit tested (test/booking_response_test.dart). The transaction that
// applies it is FireStoreUtils.updatePlacedBooking.
import 'package:spideliprovider/services/booking_push.dart';

/// A provider may accept or decline a booking only while it is still
/// "Order Placed". Any other status means someone answered first (the
/// customer cancelled, or this account already answered on another device):
/// writing then would overwrite their status and cancellation fields
/// (CANCEL-REASON-CONTRACT) and pay or refund a second time.
bool providerCanRespondToBooking(Object? status) => status?.toString() == BookingStatus.placed;

/// Untranslated message for a booking that is no longer pending, by the
/// status found when the provider answered ('' when the booking is gone).
String bookingNoLongerPendingMessage(Object? status) {
  switch (status?.toString() ?? '') {
    case BookingStatus.cancelled:
      return 'This booking was already cancelled';
    case BookingStatus.rejected:
      return 'This booking was already declined';
    case BookingStatus.accepted:
    case BookingStatus.assigned:
    case BookingStatus.ongoing:
    case BookingStatus.completed:
      return 'This booking was already accepted';
    default:
      return 'This booking is no longer available.';
  }
}
