import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';

/// The shared cancellation / rejection contract (client requirement of
/// 2 Oct 2026, `.claude/CANCEL-REASON-CONTRACT.md`).
///
/// Every final cancellation or rejection writes, on the order / booking, in
/// the same write as its status change: `cancelReason`, `cancelReasonCode`,
/// `cancelledBy`, `cancelledByName`, `cancelledAt` (server time) and
/// `cancelAction` ("cancelled" | "rejected"). This file reads those fields
/// tolerantly and turns them into the words the screens show.
class CancelAction {
  CancelAction._();

  static const String cancelled = 'cancelled';
  static const String rejected = 'rejected';
}

/// Who a record says ended it.
enum CancelParty { customer, store, driver, provider, worker, admin, unknown }

/// A value that holds no usable text: null, blank, or the string "null" a
/// `"$value"` interpolation of a null leaves behind.
bool isBlankText(Object? value) {
  if (value == null) return true;
  final String text = value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined';
}

/// The first of [keys] in [json] that carries usable text, trimmed.
String? firstText(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final Object? value = json[key];
    if (value is String || value is num) {
      if (!isBlankText(value)) return value.toString().trim();
    }
  }
  return null;
}

/// A point in time written by any of the apps or panels: a Firestore
/// [Timestamp], a [DateTime], epoch milliseconds (or seconds), an ISO string,
/// or the `{_seconds, _nanoseconds}` / `{seconds, nanoseconds}` map a REST
/// write leaves. Anything else is null.
Timestamp? parseTimestamp(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is int) {
    // Seconds before ~2001-09, milliseconds after: no real cancellation is
    // that old, so a small number is seconds.
    return value < 100000000000 ? Timestamp.fromMillisecondsSinceEpoch(value * 1000) : Timestamp.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) return parseTimestamp(value.toInt());
  if (value is String) {
    final DateTime? parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return Timestamp.fromDate(parsed);
    final int? asInt = int.tryParse(value.trim());
    return asInt == null ? null : parseTimestamp(asInt);
  }
  if (value is Map) {
    final Object? seconds = value['_seconds'] ?? value['seconds'];
    final Object? nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
    if (seconds is num) return Timestamp(seconds.toInt(), nanos is num ? nanos.toInt() : 0);
  }
  return null;
}

/// One driver passing on an order offer — not a final rejection; the order
/// went back to dispatch. Shape: `{driverId, reason, code, at, afterAccept}`.
class DriverRejection {
  final String driverId;
  final String? driverName;
  final String? reason;
  final String? code;
  final Timestamp? at;
  final bool afterAccept;

  const DriverRejection({required this.driverId, this.driverName, this.reason, this.code, this.at, this.afterAccept = false});

  static DriverRejection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return DriverRejection(
      driverId: firstText(json, const ['driverId', 'driverID', 'driver_id']) ?? '',
      driverName: firstText(json, const ['driverName', 'name']),
      reason: firstText(json, const ['reason', 'cancelReason']),
      code: firstText(json, const ['code', 'reasonCode']),
      at: parseTimestamp(json['at'] ?? json['createdAt'] ?? json['date']),
      afterAccept: json['afterAccept'] == true,
    );
  }

  /// Every readable entry of a stored `driverRejections` list, oldest first.
  static List<DriverRejection> listFrom(Object? raw) {
    if (raw is! Iterable) return const [];
    final List<DriverRejection> list = raw.map(DriverRejection.fromJson).whereType<DriverRejection>().toList();
    list.sort((a, b) => (a.at?.millisecondsSinceEpoch ?? 0).compareTo(b.at?.millisecondsSinceEpoch ?? 0));
    return list;
  }
}

/// What the screens need to say about a cancelled or rejected record.
class CancellationDetails {
  final String? reason;
  final String? cancelledBy;
  final String? cancelledByName;
  final Timestamp? cancelledAt;

