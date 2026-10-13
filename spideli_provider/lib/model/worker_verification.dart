import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/model/document_model.dart';

/// Where a worker stands, as the provider's Worker verification list shows it.
enum WorkerVerificationState { verified, pendingReview, rejected, notSubmitted }

/// Why a review action was not written.
enum WorkerReviewRefusal {
  /// The worker is not (or no longer) one of this provider's workers.
  notYourWorker,

  /// The document has not been sent: nothing to decide.
  notSent,

  /// The document is past its expiry date: the worker must send a valid one.
  expired,

  /// A rejection needs a reason.
  reasonRequired,

  /// "Approve all": no uploaded document waits for a decision.
  nothingToApprove,

  /// The required document types could not be read.
  typesUnknown,
}

/// The result of planning one review action on `documents_verify/{worker}`.
class WorkerReviewOutcome {
  /// The whole `documents` list to write (every other entry unchanged).
  final List<Map<String, dynamic>> documents;

  /// `providers_workers/{worker}.isDocumentVerify` to write: true, false, or
  /// null = leave it as it is.
  final bool? setVerified;

  /// The documents approved or rejected by this action.
  final List<String> changedIds;

  /// The required types still not approved after the action.
  final List<DocumentType> missing;

  final WorkerReviewRefusal? refusal;

  const WorkerReviewOutcome({this.documents = const [], this.setVerified, this.changedIds = const [], this.missing = const [], this.refusal});

  bool get refused => refusal != null;
}

/// Worker document verification rules shared by the provider's review
/// screens and its job assignment. They mirror the Worker app's
/// `DocumentService` (statusOf / overallStatus / canReceiveJobs) exactly, so
/// both apps agree on who is verified.
///
/// The record is the admin panel's (`.claude/BUG-REPORT-01-ADMIN.md` 24+25):
/// `documents_verify/{workerUid}` `{id, type: "worker", documents: [{documentId,
/// frontImage, backImage, status, ...}]}`; status `uploaded` -> `approved` /
/// `rejected` + `rejectReason`. The required documents are the `documents`
/// types with `type == "worker"` and `enable == true`.
/// `providers_workers/{workerUid}.isDocumentVerify` is the verified flag:
/// set true ONLY when every required document is sent and approved, never set
/// false by an approval, set false by the rejection of a required document.
class WorkerVerificationRules {
  WorkerVerificationRules._();

  static const String workerType = 'worker';
  static const String settingsDocument = 'document_verification_settings';
  static const String settingsField = 'isWorkerVerification';

  /// The panel's reason key, written on a rejection.
  static const String rejectReasonKey = 'rejectReason';

  /// Every key a reason may be stored under (cleared on a new decision).
  static const List<String> reasonKeys = ['rejectReason', 'rejectionReason', 'rejectedReason', 'rejected_reason', 'reason'];

  /// Optional review fields this app adds to an entry (the panel ignores
  /// unknown keys; the Worker app drops them on a re-upload).
  static const String reviewedAtKey = 'reviewedAt';
  static const String reviewedByKey = 'reviewedBy';
  static const String reviewedByRoleKey = 'reviewedByRole';

  /// Verification switched on: true / false when known, null when the
  /// settings document was not read (a cache miss).
  static bool? verificationRequiredFrom({required bool exists, required bool isFromCache, Map<String, dynamic>? data}) {
    if (!exists) return isFromCache ? null : false;
    return data?[settingsField] == true;
  }

  /// The uploaded entries by document id (the first entry of an id wins, as
  /// in the Worker app).
  static Map<String, UploadedDocument> uploadsFrom(dynamic rawDocuments) {
    final Map<String, UploadedDocument> out = {};
    if (rawDocuments is List) {
      for (final e in rawDocuments.whereType<Map>()) {
        final d = UploadedDocument.fromJson(Map<String, dynamic>.from(e));
        if (d.documentId.isNotEmpty) out.putIfAbsent(d.documentId, () => d);
      }
    }
    return out;
  }

