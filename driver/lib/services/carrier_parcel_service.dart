import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// The outcome of an owner's assignment ([CarrierParcelService.assign]).
class CarrierAssignResult {
  final CarrierAssignCheck check;

  /// The assigned driver's push was accepted by FCM (false also when the
  /// template is missing or the driver has no token: the driver still finds
  /// the offer from Firestore).
  final bool pushed;

  /// The write itself failed (offline, refused).
  final bool failed;

  const CarrierAssignResult(this.check, {this.pushed = false, this.failed = false});

  bool get isDone => check == CarrierAssignCheck.ok && !failed;
}

/// Firestore side of the company owner's assignment of carrier parcels
/// ([CarrierParcelRules] holds the rules; `.claude/COMPANY-CARRIER-LINK.md`
/// section 5 the flow).
abstract final class CarrierParcelService {
  static DocumentReference<Map<String, dynamic>> _order(String id) => FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(id);

  static DocumentReference<Map<String, dynamic>> _user(String id) => FireStoreUtils.fireStore.collection(CollectionName.users).doc(id);

  /// The owner's drivers that may be assigned ([CarrierParcelRules.isAssignableDriver]),
  /// online first, then by name.
  static List<UserModel> assignableDrivers(List<UserModel> drivers, String ownerUid) {
    final List<UserModel> list = drivers
        .where((d) => (d.id ?? '').isNotEmpty && CarrierParcelRules.isAssignableDriver(ownerId: d.ownerId, companyId: ownerUid, isOwner: d.isOwner, role: d.role, active: d.active))
        .toList();
    list.sort((a, b) {
      final int online = (b.isActive == true ? 1 : 0) - (a.isActive == true ? 1 : 0);
      if (online != 0) return online;
      return a.fullName().toLowerCase().compareTo(b.fullName().toLowerCase());
    });
    return list;
  }

  /// Assigns parcel [orderId] to [driver] for the company [ownerUid] (linked
  /// to [ownerCarrierId]). One transaction re-reads the order, refuses
  /// anything [CarrierParcelRules.assignCheck] refuses, writes
  /// [CarrierParcelRules.assignFields] and adds the id to the driver's
  /// `orderRequestData` (an offer, D3). A replaced driver loses the id from
  /// their `orderRequestData` afterwards (best effort; their app's
  /// housekeeping drops it too). Then the driver gets the templated
  /// [CarrierParcelRules.assignedTemplate] push on the job channel, with the
  /// parcel-offer data the driver app opens as an incoming offer.
  static Future<CarrierAssignResult> assign({
    required String orderId,
    required UserModel driver,
    required String ownerUid,
    String? ownerCarrierId,
  }) async {
    final String driverId = (driver.id ?? '').trim();
    if (orderId.isEmpty || driverId.isEmpty || ownerUid.isEmpty) return const CarrierAssignResult(CarrierAssignCheck.gone, failed: true);
    final ({CarrierAssignCheck check, String? replaced, String? tracking}) outcome;
    try {
      outcome = await FireStoreUtils.fireStore.runTransaction<({CarrierAssignCheck check, String? replaced, String? tracking})>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(_order(orderId));
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        final CarrierAssignCheck check = CarrierParcelRules.assignCheck(data, ownerUid: ownerUid, ownerCarrierId: ownerCarrierId, driverId: driverId);
        if (check != CarrierAssignCheck.ok) return (check: check, replaced: null, tracking: null);
        tx.update(_order(orderId), CarrierParcelRules.assignFields(driverId: driverId, ownerUid: ownerUid));
        tx.update(_user(driverId), {
          'orderRequestData': FieldValue.arrayUnion([orderId]),
        });
        return (check: check, replaced: CarrierParcelRules.replacedDriver(data, driverId), tracking: data?['trackingNumber']?.toString());
      });
    } catch (e) {
      log("CarrierParcelService.assign($orderId -> $driverId) failed: $e");
      return const CarrierAssignResult(CarrierAssignCheck.ok, failed: true);
    }
    if (outcome.check != CarrierAssignCheck.ok) return CarrierAssignResult(outcome.check);

    final String? replaced = outcome.replaced;
    if (replaced != null && replaced.isNotEmpty) {
      try {
        await _user(replaced).update({
          'orderRequestData': FieldValue.arrayRemove([orderId]),
        });
      } catch (e) {
        log("CarrierParcelService: replaced driver's request not cleared: $e");
      }
    }

    bool pushed = false;
    try {
      // The live token (the list's copy may be old).
      final UserModel? fresh = await FireStoreUtils.getUserProfile(driverId);
      final String token = (fresh?.fcmToken ?? driver.fcmToken ?? '').trim();
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerUid);
      final Map<String, String> values = CarrierParcelRules.pushValues(
        orderId: orderId,
        trackingNumber: outcome.tracking,
        companyName: await CarrierDispatchService.companyNameFor(owner),
        driverName: (fresh ?? driver).fullName(),
      );
      pushed = await SendNotification.sendFcmMessage(
        CarrierParcelRules.assignedTemplate,
        token,
        {
          // The parcel-offer data (DispatchPush.parse): the driver app opens
          // the incoming-order dialog with its countdown.
          'type': DispatchKind.parcel.pushType,
          'orderId': orderId,
          'id': orderId,
          'click_action': DispatchPush.clickAction,
          'status': 'Driver Pending',
        },
        recipient: PushRecipient.driverJob,
        // Template carrier_parcel_assigned: {companyName}, {trackingNumber}, {driverName}.
        placeholders: values,
      );
    } catch (e) {
      log("CarrierParcelService: the assigned push failed: $e");
    }
    return CarrierAssignResult(CarrierAssignCheck.ok, pushed: pushed);
  }

  /// The owner of a carrier parcel the driver handed back ([order] as the
  /// reject transaction read it): `carrierOwnerId`, else [fallbackOwnerId]
  /// (the rejecting driver's company). Gets the templated
  /// [CarrierParcelRules.returnedTemplate] push. Never throws.
  static Future<void> notifyOwnerReturned(String orderId, Map<String, dynamic>? order, {String? fallbackOwnerId}) async {
    try {
      String ownerId = CarrierParcelRules.ownerOf(order);
      if (ownerId.isEmpty) ownerId = (fallbackOwnerId ?? '').trim();
      if (ownerId.isEmpty) return;
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerId);
      final UserModel? me = Constant.userModel;
      await SendNotification.sendFcmMessage(
        CarrierParcelRules.returnedTemplate,
        (owner?.fcmToken ?? '').trim(),
        {'type': CarrierParcelRules.ownerPushType, 'orderId': orderId},
        recipient: PushRecipient.driverJob,
        // Template carrier_parcel_returned: {driverName}, {trackingNumber}, {companyName}.
        placeholders: CarrierParcelRules.pushValues(
          orderId: orderId,
          trackingNumber: order?['trackingNumber']?.toString(),
          companyName: await CarrierDispatchService.companyNameFor(owner),
          driverName: me?.fullName(),
        ),
      );
    } catch (e) {
      log("CarrierParcelService: owner not told about the returned parcel: $e");
    }
  }
}
