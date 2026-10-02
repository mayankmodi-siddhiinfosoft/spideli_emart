import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/delivery_pod.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/delivery_pod_rules.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/foundation.dart';

/// The device could not reach Firestore (transactions need the server).
class PodOfflineException implements Exception {
  const PodOfflineException();
  @override
  String toString() => DeliveryPodRules.offlineMessage;
}

/// What the Driver app may know about an order's code: never the code itself.
class PodState {
  /// `pending` | `verified` | `expired`, or null when the order has no code.
  final String? status;

  /// `order_pod.expiresAt`, from the generating device's clock.
  final DateTime? expiresAt;

  /// `order_pod.generatedAt`, the server's time (null until resolved).
  final DateTime? generatedAt;

  /// True when this device generated the code, so [expiresAt] is on this
  /// device's clock.
  final bool sameClock;
  final int attempts;
  final int regenerations;

  /// True when this call created a new code (and notified the customer).
  final bool created;

  /// Set when a new code was wanted but the cooldown or the cap refused it.
  final PodNewCodeDecision? refused;
  final Timestamp? verifiedAt;

  /// The order is cancelled / rejected (or completed without a code): no
  /// code can be created or verified for it.
  final bool orderClosed;

  const PodState({
    this.status,
    this.expiresAt,
    this.generatedAt,
    this.sameClock = false,
    this.attempts = 0,
    this.regenerations = 0,
    this.created = false,
    this.refused,
    this.verifiedAt,
    this.orderClosed = false,
  });

  bool get isVerified => status == DeliveryPodRules.statusVerified;

  /// When the code stops working, on this device's clock (clock-skew safe,
  /// see [DeliveryPodRules.deadline]).
  DateTime? get deadline => DeliveryPodRules.deadline(expiresAt: expiresAt, generatedAt: generatedAt, sameClock: sameClock);

  /// When the last code was issued, on this device's clock: starts the
  /// 60-second cooldown.
  DateTime? get lastGeneratedAt => DeliveryPodRules.issuedAt(expiresAt: expiresAt, generatedAt: generatedAt, sameClock: sameClock);

  bool isLive(DateTime now) => !orderClosed && DeliveryPodRules.canReuse(status: status, now: now, expiresAt: deadline, attempts: attempts);

  PodState copyWith({String? status, int? attempts, bool? orderClosed, PodNewCodeDecision? refused}) => PodState(
        status: status ?? this.status,
        expiresAt: expiresAt,
        generatedAt: generatedAt,
        sameClock: sameClock,
        attempts: attempts ?? this.attempts,
        regenerations: regenerations,
        refused: refused ?? this.refused,
        verifiedAt: verifiedAt,
        orderClosed: orderClosed ?? this.orderClosed,
      );
}

class PodVerifyOutcome {
  final PodCheck check;
  final PodState state;

  /// The order's `pod` as written on success.
  final DeliveryPod? pod;

  const PodVerifyOutcome(this.check, this.state, {this.pod});
}

/// Proof of delivery by customer OTP for multivendor / e-commerce delivery
/// orders (`.claude/POD-OTP-CONTRACT.md`). The code lives in
/// `order_pod/{orderId}`; the order carries only the `pod` record.
abstract final class DeliveryPodService {
  static const Duration _timeout = Duration(seconds: 20);

  static DocumentReference<Map<String, dynamic>> _podRef(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.orderPod).doc(orderId);

  static DocumentReference<Map<String, dynamic>> _orderRef(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderId);

