import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/pod_otp.dart';

/// Where an order's proof of delivery stands when the store starts it.
class PodStart {
  /// The order's code, without its digits. Null when [alreadyVerified].
  final PodCode? code;

  /// The order was verified earlier (a completion that failed afterwards is
  /// being retried): no code is asked for again.
  final bool alreadyVerified;

  /// The order's `pod` as stored, when [alreadyVerified].
  final OrderPod? pod;

  final bool offline;

  /// The order is cancelled / rejected (or completed without a code).
  final bool orderClosed;

  const PodStart({this.code, this.alreadyVerified = false, this.pod, this.offline = false, this.orderClosed = false});
}

/// A code that was entered: the outcome, the code's state afterwards (no
/// digits) and, once verified, the order's new `pod`.
class PodVerification {
  final PodCheckResult result;
  final PodCode? code;
  final OrderPod? pod;

  const PodVerification(this.result, {this.code, this.pod});
}

/// "Get a new code": the outcome and the code's state afterwards.
class PodRegeneration {
  final PodResend result;
  final PodCode? code;
  final Duration wait;

  const PodRegeneration(this.result, {this.code, this.wait = Duration.zero});
}

/// Firestore side of the proof-of-delivery contract for the orders the store
/// completes itself (self-delivery, and takeaway since 5 Oct 2026). Every write runs in one transaction on
/// `order_pod/{orderId}` together with the order's `pod`, so the code and what
/// the apps display can never disagree.
abstract final class PodOtpService {
  static const Duration _timeout = Duration(seconds: 20);

  static DocumentReference<Map<String, dynamic>> _codeRef(String orderId) => FireStoreUtils.fireStore.collection(PodRules.collection).doc(orderId);

  static DocumentReference<Map<String, dynamic>> _orderRef(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderId);

  /// No connection: the transaction could not reach the server.
  static bool isOffline(Object error) {
    if (error is TimeoutException || error is SocketException) return true;
    if (error is FirebaseException) return error.code == 'unavailable' || error.code == 'deadline-exceeded' || error.code == 'network-request-failed';
    return false;
  }

  static String _me() {
    try {
      return FireStoreUtils.getCurrentUid();
    } catch (_) {
      return '';
    }
  }

  /// A new code for [orderId], with the order's pending `pod`.
  static Map<String, dynamic> _newCode({required OrderModel order, required String code, required DateTime now, required int regenerations}) => {
    'orderId': order.id,
    'customerId': order.authorID ?? order.author?.id ?? '',
    'driverId': order.driverID ?? '',
    'vendorId': order.vendorID ?? '',
    'code': code,
    'status': PodStatus.pending,
    'generatedAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(PodOtp.expiryFor(now)),
    // Whose clock set `expiresAt` (see PodCode.deadline).
    'generatedBy': _me(),
    'generatedByRole': PodRole.vendor,
    'attempts': 0,
    'regenerations': regenerations,
  };

  /// The order's `pod` while a code is out. Dotted paths, so nothing else on
  /// an existing `pod` is touched.
  static Map<String, dynamic> _pendingPod(DateTime now) => {
    'pod.method': PodRules.methodOtp,
    'pod.status': PodStatus.pending,
    'pod.requestedAt': Timestamp.fromDate(now),
    'pod.expiresAt': Timestamp.fromDate(PodOtp.expiryFor(now)),
  };

  /// Starts proof of delivery for [order], or picks it up where it is: an
  /// order verified earlier is reported as such, an existing code (usable or
  /// spent) is returned as it is, and only an order with no code yet gets
  /// one. The customer is pushed when a code is created.
  static Future<PodStart> start(OrderModel order, {required String verifiedBy, required PodDeliveryMan? deliveredBy}) async {
    final String orderId = order.id ?? '';
    try {
      bool created = false;
      final PodStart start = await FireStoreUtils.fireStore
          .runTransaction<PodStart>((tx) async {
            created = false;
            final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(_orderRef(orderId));
            final DocumentSnapshot<Map<String, dynamic>> codeSnap = await tx.get(_codeRef(orderId));
            final OrderPod? pod = OrderPod.fromJson(orderSnap.data()?['pod']);
            final PodCode? existing = PodCode.fromJson(orderId, codeSnap.data(), me: _me());
            final String? orderStatus = orderSnap.data()?['status']?.toString();
            // Cancelled / rejected: no code, and a pending one stops working.
            if (!orderSnap.exists || PodRules.isCancelledStatus(orderStatus)) {
              if (existing?.status == PodStatus.pending) tx.update(_codeRef(orderId), {'status': PodStatus.expired});
              return const PodStart(orderClosed: true);
            }
            if (pod?.isVerified == true) return PodStart(alreadyVerified: true, pod: pod);
            if (existing?.isVerified == true) {
              // Verified, but the order never got its `pod`: record it now
              // rather than ask the customer for a code again.
              final OrderPod verified = _verifiedPod(current: pod, code: existing!, at: existing.verifiedAt ?? Timestamp.now(), verifiedBy: verifiedBy, deliveredBy: deliveredBy);
              tx.update(_orderRef(orderId), {'pod': verified.toJson()});
              return PodStart(alreadyVerified: true, pod: verified);
            }
            if (PodRules.isCompletedStatus(orderStatus)) return const PodStart(orderClosed: true);
            if (existing != null) return PodStart(code: existing.redacted());

            final DateTime now = DateTime.now();
            final Map<String, dynamic> fresh = _newCode(order: order, code: PodOtp.generateCode(), now: now, regenerations: 1);
            tx.set(_codeRef(orderId), fresh);
            tx.update(_orderRef(orderId), _pendingPod(now));
            created = true;
            return PodStart(
              code: PodCode(orderId: orderId, code: '', status: PodStatus.pending, expiresAt: fresh['expiresAt'] as Timestamp, regenerations: 1, sameClock: true),
            );
          })
          .timeout(_timeout);
      if (created) unawaited(_pushCustomer(order));
      return start;
    } catch (e) {
      log('POD start failed for $orderId: $e');
      if (isOffline(e)) return const PodStart(offline: true);
      rethrow;
    }
  }

