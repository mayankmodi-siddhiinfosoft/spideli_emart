import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/utils/cancellation.dart';

/// Proof of delivery by customer OTP — the shared contract of the Customer,
/// Driver and Store apps (`.claude/POD-OTP-CONTRACT.md`, 3 Oct 2026).
///
/// This file holds the shapes and the rules as pure functions, so the
/// numbers below are tested without Firestore. The Firestore side is
/// `pod_otp_service.dart`; the screens are `widget/delivery_otp_sheet.dart`
/// and `widget/pod_block.dart`.
abstract final class PodRules {
  /// Digits in a code.
  static const int codeLength = 6;

  /// A code works for this long after it was generated.
  static const Duration codeLifetime = Duration(minutes: 10);

  /// Wrong entries that invalidate a code (its status becomes `expired`).
  static const int maxAttempts = 5;

  /// Wait between two codes for the same order.
  static const Duration resendCooldown = Duration(seconds: 60);

  /// New codes ("Get a new code") an order may have after its first one.
  static const int maxRegenerations = 5;

  /// `order_pod/{orderId}`.
  static const String collection = 'order_pod';

  /// The push `type` that tells the customer app to open the code.
  static const String notificationType = 'delivery_otp';

  static const String methodOtp = 'otp';

  /// Clock skew tolerated between two devices (a code generated on one phone
  /// and checked on another). Small next to the 10 minutes.
  static const Duration skewTolerance = Duration(seconds: 30);

  /// Cancelled or rejected: such an order is never completed, and its code
  /// can neither be created nor verified.
  static bool isCancelledStatus(String? orderStatus) {
    final String s = (orderStatus ?? '').trim().toLowerCase();
    return s == Constant.orderCancelled.toLowerCase() || s == Constant.orderRejected.toLowerCase() || s == 'cancelled' || s == 'canceled' || s == 'rejected';
  }

  static bool isCompletedStatus(String? orderStatus) => (orderStatus ?? '').trim().toLowerCase() == Constant.orderCompleted.toLowerCase();
}

/// `status` of `order_pod/{orderId}` and of an order's `pod`.
abstract final class PodStatus {
  static const String pending = 'pending';
  static const String verified = 'verified';
  static const String expired = 'expired';
}

/// `pod.verifiedByRole`.
abstract final class PodRole {
  static const String driver = 'driver';
  static const String vendor = 'vendor';
}

/// The delivery man on `pod.deliveredBy`: `{id, name, phone, photo}`.
class PodDeliveryMan {
  final String? id;
  final String? name;
  final String? phone;
  final String? photo;

  const PodDeliveryMan({this.id, this.name, this.phone, this.photo});

  static PodDeliveryMan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final PodDeliveryMan man = PodDeliveryMan(
      id: firstText(json, const ['id', 'driverId', 'driverID']),
      name: firstText(json, const ['name', 'fullName']),
      phone: firstText(json, const ['phone', 'phoneNumber']),
      photo: firstText(json, const ['photo', 'profilePictureURL', 'image']),
    );
    return man.isEmpty ? null : man;
  }

  /// Built from a user record's parts; blanks and "null" are dropped, and the
  /// country code is put in front of a phone number that has none.
  factory PodDeliveryMan.of({String? id, String? firstName, String? lastName, String? countryCode, String? phoneNumber, String? photo}) {
    final String name = [firstName, lastName].where((p) => !isBlankText(p)).map((p) => p!.trim()).join(' ');
    String? phone = isBlankText(phoneNumber) ? null : phoneNumber!.trim();
    if (phone != null && !phone.startsWith('+') && !isBlankText(countryCode)) {
      final String cc = countryCode!.trim();
      phone = '${cc.startsWith('+') ? cc : '+$cc'} $phone';
    }
    return PodDeliveryMan(
      id: isBlankText(id) ? null : id!.trim(),
      name: name.isEmpty ? null : name,
      phone: phone,
      photo: isBlankText(photo) ? null : photo!.trim(),
    );
  }

  bool get isEmpty => id == null && name == null && phone == null && photo == null;

  Map<String, dynamic> toJson() => {'id': id ?? '', 'name': name ?? '', 'phone': phone ?? '', 'photo': photo ?? ''};
}

