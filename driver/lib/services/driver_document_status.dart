/// The document verification status of a driver, computed in ONE place from
/// the current status of each REQUIRED document. No Firebase here, so every
/// rule is unit tested (test/driver_document_status_test.dart).
///
/// Contract with the admin panel: `.claude/DOCUMENT-VERIFICATION-DRIVER.md`.
///
/// * Required documents: `documents` where `enable == true` and `type` is one
///   of `FireStoreUtils.documentTypesFor(driver)` — `driver`, plus `vehicle`
///   for a cab / rental driver ([DriverDocumentStatus.requiredOf]).
/// * The uploads: `documents_verify/{uid}`, a record of type `driver`
///   ([DocumentRecordType]); a record of another holder type (`worker`,
///   `provider`, `vendor`, `owner` for a driver) is never read as, nor
///   overwritten with, a driver's documents.
/// * [DocumentOverallStatus]: not submitted / pending / action required /
///   verified ([DriverDocumentStatus.overall]); every screen and, for a
///   company driver, every jobs gate uses it.
/// * `users.isDocumentVerify` follows it: the owner's review writes it to
///   `overall == verified` ([DriverDocumentStatus.flagAfterReview]); a company
///   driver's upload lowers it when the status is no longer verified, never
///   raises it ([DriverDocumentStatus.flagAfterSubmit]).
library;

import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:get/get.dart';

/// The overall verification status of a driver's documents.
enum DocumentOverallStatus {
  /// No required document uploaded.
  notSubmitted('not_submitted', 'Not submitted'),

  /// Some required documents not uploaded yet, or uploaded (or re-uploaded)
  /// and waiting for review; none rejected or expired.
  pending('pending', 'Pending'),

  /// A required document was rejected or has expired: the driver must upload
  /// it again. Never verified while this lasts.
  actionRequired('action_required', 'Action required'),

  /// Every required document uploaded AND approved.
  verified('verified', 'Verified');

  const DocumentOverallStatus(this.key, this.label);

  /// The value the admin panel shows / filters on.
  final String key;

  /// English label = translation key (`.tr`).
  final String label;

  static DocumentOverallStatus? fromKey(String? key) => DocumentOverallStatus.values.firstWhereOrNull((s) => s.key == key);
}

/// The status of ONE document entry, as shown on its row.
abstract final class DocumentEntryStatus {
  static const String notSubmitted = 'not_submitted';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String expired = 'expired';

  /// English label = translation key (`.tr`).
  static String label(String status) => switch (status) {
        approved => 'Approved',
        rejected => 'Rejected',
        expired => 'Expired',
        pending => 'Pending review',
        _ => 'Not submitted',
      };
}

/// The holder type of a `documents_verify/{uid}` record (field `type`). The
/// panel's types: `driver` | `vendor` | `owner` | `provider` | `worker`.
abstract final class DocumentRecordType {
  static const String driver = 'driver';
  static const String owner = 'owner';
  static const String worker = 'worker';
  static const String provider = 'provider';
  static const String vendor = 'vendor';

  /// The record type [user] writes: `owner` for a company account, `driver`
  /// for every driver (platform or company driver).
  static String forUser(UserModel? user) => user?.isOwner == true ? owner : driver;

  /// True when a record stored with [stored] type may be read / written as
  /// the documents of an [expected] holder. A record without a type is a
  /// legacy driver-app record. A company's record was filed as `driver`
  /// before (report §3 02#26), so an owner still reads it. A `worker`,
  /// `provider` or `vendor` record never belongs to a driver, and an `owner`
  /// record never to a driver.
  static bool belongsTo(Object? stored, String expected) {
    final String s = (stored ?? '').toString().trim();
    if (s.isEmpty || s == expected) return true;
    return expected == owner && s == driver;
  }

  /// The entries of a `documents_verify` record for an [expected] holder;
  /// none when the record belongs to another holder type.
  static List<Documents> entriesOf(Map<String, dynamic>? record, String expected) {
    if (record == null || !belongsTo(record['type'], expected)) return <Documents>[];
    return DriverDocumentModel.fromJson(record).documents ?? <Documents>[];
  }
}

/// What the document TYPE of a required document is called on screen
/// (translation keys): `driver` documents and `vehicle` documents are their
/// own types; a company driver's document is never shown as `worker`.
abstract final class DocumentTypeLabel {
  static String of(String? type) => switch ((type ?? '').trim()) {
        DocumentRecordType.driver => 'Driver',
        'vehicle' => 'Vehicle',
        DocumentRecordType.owner => 'Company',
        _ => 'Driver',
      };
}

