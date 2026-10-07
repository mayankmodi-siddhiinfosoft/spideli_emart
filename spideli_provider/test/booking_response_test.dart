import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/lang/app_ar.dart';
import 'package:spideliprovider/lang/app_en.dart';
import 'package:spideliprovider/services/booking_push.dart';
import 'package:spideliprovider/utils/booking_response.dart';

/// Provider Accept / Decline only while the booking is still "Order Placed"
/// (CANCEL-REASON-CONTRACT: a customer's cancellation is never overwritten,
/// and nobody is paid or refunded twice).
void main() {
  test('only a placed booking can be accepted or declined', () {
    expect(providerCanRespondToBooking(BookingStatus.placed), isTrue);
    for (final status in [
      BookingStatus.cancelled,
      BookingStatus.rejected,
      BookingStatus.accepted,
      BookingStatus.assigned,
      BookingStatus.ongoing,
      BookingStatus.completed,
      '',
      null,
    ]) {
      expect(providerCanRespondToBooking(status), isFalse, reason: '$status');
    }
  });

  test('the message says what happened to the booking', () {
    expect(bookingNoLongerPendingMessage(BookingStatus.cancelled), 'This booking was already cancelled');
    expect(bookingNoLongerPendingMessage(BookingStatus.rejected), 'This booking was already declined');
    for (final status in [BookingStatus.accepted, BookingStatus.assigned, BookingStatus.ongoing, BookingStatus.completed]) {
      expect(bookingNoLongerPendingMessage(status), 'This booking was already accepted');
    }
    expect(bookingNoLongerPendingMessage(''), 'This booking is no longer available.');
    expect(bookingNoLongerPendingMessage(null), 'This booking is no longer available.');
    expect(bookingNoLongerPendingMessage('Something else'), 'This booking is no longer available.');
  });

  test('every message is translated', () {
    for (final status in [BookingStatus.cancelled, BookingStatus.rejected, BookingStatus.accepted, '']) {
      final String key = bookingNoLongerPendingMessage(status);
      expect(enUS.containsKey(key), isTrue, reason: key);
      expect(lnAr.containsKey(key), isTrue, reason: key);
    }
  });
}