/// An order's `pod` — what every app displays. Never carries the code.
///
/// Read tolerantly; [toJson] gives back every field it was read with (a
/// field another app added is kept) with the known ones on top.
class OrderPod {
  final String? method;
  final String? status;
  final Timestamp? requestedAt;
  final Timestamp? expiresAt;
  final Timestamp? verifiedAt;
  final String? verifiedBy;
  final String? verifiedByRole;
  final PodDeliveryMan? deliveredBy;
  final Map<String, dynamic> raw;

  const OrderPod({this.method, this.status, this.requestedAt, this.expiresAt, this.verifiedAt, this.verifiedBy, this.verifiedByRole, this.deliveredBy, this.raw = const {}});

  /// Null for an order without proof of delivery (every order from before
  /// the contract), and for a `pod` that holds nothing usable.
  static OrderPod? fromJson(Object? value) {
    if (value is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final String? status = firstText(json, const ['status']);
    if (status == null) return null;
    return OrderPod(
      method: firstText(json, const ['method']),
      status: status.toLowerCase(),
      requestedAt: parseTimestamp(json['requestedAt']),
      expiresAt: parseTimestamp(json['expiresAt']),
      verifiedAt: parseTimestamp(json['verifiedAt']),
      verifiedBy: firstText(json, const ['verifiedBy']),
      verifiedByRole: firstText(json, const ['verifiedByRole']),
      deliveredBy: PodDeliveryMan.fromJson(json['deliveredBy']),
      raw: json,
    );
  }

  bool get isVerified => status == PodStatus.verified;

  bool get isPending => status == PodStatus.pending;

  Map<String, dynamic> toJson() {
    // The code never travels on the order, whatever a record was read with.
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw)..remove('code');
    if (method != null) data['method'] = method;
    if (status != null) data['status'] = status;
    if (requestedAt != null) data['requestedAt'] = requestedAt;
    if (expiresAt != null) data['expiresAt'] = expiresAt;
    if (verifiedAt != null) data['verifiedAt'] = verifiedAt;
    if (verifiedBy != null) data['verifiedBy'] = verifiedBy;
    if (verifiedByRole != null) data['verifiedByRole'] = verifiedByRole;
    if (deliveredBy != null) data['deliveredBy'] = deliveredBy!.toJson();
    return data;
  }

  /// "OTP Verified" block on the details screen and the Completed card.
  static bool showsVerified(OrderPod? pod) => pod?.isVerified == true;

  /// "Waiting for the customer's delivery code": a code was asked for and
  /// the order is still on its way (not completed, cancelled or rejected).
  static bool showsWaiting(OrderPod? pod, String? orderStatus) {
    if (pod?.isPending != true) return false;
    return orderStatus != Constant.orderCompleted && orderStatus != Constant.orderCancelled && orderStatus != Constant.orderRejected;
  }

  String get verifiedAtText => verifiedAt == null ? '' : Constant.timestampToDateTime(verifiedAt!);
}

/// `order_pod/{orderId}`: the code and its counters.
class PodCode {
  final String orderId;

  /// Empty in a copy handed to the screens ([redacted]).
  final String code;
  final String status;
  final Timestamp? generatedAt;
  final Timestamp? expiresAt;
  final int attempts;

  /// How many codes this order has had (the first one counts as 1).
  final int regenerations;
  final Timestamp? verifiedAt;

  /// True when this device generated the code, so [expiresAt] is on this
  /// device's clock (see [deadline]).
  final bool sameClock;

  const PodCode({
    required this.orderId,
    required this.code,
    required this.status,
    this.generatedAt,
    this.expiresAt,
    this.attempts = 0,
    this.regenerations = 1,
    this.verifiedAt,
    this.sameClock = false,
  });

