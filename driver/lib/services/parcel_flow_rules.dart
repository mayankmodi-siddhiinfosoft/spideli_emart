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

/// What a completion attempt may do with the order
/// ([ParcelCompletionRules.claimDecision]).
enum ParcelCompletionClaim {
  /// Not completable (cancelled, returned, credited, someone else's).
  refused,

  /// First completion: write `Order Completed` and credit the earnings.
  claim,

  /// Completed earlier but its earnings were not finished: credit them now.
  resume,
}

/// A parcel's completion and its earnings (`ParcelTrackingService.completeOrder`).
///
/// The completion used to claim `driverCredited: true` BEFORE the wallet was
/// credited: an app stopped in between lost the earnings for good (no retry
/// could pay any more). Now the claim writes `Order Completed` with
/// `creditPending: true`; every wallet movement has a fixed row id per order
/// and purpose ([walletRowId], paid with `WalletOnce`, so a retry pays only
/// what is missing); and only once they are all done is the order marked
/// `driverCredited: true`, `creditPending: false`. An order left
/// `creditPending` is finished by the assigned driver's app later.
abstract final class ParcelCompletionRules {
  static const String completed = 'Order Completed';
  static const String _cancelled = 'Order Cancelled';
  static const String _rejected = 'Order Rejected';

  static String _t(dynamic v) => (v ?? '').toString().trim();

  static bool _namesMe(Map<String, dynamic> order, String uid) =>
      uid.trim().isNotEmpty && ({_t(order['driverId']), _t(order['driverID'])}..remove('')).contains(uid.trim());

  /// Read inside the claim transaction. [order] null = the order is gone.
  static ParcelCompletionClaim claimDecision(Map<String, dynamic>? order, String uid) {
    if (order == null) return ParcelCompletionClaim.refused;
    if (order['driverCredited'] == true) return ParcelCompletionClaim.refused;
    final String status = _t(order['status']);
    final String parcelStatus = _t(order['parcelStatus']);
    if (status == _cancelled || status == _rejected || parcelStatus == 'Cancelled' || parcelStatus == 'Returned') {
      return ParcelCompletionClaim.refused;
    }
    if (status == completed) {
      return mustResume(order, uid) ? ParcelCompletionClaim.resume : ParcelCompletionClaim.refused;
    }
    return ParcelCompletionClaim.claim;
  }

  /// A completion of [uid]'s whose earnings are still to be credited. Only
  /// orders marked `creditPending` by this flow: an order completed before it
  /// (no marker) is never paid again.
  static bool mustResume(Map<String, dynamic> order, String uid) =>
      _t(order['status']) == completed && order['creditPending'] == true && order['driverCredited'] != true && _namesMe(order, uid);

  /// The claim's write.
  static const Map<String, dynamic> claimFields = {'status': completed, 'creditPending': true};

  /// Written once every wallet movement of the completion is done.
  static const Map<String, dynamic> creditedFields = {'driverCredited': true, 'creditPending': false};

  /// The wallet movements of a completion, each paid once per order.
  static const String credit = 'credit';
  static const String commission = 'commission';
  static const String fixedTax = 'fixed_tax';
  static const String smsFee = 'sms_fee';
  static const String platformFee = 'platform_fee';

  /// `wallet/{id}` of one movement: the same for every try of the same order.
  static String walletRowId(String purpose, String orderId) => 'parcel_${purpose}_$orderId';
}
