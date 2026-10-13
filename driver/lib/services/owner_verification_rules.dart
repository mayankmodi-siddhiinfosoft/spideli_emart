/// Pure rules of a company owner reviewing its own drivers' documents
/// (`OwnerVerificationService`, the owner verification screens). No
/// Firebase here, so every rule is unit tested
/// (test/owner_verification_rules_test.dart).
///
/// `users.isDocumentVerify` of a company driver follows the overall status
/// computed from the required documents ([DriverDocumentStatus.overall]):
/// every owner action writes it to `overall == verified`
/// ([DriverDocumentStatus.flagAfterReview]) in the same transaction as the
/// documents — approving the last outstanding document sets it, rejecting a
/// required document (or approving while another one is still pending,
/// rejected or expired) clears it.
library;

import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_document_status.dart';

/// The pushes about a company driver's documents. Their text comes only from
/// these `dynamic_notification` templates; a missing template means no push
/// (and no notification record), logged. `.claude/PUSH-CHANNELS.md`.
///
/// | Template type | To | Placeholders |
/// |---|---|---|
/// | `driver_document_approved` | the driver | `{documentTitle}`, `{companyName}` |
/// | `driver_documents_verified` | the driver | `{companyName}` |
/// | `driver_document_rejected` | the driver | `{documentTitle}`, `{companyName}`, `{reason}` |
/// | `driver_document_submitted` | the company owner | `{driverName}`, `{documentTitle}` |
abstract final class OwnerVerificationPush {
  /// The owner approved one document (the account is not complete yet, or
  /// was already verified).
  static const String documentApproved = 'driver_document_approved';

  /// The owner's approval completed the required set: the account is verified.
  static const String documentsVerified = 'driver_documents_verified';

  /// The owner rejected one document.
  static const String documentRejected = 'driver_document_rejected';

  /// A company driver uploaded a document (to the owner).
  static const String documentSubmitted = 'driver_document_submitted';

  static const List<String> templates = [documentApproved, documentsVerified, documentRejected, documentSubmitted];

  /// `data.type` of the pushes to the driver: a tap opens the driver's own
  /// documents screen.
  static const String driverDataType = 'document_verification';

  /// `data.type` of the push to the owner (with `driverId`): a tap opens the
  /// owner's review screen for that driver.
  static const String ownerDataType = 'driver_document_submitted';

  /// Placeholder values; absent values are left out, so their placeholders
  /// stay visible in the text.
  static Map<String, String> values({String? documentTitle, String? companyName, String? reason, String? driverName}) {
    String? clean(String? v) {
      final String t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    return {
      if (clean(documentTitle) != null) 'documentTitle': clean(documentTitle)!,
      if (clean(companyName) != null) 'companyName': clean(companyName)!,
      if (clean(reason) != null) 'reason': clean(reason)!,
      if (clean(driverName) != null) 'driverName': clean(driverName)!,
    };
  }

  /// The record written to `users/{driverId}/notifications/{id}` next to a
  /// push to the driver: the same shape as every other record
  /// (`CustomerNotification.document`), `read: false`, category `account`.
  static Map<String, dynamic> record({
    required String id,
    required String title,
    required String body,
    required String template,
    required Map<String, String> data,
    required Object createdAt,
    String? status,
  }) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': template,
      'category': 'account',
      'orderId': '',
      'status': (status ?? '').trim(),
      'data': Map<String, String>.of(data),
      'read': false,
      'createdAt': createdAt,
      'source': 'driver',
    };
  }
}

/// What an owner action did (or why it did nothing).
enum OwnerVerificationOutcome {
  /// Written.
  done,

  /// Approve all: the uploaded documents were approved, but required
  /// documents are still missing (or must be uploaded again), so the account
  /// was not verified.
  incomplete,

  /// The driver is not one of the signed-in owner's company drivers.
  notYourDriver,

  /// The document was not uploaded (or has expired): nothing to approve /
  /// reject.
  notUploaded,

  /// The administrator requires no documents of this driver: nothing to
  /// verify against.
  noRequiredDocuments,

  /// A read or the write failed; nothing was changed.
  failed,
}

class OwnerVerificationResult {
  final OwnerVerificationOutcome outcome;

  /// True when the account is verified after the action.
  final bool verified;

  /// Titles of the required documents still outstanding (not uploaded, or
  /// rejected / expired and waiting for a new upload).
  final List<String> outstanding;