  /// "Get a new code": replaces the order's code (the old one stops working
  /// at once) after the cooldown, within the per-order limit.
  static Future<PodRegeneration> regenerate(OrderModel order) async {
    final String orderId = order.id ?? '';
    try {
      final PodRegeneration result = await FireStoreUtils.fireStore
          .runTransaction<PodRegeneration>((tx) async {
            // All reads first, as Firestore requires.
            final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(_orderRef(orderId));
            final DocumentSnapshot<Map<String, dynamic>> codeSnap = await tx.get(_codeRef(orderId));
            final PodCode? existing = PodCode.fromJson(orderId, codeSnap.data(), me: _me());
            final String? orderStatus = orderSnap.data()?['status']?.toString();
            if (!orderSnap.exists || PodRules.isCancelledStatus(orderStatus) || PodRules.isCompletedStatus(orderStatus)) {
              if (existing?.status == PodStatus.pending) tx.update(_codeRef(orderId), {'status': PodStatus.expired});
              return PodRegeneration(PodResend.orderClosed, code: existing?.redacted());
            }
            // Proved already (by the Driver app, say): never a new code.
            if (OrderPod.fromJson(orderSnap.data()?['pod'])?.isVerified == true) {
              return PodRegeneration(PodResend.alreadyVerified, code: existing?.redacted());
            }
            final DateTime now = DateTime.now();
            final PodResend allowed = PodOtp.canResend(existing, now);
            if (allowed != PodResend.allowed) {
              return PodRegeneration(allowed, code: existing?.redacted(), wait: PodOtp.cooldownLeft(existing, now));
            }
            final int regenerations = (existing?.regenerations ?? 0) + 1;
            final Map<String, dynamic> fresh = _newCode(order: order, code: PodOtp.generateCode(previous: existing?.code), now: now, regenerations: regenerations);
            tx.set(_codeRef(orderId), fresh);
            tx.update(_orderRef(orderId), _pendingPod(now));
            return PodRegeneration(
              PodResend.allowed,
              code: PodCode(orderId: orderId, code: '', status: PodStatus.pending, expiresAt: fresh['expiresAt'] as Timestamp, regenerations: regenerations, sameClock: true),
            );
          })
          .timeout(_timeout);
      if (result.result == PodResend.allowed) unawaited(_pushCustomer(order));
      return result;
    } catch (e) {
      log('POD regenerate failed for $orderId: $e');
      if (isOffline(e)) return const PodRegeneration(PodResend.offline);
      rethrow;
    }
  }

