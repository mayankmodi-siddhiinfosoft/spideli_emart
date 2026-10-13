// Worker document verification: the ONE status rule of the Worker app and the
// Provider app. This file is identical in
//   spideli_worker/lib/model/worker_verification_status.dart
//   spideli_provider/lib/model/worker_verification_status.dart
// (a unit test in each app compares the two copies). Pure Dart: no Flutter,
// no Firebase, so both apps and their tests share it as is.
//
// Admin-panel contract: .claude/DOCUMENT-VERIFICATION-WORKER.md

/// Status of ONE required worker document.
enum WorkerDocumentState { notSubmitted, pending, approved, rejected, expired }

/// Overall status of a worker, computed ONLY from the current statuses of all
/// REQUIRED documents (see [WorkerVerificationStatusRules.overall]).
enum WorkerOverallStatus { notSubmitted, pending, actionRequired, verified }

/// Pure rules shared by both apps.
class WorkerVerificationStatusRules {
  WorkerVerificationStatusRules._();

  /// `documents_verify/{workerUid}.type` of a worker record, and `documents.type`
  /// of a worker document type.
  static const String recordType = 'worker';

  /// The other holders of `documents_verify` records (never read or written as
  /// a worker's).
  static const List<String> otherRecordTypes = ['driver', 'owner', 'vendor', 'provider'];

  /// Whether a `documents_verify` record with this `type` is a worker record.
  /// A record without a type (written before the type was stored) is the
  /// worker's own legacy record; any other holder type is not.
  static bool isWorkerRecordType(Object? type) {
    final String t = (type?.toString() ?? '').trim().toLowerCase();
    return t.isEmpty || t == 'null' || t == recordType;
  }

  /// Whether a `documents` type row is a REQUIRED worker document type.
  static bool isRequiredWorkerType(Map<String, dynamic> data) => data['type']?.toString().trim().toLowerCase() == recordType && data['enable'] == true;

  /// One document from its stored entry ([exists] false: nothing stored):
  /// rejected (even without a file) > no file = not submitted > expired
  /// (stored as such, or past [expireAt]) > approved ("approved" / "verified")
  /// > anything else sent ("uploaded", "pending", none) = pending review.
  static WorkerDocumentState documentState({required bool exists, String? status, bool hasFile = false, DateTime? expireAt, required DateTime now}) {
    if (!exists) return WorkerDocumentState.notSubmitted;
    final String s = (status ?? '').trim().toLowerCase();
    if (s == 'rejected') return WorkerDocumentState.rejected;
    if (!hasFile) return WorkerDocumentState.notSubmitted;
    if (s == 'expired') return WorkerDocumentState.expired;
    if (expireAt != null && expireAt.isBefore(now)) return WorkerDocumentState.expired;
    if (s == 'approved' || s == 'verified') return WorkerDocumentState.approved;
    return WorkerDocumentState.pending;
  }

  /// Every required document is uploaded AND approved (never with none).
  static bool allApproved(Iterable<WorkerDocumentState> required) => required.isNotEmpty && required.every((s) => s == WorkerDocumentState.approved);

  /// The overall status from the states of ALL REQUIRED documents:
  /// * Action required: any required document rejected or expired (never
  ///   Verified then, whatever `isDocumentVerify` says);
  /// * Verified: every required document uploaded and approved;
  /// * Not submitted: no required document uploaded;
  /// * Pending: otherwise (some not uploaded yet, or uploaded / resubmitted and
  ///   not reviewed yet).
  ///
  /// `providers_workers.isDocumentVerify` ([isDocumentVerify]) does NOT make a
  /// worker Verified while verification is on (or unknown): a pending or
  /// missing document keeps the worker Pending / Not submitted. It counts
  /// only when the platform switched verification off
  /// ([verificationRequired] false), and when the admin configured no
  /// document type at all (nothing else to go by).
  static WorkerOverallStatus overall(Iterable<WorkerDocumentState> required, {bool? isDocumentVerify, bool? verificationRequired}) {
    final List<WorkerDocumentState> states = required.toList();
    if (states.any((s) => s == WorkerDocumentState.rejected || s == WorkerDocumentState.expired)) return WorkerOverallStatus.actionRequired;
    if (allApproved(states)) return WorkerOverallStatus.verified;
    if (isDocumentVerify == true && (verificationRequired == false || states.isEmpty)) return WorkerOverallStatus.verified;
    if (states.every((s) => s == WorkerDocumentState.notSubmitted)) return WorkerOverallStatus.notSubmitted;
    return WorkerOverallStatus.pending;
  }

  /// The jobs gate (Worker app) and the assignment filter (Provider app):
  /// * verification off: always;
  /// * required types read and there are none: nothing can be uploaded or
  ///   approved, so the worker is not locked out;
  /// * required types could not be read: closed until they are;
  /// * otherwise only when [overall] is Verified.
  /// [verificationRequired] null (not read yet) counts as ON.
  static bool canReceiveJobs({required bool? verificationRequired, required bool noRequiredTypes, required bool typesLoadFailed, required WorkerOverallStatus overall}) {
    if (verificationRequired == false) return true;
    if (noRequiredTypes) return !typesLoadFailed;
    return overall == WorkerOverallStatus.verified;
  }

  /// `providers_workers.isDocumentVerify` after the WORKER submits or
  /// resubmits a document ([requiredAfter]: the required states once the
  /// submission is merged; the submitted one is pending). The worker may
  /// lower the flag, never raise it: false when the worker is no longer
  /// verified by the documents and the flag is not already false; null =
  /// leave it as it is.
  static bool? flagAfterWorkerSubmit({required Iterable<WorkerDocumentState> requiredAfter, bool? current}) {
    if (requiredAfter.isEmpty) return null;
    if (allApproved(requiredAfter)) return null;
    return current == false ? null : false;
  }

  /// `providers_workers.isDocumentVerify` after a REVIEW decision (approve,
  /// reject, approve all): recalculated from the required documents, true
  /// exactly when every required document is uploaded and approved. null =
  /// no change (already that value, or no required type known).
  static bool? flagAfterReview({required Iterable<WorkerDocumentState> requiredAfter, bool? current}) {
    if (requiredAfter.isEmpty) return null;
    final bool verified = allApproved(requiredAfter);
    return verified == current ? null : verified;
  }

  /// Translation key of an overall status.
  static String overallLabel(WorkerOverallStatus status) {
    switch (status) {
      case WorkerOverallStatus.notSubmitted:
        return 'Not submitted';
      case WorkerOverallStatus.pending:
        return 'Pending';
      case WorkerOverallStatus.actionRequired:
        return 'Action required';
      case WorkerOverallStatus.verified:
        return 'Verified';
    }
  }

  /// Translation key of one document's status.
  static String documentLabel(WorkerDocumentState state) {
    switch (state) {
      case WorkerDocumentState.notSubmitted:
        return 'Not submitted';
      case WorkerDocumentState.pending:
        return 'Pending review';
      case WorkerDocumentState.approved:
        return 'Approved';
      case WorkerDocumentState.rejected:
        return 'Rejected';
      case WorkerDocumentState.expired:
        return 'Expired';
    }
  }

  /// Translation key of a document holder type, shown as "Document type: ..."
  /// wherever documents are uploaded, listed or reviewed.
  static String recordTypeLabel(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'worker':
        return 'Worker';
      case 'driver':
        return 'Driver';
      case 'owner':
        return 'Owner';
      case 'vendor':
        return 'Store';
      case 'provider':
        return 'Provider';
      default:
        return (type ?? '').trim();
    }
  }
}
