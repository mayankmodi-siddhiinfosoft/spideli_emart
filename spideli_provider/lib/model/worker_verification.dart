import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/worker_verification_status.dart';

export 'package:spideliprovider/model/worker_verification_status.dart';

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

  /// `documents_verify/{worker}` holds another holder's record (driver,
  /// owner, vendor, provider): never reviewed as a worker's.
  notWorkerRecord,
}

/// Why a worker may NOT be given an order (null = may be assigned).
enum WorkerAssignmentRefusal {
  /// Not (or no longer) one of this provider's workers.
  notYourWorker,

  /// The verification state could not be read (setting, required types or
  /// the worker's documents): never assigned on a guess.
  unknown,

  /// A required document was rejected or has expired.
  rejected,

  /// A required document has not been uploaded.
  documentsMissing,

  /// Every required document was uploaded, some are not approved yet.
  pendingReview,
}

/// The result of planning one review action on `documents_verify/{worker}`.
class WorkerReviewOutcome {
  /// The whole `documents` list to write (every other entry unchanged).
  final List<Map<String, dynamic>> documents;

  /// `providers_workers/{worker}.isDocumentVerify` to write, recalculated
  /// from the required documents after the action
  /// ([WorkerVerificationStatusRules.flagAfterReview]): true, false, or null
  /// = already that value.
  final bool? setVerified;

  /// The documents approved or rejected by this action.
  final List<String> changedIds;

  /// The required types still not approved after the action.
  final List<DocumentType> missing;

  final WorkerReviewRefusal? refusal;

  const WorkerReviewOutcome({this.documents = const [], this.setVerified, this.changedIds = const [], this.missing = const [], this.refusal});

  bool get refused => refusal != null;
}

/// Worker document verification rules of the provider's review screens and
/// its job assignment. The status rule itself is
/// [WorkerVerificationStatusRules] (`worker_verification_status.dart`, the
/// SAME file in the Worker app), so both apps agree on who is verified.
///
/// The record is the admin panel's (`.claude/DOCUMENT-VERIFICATION-WORKER.md`):
/// `documents_verify/{workerUid}` `{id, type: "worker", documents: [{documentId,
/// frontImage, backImage, status, ...}]}`; status `uploaded` -> `approved` /
/// `rejected` + `rejectReason`. The required documents are the `documents`
/// types with `type == "worker"` and `enable == true`.
/// `providers_workers/{workerUid}.isDocumentVerify` is kept in sync: after
/// every decision it is recalculated (true exactly when every required
/// document is uploaded and approved); it never makes a worker Verified on its
/// own while verification is on.
class WorkerVerificationRules {
  WorkerVerificationRules._();

  static const String workerType = WorkerVerificationStatusRules.recordType;
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

  /// The required worker types of a `documents` query (`type == "worker"`,
  /// `enable == true` checked again on every row, so a provider / driver type
  /// can never become a required worker document).
  static List<DocumentType> requiredTypesFrom(Iterable<MapEntry<String, Map<String, dynamic>>> docs) =>
      DocumentType.enabledFrom(docs.where((d) => WorkerVerificationStatusRules.isRequiredWorkerType(d.value)));

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

  /// A worker's uploads from their whole `documents_verify` record: empty
  /// when there is none or when it is another holder's record (type driver,
  /// owner, vendor, provider), which is never read as the worker's.
  static Map<String, UploadedDocument> uploadsFromRecord(Map<String, dynamic>? record) {
    if (record == null || !isWorkerRecord(record)) return {};
    return uploadsFrom(record['documents']);
  }

  /// A `documents_verify` record of a worker (`type` "worker", or none on a
  /// legacy record).
  static bool isWorkerRecord(Map<String, dynamic>? record) => record != null && WorkerVerificationStatusRules.isWorkerRecordType(record['type']);

  /// One document ([WorkerVerificationStatusRules.documentState]): rejected
  /// (even without a file) > nothing sent = not submitted > expired (stored,
  /// or past `expireAt`) > approved > pending.
  static DocumentStatus statusOf(UploadedDocument? d, {DateTime? now}) => stateOf(d, now: now).asDocumentStatus;