  /// Checks [entered] in one transaction. Verified: the code becomes
  /// `verified` and the order's `pod` is written whole (who verified, who
  /// delivered, when). Wrong: `attempts` goes up, and the code expires on the
  /// last one. Anything else writes nothing.
  static Future<PodVerification> verify(OrderModel order, String entered, {required String verifiedBy, required PodDeliveryMan? deliveredBy}) async {
    final String orderId = order.id ?? '';
    if (!PodOtp.isWellFormed(entered)) return const PodVerification(PodCheckResult(PodCheck.invalidFormat));
    try {
      return await FireStoreUtils.fireStore
          .runTransaction<PodVerification>((tx) async {
            final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(_orderRef(orderId));
            final DocumentSnapshot<Map<String, dynamic>> codeSnap = await tx.get(_codeRef(orderId));
            final OrderPod? current = OrderPod.fromJson(orderSnap.data()?['pod']);
            final PodCode? code = PodCode.fromJson(orderId, codeSnap.data(), me: _me());
            final String? orderStatus = orderSnap.exists ? (orderSnap.data()?['status'])?.toString() : Constant.orderCancelled;
            if (current?.isVerified == true && !PodRules.isCancelledStatus(orderStatus)) {
              return PodVerification(const PodCheckResult(PodCheck.alreadyVerified), code: code?.redacted(), pod: current);
            }
            final DateTime now = DateTime.now();
            final PodCheckResult result = PodOtp.check(code: code, entered: entered, now: now, orderStatus: orderStatus);
            switch (result.outcome) {
              case PodCheck.orderClosed:
                // Cancelled while the code was out: it stops working for good.
                if (code?.status == PodStatus.pending) tx.update(_codeRef(orderId), {'status': PodStatus.expired});
                return PodVerification(result, code: code?.redacted());
              case PodCheck.verified:
                final Timestamp at = Timestamp.fromDate(now);
                tx.update(_codeRef(orderId), {'status': PodStatus.verified, 'verifiedAt': at});
                final OrderPod pod = _verifiedPod(current: current, code: code!, at: at, verifiedBy: verifiedBy, deliveredBy: deliveredBy);
                tx.update(_orderRef(orderId), {'pod': pod.toJson()});
                return PodVerification(result, code: code.redacted(), pod: pod);
              case PodCheck.wrongCode:
                final int attempts = code!.attempts + 1;
                tx.update(_codeRef(orderId), {'attempts': attempts, if (attempts >= PodRules.maxAttempts) 'status': PodStatus.expired});
                return PodVerification(
                  result,
                  code: PodCode(
                    orderId: orderId,
                    code: '',
                    status: attempts >= PodRules.maxAttempts ? PodStatus.expired : code.status,
                    generatedAt: code.generatedAt,
                    expiresAt: code.expiresAt,
                    attempts: attempts,
                    regenerations: code.regenerations,
                  ),
                );
              case PodCheck.alreadyVerified:
                // The code was verified but the order never got its `pod`:
                // write it now rather than ask for a code again.
                final OrderPod pod = _verifiedPod(current: current, code: code!, at: code.verifiedAt ?? Timestamp.fromDate(now), verifiedBy: verifiedBy, deliveredBy: deliveredBy);
                tx.update(_orderRef(orderId), {'pod': pod.toJson()});
                return PodVerification(result, code: code.redacted(), pod: pod);
              default:
                return PodVerification(result, code: code?.redacted());
            }
          })
          .timeout(_timeout);
    } catch (e) {
      log('POD verify failed for $orderId: $e');
      if (isOffline(e)) return const PodVerification(PodCheckResult(PodCheck.offline));
      rethrow;
    }
  }

  /// The order's `pod` once the store verified [code]: everything already on
  /// [current] is kept, the known fields are set.
  static OrderPod _verifiedPod({required OrderPod? current, required PodCode code, required Timestamp at, required String verifiedBy, required PodDeliveryMan? deliveredBy}) {
    final DateTime? issued = code.issuedAt;
    return OrderPod(
      method: PodRules.methodOtp,
      status: PodStatus.verified,
      requestedAt: current?.requestedAt ?? (issued == null ? null : Timestamp.fromDate(issued)),
      expiresAt: code.expiresAt ?? current?.expiresAt,
      verifiedAt: at,
      verifiedBy: verifiedBy,
      verifiedByRole: PodRole.vendor,
      deliveredBy: deliveredBy,
      raw: current?.raw ?? const {},
    );
  }

  /// Tells the customer their code is in the app. The push never carries the
  /// code: the customer app reads it from `order_pod/{orderId}`.
  static Future<void> _pushCustomer(OrderModel order) async {
    try {
      String token = '';
      final String customerId = order.authorID ?? order.author?.id ?? '';
      // The token on the order is a copy from checkout; the customer's
      // current one is on their user record.
      if (customerId.isNotEmpty) token = (await FireStoreUtils.getUserById(customerId))?.fcmToken ?? '';
      if (token.isEmpty || token == 'null') token = order.author?.fcmToken ?? '';
      if (token.isEmpty || token == 'null') return;
      // Wording from the dynamic_notification templates (no text in the
      // app): `pickup_otp` for a takeaway collected at the counter,
      // `delivery_otp` otherwise. The data keeps type delivery_otp, which is
      // what the customer app routes on.
      await SendNotification.sendFcmMessage(
        order.takeAway == true ? 'pickup_otp' : 'delivery_otp',
        token,
        {'type': PodRules.notificationType, 'orderId': order.id ?? ''},
        recipientId: customerId.isEmpty ? null : customerId,
      );
    } catch (e) {
      log('POD push failed for ${order.id}: $e');
    }
  }
}
