import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:driver/services/company_cash_service.dart';
import 'package:driver/services/parcel_flow_rules.dart';
import 'package:driver/services/wallet_once.dart';
import 'package:flutter/foundation.dart';

/// Parcel tracking statuses (PARCEL-CONTRACT.md, spec 7.5) — `parcel_orders.parcelStatus`.
class ParcelTrackingStatus {
  static const String created = 'Created';
  static const String paid = 'Paid';
  static const String waitingDropOff = 'Waiting drop-off';
  static const String collected = 'Collected';
  static const String atOriginPoint = 'At origin pickup point';
  static const String inTransit = 'In transit';
  static const String arrivedDestination = 'Arrived destination';
  static const String atDestinationPoint = 'At destination pickup point';
  static const String outForDelivery = 'Out for delivery';
  static const String delivered = 'Delivered';
  static const String returned = 'Returned';
  static const String cancelled = 'Cancelled';

  /// Pipeline position; statuses are never written with a lower rank than the current one.
  static int rank(String? status) {
    switch (status) {
      case null:
      case created:
        return 0;
      case paid:
      case waitingDropOff:
        return 1;
      case collected:
      case atOriginPoint:
        return 2;
      case inTransit:
        return 3;
      case arrivedDestination:
        return 4;
      case atDestinationPoint:
      case outForDelivery:
        return 5;
      case delivered:
        return 6;
      case returned:
      case cancelled:
        return 7;
      default:
        return 0;
    }
  }

  static bool isTerminal(String? status) => status == delivered || status == returned || status == cancelled;
}

/// The next statuses a driver may record for a parcel, or the reason there are none.
class ParcelNextActions {
  final List<String> statuses;
  final String? reason;

  const ParcelNextActions(this.statuses, [this.reason]);
}

/// Scans, hand-overs, delivery proof and eMart completion of parcel orders (spec 4.2 steps 8–11, 9.1).
/// All writes are field updates / arrayUnion on the existing order (contract lesson 2).
class ParcelTrackingService {
  static const String qrPrefix = 'spideli:parcel:';

  static DocumentReference<Map<String, dynamic>> _doc(String id) => FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(id);

  // ── Scan resolution ────────────────────────────────────────────────────

  /// Pulls the order id out of a public tracking URL (`.../track-parcel/{id}`),
  /// whatever host it carries. Null when the value is not one.
  ///
  /// The customer app's receipt QR encodes that URL when a site URL is
  /// configured, because the person scanning a parcel label is usually the
  /// receiver, who has no account (WEB spec §15). A driver scanning the same
  /// label must still land on the order.
  static String? orderIdFromTrackingUrl(String value) {
    final String v = value.trim().toLowerCase();
    if (!v.startsWith('http://') && !v.startsWith('https://')) return null;
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final List<String> parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final int i = parts.lastIndexWhere((s) => s.toLowerCase() == 'track-parcel');
    if (i < 0 || i + 1 >= parts.length) return null;
    return Uri.decodeComponent(parts[i + 1]).trim();
  }

