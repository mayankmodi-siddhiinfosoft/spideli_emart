import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// A document type configured in the admin panel (`documents` collection,
/// same shape the driver and store apps read), filtered on `type == "provider"`
/// and `enable == true`.
///
/// Report Doc 36/41: uploads are recorded against the admin type's Firestore
/// id only. The app used to invent two types of its own, with the ids
/// `commercialRegister` / `uniqueIdNumber`, whenever the panel had none it
/// recognised; those uploads matched no type and were invisible to the admin.
/// There are no built-in types any more -- when the admin has configured none,
/// the documents screen says so.
///
/// An admin type whose title names the commercial register or the unique
/// identification number also asks for the reference number, which is kept on
/// the user doc as before ([userField] = number, `<userField>File` = file URL;
/// the booking receipt prints it).
class DocumentType {
  String id;
  String title;
  bool frontSide;
  bool backSide;
  bool hasExpiry;
  bool enable;

  /// User doc field that mirrors this type's reference number, or null when
  /// the type has none.
  String? userField;

  DocumentType({required this.id, required this.title, this.frontSide = true, this.backSide = false, this.hasExpiry = false, this.enable = true, this.userField});

  /// Whether the upload form asks for (and requires) a reference number.
  bool get needsNumber => userField != null;

  /// Front image is asked for when the type says so, and also when it sets
  /// neither side (a type must take at least one image).
  bool get needsFront => frontSide || !backSide;

  factory DocumentType.fromJson(Map<String, dynamic> json, {String? docId}) {
    final String title = json['title']?.toString() ?? '';
    return DocumentType(
      // The Firestore document id is what the panel matches uploads on.
      id: (docId != null && docId.isNotEmpty) ? docId : (json['id']?.toString() ?? ''),
      title: title,
      frontSide: json['frontSide'] == true,
      backSide: json['backSide'] == true,
      hasExpiry: json['expireAt'] == true,
      enable: json['enable'] == true,
      userField: userFieldForTitle(title),
    );
  }

  /// User doc fields the spec (3.6 / 10) keeps the provider's reference
  /// numbers in.
  static const String commercialRegisterField = 'commercialRegister';
  static const String uniqueIdNumberField = 'uniqueIdNumber';

  /// [commercialRegisterField] / [uniqueIdNumberField] when an admin type's
  /// title (French or English) names one of them, else null.
  static String? userFieldForTitle(String title) {
    final s = title.toLowerCase();
    if (s.contains('commercial') || s.contains('commerce') || s.contains('rccm') || s.contains('trade regist')) return commercialRegisterField;
    if (s.contains('unique') || s.contains('identifiant') || s.contains('niu') || s.contains('identification number') || s.contains('tax id')) return uniqueIdNumberField;
    return null;
  }

  /// The enabled provider types of a `documents` query, in a stable order
  /// (by title), without duplicates or types lacking an id.
  static List<DocumentType> enabledFrom(Iterable<MapEntry<String, Map<String, dynamic>>> docs) {
    final Map<String, DocumentType> byId = {};
    for (final doc in docs) {
      final t = DocumentType.fromJson(doc.value, docId: doc.key);
      if (t.enable && t.id.isNotEmpty) byId[t.id] = t;
    }
    return byId.values.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// An empty `documents` answer served from the cache means the types were
  /// not read (offline on a device that never loaded them; get() does not
  /// throw then), not that the admin set up none.
  static bool unreadable({required bool isEmpty, required bool isFromCache}) => isEmpty && isFromCache;
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
