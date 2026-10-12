/// The driver's "Pickup Parcel" (`ParcelTrackingService.onLegacyPickup`):
/// when it may move a parcel to `In Transit`.
///
/// Pure (raw order maps), unit tested in `test/parcel_flow_rules_test.dart`.
library;

abstract final class ParcelPickupRules {
  static const String _accepted = 'Driver Accepted';
  static const String _shipped = 'Order Shipped';
  static const String _inTransit = 'In Transit';

  static String _t(dynamic v) => (v ?? '').toString().trim();

  /// The order fields the pickup writes, read inside its transaction: the
  /// parcel must name [uid] (`driverId` / `driverID`) and be this driver's
  /// accepted job (`Driver Accepted` / `Order Shipped`, or already
  /// `In Transit` - a retried tap, which writes nothing), and must not have
  /// been cancelled or returned. Null = refused. The write used to be an
  /// unguarded `set(merge)` of `status: In Transit`, which turned a parcel the
  /// admin had cancelled (or one completed meanwhile) back into an active one.
  static Map<String, dynamic>? pickupFields(Map<String, dynamic>? order, String uid) {
    if (order == null || uid.trim().isEmpty) return null;
    final Set<String> named = {_t(order['driverId']), _t(order['driverID'])}..remove('');
    if (!named.contains(uid.trim())) return null;
    final String parcelStatus = _t(order['parcelStatus']);
    if (parcelStatus == 'Cancelled' || parcelStatus == 'Returned') return null;
    final String status = _t(order['status']);
    if (status == _inTransit) return const <String, dynamic>{};
    if (status == _accepted || status == _shipped) return const <String, dynamic>{'status': _inTransit};
    return null;
  }
}

/// The pushes a parcel's tracking steps send (`ParcelTrackingService`),
/// by `dynamic_notification` template: the apps hold no notification text
/// (`.claude/PUSH-CHANNELS.md`). They used to send fixed English text ("Parcel
/// Picked Up", ...), untranslated for an Arabic customer. A missing template
/// sends nothing and records nothing (the customer still sees the step live
/// on the tracking screen).
abstract final class ParcelStatusPush {
  /// Template to the customer for the tracking step [trackingStatus], or null.
  static String? customerTemplate(String? trackingStatus) {
    switch (trackingStatus) {
      case 'Collected':
        return 'parcel_picked_up';
      case 'In transit':
        return 'parcel_in_transit';
      case 'Arrived destination':
        return 'parcel_arrived_destination';
    }
    return null;
  }

  /// Template to the company owner when its driver picked a parcel up.
  static const String ownerPickedUpTemplate = 'carrier_parcel_picked_up';

  /// Template to the company owner when its driver completed a parcel.
  static const String ownerDeliveredTemplate = 'carrier_parcel_delivered';

  /// `data.type` of those two owner pushes: a tap opens the owner's Orders.
  static const String ownerPushType = 'carrier_parcel_status';

  /// The company owner told about a parcel's progress: the carrier's company
  /// (`carrierOwnerId`), else the company of the driver carrying it; '' when
  /// neither (an independent driver's own parcel).
  static String ownerToNotify({String? carrierOwnerId, String? driverOwnerId}) {
    final String carrier = (carrierOwnerId ?? '').trim();
    if (carrier.isNotEmpty) return carrier;
    return (driverOwnerId ?? '').trim();
  }
}