  /// Accepts a `qrValue` (a `track-parcel/{id}` URL or `spideli:parcel:<id>`),
  /// a raw `trackingNumber` or a raw order id.
  static Future<ParcelOrderModel?> resolveScan(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      if (value.toLowerCase().startsWith(qrPrefix)) {
        return await getById(value.substring(qrPrefix.length).trim());
      }
      final String? fromUrl = orderIdFromTrackingUrl(value);
      if (fromUrl != null) return await getById(fromUrl);
      for (final candidate in {value, value.toUpperCase()}) {
        final q = await FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).where('trackingNumber', isEqualTo: candidate).limit(1).get();
        if (q.docs.isNotEmpty) return ParcelOrderModel.fromJson(q.docs.first.data());
      }
      return await getById(value);
    } catch (e) {
      debugPrint('ParcelTrackingService.resolveScan $e');
      return null;
    }
  }

  static Future<ParcelOrderModel?> getById(String id) async {
    if (id.isEmpty || id.contains('/')) return null;
    final snap = await _doc(id).get();
    if (snap.exists && snap.data() != null) {
      final data = snap.data()!;
      data['id'] ??= snap.id;
      return ParcelOrderModel.fromJson(data);
    }
    final q = await FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).where('id', isEqualTo: id).limit(1).get();
    if (q.docs.isNotEmpty) return ParcelOrderModel.fromJson(q.docs.first.data());
    return null;
  }

  // ── Who may scan ───────────────────────────────────────────────────────

  /// The company (owner) id this driver belongs to, or its own id when it is the company account.
  static String? myCompanyId() {
    final user = Constant.userModel;
    if (user == null) return null;
    if (user.isOwner == true) return FireStoreUtils.getCurrentUid();
    if (user.ownerId != null && user.ownerId!.isNotEmpty) return user.ownerId;
    return null;
  }

  static bool isAssignedToMe(ParcelOrderModel o) => o.driverId != null && o.driverId == FireStoreUtils.getCurrentUid();

  /// Assigned to me, or to a driver of my company (hand-over scans only).
  static bool isInMyFleet(ParcelOrderModel o) {
    if (isAssignedToMe(o)) return true;
    final company = myCompanyId();
    if (company == null || o.driverId == null || o.driverId!.isEmpty) return false;
    return o.driverId == company || o.driver?.ownerId == company;
  }

  // ── Status logic ───────────────────────────────────────────────────────

  static bool _isCancelled(ParcelOrderModel o) =>
      o.status == Constant.orderCancelled || o.status == Constant.orderRejected || o.parcelStatus == ParcelTrackingStatus.cancelled;

  /// Tracking status, derived from the eMart status for parcels created before the contract.
  static String? currentStatus(ParcelOrderModel o) {
    if (o.parcelStatus != null && o.parcelStatus!.isNotEmpty) return o.parcelStatus;
    if (o.status == Constant.orderCompleted) return ParcelTrackingStatus.delivered;
    if (o.status == Constant.orderInTransit || o.status == Constant.orderShipped) return ParcelTrackingStatus.collected;
    return null;
  }

  static bool _isCityScope(ParcelOrderModel o) => o.scope == null || o.scope == 'city';

  static String finalLegStatus(ParcelOrderModel o) =>
      o.deliveryMethod == 'pickup_point' ? ParcelTrackingStatus.atDestinationPoint : ParcelTrackingStatus.outForDelivery;

  /// The statuses this driver may record next (spec 4.2 steps 8–9, contract "Driver app").
  static ParcelNextActions nextActions(ParcelOrderModel o) {
    if (_isCancelled(o)) return const ParcelNextActions([], 'This parcel was cancelled.');
    if (!isInMyFleet(o)) return const ParcelNextActions([], 'This parcel is not assigned to you or your company.');
    // Final step recorded but the completion (Order Completed + earnings) did not go through: allow a retry.
    if (awaitingCompletion(o)) return ParcelNextActions([driverFinalStatus(o)]);
    final current = currentStatus(o);
    if (ParcelTrackingStatus.isTerminal(current)) return ParcelNextActions([], '${'Parcel is'} $current.');
    if (o.status == Constant.orderCompleted) return const ParcelNextActions([], 'Your part of this delivery is complete.');

    final rank = ParcelTrackingStatus.rank(current);
    final finalLeg = finalLegStatus(o);
    List<String> next;
    if (rank <= 1) {
      if (o.pickupMethod == 'pickup_point') {
        return const ParcelNextActions([], 'Waiting for the sender to drop the parcel off at the origin pickup point.');
      }
      if (o.quoteRequested == true && o.manualPrice == null) {
        return const ParcelNextActions([], 'Waiting for the quote to be priced and paid.');
      }
      next = [ParcelTrackingStatus.collected];
    } else if (rank == 2) {
      next = [ParcelTrackingStatus.inTransit, if (_isCityScope(o)) finalLeg];
    } else if (rank == 3) {
      next = [ParcelTrackingStatus.arrivedDestination, if (_isCityScope(o)) finalLeg];
    } else if (rank == 4) {
      next = [finalLeg];
    } else if (current == ParcelTrackingStatus.outForDelivery) {
      next = [ParcelTrackingStatus.delivered];
    } else {
      return const ParcelNextActions([], 'The receiver collects the parcel at the pickup point with the pickup code.');
    }

    // The final step (and its eMart completion/earnings) belongs to the assigned driver only.
    if (!isAssignedToMe(o)) {
      next = next.where((s) => !isDriverFinalStep(o, s)).toList();
      if (next.isEmpty) return const ParcelNextActions([], 'Only the assigned driver can complete this delivery.');
    }
    return ParcelNextActions(next);
  }

  /// The driver's last step: `Delivered` for home delivery, the hand-over at the destination pickup point otherwise.
  static bool isDriverFinalStep(ParcelOrderModel o, String status) => status == driverFinalStatus(o);

  static String driverFinalStatus(ParcelOrderModel o) =>
      o.deliveryMethod == 'pickup_point' ? ParcelTrackingStatus.atDestinationPoint : ParcelTrackingStatus.delivered;

  /// Assigned to me, the final step (or later) is recorded, but the order was never completed / credited
  /// (or it was completed and its earnings are still owed: `creditPending`).
  static bool awaitingCompletion(ParcelOrderModel o) {
    if (!isAssignedToMe(o) || o.driverCredited == true || _isCancelled(o)) return false;
    if (o.status == Constant.orderCompleted) return o.creditPending == true;
    final current = currentStatus(o);
    if (current == ParcelTrackingStatus.returned) return false;
    return o.parcelStatus != null && ParcelTrackingStatus.rank(current) >= ParcelTrackingStatus.rank(driverFinalStatus(o));
  }

  /// Same city, home pickup and home delivery (today's eMart parcel): the legacy button completes it in one tap.
  static bool _isSameCityHome(ParcelOrderModel o) => _isCityScope(o) && o.pickupMethod != 'pickup_point' && o.deliveryMethod != 'pickup_point';

  /// Receiver code usable as the delivery OTP (the order's `pickupCode`; the parcel flow has no other OTP).
  static String? receiverCode(ParcelOrderModel o) {
    if (o.pickupCode != null && o.pickupCode!.trim().isNotEmpty) return o.pickupCode!.trim();
    return null;
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _event(String status, {String? pickupPointId, String? note}) {
    final loc = Constant.locationDataFinal;
    return {
      'status': status,
      'at': Timestamp.now(),
      'by': FireStoreUtils.getCurrentUid(),
      'role': 'driver',
      if (pickupPointId != null && pickupPointId.isNotEmpty) 'pickupPointId': pickupPointId,
      if (note != null && note.isNotEmpty) 'note': note,
      if (loc?.latitude != null) 'lat': loc!.latitude,
      if (loc?.longitude != null) 'lng': loc!.longitude,
    };
  }

  /// Appends a tracking event and sets `parcelStatus` (field updates only). Re-reads the order first so a
  /// status is never written backwards. Returns the refreshed order, or throws a user-facing message.
  static Future<ParcelOrderModel> recordStatus(ParcelOrderModel order, String status, {Map<String, dynamic>? deliveryProof, String? note}) async {
    final fresh = await getById(order.id ?? '');
    if (fresh == null) throw 'Parcel not found.';
    if (!nextActions(fresh).statuses.contains(status)) {
      throw 'This parcel is already at "${currentStatus(fresh) ?? fresh.status}". Scan again to refresh.';
    }
    await _applyStatus(fresh, status, deliveryProof: deliveryProof, note: note);
    return (await getById(fresh.id!)) ?? fresh;
  }

  /// Writes [status] unless it is already recorded (a completion retry), then completes the order on the
  /// driver's final step. The completion itself is idempotent ([completeOrder]).
  static Future<void> _applyStatus(ParcelOrderModel fresh, String status, {Map<String, dynamic>? deliveryProof, String? note}) async {
    if (ParcelTrackingStatus.rank(currentStatus(fresh)) < ParcelTrackingStatus.rank(status) || fresh.parcelStatus == null) {
      await _writeStatus(fresh, status, deliveryProof: deliveryProof, note: note);
    }
    if (isDriverFinalStep(fresh, status) && isAssignedToMe(fresh) && (fresh.status != Constant.orderCompleted || fresh.creditPending == true)) {
      await completeOrder(fresh);
    }
  }

  static Future<void> _writeStatus(ParcelOrderModel o, String status, {Map<String, dynamic>? deliveryProof, String? note}) async {
    String? pointId;
    if (status == ParcelTrackingStatus.atDestinationPoint) pointId = o.destinationPickupPointId;
    if (status == ParcelTrackingStatus.atOriginPoint) pointId = o.originPickupPointId;
    final data = <String, dynamic>{
      'parcelStatus': status,
      'trackingEvents': FieldValue.arrayUnion([_event(status, pickupPointId: pointId, note: note)]),
      'deliveryProof': ?deliveryProof,
    };
    // Keep the eMart status in sync: a picked-up parcel is "In Transit" (same as the Pickup Parcel button).
    if (o.status == Constant.driverAccepted && ParcelTrackingStatus.rank(status) >= 2 && !isDriverFinalStep(o, status)) {
      data['status'] = Constant.orderInTransit;
    }
    // Field update only: the receiver's SMS is sent by the server trigger on
    // `parcel_orders` (sendReceiverSms / smsSent / settings/SMSGateway
    // templates, decision D5). The app never composes SMS wording, never
    // queues a message and never writes `smsSent`.
    await _doc(o.id!).update(data);
    o.parcelStatus = status;
    if (data['status'] != null) o.status = data['status'];

    // The customer (and, on pickup, the company owner) are told by template
    // (ParcelStatusPush): no notification text lives in the app.
    try {
      final String? template = ParcelStatusPush.customerTemplate(status);
      if (template != null) {
        await SendNotification.notifyCustomer(template,
            customerId: o.authorID ?? o.author?.id, embeddedToken: o.author?.fcmToken, payload: {'type': 'parcel_order', 'orderId': o.id ?? '', 'parcelStatus': status}, status: o.status);
      }
      if (status == ParcelTrackingStatus.collected) await _notifyOwner(o, ParcelStatusPush.ownerPickedUpTemplate);
    } catch (e) {
      debugPrint('ParcelTrackingService._writeStatus notification error: $e');
    }
  }

  /// The templated progress push to the parcel's company owner
  /// ([ParcelStatusPush.ownerToNotify]), on the owner's general channel; a
  /// tap opens its Orders list. Never throws.
  static Future<void> _notifyOwner(ParcelOrderModel o, String template) async {
    try {
      final String ownerUid = ParcelStatusPush.ownerToNotify(carrierOwnerId: o.carrierOwnerId, driverOwnerId: o.driver?.ownerId ?? Constant.userModel?.ownerId);
      if (ownerUid.isEmpty || ownerUid == FireStoreUtils.getCurrentUid()) return;
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerUid);
      await SendNotification.sendFcmMessage(template, (owner?.fcmToken ?? '').trim(), {'type': ParcelStatusPush.ownerPushType, 'orderId': o.id ?? ''},
          recipient: PushRecipient.driver);
    } catch (e) {
      debugPrint('ParcelTrackingService owner push $template failed: $e');
    }
  }

  /// Hook for the existing "Pickup Parcel" button: also records `Collected` (home pickup) or, for a parcel
  /// taken from the origin pickup point, `In transit`. Returns an error message when the pickup is not possible.
  static Future<String?> onLegacyPickup(ParcelOrderModel o) async {
    final current = currentStatus(o);
    if (o.pickupMethod == 'pickup_point' && ParcelTrackingStatus.rank(current) <= 1 && o.parcelStatus != null) {
      return 'The sender has not dropped the parcel off at the origin pickup point yet.';
    }
    // In a transaction on the live order: only this driver's accepted job
    // moves to In Transit (ParcelPickupRules), never a cancelled / completed
    // / reassigned one.
    final String uid = FireStoreUtils.getCurrentUid();
    final bool allowed = await FireStoreUtils.fireStore.runTransaction<bool>((tx) async {
      final snap = await tx.get(_doc(o.id!));
      final Map<String, dynamic>? fields = ParcelPickupRules.pickupFields(snap.data(), uid);
      if (fields == null) return false;
      if (fields.isNotEmpty) tx.update(_doc(o.id!), fields);
      return true;
    });
    if (!allowed) return 'This parcel can no longer be picked up.';
    o.status = Constant.orderInTransit;
    try {
      if (ParcelTrackingStatus.rank(current) <= 1) {
        await _writeStatus(o, ParcelTrackingStatus.collected);
      } else if (current == ParcelTrackingStatus.atOriginPoint) {
        await _writeStatus(o, ParcelTrackingStatus.inTransit);
      }
    } catch (e) {
      debugPrint('ParcelTrackingService.onLegacyPickup $e');
    }
    return null;
  }

  /// Re-reads the order and returns it when the existing "Deliver Parcel" button may record the driver's final
  /// step; throws a user-facing message otherwise. Same-city home-to-home parcels complete in one tap once
  /// picked up (today's flow); any other parcel only when its next scan step is the final one.
  static Future<ParcelOrderModel> prepareLegacyDeliver(ParcelOrderModel o) async {
    final fresh = await getById(o.id ?? '');
    if (fresh == null) throw 'Parcel not found.';
    if (_isCancelled(fresh) || fresh.parcelStatus == ParcelTrackingStatus.returned) throw 'This parcel was cancelled or returned.';
    if (fresh.status == Constant.orderCompleted) throw 'This delivery is already completed.';
    if (!isAssignedToMe(fresh)) throw 'Only the assigned driver can complete this delivery.';
    final finalStatus = driverFinalStatus(fresh);
    if (nextActions(fresh).statuses.contains(finalStatus)) return fresh;
    final current = currentStatus(fresh);
    final pickedUp = ParcelTrackingStatus.rank(current) >= 2 || fresh.status == Constant.orderInTransit;
    if (_isSameCityHome(fresh) && pickedUp && !ParcelTrackingStatus.isTerminal(current)) return fresh;
    throw 'Scan the parcel to update its status';
  }

  /// Hook for the existing "Deliver Parcel" button: records the driver's final tracking step
  /// (`Delivered` with proof, or the hand-over at the destination pickup point) and completes the order.
  static Future<void> onLegacyDeliver(ParcelOrderModel o, {Map<String, dynamic>? deliveryProof}) async {
    final fresh = await prepareLegacyDeliver(o);
    await _applyStatus(fresh, driverFinalStatus(fresh), deliveryProof: deliveryProof);
  }

  /// Sets `Order Completed` with `creditPending: true` in one transaction ([ParcelCompletionRules]): `claim` =
  /// this call completed the order and must credit the earnings; `resume` = it was completed earlier and its
  /// earnings are still owed; `refused` = nothing to do.
  static Future<ParcelCompletionClaim> _claimCompletion(String orderId) async {
    final String uid = FireStoreUtils.getCurrentUid();
    return FireStoreUtils.fireStore.runTransaction<ParcelCompletionClaim>((transaction) async {
      final ref = _doc(orderId);
      final snap = await transaction.get(ref);
      final ParcelCompletionClaim decision = ParcelCompletionRules.claimDecision(snap.exists ? snap.data() : null, uid);
      if (decision == ParcelCompletionClaim.claim) transaction.update(ref, ParcelCompletionRules.claimFields);
      return decision;
    });
  }

  /// The parcel leaves the signed-in driver's `inProgressOrderID` (spec §4:
  /// accepted and active only; the dispatch Cloud Function reads it as
  /// "busy"). Field-level, never fatal.
  static Future<void> _releaseFromDriver(String orderId) async {
    final String uid = FireStoreUtils.getCurrentUid();
    await FireStoreUtils.updateUserFields(uid, {
      'inProgressOrderID': FieldValue.arrayRemove([orderId]),
    });
  }

  /// The existing eMart completion: `Order Completed`, wallet credit, commission, customer notification and
  /// referral — at most once per order (a stale list, a second screen or a retry cannot pay twice), and never
  /// lost: the earnings are owed (`creditPending`) until every wallet movement is done ([_creditCompletion]).
  static Future<void> completeOrder(ParcelOrderModel o) async {
    final ParcelCompletionClaim claim = await _claimCompletion(o.id!);
    if (claim == ParcelCompletionClaim.refused) {
      final fresh = await getById(o.id!);
      if (fresh?.status == Constant.orderCompleted) {
        o.status = Constant.orderCompleted;
        await _releaseFromDriver(o.id!);
        return;
      }
      // Cancelled or returned meanwhile: not this driver's active job either.
      if (fresh == null || _isCancelled(fresh) || fresh.parcelStatus == ParcelTrackingStatus.returned) {
        await _releaseFromDriver(o.id!);
      }
      throw 'This parcel can no longer be completed.';
    }
    o.status = Constant.orderCompleted;
    o.creditPending = true;
    await _releaseFromDriver(o.id!);
    // The earnings: a failure here leaves the order `creditPending`, finished later ([resumePendingCredits]).
    try {
      await _creditCompletion(o);
    } catch (e) {
      debugPrint('ParcelTrackingService.completeOrder credit pending $e');
    }
    // A resumed completion already told the customer and the owner the first time.
    if (claim == ParcelCompletionClaim.resume) return;
    try {
      final Map<String, dynamic> payLoad = <String, dynamic>{"type": "parcel_order", "orderId": o.id};
      await SendNotification.notifyCustomer(Constant.parcelCompleted,
          customerId: o.authorID ?? o.author?.id, embeddedToken: o.author?.fcmToken, payload: payLoad, status: o.status);

      // The company owner of a carrier / fleet parcel (template).
      await _notifyOwner(o, ParcelStatusPush.ownerDeliveredTemplate);
    } catch (e) {
      debugPrint('ParcelTrackingService.completeOrder notification $e');
    }
  }

  /// Everything the completion owes, each part once per order so a retry pays only what is missing: the wallet
  /// movements, the company cash collection (deduplicated by order) and the referral. Then, and only then, the
  /// order is marked `driverCredited`. Throws when a part failed (the order stays `creditPending`).
  static Future<void> _creditCompletion(ParcelOrderModel o) async {
    await _updateWalletAmount(o);

    // Record COD collection in Company Cash Ledger if driver belongs to a company
    final bool isCod = o.paymentMethod == PaymentGateway.cod.name;
    // The snapshot written at accept, else the signed-in (assigned) driver:
    // a panel-assigned parcel may carry no snapshot.
    final UserModel? driver = (o.driver?.ownerId ?? '').isNotEmpty ? o.driver : Constant.userModel;
    if (isCod && driver?.ownerId != null && driver!.ownerId!.isNotEmpty) {
      final ParcelAmounts amounts = ParcelAmounts.of(o);
      await CompanyCashService.recordCodCollection(
        order: o,
        driver: driver,
        amount: amounts.total,
      );
    }

    if (await FireStoreUtils.getParcelFirstOrderOrNOt(o)) {
      await FireStoreUtils.updateParcelReferralAmount(o);
    }

    await _doc(o.id!).update(ParcelCompletionRules.creditedFields);
    o.driverCredited = true;
    o.creditPending = false;
  }

  /// Completions of this driver whose earnings were not finished (the app stopped, or a write failed, between
  /// the claim and the credit): finish them now. Called when the parcel home opens. Never throws.
  static Future<void> resumePendingCredits() async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) return;
    try {
      final snap = await FireStoreUtils.fireStore
          .collection(CollectionName.parcelOrders)
          .where('driverId', isEqualTo: uid)
          .where('creditPending', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        try {
          final ParcelOrderModel o = ParcelOrderModel.fromJson(doc.data());
          if (o.id == null) continue;
          if (await _claimCompletion(o.id!) != ParcelCompletionClaim.resume) continue;
          await _creditCompletion(o);
        } catch (e) {
          debugPrint('ParcelTrackingService.resumePendingCredits ${doc.id} $e');
        }
      }
    } catch (e) {
      debugPrint('ParcelTrackingService.resumePendingCredits $e');
    }
  }

  /// One wallet movement of the completion of [o]: the `wallet` row and the balance change, in one transaction,
  /// at most once per order and [purpose] ([WalletOnce]).
  static Future<void> _payOnce(ParcelOrderModel o, String purpose, WalletTransactionModel row, num balanceChange) async {
    final String rowId = ParcelCompletionRules.walletRowId(purpose, o.id!);
    row.id = rowId;
    await WalletOnce.pay(rowId: rowId, row: row.toJson(), userId: row.userId, amount: balanceChange);
  }

  static Future<void> _updateWalletAmount(ParcelOrderModel orderModel) async {
    double totalTax = 0.0;
    double adminComm = 0.0;
    double discount = 0.0;
    double subTotal = 0.0;
    double totalAmount = 0.0;

    // subTotal excludes the fixed scope tax. When the commission was added to the customer's price
    // (commissionAsExtra) the customer app records it as a fixed adminCommission equal to that amount,
    // so the driver nets subTotal − commission once (see PARCEL-CONTRACT pricing).
    subTotal = double.tryParse(orderModel.subTotal ?? '') ?? 0.0;
    discount = double.tryParse(orderModel.discount ?? '') ?? 0.0;

    // The order taxes as the customer paid them (ParcelAmounts: none on the
    // commission added as an extra).
    final ParcelAmounts amounts = ParcelAmounts.of(orderModel);
    totalTax = amounts.orderTax;

    if ((orderModel.adminCommission ?? '').isNotEmpty) {
      adminComm = Constant.calculateAdminCommission(
          amount: (subTotal - discount).toString(),
          adminCommissionType: orderModel.adminCommissionType.toString(),
          adminCommission: orderModel.adminCommission ?? '0');
    }

    final String walletUserId = ParcelAmounts.walletUserFor(
        snapshotOwnerId: orderModel.driver?.ownerId, myOwnerId: Constant.userModel?.ownerId, myUid: FireStoreUtils.getCurrentUid());

    // Fixed intercity / intercountry tax: platform revenue, outside subTotal (never credited to the driver).
    final double scopeTax = (orderModel.parcelScopeTax ?? 0).toDouble();
    final String paymentMethod = orderModel.paymentMethod ?? '';
    final bool isCod = paymentMethod == PaymentGateway.cod.name;

    // The door / pickup-point charges (priceBreakdown.pickupCharge +
    // deliveryCharge) are the Owner's prices for the courier's work
    // (app-spec-parcel-pricing 3.2): paid online, they are credited with the
    // delivery charge; in cash the driver already holds them (they are not in
    // ParcelAmounts.platformShareOfCash).
    final double options = amounts.options;
    // = ParcelAmounts.onlineCredit (company reports read the same rule).
    totalAmount = ((subTotal - discount) + totalTax + options);
    if (!isCod) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: totalAmount,
          date: Timestamp.now(),
          paymentMethod: paymentMethod,
          transactionUser: "driver",
          userId: walletUserId,
          isTopup: true,
          orderId: orderModel.id,
          note: "Booking amount credited",
          paymentStatus: "success");

      await _payOnce(orderModel, ParcelCompletionRules.credit, transactionModel, totalAmount);
    }

    WalletTransactionModel transactionModel = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: adminComm,
        date: Timestamp.now(),
        paymentMethod: paymentMethod,
        transactionUser: "driver",
        userId: walletUserId,
        isTopup: false,
        orderId: orderModel.id,
        note: "Admin commission deducted",
        paymentStatus: "success");

    await _payOnce(orderModel, ParcelCompletionRules.commission, transactionModel, -adminComm);

    // Cash collected by the driver includes the fixed scope tax, which belongs to the platform.
    if (isCod && scopeTax > 0) {
      WalletTransactionModel taxTransaction = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: scopeTax,
          date: Timestamp.now(),
          paymentMethod: paymentMethod,
          transactionUser: "driver",
          userId: walletUserId,
          isTopup: false,
          orderId: orderModel.id,
          note: "Parcel fixed tax deducted",
          paymentStatus: "success");

      await _payOnce(orderModel, ParcelCompletionRules.fixedTax, taxTransaction, -scopeTax);
    }

    // Likewise the receiver-SMS fee (point 54): collected in cash with the
    // total, never the driver's.
    final double smsCharge = orderModel.smsChargeAmount;
    if (isCod && smsCharge > 0) {
      WalletTransactionModel smsTransaction = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: smsCharge,
          date: Timestamp.now(),
          paymentMethod: paymentMethod,
          transactionUser: "driver",
          userId: walletUserId,
          isTopup: false,
          orderId: orderModel.id,
          note: "Parcel receiver SMS fee deducted",
          paymentStatus: "success");

      await _payOnce(orderModel, ParcelCompletionRules.smsFee, smsTransaction, -smsCharge);
    }

    // And the platform fee with its taxes: the customer's total includes them
    // (ParcelAmounts), so the cash the driver collects does too, and they are
    // the platform's — as for a delivery order, where the cash total the
    // driver owes back includes the platform fee.
    final double platformFeeShare = amounts.platformFee + amounts.platformTax;
    if (isCod && platformFeeShare > 0) {
      WalletTransactionModel feeTransaction = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: platformFeeShare,
          date: Timestamp.now(),
          paymentMethod: paymentMethod,
          transactionUser: "driver",
          userId: walletUserId,
          isTopup: false,
          orderId: orderModel.id,
          note: "Parcel platform fee deducted",
          paymentStatus: "success");

      await _payOnce(orderModel, ParcelCompletionRules.platformFee, feeTransaction, -platformFeeShare);
    }
  }

  // ── Manifest ───────────────────────────────────────────────────────────

  /// Driver ids whose parcels this account sees on its manifest: itself, plus its company fleet.
  static Future<Map<String, String>> manifestDrivers() async {
    final me = FireStoreUtils.getCurrentUid();
    final names = <String, String>{me: Constant.userModel?.fullName() ?? ''};
    final company = myCompanyId();
    if (company == null) return names;
    try {
      if (company != me) names[company] = '';
      final q = await FireStoreUtils.fireStore.collection(CollectionName.users).where('ownerId', isEqualTo: company).get();
      for (final d in q.docs) {
        final u = UserModel.fromJson(d.data());
        names[u.id ?? d.id] = u.fullName();
      }
      if (company != me) {
        final owner = await FireStoreUtils.getUserProfile(company);
        if (owner != null) names[company] = owner.fullName();
      }
    } catch (e) {
      debugPrint('ParcelTrackingService.manifestDrivers $e');
    }
    return names;
  }

  static bool _inProgress(ParcelOrderModel o) {
    if (_isCancelled(o)) return false;
    if (o.status == Constant.driverAccepted || o.status == Constant.orderInTransit || o.status == Constant.orderShipped) return true;
    return o.hasTrackingContract && o.status != Constant.orderCompleted && !ParcelTrackingStatus.isTerminal(o.parcelStatus);
  }

  /// In-progress parcels assigned to [driverIds], sorted by next action (pipeline order), oldest first.
  static Future<List<ParcelOrderModel>> manifest(Iterable<String> driverIds) async {
    final ids = driverIds.where((e) => e.isNotEmpty).toSet().toList();
    final result = <ParcelOrderModel>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final q = await FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).where('driverId', whereIn: chunk).get();
      for (final d in q.docs) {
        try {
          final o = ParcelOrderModel.fromJson(d.data());
          if (_inProgress(o)) result.add(o);
        } catch (e) {
          debugPrint('ParcelTrackingService.manifest parse $e');
        }
      }
    }
    result.sort((a, b) {
      final r = ParcelTrackingStatus.rank(currentStatus(a)).compareTo(ParcelTrackingStatus.rank(currentStatus(b)));
      if (r != 0) return r;
      final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return at.compareTo(bt);
    });
    return result;
  }

  // ── Pickup points ──────────────────────────────────────────────────────

  static final Map<String, String> _pointNames = {};

  static Future<String?> pickupPointName(String? id) async {
    if (id == null || id.isEmpty) return null;
    if (_pointNames.containsKey(id)) return _pointNames[id];
    try {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.pickupPoints).doc(id).get();
      final data = snap.data();
      if (data == null) return null;
      final parts = [data['name'], data['quarter'], data['town'] ?? data['city']].where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString());
      final name = parts.join(', ');
      _pointNames[id] = name;
      return name;
    } catch (e) {
      debugPrint('ParcelTrackingService.pickupPointName $e');
      return null;
    }
  }
}