/// What a driver's upload writes ([DriverDocumentStatus.submit]).
class DocumentSubmitPlan {
  /// The record belongs to another holder type: nothing is written.
  final bool refused;

  /// The complete entry list to write (other entries unchanged).
  final List<Documents> documents;

  /// The overall status after the upload.
  final DocumentOverallStatus overall;

  /// `false` = lower `isDocumentVerify` in the same write; `null` = leave it.
  /// Never `true`: a driver never raises its own flag.
  final bool? setVerified;

  const DocumentSubmitPlan({this.refused = false, this.documents = const [], this.overall = DocumentOverallStatus.notSubmitted, this.setVerified});
}

abstract final class DriverDocumentStatus {
  /// A company driver: `users.ownerId` set, not the company itself. Their
  /// company owner reviews their documents.
  static bool isCompanyDriver(UserModel? user) => user != null && user.isOwner != true && (user.ownerId ?? '').trim().isNotEmpty;

  /// The required documents among [all]: enabled, and of one of [types].
  static List<DocumentModel> requiredOf(Iterable<DocumentModel> all, List<String> types) {
    final Set<String> wanted = types.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    final Set<String> seen = {};
    return all.where((d) => d.enable == true && wanted.contains((d.type ?? '').trim()) && seen.add(d.id ?? '')).toList();
  }

  /// The status of one entry ([DocumentEntryStatus]). A rejection counts even
  /// without an image; otherwise an entry without any uploaded file is not
  /// submitted.
  static String entryStatus(Documents? d) {
    if (d == null) return DocumentEntryStatus.notSubmitted;
    final String s = d.verificationStatus;
    if (s == DocumentEntryStatus.rejected) return s;
    if (!OwnerVerificationRules.isUploaded(d)) return DocumentEntryStatus.notSubmitted;
    return s;
  }

  /// THE overall status, from the current status of every [required]
  /// document in [docs] (entries for other documents are ignored):
  ///
  /// 1. any required document rejected or expired → [DocumentOverallStatus.actionRequired]
  /// 2. every required document uploaded and approved → [DocumentOverallStatus.verified]
  /// 3. no required document uploaded → [DocumentOverallStatus.notSubmitted]
  /// 4. otherwise → [DocumentOverallStatus.pending]
  ///
  /// `users.isDocumentVerify` does not decide it. Only when the admin requires
  /// no document at all ([required] empty) is there nothing to compute: the
  /// stored [flag] then says verified or not submitted.
  static DocumentOverallStatus overall({required List<DocumentModel> required, required List<Documents> docs, bool? flag}) {
    if (required.isEmpty) return flag == true ? DocumentOverallStatus.verified : DocumentOverallStatus.notSubmitted;
    final List<String> statuses = required.map((r) => entryStatus(OwnerVerificationRules.entryFor(docs, r.id))).toList();
    if (statuses.any((s) => s == DocumentEntryStatus.rejected || s == DocumentEntryStatus.expired)) return DocumentOverallStatus.actionRequired;
    if (statuses.every((s) => s == DocumentEntryStatus.approved)) return DocumentOverallStatus.verified;
    if (statuses.every((s) => s == DocumentEntryStatus.notSubmitted)) return DocumentOverallStatus.notSubmitted;
    return DocumentOverallStatus.pending;
  }

  /// Count of drivers per status (the owner's list).
  static Map<DocumentOverallStatus, int> counts(Iterable<DocumentOverallStatus> statuses) {
    final Map<DocumentOverallStatus, int> out = {for (final s in DocumentOverallStatus.values) s: 0};
    for (final s in statuses) {
      out[s] = out[s]! + 1;
    }
    return out;
  }

  /// `isDocumentVerify` after an owner's review: exactly `overall ==
  /// verified`; `null` (leave it) when nothing is required.
  static bool? flagAfterReview({required List<DocumentModel> required, required List<Documents> docs}) {
    if (required.isEmpty) return null;
    return overall(required: required, docs: docs) == DocumentOverallStatus.verified;
  }

