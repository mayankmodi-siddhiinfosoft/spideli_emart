import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';

/// The outcome of an accept / reject written by [DispatchOfferService].
class DispatchResult {
  final OfferAnswer answer;

  /// The live order as the transaction read it (null when it is gone, could
  /// not be read, or for delivery, whose callers keep their OrderModel).
  final Map<String, dynamic>? order;

  /// Why an accept was [OfferAnswer.blocked] (a translation key).
  final String? message;

  const DispatchResult(this.answer, {this.order, this.message});

  bool get isAccepted => answer == OfferAnswer.done || answer == OfferAnswer.held;
}

/// Accept, reject and timeout of an order offered to this driver, for the
/// four dispatched collections (`vendor_orders`, `rides`, `parcel_orders`,
/// `rental_orders`) — decision D2 of the dispatch spec, shared by the
/// incoming-offer dialog and every module card.
///
/// Every answer re-reads the live order in a transaction and writes only if
/// it is still this driver's to answer ([DispatchOrderRules.acceptCheck] /
/// [DispatchOrderRules.canReject]), with known fields only — never a whole
/// model from a local copy (that rolled back `rejectedByDrivers`, the
/// server-owned parcel SMS fields and other drivers' writes). The driver's
/// own arrays then move field-level:
///
///   * accept: order `Driver Accepted` (`driverId` / `driverID` / `driver` =
///     this driver); `inProgressOrderID` arrayUnion, `orderRequestData`
///     arrayRemove. A pending offer is never put in `inProgressOrderID`.
///   * reject / timeout: order `Driver Rejected`, `rejectedByDrivers`
///     arrayUnion, `driverId` and `driverID` null; `orderRequestData`
///     arrayRemove. Only a manual reject records its reason
///     (`driverRejections`); a timeout never does.
///
/// Delivery runs through [AssignedDeliveryOrders] (same rules, OrderModel).
abstract final class DispatchOfferService {
  static DocumentReference<Map<String, dynamic>> _ref(DispatchKind kind, String orderId) => FireStoreUtils.fireStore.collection(kind.collection).doc(orderId);

  static List<FieldPath> _paths(Map<String, dynamic> fields) => fields.keys.map((key) => FieldPath([key])).toList();

