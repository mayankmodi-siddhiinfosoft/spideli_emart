import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/cancellation_fields.dart';

/// Proof of delivery by customer OTP (POD-OTP-CONTRACT), multivendor and
/// e-commerce delivery orders only.
///
/// The Driver and Store apps write both shapes; the customer app only reads
/// them and never writes `pod` or `order_pod`.

/// `order_pod/{orderId}` — the live delivery code the customer shows to the
/// delivery partner.
class OrderPodCode {
  static const String statusPending = 'pending';
  static const String statusVerified = 'verified';
  static const String statusExpired = 'expired';

  final String? orderId;
  final String? customerId;
  final String? driverId;
  final String? vendorId;

  /// The 6 digits, as a string.
  final String? code;

  /// `pending` | `verified` | `expired`.
  final String? status;
  final Timestamp? generatedAt;
  final Timestamp? expiresAt;
  final int attempts;
  final int regenerations;
  final Timestamp? verifiedAt;

  const OrderPodCode({
    this.orderId,
    this.customerId,
    this.driverId,
    this.vendorId,
    this.code,
    this.status,
    this.generatedAt,
    this.expiresAt,
    this.attempts = 0,
    this.regenerations = 0,
    this.verifiedAt,
  });

  factory OrderPodCode.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return OrderPodCode(
      orderId: cancellationText(json['orderId']),
      customerId: cancellationText(json['customerId']),
      driverId: cancellationText(json['driverId']),
      vendorId: cancellationText(json['vendorId']),
      code: cancellationText(json['code']),
      status: cancellationText(json['status'])?.toLowerCase(),
      generatedAt: cancellationTimestamp(json['generatedAt']),
      expiresAt: cancellationTimestamp(json['expiresAt']),
      attempts: asInt(json['attempts']),
      regenerations: asInt(json['regenerations']),
      verifiedAt: cancellationTimestamp(json['verifiedAt']),
    );
  }

  bool get isVerified => status == statusVerified;

  /// A code the customer can still read out: `pending`, has 6 digits and an
  /// expiry, and [now] is before it.
  bool isLive(DateTime now) => status == statusPending && (code ?? '').isNotEmpty && expiresAt != null && now.isBefore(expiresAt!.toDate());

  /// `expired`, or `pending` past its expiry.
  bool isExpired(DateTime now) => status == statusExpired || (status == statusPending && expiresAt != null && !now.isBefore(expiresAt!.toDate()));

  /// Time left before expiry (never negative).
  Duration remaining(DateTime now) {
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt!.toDate().difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether this document may be shown to [uid] for [orderId]: it must name
  /// that order and that customer.
  bool belongsTo({required String orderId, required String uid}) => this.orderId == orderId && customerId != null && customerId == uid;
}

/// `pod.deliveredBy` — the delivery man.
class PodDeliveredBy {
  final String? id;
  final String? name;
  final String? phone;
  final String? photo;

  const PodDeliveredBy({this.id, this.name, this.phone, this.photo});

  static PodDeliveredBy? tryParse(dynamic value) {
    if (value is! Map) return null;
    final m = Map<String, dynamic>.from(value);
    final d = PodDeliveredBy(
      id: cancellationText(m['id']),
      name: cancellationText(m['name']),
      phone: cancellationText(m['phone']),
      photo: cancellationText(m['photo']),
    );
    return d.isEmpty ? null : d;
  }

  bool get isEmpty => id == null && name == null && phone == null && photo == null;
}

/// `vendor_orders/{id}.pod` — the record every app displays once verified.
/// Never contains the code.
///
/// Kept as the raw map it was read as, so a customer save writes back exactly
/// what the driver / store wrote (including fields this app does not model).
class OrderPod {
  static const String statusPending = 'pending';
  static const String statusVerified = 'verified';

  final Map<String, dynamic> raw;

  OrderPod._(this.raw);

  /// Null for a missing / non-map / empty value (orders from before POD).
  static OrderPod? tryParse(dynamic value) {
    if (value is! Map || value.isEmpty) return null;
    return OrderPod._(Map<String, dynamic>.from(value));
  }

  /// `otp`.
  String? get method => cancellationText(raw['method']);

  /// `pending` | `verified`.
  String? get status => cancellationText(raw['status'])?.toLowerCase();
  Timestamp? get requestedAt => cancellationTimestamp(raw['requestedAt']);
  Timestamp? get expiresAt => cancellationTimestamp(raw['expiresAt']);
  Timestamp? get verifiedAt => cancellationTimestamp(raw['verifiedAt']);
  String? get verifiedBy => cancellationText(raw['verifiedBy']);

  /// `driver` | `vendor`.
  String? get verifiedByRole => cancellationText(raw['verifiedByRole'])?.toLowerCase();
  PodDeliveredBy? get deliveredBy => PodDeliveredBy.tryParse(raw['deliveredBy']);

  bool get isVerified => status == statusVerified;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}
