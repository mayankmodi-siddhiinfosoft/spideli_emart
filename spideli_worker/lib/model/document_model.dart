import 'package:cloud_firestore/cloud_firestore.dart';

/// A document type configured by the admin in the `documents` collection
/// (same shape the Driver and Store apps read). Worker documents have
/// `type == "worker"`. `expireAt` is a flag: the document has an expiry date.
class DocumentModel {
  String? id;
  String? title;
  bool? enable;
  bool? frontSide;
  bool? backSide;
  bool? expireAt;

  DocumentModel({this.id, this.title, this.enable, this.frontSide, this.backSide, this.expireAt});

  DocumentModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    id = (json['id']?.toString().isNotEmpty == true) ? json['id'].toString() : docId;
    title = json['title']?.toString();
    enable = json['enable'] == true;
    frontSide = json['frontSide'] == true;
    backSide = json['backSide'] == true;
    expireAt = json['expireAt'] == true;
  }

  /// Used only when the admin has not configured any "worker" document type:
  /// spec 3.6 requires at least an identity document for a worker.
  static const String identityDocumentId = 'worker_identity_document';

  static DocumentModel identityDocument() =>
      DocumentModel(id: identityDocumentId, title: 'Identity document', enable: true, frontSide: true, backSide: true, expireAt: true);
}

/// `documents_verify/{uid}` -- the documents one actor uploaded (same shape
/// as the Driver app's DriverDocumentModel, with type "worker").
class WorkerDocumentModel {
  String? id;
  String? type;
  List<Documents> documents;

  WorkerDocumentModel({this.id, this.type, List<Documents>? documents}) : documents = documents ?? [];

  factory WorkerDocumentModel.fromJson(Map<String, dynamic> json) {
    final List<Documents> list = [];
    if (json['documents'] is List) {
      for (final v in json['documents']) {
        if (v is Map) list.add(Documents.fromJson(Map<String, dynamic>.from(v)));
      }
    }
    return WorkerDocumentModel(id: json['id']?.toString(), type: json['type']?.toString(), documents: list);
  }

  Documents? documentFor(String? documentId) {
    for (final d in documents) {
      if (d.documentId == documentId) return d;
    }
    return null;
  }
}

/// One uploaded document. The Driver app writes `documentId`, `frontImage`,
/// `backImage` and `status` ("uploaded" -> "approved" / "rejected", set by the
/// admin). This app keeps those four and adds, additively:
/// * `expiryDate` (Timestamp) -- entered by the worker when the document type
///   has `expireAt == true`; an approved document past it is "expired".
/// * `rejectionReason` -- written by the admin; read tolerantly from
///   `rejectionReason` / `rejectReason` / `reason`.
/// * `uploadedAt` (Timestamp).
/// Unknown keys found on an entry are carried over on re-upload.
class Documents {
  String? documentId;
  String? frontImage;
  String? backImage;
  String? status;
  Timestamp? expiryDate;
  String? rejectionReason;
  Timestamp? uploadedAt;
  Map<String, dynamic> extra;

  Documents({this.documentId, this.frontImage, this.backImage, this.status, this.expiryDate, this.rejectionReason, this.uploadedAt, Map<String, dynamic>? extra})
      : extra = extra ?? {};

  static const List<String> _known = ['documentId', 'frontImage', 'backImage', 'status', 'expiryDate', 'rejectionReason', 'uploadedAt'];

  factory Documents.fromJson(Map<String, dynamic> json) {
    final dynamic reason = json['rejectionReason'] ?? json['rejectReason'] ?? json['reason'];
    final dynamic expiry = json['expiryDate'] ?? json['expireAt'];
    return Documents(
      documentId: json['documentId']?.toString(),
      frontImage: json['frontImage']?.toString(),
      backImage: json['backImage']?.toString(),
      status: json['status']?.toString(),
      expiryDate: expiry is Timestamp ? expiry : null,
      rejectionReason: (reason == null || reason.toString().isEmpty) ? null : reason.toString(),
      uploadedAt: json['uploadedAt'] is Timestamp ? json['uploadedAt'] : null,
      extra: Map<String, dynamic>.from(json)..removeWhere((k, _) => _known.contains(k)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...extra,
      'documentId': documentId,
      'frontImage': frontImage ?? '',
      'backImage': backImage ?? '',
      'status': status,
      if (expiryDate != null) 'expiryDate': expiryDate,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (uploadedAt != null) 'uploadedAt': uploadedAt,
    };
  }
}

/// Spec 3.6 statuses.
enum VerificationStatus { notSubmitted, pending, approved, rejected, expired }

extension VerificationStatusLabel on VerificationStatus {
  String get label {
    switch (this) {
      case VerificationStatus.notSubmitted:
        return 'Not submitted';
      case VerificationStatus.pending:
        return 'Pending review';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.expired:
        return 'Expired';
    }
  }
}
