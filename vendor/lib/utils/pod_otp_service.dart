import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
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

  const PodStart({this.code, this.alreadyVerified = false, this.pod, this.offline = false});
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

/// Firestore side of the proof-of-delivery contract for the store's own
/// (self-delivery) orders. Every write runs in one transaction on
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
            final PodCode? existing = PodCode.fromJson(orderId, codeSnap.data());
            if (pod?.isVerified == true) return PodStart(alreadyVerified: true, pod: pod);
            if (existing?.isVerified == true) {
              // Verified, but the order never got its `pod`: record it now
              // rather than ask the customer for a code again.
              final OrderPod verified = _verifiedPod(current: pod, code: existing!, at: existing.verifiedAt ?? Timestamp.now(), verifiedBy: verifiedBy, deliveredBy: deliveredBy);
              tx.update(_orderRef(orderId), {'pod': verified.toJson()});
              return PodStart(alreadyVerified: true, pod: verified);
            }
            if (existing != null) return PodStart(code: existing.redacted());

            final DateTime now = DateTime.now();
            final Map<String, dynamic> fresh = _newCode(order: order, code: PodOtp.generateCode(), now: now, regenerations: 1);
            tx.set(_codeRef(orderId), fresh);
            tx.update(_orderRef(orderId), _pendingPod(now));
            created = true;
            return PodStart(
              code: PodCode(orderId: orderId, code: '', status: PodStatus.pending, expiresAt: fresh['expiresAt'] as Timestamp, regenerations: 1),
            );
          })
          .timeout(_timeout);
      if (created) _pushCustomer(order);
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
            final DocumentSnapshot<Map<String, dynamic>> codeSnap = await tx.get(_codeRef(orderId));
            final PodCode? existing = PodCode.fromJson(orderId, codeSnap.data());
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
              code: PodCode(orderId: orderId, code: '', status: PodStatus.pending, expiresAt: fresh['expiresAt'] as Timestamp, regenerations: regenerations),
            );
          })
          .timeout(_timeout);
      if (result.result == PodResend.allowed) _pushCustomer(order);
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
            final PodCode? code = PodCode.fromJson(orderId, codeSnap.data());
            if (current?.isVerified == true) {
              return PodVerification(const PodCheckResult(PodCheck.alreadyVerified), code: code?.redacted(), pod: current);
            }
            final DateTime now = DateTime.now();
            final PodCheckResult result = PodOtp.check(code: code, entered: entered, now: now);
            switch (result.outcome) {
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
  static void _pushCustomer(OrderModel order) {
    final String token = order.author?.fcmToken ?? '';
    if (token.isEmpty || token == 'null') return;
    SendNotification.sendOneNotification(
      token: token,
      title: "Your order has arrived".tr,
      body: "Open the app for your delivery code.".tr,
      payload: {'type': PodRules.notificationType, 'orderId': order.id ?? ''},
    );
  }
}