  /// One document: rejected (even without a file) > nothing sent = not
  /// submitted > expired (stored, or past `expireAt`) > approved > pending.
  static DocumentStatus statusOf(UploadedDocument? d, {DateTime? now}) {
    if (d == null) return DocumentStatus.notSubmitted;
    final String s = (d.status ?? '').trim().toLowerCase();
    if (s == 'rejected') return DocumentStatus.rejected;
    if (!d.hasFile) return DocumentStatus.notSubmitted;
    if (s == 'expired') return DocumentStatus.expired;
    if (d.expireAt != null && d.expireAt!.toDate().isBefore(now ?? DateTime.now())) return DocumentStatus.expired;
    if (s == 'approved' || s == 'verified') return DocumentStatus.approved;
    return DocumentStatus.pendingReview;
  }

  /// Over the REQUIRED types only: rejected > expired > not submitted >
  /// pending > approved; `isDocumentVerify` approves unless something is
  /// rejected or expired; no type configured: approved only with the flag.
  static DocumentStatus overall(List<DocumentType> types, Map<String, UploadedDocument> uploads, {bool? isDocumentVerify, DateTime? now}) {
    if (types.isEmpty) return isDocumentVerify == true ? DocumentStatus.approved : DocumentStatus.notSubmitted;
    final statuses = types.map((t) => statusOf(uploads[t.id], now: now)).toList();
    DocumentStatus result;
    if (statuses.contains(DocumentStatus.rejected)) {
      result = DocumentStatus.rejected;
    } else if (statuses.contains(DocumentStatus.expired)) {
      result = DocumentStatus.expired;
    } else if (statuses.contains(DocumentStatus.notSubmitted)) {
      result = DocumentStatus.notSubmitted;
    } else if (statuses.contains(DocumentStatus.pendingReview)) {
      result = DocumentStatus.pendingReview;
    } else {
      result = DocumentStatus.approved;
    }
    if (isDocumentVerify == true && result != DocumentStatus.rejected && result != DocumentStatus.expired) return DocumentStatus.approved;
    return result;
  }

  /// Whether the worker may be given jobs (the Worker app's job gate): always
  /// with verification off; with it on (or unknown), when the overall status
  /// is approved, or when the types were read and there are none.
  static bool canReceiveJobs({
    required bool? verificationRequired,
    required List<DocumentType> types,
    required bool typesLoadFailed,
    required Map<String, UploadedDocument> uploads,
    bool? isDocumentVerify,
    DateTime? now,
  }) {
    if (verificationRequired == false) return true;
    if (types.isEmpty && !typesLoadFailed) return true;
    return overall(types, uploads, isDocumentVerify: isDocumentVerify, now: now) == DocumentStatus.approved;
  }

  /// The list state: verified, else something to review (pending), else
  /// something the worker must redo (rejected / expired), else not submitted.
  static WorkerVerificationState stateOf(List<DocumentType> types, Map<String, UploadedDocument> uploads, {bool? isDocumentVerify, DateTime? now}) {
    if (overall(types, uploads, isDocumentVerify: isDocumentVerify, now: now) == DocumentStatus.approved) return WorkerVerificationState.verified;
    final statuses = types.map((t) => statusOf(uploads[t.id], now: now)).toSet();
    if (statuses.contains(DocumentStatus.pendingReview)) return WorkerVerificationState.pendingReview;
    if (statuses.contains(DocumentStatus.rejected) || statuses.contains(DocumentStatus.expired)) return WorkerVerificationState.rejected;
    return WorkerVerificationState.notSubmitted;
  }

  /// The required types not approved yet.
  static List<DocumentType> missing(List<DocumentType> types, Map<String, UploadedDocument> uploads, {DateTime? now}) =>
      types.where((t) => statusOf(uploads[t.id], now: now) != DocumentStatus.approved).toList();

  /// Every required document is sent AND approved (never with no types).
  static bool allRequiredApproved(List<DocumentType> types, Map<String, UploadedDocument> uploads, {DateTime? now}) => types.isNotEmpty && missing(types, uploads, now: now).isEmpty;

