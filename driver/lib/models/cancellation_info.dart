import 'package:cloud_firestore/cloud_firestore.dart';

/// The cancel-reason contract fields of an order / ride / rental / parcel
/// (`.claude/CANCEL-REASON-CONTRACT.md`), read tolerantly.
///
/// A FINAL cancellation or rejection writes `cancelReason`, `cancelReasonCode`,
/// `cancelledBy`, `cancelledByName`, `cancelledAt` and `cancelAction` on the
/// record. A driver PASSING on an offer appends to `driverRejections` instead.
class CancellationInfo {
  String? reason;
  String? code;
  String? by;
  String? byName;
  Timestamp? at;
  String? action;

  /// `driverRejections` entries (`{driverId, reason, code, at, afterAccept}`).
  /// Read only: they are only ever appended with `FieldValue.arrayUnion`, so
  /// [toJson] never writes them back.
  List<Map<String, dynamic>> driverRejections;

  CancellationInfo({this.reason, this.code, this.by, this.byName, this.at, this.action, List<Map<String, dynamic>>? driverRejections})
      : driverRejections = driverRejections ?? [];

  factory CancellationInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['driverRejections'];
    return CancellationInfo(
      reason: text(json['cancelReason']),
      code: text(json['cancelReasonCode']),
      by: text(json['cancelledBy']),
      byName: text(json['cancelledByName']),
      at: parseAt(json['cancelledAt']),
      action: text(json['cancelAction']),
      driverRejections: raw is Iterable ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [],
    );
  }

  /// Only the fields that are known, so a later save of the record (a full
  /// `set(..., merge: true)`) never clears what another app wrote.
  Map<String, dynamic> toJson() => {
        if (reason != null) 'cancelReason': reason,
        if (code != null) 'cancelReasonCode': code,
        if (by != null) 'cancelledBy': by,
        if (byName != null) 'cancelledByName': byName,
        if (at != null) 'cancelledAt': at,
        if (action != null) 'cancelAction': action,
      };

  static String? text(dynamic value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  /// Timestamp, DateTime, epoch millis / seconds, ISO string or a serialised
  /// `{_seconds}` / `{seconds}` map.
  static Timestamp? parseAt(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is num) {
      final n = value.toInt();
      if (n <= 0) return null;
      return Timestamp.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
    }
    if (value is Map) {
      final s = value['_seconds'] ?? value['seconds'];
      if (s is num) return Timestamp(s.toInt(), ((value['_nanoseconds'] ?? value['nanoseconds'] ?? 0) as num).toInt());
      return null;
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? null : Timestamp.fromDate(parsed);
  }
}