  /// [statusOf] as the shared state.
  static WorkerDocumentState stateOf(UploadedDocument? d, {DateTime? now}) => WorkerVerificationStatusRules.documentState(
        exists: d != null,
        status: d?.status,
        hasFile: d?.hasFile ?? false,
        expireAt: d?.expireAt?.toDate(),
        now: now ?? DateTime.now(),
      );

  /// The states of the REQUIRED documents.
  static List<WorkerDocumentState> requiredStates(List<DocumentType> types, Map<String, UploadedDocument> uploads, {DateTime? now}) =>
      types.map((t) => stateOf(uploads[t.id], now: now)).toList();

  /// Not submitted / Pending / Action required / Verified, over the REQUIRED
  /// types only ([WorkerVerificationStatusRules.overall]).
  static WorkerOverallStatus overall(List<DocumentType> types, Map<String, UploadedDocument> uploads, {bool? isDocumentVerify, bool? verificationRequired, DateTime? now}) =>
      WorkerVerificationStatusRules.overall(requiredStates(types, uploads, now: now), isDocumentVerify: isDocumentVerify, verificationRequired: verificationRequired);

  /// Whether the worker may be given jobs: the Worker app's job gate
  /// ([WorkerVerificationStatusRules.canReceiveJobs]).
  static bool canReceiveJobs({
    required bool? verificationRequired,
    required List<DocumentType> types,
    required bool typesLoadFailed,
    required Map<String, UploadedDocument> uploads,
    bool? isDocumentVerify,
    DateTime? now,
  }) =>
      WorkerVerificationStatusRules.canReceiveJobs(
        verificationRequired: verificationRequired,
        noRequiredTypes: types.isEmpty,
        typesLoadFailed: typesLoadFailed,
        overall: overall(types, uploads, isDocumentVerify: isDocumentVerify, verificationRequired: verificationRequired, now: now),
      );

  /// Whether [workerData] / its documents allow assigning an order NOW, from
  /// the worker's LIVE `documents_verify` record ([record]) and the CURRENT
  /// required types -- never from `isDocumentVerify` alone. null = allowed
  /// (overall status Verified, or verification off, or no required type).
  /// Otherwise the reason, most serious first: rejected / expired, documents
  /// missing, pending review.
  static WorkerAssignmentRefusal? assignmentRefusal({
    required Map<String, dynamic>? workerData,
    required String providerId,
    required bool? verificationRequired,
    required List<DocumentType> types,
    required bool typesLoadFailed,
    required Map<String, dynamic>? record,
    bool recordLoadFailed = false,
    DateTime? now,
  }) {
    if (!canReview(workerData, providerId)) return WorkerAssignmentRefusal.notYourWorker;
    if (verificationRequired == false) return null;
    if (types.isEmpty) return typesLoadFailed ? WorkerAssignmentRefusal.unknown : null;
    if (recordLoadFailed) return WorkerAssignmentRefusal.unknown;
    final bool? flag = workerData?['isDocumentVerify'] is bool ? workerData!['isDocumentVerify'] as bool : null;
    final uploads = uploadsFromRecord(record);
    final WorkerOverallStatus status = overall(types, uploads, isDocumentVerify: flag, verificationRequired: verificationRequired, now: now);
    if (canReceiveJobs(verificationRequired: verificationRequired, types: types, typesLoadFailed: typesLoadFailed, uploads: uploads, isDocumentVerify: flag, now: now)) return null;
    final states = requiredStates(types, uploads, now: now);
    if (status == WorkerOverallStatus.actionRequired) return WorkerAssignmentRefusal.rejected;
    if (states.contains(WorkerDocumentState.notSubmitted)) return WorkerAssignmentRefusal.documentsMissing;
    return WorkerAssignmentRefusal.pendingReview;
  }

