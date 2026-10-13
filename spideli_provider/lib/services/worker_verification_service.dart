import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/push_message.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/services/worker_document_push.dart';

/// The required worker document types, or a failed read.
class WorkerDocumentTypes {
  final List<DocumentType> types;
  final bool failed;

  const WorkerDocumentTypes(this.types, {this.failed = false});
}

/// What a committed (or refused) review action returns to the screen.
class WorkerReviewResult {
  final WorkerReviewOutcome outcome;

  /// The action could not be written (offline, rules).
  final bool failed;

  const WorkerReviewResult(this.outcome, {this.failed = false});

  bool get ok => !failed && !outcome.refused;
}

/// Firestore side of the provider's worker verification
/// ([WorkerVerificationRules] holds the rules).
///
/// Every review action is ONE transaction that re-reads the worker record
/// (guard: it must still be this provider's worker) and the worker's
/// `documents_verify` record (a re-upload made meanwhile is never
/// overwritten), then writes only `documents_verify.documents` (merge, every
/// other entry and field kept) and, when the rules say so,
/// `providers_workers.isDocumentVerify`. The worker's push follows the commit.
class WorkerVerificationService {
  WorkerVerificationService._();

  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static DocumentReference<Map<String, dynamic>> workerRef(String workerId) => _db.collection(WORKERS).doc(workerId);

  static DocumentReference<Map<String, dynamic>> verifyRef(String workerId) => _db.collection('documents_verify').doc(workerId);

  static String get providerId => MyAppState.currentUser?.id ?? '';

  /// `{providerName}`: the company name when set, else the provider's name.
  static String get providerName {
    final user = MyAppState.currentUser;
    final String company = (user?.companyName ?? '').trim();
    return company.isNotEmpty ? company : (user?.fullName() ?? '').trim();
  }

  /// `settings/document_verification_settings.isWorkerVerification`; null
  /// when it could not be read.
  static Future<bool?> verificationRequired() async {
    try {
      final snap = await _db.collection(Setting).doc(WorkerVerificationRules.settingsDocument).get();
      return WorkerVerificationRules.verificationRequiredFrom(exists: snap.exists, isFromCache: snap.metadata.isFromCache, data: snap.data());
    } catch (e) {
      log('Worker verification setting not read: $e');
      return null;
    }
  }

  /// The required worker document types (`type == "worker"`,
  /// `enable == true`). An empty answer from the cache is a failed read.
  static Future<WorkerDocumentTypes> requiredTypes() async {
    try {
      final snap = await _db.collection('documents').where('type', isEqualTo: WorkerVerificationRules.workerType).where('enable', isEqualTo: true).get();
      final types = DocumentType.enabledFrom(snap.docs.map((d) => MapEntry(d.id, d.data())));
      return WorkerDocumentTypes(types, failed: DocumentType.unreadable(isEmpty: snap.docs.isEmpty, isFromCache: snap.metadata.isFromCache));
    } catch (e) {
      log('Worker document types not read: $e');
      return const WorkerDocumentTypes([], failed: true);
    }
  }

  /// The uploads of [workerIds] (`documents_verify/{id}`), 30 ids per query.
  /// Throws when they could not be read.
  static Future<Map<String, Map<String, UploadedDocument>>> uploadsOf(List<String> workerIds) async {
    final Map<String, Map<String, UploadedDocument>> out = {};
    final ids = workerIds.where((id) => id.trim().isNotEmpty && !id.contains('/')).toSet().toList();
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db.collection('documents_verify').where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        out[doc.id] = WorkerVerificationRules.uploadsFrom(doc.data()['documents']);
      }
    }
    return out;
  }

  /// Which of [workers] may be given a job now (the Worker app's gate). When
  /// the state cannot be read, the worker is NOT offered (the assignment would
  /// land on a worker whose app hides it).
  static Future<Set<String>> assignableWorkerIds(List<({String id, bool? isDocumentVerify})> workers) async {
    final bool? required = await verificationRequired();
    if (required == false) return workers.map((w) => w.id).toSet();
    final WorkerDocumentTypes types = await requiredTypes();
    if (types.types.isEmpty && !types.failed) return workers.map((w) => w.id).toSet();
    Map<String, Map<String, UploadedDocument>> uploads = {};
    try {
      uploads = await uploadsOf(workers.map((w) => w.id).toList());
    } catch (e) {
      log('Worker uploads not read: $e');
    }
    return workers
        .where((w) => WorkerVerificationRules.canReceiveJobs(
              verificationRequired: required,
              types: types.types,
              typesLoadFailed: types.failed,
              uploads: uploads[w.id] ?? const {},
              isDocumentVerify: w.isDocumentVerify,
            ))
        .map((w) => w.id)
        .toSet();
  }

  /// Runs one review action ([plan] on the stored `documents`) for
  /// [workerId], then pushes the decision to the worker.
  static Future<WorkerReviewResult> review({
    required String workerId,
    required WorkerReviewAction action,
    required List<DocumentType> types,
    required WorkerReviewOutcome Function(dynamic storedDocuments, String reviewerId, Timestamp at) plan,
    String reason = '',
  }) async {
    final String reviewer = providerId;
    bool? wasVerified;
    WorkerReviewOutcome outcome;
    try {
      outcome = await _db.runTransaction<WorkerReviewOutcome>((tx) async {
        final workerSnap = await tx.get(workerRef(workerId));
        if (!WorkerVerificationRules.canReview(workerSnap.data(), reviewer)) {
          return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notYourWorker);
        }
        wasVerified = workerSnap.data()?['isDocumentVerify'] is bool ? workerSnap.data()!['isDocumentVerify'] as bool : null;
        final verifySnap = await tx.get(verifyRef(workerId));
        final WorkerReviewOutcome planned = plan(verifySnap.data()?['documents'], reviewer, Timestamp.now());
        if (planned.refused) return planned;
        if (planned.changedIds.isNotEmpty) {
          tx.set(verifyRef(workerId), {'documents': planned.documents}, SetOptions(mergeFields: [FieldPath(const ['documents'])]));
        }
        if (planned.setVerified != null && planned.setVerified != wasVerified) {
          tx.update(workerRef(workerId), {'isDocumentVerify': planned.setVerified});
        }
        return planned;
      });
    } catch (e, s) {
      log('Worker document review not saved: $e', stackTrace: s);
      return const WorkerReviewResult(WorkerReviewOutcome(), failed: true);
    }
    if (!outcome.refused) {
      for (final push in workerDocumentPushes(
        action: action,
        outcome: outcome,
        types: types,
        workerId: workerId,
        providerId: reviewer,
        providerName: providerName,
        wasVerified: wasVerified,
        reason: reason,
      )) {
        // The decision is saved whether the push goes out or not.
        unawaited(SendNotification.sendFcmMessage(push.type, '', push.data, recipientId: workerId, recipient: PushApp.worker, values: push.values));
      }
    }
    return WorkerReviewResult(outcome);
  }
}