  /// The guard: [workerData] is a worker record whose `providerId` is
  /// [providerId].
  static bool canReview(Map<String, dynamic>? workerData, String providerId) {
    if (workerData == null || providerId.trim().isEmpty) return false;
    return (workerData['providerId']?.toString() ?? '').trim() == providerId.trim();
  }

  static List<Map<String, dynamic>> _copy(dynamic stored) =>
      stored is List ? stored.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  static int _indexOf(List<Map<String, dynamic>> list, String documentId) => list.indexWhere((e) => e['documentId']?.toString() == documentId);

  static Map<String, dynamic> _decided(Map<String, dynamic> entry, String status, {required String reviewerId, required Timestamp at, String? reason}) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(entry)..removeWhere((k, _) => reasonKeys.contains(k));
    out['status'] = status;
    if (reason != null) out[rejectReasonKey] = reason;
    out[reviewedAtKey] = at;
    out[reviewedByKey] = reviewerId;
    out[reviewedByRoleKey] = 'provider';
    return out;
  }

  /// Approves [documentId]. Verifies the worker when every required document
  /// is then approved; never un-verifies.
  static WorkerReviewOutcome approve({required List<DocumentType> types, required dynamic stored, required String documentId, required String reviewerId, required Timestamp at, DateTime? now}) {
    final list = _copy(stored);
    final int i = _indexOf(list, documentId);
    if (i < 0) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notSent);
    final UploadedDocument current = UploadedDocument.fromJson(list[i]);
    if (!current.hasFile) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notSent);
    final DocumentStatus status = statusOf(current, now: now);
    if (status == DocumentStatus.expired) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.expired);
    list[i] = _decided(list[i], 'approved', reviewerId: reviewerId, at: at);
    final uploads = uploadsFrom(list);
    return WorkerReviewOutcome(
      documents: list,
      setVerified: allRequiredApproved(types, uploads, now: now) ? true : null,
      changedIds: [documentId],
      missing: missing(types, uploads, now: now),
    );
  }

  /// Rejects [documentId] with a mandatory [reason]. Rejecting a REQUIRED
  /// document un-verifies the worker.
  static WorkerReviewOutcome reject({required List<DocumentType> types, required dynamic stored, required String documentId, required String reason, required String reviewerId, required Timestamp at, DateTime? now}) {
    final String text = reason.trim();
    if (text.isEmpty) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.reasonRequired);
    final list = _copy(stored);
    final int i = _indexOf(list, documentId);
    if (i < 0 || !UploadedDocument.fromJson(list[i]).hasFile) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notSent);
    list[i] = _decided(list[i], 'rejected', reviewerId: reviewerId, at: at, reason: text);
    return WorkerReviewOutcome(
      documents: list,
      setVerified: types.any((t) => t.id == documentId) ? false : null,
      changedIds: [documentId],
      missing: missing(types, uploadsFrom(list), now: now),
    );
  }

  /// Approves every REQUIRED document that was uploaded and waits for a
  /// decision (pending review). Verifies only when nothing is then missing;
  /// otherwise [WorkerReviewOutcome.missing] names what is.
  static WorkerReviewOutcome approveAll({required List<DocumentType> types, required dynamic stored, required String reviewerId, required Timestamp at, DateTime? now}) {
    if (types.isEmpty) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.typesUnknown);
    final list = _copy(stored);
    final List<String> changed = [];
    for (final type in types) {
      final int i = _indexOf(list, type.id);
      if (i < 0) continue;
      if (statusOf(UploadedDocument.fromJson(list[i]), now: now) != DocumentStatus.pendingReview) continue;
      list[i] = _decided(list[i], 'approved', reviewerId: reviewerId, at: at);
      changed.add(type.id);
    }
    final uploads = uploadsFrom(list);
    final List<DocumentType> stillMissing = missing(types, uploads, now: now);
    if (changed.isEmpty && stillMissing.isNotEmpty) {
      return WorkerReviewOutcome(refusal: WorkerReviewRefusal.nothingToApprove, missing: stillMissing);
    }
    return WorkerReviewOutcome(documents: list, setVerified: stillMissing.isEmpty ? true : null, changedIds: changed, missing: stillMissing);
  }
}
