/// Which company account manages a carrier, and what a carrier parcel is
/// written with (`.claude/COMPANY-CARRIER-LINK.md`).
///
/// The link the admin writes is `users/{companyId}.carrierId` = the id of a
/// `delivery_carriers` document (older spelling `deliveryCarrierId`). A
/// carrier document also names its owner itself (`ownerId`), used only when
/// no company account carries the link. The app never creates or links a
/// carrier: the admin binds owners to carriers.
///
/// Pure, unit tested in `test/carrier_owner_link_test.dart`.
library;

abstract final class CarrierOwnerLink {
  /// `dynamic_notification` template of the push to the company owner when a
  /// carrier parcel is placed (or a priced quote is paid).
  static const String orderTemplate = 'carrier_parcel_order';

  /// `data.type` of that push: the driver app opens the owner's Orders list.
  static const String ownerPushType = 'carrier_parcel_order';

  static String _t(dynamic v) => (v ?? '').toString().trim();

  /// A company (fleet owner) account: `isOwner`, `driverType: company`, or
  /// the older `isCompany`.
  static bool isCompanyAccount(Map<String, dynamic> user) =>
      user['isOwner'] == true || _t(user['driverType']).toLowerCase() == 'company' || user['isCompany'] == true;

  /// The company account linked to [carrierId] among [users] (documents
  /// whose `carrierId` / `deliveryCarrierId` was queried), as `(id, data)`:
  /// only a company account counts (a company's drivers may carry the same
  /// `carrierId`). Falls back to [carrierDocOwnerId]; '' when none.
  static String pickOwner(String carrierId, Iterable<(String, Map<String, dynamic>)> users, {String? carrierDocOwnerId}) {
    final String id = carrierId.trim();
    if (id.isNotEmpty) {
      for (final (String uid, Map<String, dynamic> data) in users) {
        final bool linked = _t(data['carrierId']) == id || (_t(data['carrierId']).isEmpty && _t(data['deliveryCarrierId']) == id);
        if (uid.trim().isNotEmpty && linked && isCompanyAccount(data)) return uid.trim();
      }
    }
    return _t(carrierDocOwnerId);
  }

  /// A carrier parcel (booked with a delivery company).
  static bool isCarrierOrder({String? carrierId, String? carrierOwnerId}) => _t(carrierId).isNotEmpty || _t(carrierOwnerId).isNotEmpty;

  /// What a carrier parcel is written with, on every path (new order,
  /// scheduled, quote request, quote payment): nobody named, never sent to
  /// the dispatch — its company owner assigns a driver.
  static Map<String, dynamic> unassignedFields() => const <String, dynamic>{
        'sendToDriver': false,
        'driverId': null,
        'driverID': null,
      };
}