  /// [me] is the signed-in user: a code whose `generatedBy` is [me] was
  /// timed by this device's clock.
  static PodCode? fromJson(String orderId, Map<String, dynamic>? json, {String? me}) {
    if (json == null) return null;
    int asInt(Object? v, int fallback) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
    return PodCode(
      orderId: firstText(json, const ['orderId']) ?? orderId,
      code: firstText(json, const ['code']) ?? '',
      status: (firstText(json, const ['status']) ?? PodStatus.pending).toLowerCase(),
      generatedAt: parseTimestamp(json['generatedAt']),
      expiresAt: parseTimestamp(json['expiresAt']),
      attempts: asInt(json['attempts'], 0),
      regenerations: asInt(json['regenerations'], 1),
      verifiedAt: parseTimestamp(json['verifiedAt']),
      sameClock: me != null && me.isNotEmpty && firstText(json, const ['generatedBy']) == me,
    );
  }

  /// The same record without the digits, for anything that is displayed.
  PodCode redacted() => PodCode(
    orderId: orderId,
    code: '',
    status: status,
    generatedAt: generatedAt,
    expiresAt: expiresAt,
    attempts: attempts,
    regenerations: regenerations,
    verifiedAt: verifiedAt,
    sameClock: sameClock,
  );

  bool get isVerified => status == PodStatus.verified;

  /// When the code stops working, on THIS device's clock.
  ///
  /// `expiresAt` is written from the generating device's clock, `generatedAt`
  /// by the server. On the device that generated the code ([sameClock])
  /// `expiresAt` is exact; any other device goes by the server's
  /// `generatedAt` + 10 minutes (+ [PodRules.skewTolerance]), so a phone
  /// whose clock is minutes off can neither stretch nor shorten the code's
  /// life elsewhere.
  DateTime? get deadline {
    if (sameClock && expiresAt != null) return expiresAt!.toDate();
    if (generatedAt != null) return generatedAt!.toDate().add(PodRules.codeLifetime).add(PodRules.skewTolerance);
    return expiresAt?.toDate();
  }

  /// Spent: marked expired, out of attempts, or past its [deadline].
  bool isExpiredAt(DateTime now) {
    if (status == PodStatus.expired || attempts >= PodRules.maxAttempts) return true;
    final DateTime? end = deadline;
    if (end == null) return true;
    return !now.isBefore(end);
  }

  /// Can still be entered: tapping "Mark as Completed" again reuses it.
  bool isUsableAt(DateTime now) => status == PodStatus.pending && !isExpiredAt(now);

  /// Ran out of wrong entries (as opposed to running out of time).
  bool get isLockedByAttempts => attempts >= PodRules.maxAttempts;

  /// When this code was generated, on THIS device's clock (starts the
  /// cooldown): from [expiresAt] when this device set it, else the server's
  /// `generatedAt`.
  DateTime? get issuedAt {
    if (sameClock && expiresAt != null) return expiresAt!.toDate().subtract(PodRules.codeLifetime);
    return generatedAt?.toDate() ?? expiresAt?.toDate().subtract(PodRules.codeLifetime);
  }

  /// "Get a new code" uses left (the first code is not one).
  int get regenerationsLeft => max(0, 1 + PodRules.maxRegenerations - regenerations);
}

/// What an entered code came to.
enum PodCheck { verified, wrongCode, expired, tooManyAttempts, noCode, alreadyVerified, invalidFormat, offline, orderClosed }

class PodCheckResult {
  final PodCheck outcome;

  /// Wrong entries still allowed on this code (for [PodCheck.wrongCode]).
  final int attemptsLeft;

  const PodCheckResult(this.outcome, {this.attemptsLeft = 0});

  bool get isVerified => outcome == PodCheck.verified || outcome == PodCheck.alreadyVerified;

  /// The contract's words for the store person.
  String get message => switch (outcome) {
    PodCheck.verified || PodCheck.alreadyVerified => "Delivery code verified".tr,
    PodCheck.wrongCode => attemptsLeft <= 0 ? "Too many wrong attempts. Generate a new code.".tr : "Incorrect code. @n attempts left.".trParams({'n': '$attemptsLeft'}),
    PodCheck.expired => "This code has expired. Generate a new one.".tr,
    PodCheck.tooManyAttempts => "Too many wrong attempts. Generate a new code.".tr,
    PodCheck.noCode => "No delivery code yet. Generate a code first.".tr,
    PodCheck.invalidFormat => "Enter the 6-digit code from the customer's app.".tr,
    PodCheck.offline => "You are offline. Check your connection and try again.".tr,
    PodCheck.orderClosed => "This order was cancelled or closed. It can no longer be completed.".tr,
  };
}

