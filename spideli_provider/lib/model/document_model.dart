import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// A document type configured in the admin panel (`documents` collection,
/// same shape the driver and store apps read), filtered on `type == "provider"`.
///
/// The spec (3.6 / 10) requires a commercial register and a unique
/// identification number from every service provider. When the admin panel has
/// not configured them, [commercialRegister] / [uniqueIdNumber] supply them; their uploads go
/// to the same `documents_verify` doc and are mirrored on the user doc
/// (`commercialRegister*`, `uniqueIdNumber*`, like delivery carriers).
class DocumentType {
  String id;
  String title;
  bool frontSide;
  bool backSide;
  bool hasExpiry;
  bool enable;

  /// Built-in type the spec requires; [userField] names the user doc fields
  /// (`<userField>` = number, `<userField>File` = file URL).
  String? userField;

  DocumentType({required this.id, required this.title, this.frontSide = true, this.backSide = false, this.hasExpiry = false, this.enable = true, this.userField});

  bool get isBuiltIn => userField != null;

  factory DocumentType.fromJson(Map<String, dynamic> json, {String? docId}) {
    return DocumentType(
      id: (json['id']?.toString().isNotEmpty == true) ? json['id'].toString() : (docId ?? ''),
      title: json['title']?.toString() ?? '',
      frontSide: json['frontSide'] == true,
      backSide: json['backSide'] == true,
      hasExpiry: json['expireAt'] == true,
      enable: json['enable'] != false,
    );
  }

  static const String commercialRegisterId = 'commercialRegister';
  static const String uniqueIdNumberId = 'uniqueIdNumber';

  static DocumentType commercialRegister() =>
      DocumentType(id: commercialRegisterId, title: 'Commercial register'.tr, frontSide: true, userField: 'commercialRegister');

  static DocumentType uniqueIdNumber() =>
      DocumentType(id: uniqueIdNumberId, title: 'Unique identification number'.tr, frontSide: true, userField: 'uniqueIdNumber');

  /// Whether an admin-configured type already covers a required one (matched
  /// on its title, French or English).
  static bool coversCommercialRegister(DocumentType t) {
    final s = t.title.toLowerCase();
    return s.contains('commercial') || s.contains('commerce') || s.contains('rccm') || s.contains('trade regist');
  }

  static bool coversUniqueIdNumber(DocumentType t) {
    final s = t.title.toLowerCase();
    return s.contains('unique') || s.contains('identifiant') || s.contains('niu') || s.contains('identification number') || s.contains('tax id');
  }
}

/// Verification statuses (spec 3.6).
enum DocumentStatus { notSubmitted, pendingReview, approved, rejected, expired }

extension DocumentStatusLabel on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.notSubmitted:
        return 'Not submitted'.tr;
      case DocumentStatus.pendingReview:
        return 'Pending review'.tr;
      case DocumentStatus.approved:
        return 'Approved'.tr;
      case DocumentStatus.rejected:
        return 'Rejected'.tr;
      case DocumentStatus.expired:
        return 'Expired'.tr;
    }
  }

  /// A new upload is allowed when nothing valid is on file.
  bool get canUpload => this == DocumentStatus.notSubmitted || this == DocumentStatus.rejected || this == DocumentStatus.expired;
}

/// One entry of `documents_verify/{uid}.documents` (existing eMart shape:
/// `documentId`, `frontImage`, `backImage`, `status`), plus the optional
/// `expireAt`, `number`, `submittedAt` and the panel's rejection reason.
class UploadedDocument {
  String documentId;
  String? frontImage;
  String? backImage;
  String? status;
  String? number;
  Timestamp? expireAt;
  Timestamp? submittedAt;
  String? rejectionReason;

  /// Every other key of the entry, kept as-is so a re-upload never drops a
  /// field the admin panel wrote.
  Map<String, dynamic> extra;

  UploadedDocument({required this.documentId, this.frontImage, this.backImage, this.status, this.number, this.expireAt, this.submittedAt, this.rejectionReason, Map<String, dynamic>? extra})
      : extra = extra ?? {};

  static const List<String> reasonKeys = ['rejectionReason', 'rejectReason', 'rejectedReason', 'rejected_reason', 'reason', 'note'];

  factory UploadedDocument.fromJson(Map<String, dynamic> json) {
    String? reason;
    for (final key in reasonKeys) {
      final v = json[key]?.toString();
      if (v != null && v.trim().isNotEmpty) {
        reason = v.trim();
        break;
      }
    }
    final Map<String, dynamic> extra = Map<String, dynamic>.from(json)
      ..remove('documentId')
      ..remove('frontImage')
      ..remove('backImage')
      ..remove('status')
      ..remove('number')
      ..remove('expireAt')
      ..remove('submittedAt');
    return UploadedDocument(
      documentId: json['documentId']?.toString() ?? '',
      frontImage: json['frontImage']?.toString(),
      backImage: json['backImage']?.toString(),
      status: json['status']?.toString(),
      number: json['number']?.toString(),
      expireAt: _timestamp(json['expireAt']),
      submittedAt: _timestamp(json['submittedAt']),
      rejectionReason: reason,
      extra: extra,
    );
  }

  static Timestamp? _timestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String && v.isNotEmpty) {
      final d = DateTime.tryParse(v);
      if (d != null) return Timestamp.fromDate(d);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'documentId': documentId,
        'frontImage': frontImage ?? '',
        'backImage': backImage ?? '',
        'status': status,
        if (number != null) 'number': number,
        if (expireAt != null) 'expireAt': expireAt,
        if (submittedAt != null) 'submittedAt': submittedAt,
      };

  bool get hasFile => (frontImage ?? '').isNotEmpty || (backImage ?? '').isNotEmpty;

  /// Status as defined by spec 3.6, from the stored eMart status values
  /// ("uploaded"/"pending", "approved", "rejected", "expired") and the
  /// expiry date.
  DocumentStatus get verificationStatus {
    final s = (status ?? '').toLowerCase();
    if (s == 'rejected') return DocumentStatus.rejected;
    if (s == 'expired') return DocumentStatus.expired;
    if (expireAt != null && expireAt!.toDate().isBefore(DateTime.now())) return DocumentStatus.expired;
    if (s == 'approved' || s == 'verified') return DocumentStatus.approved;
    if (!hasFile) return DocumentStatus.notSubmitted;
    return DocumentStatus.pendingReview;
  }
}
