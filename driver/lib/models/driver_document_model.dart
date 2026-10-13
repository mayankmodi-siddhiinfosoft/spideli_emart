import 'package:cloud_firestore/cloud_firestore.dart';

class DriverDocumentModel {
  List<Documents>? documents;
  String? id;
  String? type;

  DriverDocumentModel({this.documents, this.id});

  DriverDocumentModel.fromJson(Map<String, dynamic> json) {
    if (json['documents'] != null) {
      documents = <Documents>[];
      json['documents'].forEach((v) {
        documents!.add(Documents.fromJson(v));
      });
    }
    id = json['id'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (documents != null) {
      data['documents'] = documents!.map((v) => v.toJson()).toList();
    }
    data['id'] = id;
    data['type'] = type;
    return data;
  }
}

class Documents {
  String? frontImage;
  String? status;
  String? documentId;
  String? backImage;

  /// Rejection reason written by the admin (spec 3.6). Read tolerantly from
  /// `rejectReason`, `rejectionReason` or `reason`.
  String? rejectReason;

  /// Expiry date of the document, for document types with `expireAt: true`.
  /// Read from `expireAt`, `expiryDate` or `expiry_date`.
  Timestamp? expiryDate;

  /// Every other key of the stored entry (admin-written fields), kept so that
  /// saving the list after one upload does not strip them from the others.
  Map<String, dynamic> extra = {};

  static const Set<String> _reviewKeys = {'rejectReason', 'rejectionReason', 'reason'};

  /// Who reviewed the entry and when (written by the company owner and by the
  /// admin panel). A new upload starts a new review: they go too.
  static const Set<String> _reviewerKeys = {'reviewedAt', 'reviewedBy', 'approvedAt', 'approvedBy', 'rejectedAt', 'rejectedBy'};

  /// Drops the previous review outcome (the rejection reason).
  void clearReview() {
    rejectReason = null;
    extra.removeWhere((key, _) => _reviewKeys.contains(key));
  }

  /// A new upload by the driver: a new review, never an approval. The
  /// rejection reason and who reviewed it / when are cleared; the status is
  /// `uploaded` (waiting for review).
  void resetForNewReview() {
    clearReview();
    extra.removeWhere((key, _) => _reviewerKeys.contains(key));
    status = 'uploaded';
  }

  Documents({this.frontImage, this.status, this.documentId, this.backImage, this.rejectReason, this.expiryDate});

  Documents.fromJson(Map<String, dynamic> json) {
    extra = Map<String, dynamic>.from(json)..removeWhere((key, _) => const {'frontImage', 'status', 'documentId', 'backImage', 'expireAt'}.contains(key));
    frontImage = json['frontImage'];
    status = json['status'];
    documentId = json['documentId'];
    backImage = json['backImage'];
    for (final key in const ['rejectReason', 'rejectionReason', 'reason']) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        rejectReason = value.trim();
        break;
      }
    }
    for (final key in const ['expireAt', 'expiryDate', 'expiry_date']) {
      final value = json[key];
      if (value is Timestamp) {
        expiryDate = value;
        break;
      }
    }
  }

  /// Verification status (spec 3.6): not_submitted > pending > approved /
  /// rejected > expired. "uploaded" is the app's existing "pending review".
  String get verificationStatus {
    if (status == null || status!.isEmpty) return 'not_submitted';
    if (status == 'rejected') return 'rejected';
    if (expiryDate != null && expiryDate!.toDate().isBefore(DateTime.now())) return 'expired';
    if (status == 'approved') return 'approved';
    return 'pending';
  }

  bool get isExpired => verificationStatus == 'expired';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{...extra};
    data['frontImage'] = frontImage;
    data['status'] = status;
    data['documentId'] = documentId;
    data['backImage'] = backImage;
    if (expiryDate != null) data['expireAt'] = expiryDate;
    if (rejectReason != null && rejectReason!.trim().isNotEmpty) {
      data['rejectReason'] = rejectReason!.trim();
      data['rejectionReason'] = rejectReason!.trim();
      data['reason'] = rejectReason!.trim();
    } else {
      data.remove('rejectReason');
      data.remove('rejectionReason');
      data.remove('reason');
    }
    return data;
  }
}
