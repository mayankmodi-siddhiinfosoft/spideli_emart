/// Carrier-bound parcels: the company owner assigns, never the dispatch.
///
/// A customer who books a parcel with a delivery company (a carrier) writes
/// the order unassigned, with `carrierId` (the `delivery_carriers` document)
/// and `carrierOwnerId` (the company account, `users/{ownerId}` with
/// `carrierId` = that carrier; `.claude/COMPANY-CARRIER-LINK.md`). Then:
///
///  1. the company OWNER sees it in its Orders list (waiting for assignment)
///     and assigns one of its own drivers ([assignCheck], [assignFields]):
///     `Driver Pending` naming that driver, `assignedBy` = the owner;
///  2. that driver answers with the normal offer flow (accept / reject /
///     timeout, `.claude/DRIVER-DISPATCH-CONTRACT.md` D2 / D3);
///  3. a reject or a timeout hands the parcel back to the OWNER, never to the
///     public dispatch ([returnToOwnerFields]): `Order Placed`, nobody named,
///     `sendToDriver: false`, the driver in `rejectedByDrivers`.
///
/// No other driver ever sees, is offered or may accept a carrier parcel: the
/// open parcel search hides it, an accept that is not the owner's assignment
/// is refused, and an offer for it that the owner did not make is handed
/// back to the owner unseen ([isForeignOffer]).
///
/// Pure (raw order maps, no Firebase), unit tested in
/// `test/carrier_parcel_rules_test.dart`.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/utils/document_verification.dart';

/// Why the owner may (not) assign a carrier parcel now.
enum CarrierAssignCheck {
  /// May be assigned (or reassigned) to the chosen driver.
  ok,

  /// The order is gone / unreadable.
  gone,

  /// Not this company's parcel.
  notMine,

  /// A quote that is not priced and paid yet.
  notPaid,

  /// A driver already accepted it (or it is under way): no reassignment.
  accepted,

  /// Completed, cancelled or rejected.
  ended,

  /// Already offered to that same driver and waiting for their answer.
  sameDriver,

  /// The chosen driver's documents are not verified yet: they could not
  /// accept the offer (the documents gate of every offer), so it would only
  /// time out and come back to the owner.
  driverNotVerified,
}

abstract final class CarrierParcelRules {
  /// `dynamic_notification` template (customer app -> the company owner):
  /// a new carrier parcel waits for assignment.
  static const String orderTemplate = 'carrier_parcel_order';

  /// `dynamic_notification` template (owner -> the chosen company driver):
  /// the owner assigned a parcel to them (sent with the parcel-offer data).
  static const String assignedTemplate = 'carrier_parcel_assigned';

