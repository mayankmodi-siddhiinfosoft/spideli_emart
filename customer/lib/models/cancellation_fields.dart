import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The cancellation / rejection fields every order, booking, ride and parcel
/// document carries (CANCEL-REASON-CONTRACT, shared by all five apps):
/// `cancelReason`, `cancelReasonCode`, `cancelledBy`, `cancelledByName`,
/// `cancelledAt`, `cancelAction`.
///
/// Read tolerantly (any app may have written them, older records may not have
/// them at all) and written back only when present, so no save from this app
/// ever clears what another app recorded.
mixin CancellationFields {
  String? cancelReason;
  String? cancelReasonCode;

  /// `customer` | `vendor` (also `store` / `restaurant`) | `driver` |
  /// `provider` | `worker` | `admin`.
  String? cancelledBy;
  String? cancelledByName;
  Timestamp? cancelledAt;

  /// `cancelled` | `rejected`.
  String? cancelAction;

  void readCancellation(Map<String, dynamic> json) {
    cancelReason = cancellationText(json['cancelReason']);
    cancelReasonCode = cancellationText(json['cancelReasonCode']);
    cancelledBy = cancellationText(json['cancelledBy'])?.toLowerCase();
    cancelledByName = cancellationText(json['cancelledByName']);
    cancelledAt = cancellationTimestamp(json['cancelledAt']);
    cancelAction = cancellationText(json['cancelAction'])?.toLowerCase();
  }

  /// Adds the fields that are set; absent ones are left out (never written as
  /// null), so a full-model save cannot wipe them.
  void writeCancellation(Map<String, dynamic> data) {
    if (cancelReason != null) data['cancelReason'] = cancelReason;
    if (cancelReasonCode != null) data['cancelReasonCode'] = cancelReasonCode;
    if (cancelledBy != null) data['cancelledBy'] = cancelledBy;
    if (cancelledByName != null) data['cancelledByName'] = cancelledByName;
    if (cancelledAt != null) data['cancelledAt'] = cancelledAt;
    if (cancelAction != null) data['cancelAction'] = cancelAction;
  }
}

/// Trimmed text, or null for missing / blank / "null".
String? cancellationText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

/// Timestamp written by any client: Firestore Timestamp, DateTime, epoch
/// millis, ISO string or a serialized `{_seconds, _nanoseconds}` map.
Timestamp? cancellationTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : Timestamp.fromDate(parsed);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
    if (seconds is int && nanos is int) return Timestamp(seconds, nanos);
  }
  return null;
}

/// What a details screen / list card shows for a cancelled or rejected
/// record: "Cancelled by Restaurant", the reason (or "No reason recorded")
/// and the time.
class CancellationSummary {
  final String headline;
  final String reason;
  final bool hasReason;
  final String? actorName;
  final DateTime? at;

  const CancellationSummary({required this.headline, required this.reason, required this.hasReason, this.actorName, this.at});

  /// Statuses that end a record. A driver passing on an offer ("Driver
  /// Rejected") is not final: the order goes back to dispatch.
  static bool isFinalStatus(String? status) {
    if (status == null) return false;
    if (status == Constant.orderCancelled || status == Constant.orderRejected) return true;
    final s = status.trim().toLowerCase();
    return s == 'cancelled' || s == 'canceled' || s == 'rejected' || s == 'declined';
  }

  /// The party label for `cancelledBy`, or null when unknown.
  /// [vendorWord] is the section's own word for the store ("Restaurant" /
  /// "Store").
  static String? partyLabel(String? by, {String vendorWord = 'Store'}) {
    switch (by?.trim().toLowerCase()) {
      case 'customer':
      case 'user':
        return 'Customer'.tr;
      case 'vendor':
      case 'store':
      case 'restaurant':
        return vendorWord.tr;
      case 'driver':
        return 'Driver'.tr;
      case 'provider':
        return 'Service provider'.tr;
      case 'worker':
        return 'Worker'.tr;
      case 'admin':
        return 'Admin'.tr;
      default:
        return null;
    }
  }

  /// Null when the record is not cancelled / rejected. [fallbackReason] is a
  /// pre-contract reason field (e.g. on-demand `reason`).
  static CancellationSummary? of({required String? status, required CancellationFields fields, String vendorWord = 'Store', String? fallbackReason}) {
    if (!isFinalStatus(status)) return null;
    final by = fields.cancelledBy;
    final String lowerStatus = (status ?? '').toLowerCase();
    final bool rejected = switch (fields.cancelAction) {
      'rejected' => true,
      'cancelled' => false,
      // Older records: a customer always cancels; otherwise the status says.
      _ => by != 'customer' && (lowerStatus.contains('reject') || lowerStatus.contains('declin')),
    };
    final party = partyLabel(by, vendorWord: vendorWord);
    final String headline = party == null
        ? (rejected ? 'Rejected'.tr : 'Cancelled'.tr)
        : (rejected ? 'Rejected by @party'.trParams({'party': party}) : 'Cancelled by @party'.trParams({'party': party}));
    final reason = fields.cancelReason ?? cancellationText(fallbackReason);
    return CancellationSummary(
      headline: headline,
      reason: reason ?? 'No reason recorded'.tr,
      hasReason: reason != null,
      actorName: by == 'customer' ? null : fields.cancelledByName,
      at: fields.cancelledAt?.toDate(),
    );
  }

  String? get timeLabel => at == null ? null : DateFormat('dd MMM yyyy, hh:mm a').format(at!);

  /// "Cancelled by Customer · Changed my plans".
  String get oneLine => '$headline · $reason';
}