  /// Accepts [orderId] of [kind] for [driver].
  ///
  /// [heldAsRequest]: the driver's record holds the id as an offer (needed for
  /// a legacy offer that names nobody; by default read from [driver]).
  /// [fromOpenSearch]: the parcel / rental search list, which may take an
  /// `Order Placed` order that names nobody. [notify]: the customer (and, for
  /// delivery, the store) gets the templated "accepted" push.
  /// [tappedInWindow]: the caller checked the window when Accept was tapped
  /// and then awaited (the company wallet read): an accept tapped in time is
  /// never turned into a timeout by the caller's own latency — the
  /// transaction below still refuses an offer that is no longer this
  /// driver's.
  static Future<DispatchResult> accept(DispatchKind kind, String orderId, UserModel driver,
      {bool? heldAsRequest, bool fromOpenSearch = false, bool notify = true, bool tappedInWindow = false}) async {
    final String uid = driver.id ?? '';
    if (uid.isEmpty || orderId.isEmpty) return const DispatchResult(OfferAnswer.failed);
    // The window of a dispatch offer is over: it is answered as a timeout,
    // never accepted late (the Cloud Function may already be offering it to
    // the next driver).
    if (!tappedInWindow && IncomingOfferService.isExpired(orderId)) {
      await timeout(kind, orderId, uid);
      return const DispatchResult(OfferAnswer.gone);
    }
    // This device's own accept is never announced back to it as "a job has
    // been assigned to you" (a transaction's write reaches the listeners
    // without the local pending-write mark).
    DriverAssignmentWatcher.markOwnAnswer(kind.serviceType, orderId);
    final bool held = heldAsRequest ?? _holds(driver, orderId);

    if (kind == DispatchKind.delivery) {
      final result = await AssignedDeliveryOrders.acceptOffer(orderId, driver, heldAsRequest: held);
      if (result.answer != OfferAnswer.failed) IncomingOfferService.markAnswered(orderId);
      if (result.answer == OfferAnswer.done && notify) {
        final OrderModel? order = result.order;
        if (order != null) unawaited(SendNotification.notifyOrderAccepted(order));
      }
      return DispatchResult(result.answer);
    }

    // Spec 18.12: a ride / rental carries the assigned driver's region.
    String? regionToStamp;
    if (kind == DispatchKind.cab || kind == DispatchKind.rental) {
      try {
        regionToStamp = await RegionService.regionIdToStamp(driver);
      } catch (e) {
        log("DispatchOfferService: region lookup failed: $e");
      }
    }

    final DocumentReference<Map<String, dynamic>> ref = _ref(kind, orderId);
    final ({AcceptCheck check, Map<String, dynamic>? data, String? blocked}) outcome;
    try {
      outcome = await FireStoreUtils.fireStore.runTransaction<({AcceptCheck check, Map<String, dynamic>? data, String? blocked})>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        final AcceptCheck check = DispatchOrderRules.acceptCheck(kind, data, uid, heldAsRequest: held, fromOpenSearch: fromOpenSearch);
        if (check != AcceptCheck.ok) return (check: check, data: data, blocked: null);
        // Spec 4.9: a rental whose price proposal is still open is answered first.
        if (kind == DispatchKind.rental) {
          final dynamic proposal = data?['priceProposal'];
          final String proposalStatus = proposal is Map ? (proposal['status'] ?? '').toString() : '';
          if (proposalStatus == 'pending') return (check: check, data: data, blocked: "Please answer the customer's price proposal first");
          if (proposalStatus == 'countered') return (check: check, data: data, blocked: "Waiting for the customer to answer your counter-offer");
        }
        final bool hasRegion = (data?['regionId'] ?? '').toString().trim().isNotEmpty;
        final Map<String, dynamic> fields = DispatchOrderRules.acceptFields(uid, driver.toJson(), extra: {
          if (!hasRegion && (regionToStamp ?? '').isNotEmpty) 'regionId': regionToStamp,
          if (kind == DispatchKind.parcel) 'receiverPickupDateTime': Timestamp.now(),
        });
        tx.set(ref, fields, SetOptions(mergeFields: _paths(fields)));
        return (check: check, data: data, blocked: null);
      });
    } catch (e) {
      log("DispatchOfferService.accept(${kind.collection}/$orderId) failed: $e");
      return const DispatchResult(OfferAnswer.failed);
    }

    if (outcome.blocked != null) return DispatchResult(OfferAnswer.blocked, order: outcome.data, message: outcome.blocked);
    final bool clearsCabRequest = kind == DispatchKind.cab && driver.orderCabRequestData?.id == orderId;
    switch (outcome.check) {
      case AcceptCheck.ok:
      case AcceptCheck.held:
        await FireStoreUtils.updateUserFields(uid, {
          'inProgressOrderID': FieldValue.arrayUnion([orderId]),
          'orderRequestData': FieldValue.arrayRemove([orderId]),
          if (clearsCabRequest) 'ordercabRequestData': FieldValue.delete(),
        });
        IncomingOfferService.markAnswered(orderId);
        if (outcome.check == AcceptCheck.ok) {
          _cacheSection(outcome.data);
          if (notify) unawaited(_notifyAccepted(kind, orderId, outcome.data));
          return DispatchResult(OfferAnswer.done, order: outcome.data);
        }
        return DispatchResult(OfferAnswer.held, order: outcome.data);
      case AcceptCheck.gone:
        await FireStoreUtils.updateUserFields(uid, {
          'orderRequestData': FieldValue.arrayRemove([orderId]),
          if (clearsCabRequest) 'ordercabRequestData': FieldValue.delete(),
        });
        IncomingOfferService.markAnswered(orderId);
        return DispatchResult(OfferAnswer.gone, order: outcome.data);
    }
  }

  /// Rejects [orderId] of [kind] for [uid] (D2). [reasonFields] is the
  /// mandatory reason of a manual reject (`CancelReasonResult.toFields`);
  /// null for the automatic out-of-region decline. [cabRequestId]: the id of
  /// the driver's legacy `ordercabRequestData`, cleared when it is this ride.
  static Future<DispatchResult> reject(
    DispatchKind kind,
    String orderId,
    String uid, {
    Map<String, dynamic>? reasonFields,
    bool heldAsRequest = false,
    String? cabRequestId,
  }) =>
      _reject(kind, orderId, uid, reasonFields: reasonFields, heldAsRequest: heldAsRequest, cabRequestId: cabRequestId, timeout: false);

  /// The window of a dispatch offer ran out (D3): the reject flow without a
  /// reason, and only while the order is still `Driver Pending` for [uid].
  /// Idempotent: a second call finds it [OfferAnswer.gone].
  static Future<DispatchResult> timeout(DispatchKind kind, String orderId, String uid) => _reject(kind, orderId, uid, timeout: true);

  static Future<DispatchResult> _reject(
    DispatchKind kind,
    String orderId,
    String uid, {
    Map<String, dynamic>? reasonFields,
    bool heldAsRequest = false,
    String? cabRequestId,
    required bool timeout,
  }) async {
    if (uid.isEmpty || orderId.isEmpty) return const DispatchResult(OfferAnswer.failed);
    if (kind == DispatchKind.delivery) {
      final OfferAnswer answer = await AssignedDeliveryOrders.rejectOffer(orderId, uid, reasonFields: reasonFields, timeout: timeout);
      if (answer != OfferAnswer.failed) IncomingOfferService.markAnswered(orderId);
      return DispatchResult(answer);
    }
    final DocumentReference<Map<String, dynamic>> ref = _ref(kind, orderId);
    final ({bool done, Map<String, dynamic>? data}) outcome;
    try {
      outcome = await FireStoreUtils.fireStore.runTransaction<({bool done, Map<String, dynamic>? data})>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        if (!DispatchOrderRules.canReject(kind, data, uid, heldAsRequest: heldAsRequest, timeout: timeout)) return (done: false, data: data);
        final Map<String, dynamic> fields = DispatchOrderRules.rejectFields(uid, reasonFields: timeout ? null : reasonFields);
        tx.set(ref, fields, SetOptions(mergeFields: _paths(fields)));
        return (done: true, data: data);
      });
    } catch (e) {
      log("DispatchOfferService.${timeout ? 'timeout' : 'reject'}(${kind.collection}/$orderId) failed: $e");
      return const DispatchResult(OfferAnswer.failed);
    }
    await FireStoreUtils.updateUserFields(uid, {
      'orderRequestData': FieldValue.arrayRemove([orderId]),
      // A ride adopted into inProgressOrderID by an older build.
      if (outcome.done) 'inProgressOrderID': FieldValue.arrayRemove([orderId]),
      if (kind == DispatchKind.cab && cabRequestId == orderId) 'ordercabRequestData': FieldValue.delete(),
    });
    IncomingOfferService.markAnswered(orderId);
    return DispatchResult(outcome.done ? OfferAnswer.done : OfferAnswer.gone, order: outcome.data);
  }

  /// A booking in the rental search: an offer the Cloud Function dispatched
  /// to this driver is rejected (D2, back to dispatch); an open `Order
  /// Placed` booking nobody was dispatched yet is only passed — this driver in
  /// `rejectedByDrivers` and the reason in `driverRejections`, status
  /// unchanged (dispatch already excludes `rejectedByDrivers`).
  static Future<DispatchResult> rejectOrPassOpen(DispatchKind kind, String orderId, String uid, Map<String, dynamic> reasonFields) async {
    if (uid.isEmpty || orderId.isEmpty) return const DispatchResult(OfferAnswer.failed);
    final DocumentReference<Map<String, dynamic>> ref = _ref(kind, orderId);
    final bool? dispatched;
    try {
      dispatched = await FireStoreUtils.fireStore.runTransaction<bool?>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        if (data == null) return null;
        if (DispatchOrderRules.canReject(kind, data, uid)) {
          final Map<String, dynamic> fields = DispatchOrderRules.rejectFields(uid, reasonFields: reasonFields);
          tx.set(ref, fields, SetOptions(mergeFields: _paths(fields)));
          return true;
        }
        if (DispatchOrderRules.status(data) == Constant.orderPlaced && DispatchOrderRules.driverNames(data).isEmpty) {
          final Map<String, dynamic> fields = {
            'rejectedByDrivers': FieldValue.arrayUnion([uid]),
            ...reasonFields,
          };
          tx.set(ref, fields, SetOptions(mergeFields: _paths(fields)));
          return false;
        }
        return null;
      });
    } catch (e) {
      log("DispatchOfferService.rejectOrPassOpen(${kind.collection}/$orderId) failed: $e");
      return const DispatchResult(OfferAnswer.failed);
    }
    if (dispatched == true) {
      await FireStoreUtils.updateUserFields(uid, {
        'orderRequestData': FieldValue.arrayRemove([orderId]),
        'inProgressOrderID': FieldValue.arrayRemove([orderId]),
      });
      IncomingOfferService.markAnswered(orderId);
    }
    return DispatchResult(dispatched == null ? OfferAnswer.gone : OfferAnswer.done);
  }

  static bool _holds(UserModel driver, String orderId) =>
      [...?driver.orderRequestData, ...?driver.inProgressOrderID].any((id) => id.toString() == orderId) || driver.orderCabRequestData?.id == orderId;

  static void _cacheSection(Map<String, dynamic>? order) {
    final String sid = (order?['sectionId'] ?? order?['section_id'] ?? '').toString();
    if (sid.isEmpty || Constant.sectionModels.containsKey(sid)) return;
    FireStoreUtils.getSectionBySectionId(sid).then((s) {
      if (s != null) Constant.sectionModels[sid] = s;
    }).catchError((Object e) => log("DispatchOfferService: section $sid not loaded: $e"));
  }

  /// The customer's templated "accepted" push (text from dynamic_notification).
  static Future<void> _notifyAccepted(DispatchKind kind, String orderId, Map<String, dynamic>? order) async {
    final Map<String, dynamic> author = order?['author'] is Map ? Map<String, dynamic>.from(order!['author']) : const <String, dynamic>{};
    final String? customerId = (order?['authorID'] ?? author['id'])?.toString();
    final String? token = author['fcmToken']?.toString();
    try {
      switch (kind) {
        case DispatchKind.cab:
          await SendNotification.notifyCustomer(Constant.driverAcceptedNotification,
              customerId: customerId, embeddedToken: token, payload: {'orderId': orderId}, status: Constant.driverAccepted);
        case DispatchKind.parcel:
          await SendNotification.notifyCustomer(Constant.parcelAccepted,
              customerId: customerId, embeddedToken: token, payload: {'type': 'parcel_order', 'orderId': orderId}, status: Constant.driverAccepted);
        case DispatchKind.rental:
          await SendNotification.notifyCustomer(Constant.rentalAccepted,
              customerId: customerId, embeddedToken: token, payload: {'type': 'rental_order', 'orderId': orderId}, status: Constant.driverAccepted);
        case DispatchKind.delivery:
          break;
      }
    } catch (e) {
      log("DispatchOfferService: the accepted push failed: $e");
    }
  }
}