  /// `{name}` values of the [assignedTemplate] / [returnedTemplate] text
  /// (PushTemplateText): `{trackingNumber}` (the order id when the parcel
  /// has none), `{companyName}`, `{driverName}`. An unknown name is left out,
  /// so the template shows its placeholder rather than an empty gap.
  static Map<String, String> pushValues({required String orderId, String? trackingNumber, String? companyName, String? driverName}) {
    String? clean(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    return {
      'trackingNumber': clean(trackingNumber) ?? orderId,
      if (clean(companyName) != null) 'companyName': clean(companyName)!,
      if (clean(driverName) != null) 'driverName': clean(driverName)!,
    };
  }

  /// `dynamic_notification` template (driver app -> the company owner): the
  /// assigned driver rejected or let the offer time out; assign again.
  static const String returnedTemplate = 'carrier_parcel_returned';

  /// `data.type` of the owner pushes: the driver app opens the owner's
  /// Orders list on a tap.
  static const String ownerPushType = 'carrier_parcel_order';

  /// Every `data.type` that opens the owner's Orders list (also the
  /// parcel-progress pushes, `ParcelStatusPush.ownerPushType`).
  static const Set<String> ownerPushTypes = {orderTemplate, returnedTemplate, 'carrier_parcel_status'};

  static const String _placed = 'Order Placed';
  static const String _pending = 'Driver Pending';
  static const String _rejected = 'Driver Rejected';
  static const String _quote = 'Quote Requested';

  /// A driver is working the parcel.
  static const List<String> workingStatuses = ['Driver Accepted', 'Order Shipped', 'In Transit'];

  /// Nothing is left to assign.
  static const List<String> endedStatuses = ['Order Completed', 'Order Cancelled', 'Order Rejected'];

  /// The owner may assign from these (Driver Pending = reassign before the
  /// driver answered).
  static const List<String> assignableStatuses = [_placed, _rejected, _pending];

  static String _t(dynamic value) => (value ?? '').toString().trim();

  static String status(Map<String, dynamic> order) => _t(order['status']);

  /// The company account the parcel belongs to (`carrierOwnerId`, or the
  /// `companyOwnerId` spelling); '' when the order names none.
  static String ownerOf(Map<String, dynamic>? order) {
    if (order == null) return '';
    final String owner = _t(order['carrierOwnerId']);
    return owner.isNotEmpty ? owner : _t(order['companyOwnerId']);
  }

  /// The parcel was booked with a carrier (delivery company).
  static bool isCarrierBound(Map<String, dynamic>? order) => order != null && (_t(order['carrierId']).isNotEmpty || ownerOf(order).isNotEmpty);

  static Set<String> _driverNames(Map<String, dynamic> order) => {_t(order['driverId']), _t(order['driverID'])}..remove('');

  static bool _names(Map<String, dynamic> order, String uid) => uid.isNotEmpty && _driverNames(order).contains(uid);

  /// The company [ownerUid] (linked to [ownerCarrierId]) owns this parcel:
  /// `carrierOwnerId` is the owner, or the order's carrier is the owner's.
  static bool belongsToCompany(Map<String, dynamic>? order, {required String ownerUid, String? ownerCarrierId}) {
    if (order == null || ownerUid.trim().isEmpty) return false;
    final String owner = ownerOf(order);
    if (owner.isNotEmpty) return owner == ownerUid.trim();
    final String carrier = _t(order['carrierId']);
    return carrier.isNotEmpty && carrier == _t(ownerCarrierId);
  }

  /// The owner assigned this parcel to [uid]: it names [uid] and carries the
  /// owner's `assignedBy` (the order's company when it names one).
  static bool ownerAssignedTo(Map<String, dynamic>? order, String uid) {
    if (order == null || !_names(order, uid)) return false;
    final String by = _t(order['assignedBy']);
    if (by.isEmpty) return false;
    final String owner = ownerOf(order);
    return owner.isEmpty || by == owner;
  }

  /// [uid] may see this parcel (search lists, offers, cards): every parcel
  /// without a carrier; a carrier parcel only once its owner assigned it to
  /// [uid], or while [uid] is already working it.
  static bool visibleToDriver(Map<String, dynamic>? order, String uid) {
    if (order == null) return false;
    if (!isCarrierBound(order)) return true;
    if (ownerAssignedTo(order, uid)) return true;
    return _names(order, uid) && workingStatuses.contains(status(order));
  }

  /// A `Driver Pending` carrier parcel naming [uid] that the owner did NOT
  /// assign (e.g. a dispatch function not yet updated to skip carrier
  /// parcels): never shown; handed back to the owner.
  static bool isForeignOffer(Map<String, dynamic>? order, String uid) =>
      order != null && isCarrierBound(order) && status(order) == _pending && _names(order, uid) && !ownerAssignedTo(order, uid);

  /// Waiting for the owner to pick a driver: placed (or handed back) and
  /// naming nobody.
  static bool awaitsOwner({required String? status, String? driverId, String? driverID}) {
    final String s = _t(status);
    return (s == _placed || s == _rejected) && _t(driverId).isEmpty && _t(driverID).isEmpty;
  }

  /// Offered to a driver by the owner, not answered yet.
  static bool awaitsDriver({required String? status, String? driverId, String? driverID}) =>
      _t(status) == _pending && (_t(driverId).isNotEmpty || _t(driverID).isNotEmpty);

  /// The owner may assign / reassign this parcel (status only; the
  /// transaction also runs [assignCheck]).
  static bool canAssignStatus(String? status) => assignableStatuses.contains(_t(status));

  /// Read inside the owner's assign transaction.
  static CarrierAssignCheck assignCheck(
    Map<String, dynamic>? order, {
    required String ownerUid,
    String? ownerCarrierId,
    required String driverId,
  }) {
    if (order == null) return CarrierAssignCheck.gone;
    if (!belongsToCompany(order, ownerUid: ownerUid, ownerCarrierId: ownerCarrierId)) return CarrierAssignCheck.notMine;
    final String s = status(order);
    if (endedStatuses.contains(s)) return CarrierAssignCheck.ended;
    if (workingStatuses.contains(s)) return CarrierAssignCheck.accepted;
    if (s == _quote) return CarrierAssignCheck.notPaid;
    if (!assignableStatuses.contains(s)) return CarrierAssignCheck.ended;
    if (s == _pending && _names(order, driverId)) return CarrierAssignCheck.sameDriver;
    return CarrierAssignCheck.ok;
  }

  /// The driver an assignment replaces (a reassign while `Driver Pending`),
  /// or null.
  static String? replacedDriver(Map<String, dynamic>? order, String newDriverId) {
    if (order == null || status(order) != _pending) return null;
    for (final String id in _driverNames(order)) {
      if (id != newDriverId) return id;
    }
    return null;
  }

  /// The owner's assignment, order side: an offer to [driverId] in the D3
  /// shape (`Driver Pending`, both driver fields), so the driver answers it
  /// with the normal accept / reject flow and countdown. [now] is the
  /// server timestamp (a test passes a fixed value). The driver comes off
  /// `rejectedByDrivers` (the owner chose them again) and any old `driver`
  /// snapshot is removed (written only by an accept).
  static Map<String, dynamic> assignFields({required String driverId, required String ownerUid, Object? now}) {
    final Object at = now ?? FieldValue.serverTimestamp();
    return <String, dynamic>{
      'status': _pending,
      'driverId': driverId,
      'driverID': driverId,
      'assignedBy': ownerUid,
      'assignedAt': at,
      'dispatchedAt': at,
      'sendToDriver': false,
      'rejectedByDrivers': FieldValue.arrayRemove([driverId]),
      'driver': FieldValue.delete(),
    };
  }

  /// A reject or timeout by [uid] of a carrier parcel: back to the owner,
  /// never to the public dispatch. A manual reject adds [reasonFields]
  /// (`driverRejections`); a timeout writes none.
  static Map<String, dynamic> returnToOwnerFields(String uid, {Map<String, dynamic>? reasonFields}) => <String, dynamic>{
        'status': _placed,
        'sendToDriver': false,
        'driverId': null,
        'driverID': null,
        'rejectedByDrivers': FieldValue.arrayUnion([uid]),
        ...?reasonFields,
      };

  /// The company driver may be given a parcel: their documents are verified
  /// (or verification does not apply to them) - exactly the documents gate a
  /// driver meets when accepting an offer ([DocumentVerification.isPending]):
  /// the overall status computed from the required documents ([overall] when
  /// the caller just computed it), never the flag alone.
  static bool canTakeAssignment(UserModel? driver, {DocumentOverallStatus? overall}) => driver != null && !DocumentVerification.isPending(driver, overall: overall);

  /// The owner's drivers that may be offered a parcel: driver accounts of
  /// this company (not the company itself), not disabled by the admin.
  static bool isAssignableDriver({required String? ownerId, required String companyId, bool? isOwner, String? role, bool? active}) {
    if (_t(ownerId) != companyId.trim() || companyId.trim().isEmpty) return false;
    if (isOwner == true) return false;
    final String r = _t(role);
    if (r.isNotEmpty && r != 'driver') return false;
    return active != false;
  }
}