  /// `isDocumentVerify` after a driver's own upload: lowered (`false`) when
  /// it was true and the status is no longer verified; otherwise left
  /// (`null`). Never raised. Only for a company driver: a platform driver's
  /// flag is the administrator's alone.
  static bool? flagAfterSubmit({required bool companyDriver, required bool currentFlag, required DocumentOverallStatus after}) {
    if (!companyDriver || !currentFlag) return null;
    return after == DocumentOverallStatus.verified ? null : false;
  }

  /// A driver uploads [entry] (new or again) into the `documents_verify`
  /// [record] (null = none yet) of holder type [recordType]. The entry
  /// starts a new review (`uploaded`, never approved; rejection reason and
  /// reviewer cleared), keeps the extra fields of the entry it replaces, and
  /// takes its place in the list. [required] null = the required list could
  /// not be read: the uploaded document is then taken as required (so a
  /// company driver's flag is lowered rather than left wrongly true).
  static DocumentSubmitPlan submit({
    required Map<String, dynamic>? record,
    required Documents entry,
    required String recordType,
    required List<DocumentModel>? required,
    required bool currentFlag,
    required bool companyDriver,
  }) {
    final String id = (entry.documentId ?? '').trim();
    if (id.isEmpty) return const DocumentSubmitPlan(refused: true);
    if (record != null && !DocumentRecordType.belongsTo(record['type'], recordType)) return const DocumentSubmitPlan(refused: true);
    final List<Documents> docs = DocumentRecordType.entriesOf(record, recordType);
    final Documents? previous = OwnerVerificationRules.entryFor(docs, id);
    entry.extra = {...?previous?.extra, ...entry.extra};
    entry.resetForNewReview();
    final int index = previous == null ? -1 : docs.indexOf(previous);
    if (index >= 0) {
      docs[index] = entry;
    } else {
      docs.add(entry);
    }
    final List<DocumentModel> req = required ?? [DocumentModel(id: id, enable: true)];
    final DocumentOverallStatus after = overall(required: req, docs: docs, flag: currentFlag);
    return DocumentSubmitPlan(
      documents: docs,
      overall: after,
      setVerified: flagAfterSubmit(companyDriver: companyDriver, currentFlag: currentFlag, after: after),
    );
  }
}

/// One driver's documents as a screen shows them (live): the profile, the
/// required documents, the record's entries, and the overall status.
class DriverDocumentsView {
  final UserModel? user;
  final List<DocumentModel> required;
  final List<Documents> docs;

  /// The `documents_verify` record belongs to another holder type: shown as
  /// "nothing uploaded", never reviewed or written.
  final bool foreignRecord;

  final DocumentOverallStatus overall;

  const DriverDocumentsView({this.user, this.required = const [], this.docs = const [], this.foreignRecord = false, this.overall = DocumentOverallStatus.notSubmitted});

  factory DriverDocumentsView.of({required UserModel? user, required List<DocumentModel> required, required Map<String, dynamic>? record}) {
    final String type = DocumentRecordType.forUser(user);
    final bool foreign = record != null && !DocumentRecordType.belongsTo(record['type'], type);
    final List<Documents> docs = DocumentRecordType.entriesOf(record, type);
    return DriverDocumentsView(
      user: user,
      required: required,
      docs: docs,
      foreignRecord: foreign,
      overall: DriverDocumentStatus.overall(required: required, docs: docs, flag: user?.isDocumentVerify),
    );
  }

  Documents? entryFor(String? documentId) => OwnerVerificationRules.entryFor(docs, documentId);

  int get approvedCount => required.where((r) => DriverDocumentStatus.entryStatus(entryFor(r.id)) == DocumentEntryStatus.approved).length;

  int get uploadedCount => OwnerVerificationRules.uploadedCount(required, docs);
}

/// The last computed status per driver uid: filled by the live views (the
/// driver's own, the owner's list and review screens) and by the async gates
/// before they decide, read by the synchronous gates
/// (`DocumentVerification.isPending`). Observable: an `Obx` reading [of]
/// rebuilds when it changes.
abstract final class DocumentStatusCache {
  static final RxMap<String, DocumentOverallStatus> _byUid = <String, DocumentOverallStatus>{}.obs;

  static DocumentOverallStatus? of(String? uid) {
    final String id = (uid ?? '').trim();
    return id.isEmpty ? null : _byUid[id];
  }

  static void put(String? uid, DocumentOverallStatus status) {
    final String id = (uid ?? '').trim();
    if (id.isEmpty || _byUid[id] == status) return;
    _byUid[id] = status;
  }

  static void clear() => _byUid.clear();
}