  /// True when, after the action, every required document is uploaded and
  /// approved (this action verified the account, or kept it verified).
  final bool completed;

  const OwnerVerificationResult(this.outcome, {this.verified = false, this.outstanding = const [], this.completed = false});

  bool get written => outcome == OwnerVerificationOutcome.done || outcome == OwnerVerificationOutcome.incomplete;
}

/// The change one owner action makes to `documents_verify/{driverId}` and
/// `users/{driverId}.isDocumentVerify`.
class DocumentReviewPlan {
  final OwnerVerificationOutcome outcome;

  /// The complete entry list to write back (other entries and their fields
  /// unchanged). Empty when nothing is written.
  final List<Documents> documents;

  /// `true` / `false` to write, `null` = leave `isDocumentVerify` untouched.
  final bool? setVerified;

  /// Required documents still outstanding after the action.
  final List<DocumentModel> outstanding;

  /// Entries this action approved.
  final List<String> approvedIds;

  const DocumentReviewPlan(this.outcome, {this.documents = const [], this.setVerified, this.outstanding = const [], this.approvedIds = const []});

  bool get writes => outcome == OwnerVerificationOutcome.done || outcome == OwnerVerificationOutcome.incomplete;
}

/// Where a tapped document push goes.
enum DocumentTapRoute {
  /// The owner's review screen for the driver named in the push.
  ownerReview,

  /// The owner's list of company drivers to verify.
  ownerList,

  /// The signed-in account's own documents screen.
  ownDocuments,

  /// Not a document push.
  none,
}

abstract final class OwnerVerificationRules {
  /// True when [driver] is one of [ownerUid]'s company drivers
  /// (`users.ownerId`), never the owner itself.
  static bool isOwnersDriver(UserModel? driver, String ownerUid) => isOwnersDriverData(driver?.id, driver?.ownerId, ownerUid);

  /// [isOwnersDriver] on the raw fields of a `users` document.
  static bool isOwnersDriverData(String? driverId, Object? ownerId, String ownerUid) {
    final String owner = ownerUid.trim();
    final String id = (driverId ?? '').trim();
    if (owner.isEmpty || id.isEmpty || id == owner) return false;
    return (ownerId ?? '').toString().trim() == owner;
  }

  static Documents? entryFor(List<Documents> docs, String? documentId) {
    final String id = (documentId ?? '').trim();
    if (id.isEmpty) return null;
    for (final Documents d in docs) {
      if ((d.documentId ?? '').trim() == id) return d;
    }
    return null;
  }

  /// The driver uploaded something for this document (a front or back image).
  static bool isUploaded(Documents? d) => d != null && ((d.frontImage ?? '').trim().isNotEmpty || (d.backImage ?? '').trim().isNotEmpty);

  /// Uploaded and approved (an expired document is not).
  static bool isApproved(Documents? d) => isUploaded(d) && d!.verificationStatus == 'approved';

  /// Uploaded and waiting for review.
  static bool awaitsReview(Documents? d) => isUploaded(d) && d!.verificationStatus == 'pending';

  /// The owner may approve it: uploaded and not expired.
  static bool canApprove(Documents? d) => isUploaded(d) && d!.verificationStatus != 'expired';

  /// The owner may reject it: the driver uploaded something for it.
  static bool canReject(Documents? d) => d != null && (isUploaded(d) || (d.status ?? '').trim().isNotEmpty);

  /// Required documents that are not uploaded + approved.
  static List<DocumentModel> outstanding(List<DocumentModel> required, List<Documents> docs) =>
      required.where((r) => !isApproved(entryFor(docs, r.id))).toList();

  /// Every required document is uploaded and approved (and there is at
  /// least one).
  static bool complete(List<DocumentModel> required, List<Documents> docs) => required.isNotEmpty && outstanding(required, docs).isEmpty;

  /// Approves [d]; stamps who reviewed it and when (when given).
  static void _approve(Documents d, {String? reviewedBy, Object? reviewedAt}) {
    d.status = 'approved';
    d.clearReview();
    _stamp(d, reviewedBy, reviewedAt);
  }

  static void _stamp(Documents d, String? reviewedBy, Object? reviewedAt) {
    if ((reviewedBy ?? '').trim().isNotEmpty) d.extra['reviewedBy'] = reviewedBy!.trim();
    if (reviewedAt != null) d.extra['reviewedAt'] = reviewedAt;
  }