  /// "Drop Delivery" ([forceNew] false) reuses a pending, unexpired code, or
  /// creates one. "Get a new code" ([forceNew] true) replaces the code,
  /// subject to the 60-second cooldown and the 5-regeneration cap. A new code
  /// notifies the customer. Returns verified when the order is already proved
  /// (a retry after a failed completion).
  static Future<PodState> requestCode(OrderModel order, {bool forceNew = false}) async {
    final String orderId = order.id!;
    final String me = FireStoreUtils.getCurrentUid();
    final Map<String, dynamic> deliveredBy = deliveredByMap();
    final PodState state = await _guard(() => FireStoreUtils.fireStore.runTransaction<PodState>((tx) async {
          // All reads first, as Firestore requires.
          final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(_podRef(orderId));
          final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(_orderRef(orderId));
          final Map<String, dynamic> data = snap.data() ?? const {};
          final Map<String, dynamic> orderData = orderSnap.data() ?? const {};
          final PodState current = _stateOf(data, me);
          final DeliveryPod? orderPod = DeliveryPod.fromJson(orderData['pod']);
          final String? orderStatus = orderData['status']?.toString();
          final DateTime now = DateTime.now();

          // Cancelled / rejected: no code, and a pending one stops working.
          if (!orderSnap.exists || DeliveryPodRules.isCancelledStatus(orderStatus)) {
            if (current.status == DeliveryPodRules.statusPending) tx.update(_podRef(orderId), {'status': DeliveryPodRules.statusExpired});
            return current.copyWith(orderClosed: true);
          }
          // Proved already (a retry after a failed completion): no new code.
          if (current.isVerified) return current;
          if (orderPod?.isVerified == true) {
            return PodState(status: DeliveryPodRules.statusVerified, verifiedAt: orderPod!.verifiedAt, regenerations: current.regenerations);
          }
          if (DeliveryPodRules.isCompletedStatus(orderStatus)) return current.copyWith(orderClosed: true);
          if (!forceNew && current.isLive(now)) return current;

          final PodNewCodeDecision decision = DeliveryPodRules.newCodeDecision(
            regenerations: current.regenerations,
            now: now,
            lastGeneratedAt: current.status == null ? null : current.lastGeneratedAt,
          );
          if (!decision.allowed) return current.copyWith(refused: decision);

          final String code = DeliveryPodRules.generateCode(previous: data['code']?.toString());
          final Timestamp requestedAt = Timestamp.fromDate(now);
          final Timestamp expiresAt = Timestamp.fromDate(DeliveryPodRules.expiryFor(now));
          final int regenerations = current.regenerations + 1;
          tx.set(_podRef(orderId), {
            'orderId': orderId,
            'customerId': order.authorID ?? order.author?.id ?? '',
            'driverId': me,
            'vendorId': order.vendorID ?? order.vendor?.id ?? '',
            'code': code,
            'status': DeliveryPodRules.statusPending,
            'generatedAt': FieldValue.serverTimestamp(),
            'expiresAt': expiresAt,
            // Whose clock set `expiresAt` (see DeliveryPodRules.deadline).
            'generatedBy': me,
            'generatedByRole': 'driver',
            'attempts': 0,
            'regenerations': regenerations,
          });
          tx.update(_orderRef(orderId), {
            'pod.method': 'otp',
            'pod.status': DeliveryPodRules.statusPending,
            'pod.requestedAt': requestedAt,
            'pod.expiresAt': expiresAt,
            if (deliveredBy.isNotEmpty) 'pod.deliveredBy': deliveredBy,
          });
          return PodState(status: DeliveryPodRules.statusPending, expiresAt: expiresAt.toDate(), sameClock: true, regenerations: regenerations, created: true);
        }, timeout: _timeout));
    if (state.created) unawaited(notifyCustomer(order));
    return state;
  }

  /// The contract's verification, in one transaction on `order_pod/{orderId}`.
  /// Success marks the code and the order's `pod` verified; a wrong entry
  /// increments `attempts` (and expires the code at 5). The order's
  /// completion is NOT run here.
  static Future<PodVerifyOutcome> verify(OrderModel order, String entered) async {
    final String orderId = order.id!;
    final Map<String, dynamic> deliveredBy = deliveredByMap();
    final String uid = FireStoreUtils.getCurrentUid();
    return _guard(() => FireStoreUtils.fireStore.runTransaction<PodVerifyOutcome>((tx) async {
          final DocumentReference<Map<String, dynamic>> podRef = _podRef(orderId);
          // All reads first, as Firestore requires.
          final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(podRef);
          final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(_orderRef(orderId));
          final Map<String, dynamic> data = snap.data() ?? const {};
          final Map<String, dynamic> orderData = orderSnap.data() ?? const {};
          final PodState current = _stateOf(data, uid);
          final DeliveryPod? orderPod = DeliveryPod.fromJson(orderData['pod']);
          final DateTime now = DateTime.now();
          final PodCheck check = DeliveryPodRules.check(
            orderStatus: orderSnap.exists ? orderData['status']?.toString() : 'Order Cancelled',
            // The order's `pod` counts as proof too (written in the same
            // transaction as the code's `verified`).
            status: orderPod?.isVerified == true ? DeliveryPodRules.statusVerified : current.status,
            code: data['code']?.toString(),
            now: now,
            expiresAt: current.deadline,
            attempts: current.attempts,
            entered: entered,
          );

          switch (check.result) {
            case PodCheckResult.verified:
              final Timestamp verifiedAt = Timestamp.fromDate(now);
              tx.update(podRef, {'status': DeliveryPodRules.statusVerified, 'verifiedAt': verifiedAt});
              tx.update(_orderRef(orderId), {
                'pod.method': 'otp',
                'pod.status': DeliveryPodRules.statusVerified,
                'pod.verifiedAt': verifiedAt,
                'pod.verifiedBy': uid,
                'pod.verifiedByRole': 'driver',
                if (deliveredBy.isNotEmpty) 'pod.deliveredBy': deliveredBy,
              });
              final DeliveryPod pod = DeliveryPod(
                method: 'otp',
                status: DeliveryPodRules.statusVerified,
                requestedAt: orderPod?.requestedAt,
                expiresAt: current.expiresAt == null ? null : Timestamp.fromDate(current.expiresAt!),
                verifiedAt: verifiedAt,
                verifiedBy: uid,
                verifiedByRole: 'driver',
                deliveredBy: deliveredBy.isEmpty ? orderPod?.deliveredBy : PodDeliveredBy.fromJson(deliveredBy),
              );
              return PodVerifyOutcome(check, current.copyWith(status: DeliveryPodRules.statusVerified), pod: pod);
            case PodCheckResult.alreadyVerified:
              return PodVerifyOutcome(
                check,
                current.copyWith(status: DeliveryPodRules.statusVerified),
                pod: orderPod?.isVerified == true ? orderPod : DeliveryPod(method: 'otp', status: DeliveryPodRules.statusVerified, verifiedAt: current.verifiedAt),
              );
            case PodCheckResult.wrong:
            case PodCheckResult.tooManyAttempts:
              if (check.countsAttempt) {
                tx.update(podRef, {
                  'attempts': check.attemptsAfter,
                  if (check.invalidates) 'status': DeliveryPodRules.statusExpired,
                });
              }
              return PodVerifyOutcome(
                check,
                current.copyWith(
                  status: check.invalidates ? DeliveryPodRules.statusExpired : current.status,
                  attempts: check.attemptsAfter ?? current.attempts,
                ),
              );
            case PodCheckResult.expired:
              // Past its 10 minutes: record it, so every app agrees.
              if (current.status == DeliveryPodRules.statusPending) tx.update(podRef, {'status': DeliveryPodRules.statusExpired});
              return PodVerifyOutcome(check, current.copyWith(status: DeliveryPodRules.statusExpired));
            case PodCheckResult.orderClosed:
              // Cancelled while the code was out: it stops working for good.
              if (current.status == DeliveryPodRules.statusPending) tx.update(podRef, {'status': DeliveryPodRules.statusExpired});
              return PodVerifyOutcome(check, current.copyWith(orderClosed: true));
            case PodCheckResult.noCode:
              return PodVerifyOutcome(check, current);
          }
        }, timeout: _timeout));
  }

