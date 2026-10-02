import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/cancellation_info.dart';

/// `vendor_orders/{id}.pod` — the proof-of-delivery record every app shows
/// (`.claude/POD-OTP-CONTRACT.md`). It never contains the code.
class DeliveryPod {
  String? method;
  String? status;
  Timestamp? requestedAt;
  Timestamp? expiresAt;
  Timestamp? verifiedAt;
  String? verifiedBy;
  String? verifiedByRole;
  PodDeliveredBy? deliveredBy;

  DeliveryPod({this.method, this.status, this.requestedAt, this.expiresAt, this.verifiedAt, this.verifiedBy, this.verifiedByRole, this.deliveredBy});

  static DeliveryPod? fromJson(dynamic json) {
    if (json is! Map) return null;
    final Map<String, dynamic> m = Map<String, dynamic>.from(json);
    final dynamic by = m['deliveredBy'];
    return DeliveryPod(
      method: CancellationInfo.text(m['method']),
      status: CancellationInfo.text(m['status']),
      requestedAt: CancellationInfo.parseAt(m['requestedAt']),
      expiresAt: CancellationInfo.parseAt(m['expiresAt']),
      verifiedAt: CancellationInfo.parseAt(m['verifiedAt']),
      verifiedBy: CancellationInfo.text(m['verifiedBy']),
      verifiedByRole: CancellationInfo.text(m['verifiedByRole']),
      deliveredBy: by is Map ? PodDeliveredBy.fromJson(Map<String, dynamic>.from(by)) : null,
    );
  }

  /// Known fields only: the order is saved with `set(merge: true)`, which
  /// merges this map field by field, so a later save never clears what the
  /// verification (or another app) wrote.
  Map<String, dynamic> toJson() => {
        if (method != null) 'method': method,
        if (status != null) 'status': status,
        if (requestedAt != null) 'requestedAt': requestedAt,
        if (expiresAt != null) 'expiresAt': expiresAt,
        if (verifiedAt != null) 'verifiedAt': verifiedAt,
        if (verifiedBy != null) 'verifiedBy': verifiedBy,
        if (verifiedByRole != null) 'verifiedByRole': verifiedByRole,
        if (deliveredBy != null && deliveredBy!.toJson().isNotEmpty) 'deliveredBy': deliveredBy!.toJson(),
      };

  bool get isVerified => status == 'verified';
}

/// `pod.deliveredBy` — the delivery man.
class PodDeliveredBy {
  String? id;
  String? name;
  String? phone;
  String? photo;

  PodDeliveredBy({this.id, this.name, this.phone, this.photo});

  factory PodDeliveredBy.fromJson(Map<String, dynamic> json) => PodDeliveredBy(
        id: CancellationInfo.text(json['id']),
        name: CancellationInfo.text(json['name']),
        phone: CancellationInfo.text(json['phone']),
        photo: CancellationInfo.text(json['photo']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (photo != null) 'photo': photo,
      };
}
