import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/worker_verification.dart';

/// `dynamic_notification` templates of the worker document review
/// (service_type "OnDemand Service"):
///
/// | type | to | placeholders |
/// |---|---|---|
/// | `worker_document_submitted` | the provider (sent by the Worker app) | `{workerName}`, `{documentTitle}` |
/// | `worker_document_approved` | the worker | `{documentTitle}`, `{providerName}` |
/// | `worker_documents_verified` | the worker | `{providerName}` |
/// | `worker_document_rejected` | the worker | `{documentTitle}`, `{providerName}`, `{reason}` |
///
/// A tap on `worker_document_submitted` opens that worker's review screen
/// (data `workerId`); the worker's pushes open the Worker app's Documents tab.
class WorkerDocumentPushType {
  WorkerDocumentPushType._();

  static const String submitted = 'worker_document_submitted';
  static const String approved = 'worker_document_approved';
  static const String verified = 'worker_documents_verified';
  static const String rejected = 'worker_document_rejected';
}

/// The review action a push follows.
enum WorkerReviewAction { approve, approveAll, reject }

/// One push to send to the worker after a review action.
class WorkerDocumentPushPlan {
  final String type;
  final Map<String, String> values;
  final Map<String, String> data;

  const WorkerDocumentPushPlan(this.type, this.values, this.data);
}

/// The pushes of a committed review action ([outcome], not refused):
/// * the worker became verified by it ([wasVerified] not true, the action
///   set the flag): `worker_documents_verified` only;
/// * otherwise an approval: one `worker_document_approved` naming the
///   approved document(s);
/// * a rejection: `worker_document_rejected` with the reason.
List<WorkerDocumentPushPlan> workerDocumentPushes({
  required WorkerReviewAction action,
  required WorkerReviewOutcome outcome,
  required List<DocumentType> types,
  required String workerId,
  required String providerId,
  required String providerName,
  bool? wasVerified,
  String reason = '',
}) {
  if (outcome.refused) return const [];
  String titleOf(String id) {
    for (final t in types) {
      if (t.id == id && t.title.trim().isNotEmpty) return t.title.trim();
    }
    return id;
  }

  final String titles = outcome.changedIds.map(titleOf).join(', ');
  Map<String, String> data(String type) => {
        'type': type,
        if (workerId.trim().isNotEmpty) 'workerId': workerId.trim(),
        if (providerId.trim().isNotEmpty) 'providerId': providerId.trim(),
        if (outcome.changedIds.length == 1) 'documentId': outcome.changedIds.single,
      };

  switch (action) {
    case WorkerReviewAction.reject:
      if (outcome.changedIds.isEmpty) return const [];
      return [
        WorkerDocumentPushPlan(WorkerDocumentPushType.rejected, {'documentTitle': titles, 'providerName': providerName, 'reason': reason.trim()}, data(WorkerDocumentPushType.rejected)),
      ];
    case WorkerReviewAction.approve:
    case WorkerReviewAction.approveAll:
      if (outcome.setVerified == true && wasVerified != true) {
        return [WorkerDocumentPushPlan(WorkerDocumentPushType.verified, {'providerName': providerName}, data(WorkerDocumentPushType.verified))];
      }
      if (outcome.changedIds.isEmpty) return const [];
      return [WorkerDocumentPushPlan(WorkerDocumentPushType.approved, {'documentTitle': titles, 'providerName': providerName}, data(WorkerDocumentPushType.approved))];
  }
}