  /// Approve one document. `isDocumentVerify` becomes `overall == verified`
  /// ([DriverDocumentStatus.flagAfterReview]): true when this completes the
  /// required set, false while another required document is still missing,
  /// pending, rejected or expired.
  static DocumentReviewPlan approveOne({required List<DocumentModel> required, required List<Documents> docs, required String documentId, String? reviewedBy, Object? reviewedAt}) {
    final Documents? entry = entryFor(docs, documentId);
    if (!canApprove(entry)) return const DocumentReviewPlan(OwnerVerificationOutcome.notUploaded);
    _approve(entry!, reviewedBy: reviewedBy, reviewedAt: reviewedAt);
    final List<DocumentModel> left = outstanding(required, docs);
    return DocumentReviewPlan(
      OwnerVerificationOutcome.done,
      documents: docs,
      setVerified: DriverDocumentStatus.flagAfterReview(required: required, docs: docs),
      outstanding: left,
      approvedIds: [documentId],
    );
  }

  /// Approve every required document the driver uploaded and that is
  /// waiting for review. Never creates an entry for a document that was not
  /// uploaded, never re-approves a rejected or expired one. Verifies the
  /// account only when nothing required is outstanding afterwards (and
  /// clears the flag otherwise).
  static DocumentReviewPlan approveAll({required List<DocumentModel> required, required List<Documents> docs, String? reviewedBy, Object? reviewedAt}) {
    if (required.isEmpty) return const DocumentReviewPlan(OwnerVerificationOutcome.noRequiredDocuments);
    final List<String> approved = [];
    for (final DocumentModel r in required) {
      final Documents? entry = entryFor(docs, r.id);
      if (awaitsReview(entry)) {
        _approve(entry!, reviewedBy: reviewedBy, reviewedAt: reviewedAt);
        approved.add(r.id ?? '');
      }
    }
    final List<DocumentModel> left = outstanding(required, docs);
    return DocumentReviewPlan(
      left.isEmpty ? OwnerVerificationOutcome.done : OwnerVerificationOutcome.incomplete,
      documents: docs,
      setVerified: DriverDocumentStatus.flagAfterReview(required: required, docs: docs),
      outstanding: left,
      approvedIds: approved,
    );
  }

  /// Reject one document with [reason] (mandatory). A rejected REQUIRED
  /// document makes the status "action required": the flag is cleared.
  /// Rejecting an entry that is not required leaves the status as it is.
  static DocumentReviewPlan reject({required List<DocumentModel> required, required List<Documents> docs, required String documentId, required String reason, String? reviewedBy, Object? reviewedAt}) {
    final Documents? entry = entryFor(docs, documentId);
    if (!canReject(entry) || reason.trim().isEmpty) return const DocumentReviewPlan(OwnerVerificationOutcome.notUploaded);
    entry!.clearReview();
    entry.status = 'rejected';
    entry.rejectReason = reason.trim();
    _stamp(entry, reviewedBy, reviewedAt);
    return DocumentReviewPlan(
      OwnerVerificationOutcome.done,
      documents: docs,
      setVerified: DriverDocumentStatus.flagAfterReview(required: required, docs: docs),
      outstanding: outstanding(required, docs),
    );
  }

  /// Number of required documents the driver uploaded.
  static int uploadedCount(List<DocumentModel> required, List<Documents> docs) => required.where((r) => isUploaded(entryFor(docs, r.id))).length;

  /// Where a tap on a push with `data.type` [type] goes. The owner's push
  /// ([OwnerVerificationPush.ownerDataType] + `driverId`) opens the review of
  /// that driver; older builds sent it as `document_verification` with a
  /// `driverId`, which an owner routes the same way. A driver's
  /// `document_verification` opens its own documents.
  static DocumentTapRoute tapRoute({required String type, String? driverId, required bool isOwner}) {
    final bool hasDriver = (driverId ?? '').trim().isNotEmpty;
    if (type == OwnerVerificationPush.ownerDataType) {
      if (!isOwner) return DocumentTapRoute.none;
      return hasDriver ? DocumentTapRoute.ownerReview : DocumentTapRoute.ownerList;
    }
    if (type == OwnerVerificationPush.driverDataType) {
      if (isOwner && hasDriver) return DocumentTapRoute.ownerReview;
      return DocumentTapRoute.ownDocuments;
    }
    return DocumentTapRoute.none;
  }
}
