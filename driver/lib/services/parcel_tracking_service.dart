import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/parcel_sms_outbox.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
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

  /// Accepts a `qrValue` (`spideli:parcel:<id>`), a raw `trackingNumber` or a raw order id.
  static Future<ParcelOrderModel?> resolveScan(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      if (value.toLowerCase().startsWith(qrPrefix)) {
        return await getById(value.substring(qrPrefix.length).trim());
      }
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

  /// Assigned to me, the final step (or later) is recorded, but the order was never completed / credited.
  static bool awaitingCompletion(ParcelOrderModel o) {
    if (!isAssignedToMe(o) || o.status == Constant.orderCompleted || o.driverCredited == true || _isCancelled(o)) return false;
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
    if (isDriverFinalStep(fresh, status) && isAssignedToMe(fresh) && fresh.status != Constant.orderCompleted) {
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
    // The receiver's SMS request, when one is due, is committed with the status itself:
    // no message can be queued for a status write that failed.
    final ParcelSmsRequest? sms = await ParcelSmsOutbox.requestFor(o, status);
    if (sms == null) {
      await _doc(o.id!).update(data);
    } else {
      final WriteBatch batch = FireStoreUtils.fireStore.batch();
      batch.update(_doc(o.id!), data);
      ParcelSmsOutbox.addToBatch(batch, sms);
      // The SMS must never cost the driver the status write: a refused outbox
      // (rules) falls back to the plain update, with no message queued.
      try {
        await batch.commit();
      } catch (e) {
        debugPrint('ParcelSmsOutbox: batch refused ($e) — writing $status without the SMS request');
        await _doc(o.id!).update(data);
      }
    }
    o.parcelStatus = status;
    if (data['status'] != null) o.status = data['status'];
  }

  /// Hook for the existing "Pickup Parcel" button: also records `Collected` (home pickup) or, for a parcel
  /// taken from the origin pickup point, `In transit`. Returns an error message when the pickup is not possible.
  static Future<String?> onLegacyPickup(ParcelOrderModel o) async {
    final current = currentStatus(o);
    if (o.pickupMethod == 'pickup_point' && ParcelTrackingStatus.rank(current) <= 1 && o.parcelStatus != null) {
      return 'The sender has not dropped the parcel off at the origin pickup point yet.';
    }
    await _doc(o.id!).set({'status': Constant.orderInTransit}, SetOptions(merge: true));
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

  /// Sets `Order Completed` and claims `driverCredited` in one transaction — only when the order is not already
  /// completed / credited / cancelled. True = this call won and must credit the wallet.
  static Future<bool> _claimCompletion(String orderId) async {
    return FireStoreUtils.fireStore.runTransaction<bool>((transaction) async {
      final ref = _doc(orderId);
      final snap = await transaction.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) return false;
      final status = data['status']?.toString();
      final parcelStatus = data['parcelStatus']?.toString();
      if (data['driverCredited'] == true ||
          status == Constant.orderCompleted ||
          status == Constant.orderCancelled ||
          status == Constant.orderRejected ||
          parcelStatus == ParcelTrackingStatus.cancelled ||
          parcelStatus == ParcelTrackingStatus.returned) {
        return false;
      }
      transaction.update(ref, {'status': Constant.orderCompleted, 'driverCredited': true});
      return true;
    });
  }

  /// The existing eMart completion: `Order Completed`, wallet credit, commission, customer notification and
  /// referral — at most once per order (a stale list, a second screen or a retry cannot pay twice).
  static Future<void> completeOrder(ParcelOrderModel o) async {
    final won = await _claimCompletion(o.id!);
    if (!won) {
      final fresh = await getById(o.id!);
      if (fresh?.status == Constant.orderCompleted) {
        o.status = Constant.orderCompleted;
        return;
      }
      throw 'This parcel can no longer be completed.';
    }
    o.status = Constant.orderCompleted;
    o.driverCredited = true;
    await _updateWalletAmount(o);
    try {
      final token = o.author?.fcmToken;
      if (token != null && token.isNotEmpty) {
        Map<String, dynamic> payLoad = <String, dynamic>{"type": "parcel_order", "orderId": o.id};
        await SendNotification.sendFcmMessage(Constant.parcelCompleted, token, payLoad);
      }
    } catch (e) {
      debugPrint('ParcelTrackingService.completeOrder notification $e');
    }
    await FireStoreUtils.getParcelFirstOrderOrNOt(o).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateParcelReferralAmount(o);
      }
    });
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

    for (var element in orderModel.taxSetting ?? []) {
      totalTax = totalTax + Constant.calculateTax(amount: (subTotal - discount).toString(), taxModel: element);
    }

    if ((orderModel.adminCommission ?? '').isNotEmpty) {
      adminComm = Constant.calculateAdminCommission(
          amount: (subTotal - discount).toString(),
          adminCommissionType: orderModel.adminCommissionType.toString(),
          adminCommission: orderModel.adminCommission ?? '0');
    }

    final UserModel? driver = orderModel.driver;
    final String walletUserId = driver?.ownerId != null && driver!.ownerId!.isNotEmpty ? driver.ownerId.toString() : FireStoreUtils.getCurrentUid();

    // Fixed intercity / intercountry tax: platform revenue, outside subTotal (never credited to the driver).
    final double scopeTax = (orderModel.parcelScopeTax ?? 0).toDouble();
    final String paymentMethod = orderModel.paymentMethod ?? '';
    final bool isCod = paymentMethod == PaymentGateway.cod.name;

    totalAmount = ((subTotal - discount) + totalTax);
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

      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(amount: totalAmount.toString(), userId: walletUserId);
        }
      });
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

    await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(amount: "-${adminComm.toString()}", userId: walletUserId);
      }
    });

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

      await FireStoreUtils.setWalletTransaction(taxTransaction).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(amount: "-${scopeTax.toString()}", userId: walletUserId);
        }
      });
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
