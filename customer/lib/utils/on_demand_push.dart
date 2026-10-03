/// On-demand booking pushes (`.claude/ONDEMAND-NOTIFICATIONS.md`): the event
/// codes, the data payload every on-demand push carries, and how a received
/// one is recognised. Pure (no Firebase), so it is unit tested; sending is
/// `OnDemandNotifier`, opening a tapped one `OnDemandBookingOpener`.
abstract final class OnDemandPush {
  /// The routing key all three apps use for a booking push.
  static const String type = 'provider_order';

  static const String senderRole = 'customer';

  // Events the customer app sends (contract table, # in brackets).
  /// [1] The customer booked (every booking path, also after payment).
  static const String bookingPlaced = 'booking_placed';

  /// [2] The customer cancelled the booking.
  static const String bookingCancelledByCustomer = 'booking_cancelled_by_customer';

  /// [14] The customer paid an hourly booking from its details screen.
  static const String bookingPaid = 'booking_paid';

  /// [14] The customer paid the extra charges added by the provider / worker.
  static const String extraChargesPaid = 'extra_charges_paid';

  // Events the customer app receives.
  static const String providerAccepted = 'provider_accepted';
  static const String providerRejected = 'provider_rejected';
  static const String workerAssigned = 'worker_assigned';
  static const String workerAssignedCustomer = 'worker_assigned_customer';
  static const String workerUnassigned = 'worker_unassigned';
  static const String serviceIntransit = 'service_intransit';
  static const String stopTime = 'stop_time';
  static const String serviceCharges = 'service_charges';
  static const String serviceCompleted = 'service_completed';
  static const String workerAccepted = 'worker_accepted';
  static const String workerRejected = 'worker_rejected';

  /// Firestore templates (`dynamic_notification`) the customer app sends with.
  static const String templateBookingPlaced = 'booking_placed';
  static const String templateServiceCancelled = 'service_cancelled';
  static const String templateBookingPaid = 'booking_paid';
  static const String templateExtraChargesPaid = 'extra_charges_paid';

  /// The template each event the customer app sends goes out with: every
  /// push's title and body are the template's (`subject` / `message`).
  static const Map<String, String> templateFor = {
    bookingPlaced: templateBookingPlaced,
    bookingCancelledByCustomer: templateServiceCancelled,
    bookingPaid: templateBookingPaid,
    extraChargesPaid: templateExtraChargesPaid,
  };

  /// Every on-demand event code and template type. A push whose `type` or
  /// `event` is one of these is a booking push, also from an older sender
  /// that put the template type in `type` instead of `provider_order`.
  static const Set<String> events = {
    bookingPlaced,
    bookingCancelledByCustomer,
    bookingPaid,
    extraChargesPaid,
    providerAccepted,
    providerRejected,
    workerAssigned,
    workerAssignedCustomer,
    workerUnassigned,
    serviceIntransit,
    stopTime,
    serviceCharges,
    serviceCompleted,
    workerAccepted,
    workerRejected,
    templateServiceCancelled,
  };

  /// The data of an on-demand push: all strings, empty / null values dropped
  /// (the contract never sends nulls).
  static Map<String, String> payload({
    required String event,
    required String orderId,
    String? status,
    String? serviceId,
    String? serviceName,
    String? customerId,
    String? providerId,
    String? workerId,
    String role = senderRole,
  }) {
    final Map<String, String> out = {};
    void put(String key, String? value) {
      final String v = value?.trim() ?? '';
      if (v.isEmpty || v.toLowerCase() == 'null') return;
      out[key] = v;
    }

    put('type', type);
    put('event', event);
    put('orderId', orderId);
    put('status', status);
    put('serviceId', serviceId);
    put('serviceName', serviceName);
    put('customerId', customerId);
    put('providerId', providerId);
    put('workerId', workerId);
    put('senderRole', role);
    return out;
  }

  static String _field(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  /// Whether a received push is about an on-demand booking.
  static bool isOnDemand(Map<String, dynamic> data) {
    final String t = _field(data, 'type');
    if (t == type || events.contains(t)) return true;
    return events.contains(_field(data, 'event'));
  }

  /// The booking id of a push, or null when it has none.
  static String? orderIdOf(Map<String, dynamic> data) {
    for (final key in const ['orderId', 'order_id', 'orderID']) {
      final String value = _field(data, key);
      // A Firestore document id never contains '/'; anything else is junk.
      if (value.isNotEmpty && !value.contains('/')) return value;
    }
    return null;
  }

  /// A tapped push opens a booking only when it is the signed-in customer's
  /// own ([orderAuthorId] is the booking's `authorID`).
  static bool isOwnBooking({required String? orderAuthorId, required String? uid}) {
    final String a = orderAuthorId?.trim() ?? '';
    final String u = uid?.trim() ?? '';
    return a.isNotEmpty && a == u;
  }
}