/// Why a new code can or cannot be generated now.
enum PodResend { allowed, coolingDown, limitReached, alreadyVerified, offline, orderClosed }

/// The rules, as pure functions.
abstract final class PodOtp {
  static final RegExp _sixDigits = RegExp(r'^\d{6}$');

  /// A new code: [PodRules.codeLength] digits from [Random.secure], never the
  /// same as [previous].
  static String generateCode({String? previous, Random? random}) {
    final Random rng = random ?? Random.secure();
    String code;
    do {
      code = List<String>.generate(PodRules.codeLength, (_) => rng.nextInt(10).toString()).join();
    } while (code == previous);
    return code;
  }

  static bool isWellFormed(String entered) => _sixDigits.hasMatch(entered.trim());

  /// When a code generated [at] stops working.
  static DateTime expiryFor(DateTime at) => at.add(PodRules.codeLifetime);

  /// Checks [entered] against [code] at [now]. The caller writes the result:
  /// [PodCheck.verified] verifies the code, [PodCheck.wrongCode] adds one to
  /// `attempts` (and expires the code when [PodCheckResult.attemptsLeft] is
  /// 0). Nothing else is written.
  static PodCheckResult check({required PodCode? code, required String entered, required DateTime now, String? orderStatus}) {
    // A cancelled / rejected order is never completed, verified code or not.
    if (PodRules.isCancelledStatus(orderStatus)) return const PodCheckResult(PodCheck.orderClosed);
    if (code != null && code.isVerified) return const PodCheckResult(PodCheck.alreadyVerified);
    // Completed without a verified code (an order from before POD).
    if (PodRules.isCompletedStatus(orderStatus)) return const PodCheckResult(PodCheck.orderClosed);
    if (!isWellFormed(entered)) return const PodCheckResult(PodCheck.invalidFormat);
    if (code == null || code.code.isEmpty) return const PodCheckResult(PodCheck.noCode);
    if (code.isLockedByAttempts) return const PodCheckResult(PodCheck.tooManyAttempts);
    if (code.status != PodStatus.pending || code.isExpiredAt(now)) return const PodCheckResult(PodCheck.expired);
    if (entered.trim() != code.code) {
      return PodCheckResult(PodCheck.wrongCode, attemptsLeft: max(0, PodRules.maxAttempts - (code.attempts + 1)));
    }
    return const PodCheckResult(PodCheck.verified);
  }

  /// How long until another code may be generated for [code] (zero when it
  /// may be generated now, or when there is no code yet).
  static Duration cooldownLeft(PodCode? code, DateTime now) {
    final DateTime? issued = code?.issuedAt;
    if (issued == null) return Duration.zero;
    final Duration left = issued.add(PodRules.resendCooldown).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the order still has new codes left after the one it has.
  static bool hasRegenerationsLeft(PodCode? code) => code == null || code.regenerations < 1 + PodRules.maxRegenerations;

  /// Whether "Get a new code" may run for [code] at [now].
  static PodResend canResend(PodCode? code, DateTime now) {
    if (code != null && code.isVerified) return PodResend.alreadyVerified;
    if (!hasRegenerationsLeft(code)) return PodResend.limitReached;
    if (cooldownLeft(code, now) > Duration.zero) return PodResend.coolingDown;
    return PodResend.allowed;
  }

  static String resendMessage(PodResend result, {Duration wait = Duration.zero}) => switch (result) {
    PodResend.allowed => "A new code was sent to the customer's app.".tr,
    PodResend.coolingDown => "You can get a new code in @s seconds.".trParams({'s': '${max(1, wait.inSeconds)}'}),
    PodResend.limitReached => "No more new codes can be generated for this order.".tr,
    PodResend.alreadyVerified => "Delivery code verified".tr,
    PodResend.offline => "You are offline. Check your connection and try again.".tr,
    PodResend.orderClosed => "This order was cancelled or closed. It can no longer be completed.".tr,
  };
}