  /// Push to the customer: the order has arrived, the code is in the app.
  /// Never contains the code. Silent when the customer has no token.
  static Future<void> notifyCustomer(OrderModel order) async {
    try {
      String token = '';
      final String? customerId = order.authorID ?? order.author?.id;
      if (customerId != null && customerId.isNotEmpty) {
        final UserModel? customer = await FireStoreUtils.getUserProfile(customerId);
        token = customer?.fcmToken ?? '';
      }
      if (token.isEmpty) token = order.author?.fcmToken ?? '';
      if (token.isEmpty) return;
      await SendNotification.sendOneNotification(
        token: token,
        title: 'Your order has arrived',
        body: 'Open the app for your delivery code.',
        payload: {'type': 'delivery_otp', 'orderId': order.id ?? ''},
      );
    } catch (e) {
      debugPrint('DeliveryPodService.notifyCustomer $e');
    }
  }

  /// `pod.deliveredBy` from the signed-in driver.
  static Map<String, dynamic> deliveredByMap() {
    final UserModel? me = Constant.userModel;
    String uid;
    try {
      uid = FireStoreUtils.getCurrentUid();
    } catch (_) {
      uid = (me?.id ?? '').trim();
    }
    final String name = me?.fullName().trim() ?? '';
    final String number = (me?.phoneNumber ?? '').trim();
    final String cc = (me?.countryCode ?? '').trim();
    final String phone = number.isEmpty ? '' : (number.startsWith('+') || cc.isEmpty ? number : '$cc $number');
    final String photo = (me?.profilePictureURL ?? '').trim();
    return PodDeliveredBy(
      id: uid.isEmpty ? null : uid,
      name: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
      photo: photo.isEmpty ? null : photo,
    ).toJson();
  }

  static PodState _stateOf(Map<String, dynamic> data, String me) {
    final dynamic status = data['status'];
    final String generatedBy = (data['generatedBy'] ?? '').toString();
    return PodState(
      status: status is String && status.isNotEmpty ? status : null,
      expiresAt: _date(data['expiresAt']),
      generatedAt: _date(data['generatedAt']),
      sameClock: generatedBy.isNotEmpty && generatedBy == me,
      attempts: (data['attempts'] as num?)?.toInt() ?? 0,
      regenerations: (data['regenerations'] as num?)?.toInt() ?? 0,
      verifiedAt: data['verifiedAt'] is Timestamp ? data['verifiedAt'] as Timestamp : null,
    );
  }

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  /// Maps "no connection" failures to [PodOfflineException].
  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run().timeout(_timeout + const Duration(seconds: 5));
    } on TimeoutException {
      throw const PodOfflineException();
    } on SocketException {
      throw const PodOfflineException();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') throw const PodOfflineException();
      rethrow;
    }
  }
}