  /// "cancelled" or "rejected"; from `cancelAction`, else the status.
  final String action;
  final List<DriverRejection> driverRejections;

  const CancellationDetails({
    required this.reason,
    required this.cancelledBy,
    required this.cancelledByName,
    required this.cancelledAt,
    required this.action,
    this.driverRejections = const [],
  });

  /// [status] decides the action when the record carries no `cancelAction`
  /// (written before the contract existed).
  factory CancellationDetails.of({
    required String? status,
    String? cancelAction,
    String? reason,
    String? cancelledBy,
    String? cancelledByName,
    Timestamp? cancelledAt,
    List<DriverRejection> driverRejections = const [],
  }) {
    final String explicit = (cancelAction ?? '').trim().toLowerCase();
    final String action = explicit == CancelAction.rejected || explicit == 'reject'
        ? CancelAction.rejected
        : explicit == CancelAction.cancelled || explicit == 'canceled' || explicit == 'cancel'
        ? CancelAction.cancelled
        : (status == Constant.orderRejected || (status ?? '').toLowerCase().contains('reject'))
        ? CancelAction.rejected
        : CancelAction.cancelled;
    return CancellationDetails(
      reason: isBlankText(reason) ? null : reason!.trim(),
      cancelledBy: isBlankText(cancelledBy) ? null : cancelledBy!.trim(),
      cancelledByName: isBlankText(cancelledByName) ? null : cancelledByName!.trim(),
      cancelledAt: cancelledAt,
      action: action,
      driverRejections: driverRejections,
    );
  }

  /// True for a status that ends the order / booking.
  static bool isEndedStatus(String? status) => status == Constant.orderCancelled || status == Constant.orderRejected;

  bool get isRejected => action == CancelAction.rejected;

  CancelParty get party => partyOf(cancelledBy);

  static CancelParty partyOf(String? by) {
    switch ((by ?? '').trim().toLowerCase()) {
      case 'customer':
      case 'user':
        return CancelParty.customer;
      case 'vendor':
      case 'store':
      case 'restaurant':
        return CancelParty.store;
      case 'driver':
        return CancelParty.driver;
      case 'provider':
        return CancelParty.provider;
      case 'worker':
        return CancelParty.worker;
      case 'admin':
      case 'superadmin':
        return CancelParty.admin;
      default:
        return CancelParty.unknown;
    }
  }

  /// The section's own word for the store: "Restaurant" for a food section,
  /// "Store" otherwise.
  static String storeWord() {
    final String name = (Constant.selectedSection?.name ?? '').toLowerCase();
    return name.contains('food') || name.contains('restaurant') ? "Restaurant".tr : "Store".tr;
  }

  static String partyLabel(CancelParty party) => switch (party) {
    CancelParty.customer => "Customer".tr,
    CancelParty.store => storeWord(),
    CancelParty.driver => "Driver".tr,
    CancelParty.provider => "Service provider".tr,
    CancelParty.worker => "Worker".tr,
    CancelParty.admin => "Admin".tr,
    CancelParty.unknown => '',
  };

  /// "Cancelled by Customer", "Rejected by Restaurant", or just "Cancelled"
  /// when nobody was recorded.
  String get headline {
    String who = partyLabel(party);
    // An unrecognised party name is still better shown than dropped.
    if (who.isEmpty && cancelledBy != null) who = cancelledBy!;
    if (who.isEmpty) return isRejected ? "Rejected".tr : "Cancelled".tr;
    return "${isRejected ? "Rejected by".tr : "Cancelled by".tr} $who";
  }

  /// The reason, or "No reason recorded" for a record from before reasons
  /// were mandatory — never blank, never "null".
  String get reasonText => reason ?? "No reason recorded".tr;

  String get timeText => cancelledAt == null ? '' : Constant.timestampToDateTime(cancelledAt!);

  /// "Cancelled by Customer · Changed my plans", for list cards.
  String get oneLine => "$headline · ${reason == null ? reasonText : reason!.tr}";
}
