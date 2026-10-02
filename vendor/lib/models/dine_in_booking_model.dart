import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/cancellation.dart';

class DineInBookingModel {
  String? discount;
  String? id;
  String? guestPhone;
  String? guestFirstName;
  String? status;
  UserModel? author;
  String? guestEmail;
  String? vendorID;
  String? occasion;
  String? authorID;
  String? specialRequest;
  Timestamp? date;
  String? totalGuest;
  VendorModel? vendor;
  bool? firstVisit;
  Timestamp? createdAt;
  String? guestLastName;
  String? discountType;

  /// Who cancelled / rejected the booking, why and when — the shared contract
  /// (`.claude/CANCEL-REASON-CONTRACT.md`). Read tolerantly and written only
  /// when set, so a later save never clears what another actor recorded.
  String? cancelReason;
  String? cancelReasonCode;
  String? cancelledBy;
  String? cancelledByName;
  Timestamp? cancelledAt;
  String? cancelAction;

  /// Set by [markEndedByVendor]: the next write stamps `cancelledAt` with the
  /// server's clock. Cleared once that write lands.
  bool stampCancelledAtOnServer = false;

  DineInBookingModel({
    this.discount,
    this.id,
    this.guestPhone,
    this.guestFirstName,
    this.status,
    this.author,
    this.guestEmail,
    this.vendorID,
    this.occasion,
    this.authorID,
    this.specialRequest,
    this.date,
    this.totalGuest,
    this.vendor,
    this.firstVisit,
    this.createdAt,
    this.guestLastName,
    this.discountType,
    this.cancelReason,
    this.cancelReasonCode,
    this.cancelledBy,
    this.cancelledByName,
    this.cancelledAt,
    this.cancelAction,
  });

  DineInBookingModel.fromJson(Map<String, dynamic> json) {
    print(json['id']);
    discount = json['discount'] ?? "0";
    id = json['id'];
    guestPhone = json['guestPhone'];
    guestFirstName = json['guestFirstName'];
    status = json['status'];
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    guestEmail = json['guestEmail'];
    vendorID = json['vendorID'];
    occasion = json['occasion'];
    authorID = json['authorID'];
    specialRequest = json['specialRequest'];
    date = json['date'];
    totalGuest = json['totalGuest'].toString();
    vendor = json['vendor'] != null ? VendorModel.fromJson(json['vendor']) : null;
    firstVisit = json['firstVisit'];
    createdAt = json['createdAt'];
    guestLastName = json['guestLastName'];
    discountType = json['discountType'];
    cancelReason = firstText(json, const ['cancelReason', 'cancellationReason', 'cancel_reason', 'rejectReason', 'rejectionReason']);
    cancelReasonCode = firstText(json, const ['cancelReasonCode', 'cancel_reason_code']);
    cancelledBy = firstText(json, const ['cancelledBy', 'canceledBy', 'cancelled_by']);
    cancelledByName = firstText(json, const ['cancelledByName', 'canceledByName']);
    cancelledAt = parseTimestamp(json['cancelledAt'] ?? json['canceledAt']);
    cancelAction = firstText(json, const ['cancelAction']);
  }

  /// Records that the store [action]ed this booking for [reason]; the caller
  /// writes it with the status change in one [FireStoreUtils.setBookedOrder].
  void markEndedByVendor({required String action, required String reason, required String code, String? byName}) {
    cancelReason = reason;
    cancelReasonCode = code;
    cancelledBy = 'vendor';
    cancelledByName = isBlankText(byName) ? null : byName!.trim();
    cancelAction = action;
    cancelledAt = Timestamp.now();
    stampCancelledAtOnServer = true;
  }

  /// True while the booking stands cancelled or rejected (by anyone).
  bool get isEnded => CancellationDetails.isEndedStatus(status);

  CancellationDetails get cancellation => CancellationDetails.of(
    status: status,
    cancelAction: cancelAction,
    reason: cancelReason,
    cancelledBy: cancelledBy,
    cancelledByName: cancelledByName,
    cancelledAt: cancelledAt,
  );

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['discount'] = discount;
    data['id'] = id;
    data['guestPhone'] = guestPhone;
    data['guestFirstName'] = guestFirstName;
    data['status'] = status;
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['guestEmail'] = guestEmail;
    data['vendorID'] = vendorID;
    data['occasion'] = occasion;
    data['authorID'] = authorID;
    data['specialRequest'] = specialRequest;
    data['date'] = date;
    data['totalGuest'] = totalGuest;
    if (vendor != null) {
      data['vendor'] = vendor!.toJson();
    }
    data['firstVisit'] = firstVisit;
    data['createdAt'] = createdAt;
    data['guestLastName'] = guestLastName;
    data['discountType'] = discountType;
    if (cancelReason != null) data['cancelReason'] = cancelReason;
    if (cancelReasonCode != null) data['cancelReasonCode'] = cancelReasonCode;
    if (cancelledBy != null) data['cancelledBy'] = cancelledBy;
    if (cancelledByName != null) data['cancelledByName'] = cancelledByName;
    if (cancelAction != null) data['cancelAction'] = cancelAction;
    if (stampCancelledAtOnServer) {
      data['cancelledAt'] = FieldValue.serverTimestamp();
    } else if (cancelledAt != null) {
      data['cancelledAt'] = cancelledAt;
    }
    return data;
  }
}