  /// Translation key of the message shown when an assignment is refused.
  static String assignmentRefusalMessage(WorkerAssignmentRefusal refusal) {
    switch (refusal) {
      case WorkerAssignmentRefusal.notYourWorker:
        return 'Cannot assign: this worker is not one of your workers.';
      case WorkerAssignmentRefusal.unknown:
        return 'Cannot assign: this worker\'s documents could not be checked. Check your connection and try again.';
      case WorkerAssignmentRefusal.rejected:
        return 'Cannot assign: a required document of this worker was rejected or has expired.';
      case WorkerAssignmentRefusal.documentsMissing:
        return 'Cannot assign: this worker has not uploaded every required document.';
      case WorkerAssignmentRefusal.pendingReview:
        return 'Cannot assign: this worker\'s documents are pending your review.';
    }
  }

  /// Translation key of the short reason shown on a greyed-out worker.
  static String assignmentRefusalLabel(WorkerAssignmentRefusal refusal) {
    switch (refusal) {
      case WorkerAssignmentRefusal.notYourWorker:
        return 'Not your worker';
      case WorkerAssignmentRefusal.unknown:
        return 'Documents not checked';
      case WorkerAssignmentRefusal.rejected:
        return 'Documents rejected';
      case WorkerAssignmentRefusal.documentsMissing:
        return 'Documents missing';
      case WorkerAssignmentRefusal.pendingReview:
        return 'Pending review';
    }
  }

  /// The required types not approved yet.
  static List<DocumentType> missing(List<DocumentType> types, Map<String, UploadedDocument> uploads, {DateTime? now}) =>
      types.where((t) => statusOf(uploads[t.id], now: now) != DocumentStatus.approved).toList();

  /// Every required document is sent AND approved (never with no types).
  static bool allRequiredApproved(List<DocumentType> types, Map<String, UploadedDocument> uploads, {DateTime? now}) =>
      WorkerVerificationStatusRules.allApproved(requiredStates(types, uploads, now: now));

  /// The flag after a decision on [list], given its current value.
  static bool? _flagAfter(List<DocumentType> types, List<Map<String, dynamic>> list, bool? currentFlag, DateTime? now) =>
      WorkerVerificationStatusRules.flagAfterReview(requiredAfter: requiredStates(types, uploadsFrom(list), now: now), current: currentFlag);

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

  /// Approves [documentId]. The flag is recalculated: true when every
  /// required document is then approved, false otherwise.
  static WorkerReviewOutcome approve({required List<DocumentType> types, required dynamic stored, required String documentId, required String reviewerId, required Timestamp at, bool? currentFlag, DateTime? now}) {
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
      setVerified: _flagAfter(types, list, currentFlag, now),
      changedIds: [documentId],
      missing: missing(types, uploads, now: now),
    );
  }

  /// Rejects [documentId] with a mandatory [reason]. The flag is
  /// recalculated (a rejected REQUIRED document un-verifies the worker).
  static WorkerReviewOutcome reject({required List<DocumentType> types, required dynamic stored, required String documentId, required String reason, required String reviewerId, required Timestamp at, bool? currentFlag, DateTime? now}) {
    final String text = reason.trim();
    if (text.isEmpty) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.reasonRequired);
    final list = _copy(stored);
    final int i = _indexOf(list, documentId);
    if (i < 0 || !UploadedDocument.fromJson(list[i]).hasFile) return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notSent);
    list[i] = _decided(list[i], 'rejected', reviewerId: reviewerId, at: at, reason: text);
    return WorkerReviewOutcome(
      documents: list,
      setVerified: _flagAfter(types, list, currentFlag, now),
      changedIds: [documentId],
      missing: missing(types, uploadsFrom(list), now: now),
    );
  }

  /// Approves every REQUIRED document that was uploaded and waits for a
  /// decision (pending review). The flag is recalculated: verified only when
  /// nothing is then missing; otherwise [WorkerReviewOutcome.missing] names
  /// what is.
  static WorkerReviewOutcome approveAll({required List<DocumentType> types, required dynamic stored, required String reviewerId, required Timestamp at, bool? currentFlag, DateTime? now}) {
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
    return WorkerReviewOutcome(documents: list, setVerified: _flagAfter(types, list, currentFlag, now), changedIds: changed, missing: stillMissing);
  }
}

extension WorkerDocumentStateMapping on WorkerDocumentState {
  /// The same status under this app's [DocumentStatus] names.
  DocumentStatus get asDocumentStatus => DocumentStatus.values[index];
}
