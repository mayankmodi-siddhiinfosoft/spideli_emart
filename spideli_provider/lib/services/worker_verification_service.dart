import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
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
/// overwritten; another holder's record is refused), then writes only `id`,
/// `type` ("worker") and `documents` of `documents_verify` (merge, every other
/// entry and field kept) and `providers_workers.isDocumentVerify`
/// recalculated from the required documents when it changes. The worker's
/// push follows the commit.
class WorkerVerificationService {
  WorkerVerificationService._();

  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static DocumentReference<Map<String, dynamic>> workerRef(String workerId) => _db.collection(WORKERS).doc(workerId);

  static DocumentReference<Map<String, dynamic>> verifyRef(String workerId) => _db.collection('documents_verify').doc(workerId);

  static DocumentReference<Map<String, dynamic>> settingsRef() => _db.collection(Setting).doc(WorkerVerificationRules.settingsDocument);

  static Query<Map<String, dynamic>> typesQuery() =>
      _db.collection('documents').where('type', isEqualTo: WorkerVerificationRules.workerType).where('enable', isEqualTo: true);

  /// This provider's workers (`providers_workers` where `providerId` is the
  /// provider): the only workers it may review.
  static Query<Map<String, dynamic>> myWorkersQuery() => _db.collection(WORKERS).where('providerId', isEqualTo: providerId);

  /// `isWorkerVerification`, live: null until known (a cache miss).
  static Stream<bool?> verificationRequiredStream() => settingsRef()
      .snapshots(includeMetadataChanges: true)
      .map((snap) => WorkerVerificationRules.verificationRequiredFrom(exists: snap.exists, isFromCache: snap.metadata.isFromCache, data: snap.data()));

  /// The required worker document types, live. An empty answer from the cache
  /// is a failed read.
  static Stream<WorkerDocumentTypes> requiredTypesStream() => typesQuery().snapshots(includeMetadataChanges: true).map((snap) => WorkerDocumentTypes(
        WorkerVerificationRules.requiredTypesFrom(snap.docs.map((d) => MapEntry(d.id, d.data()))),
        failed: DocumentType.unreadable(isEmpty: snap.docs.isEmpty, isFromCache: snap.metadata.isFromCache),
      ));

  /// The worker records of [workerIds] (`documents_verify/{id}`, at most 30
  /// ids), live: worker records only (another holder's record reads as no
  /// upload).
  static Stream<Map<String, Map<String, UploadedDocument>>> uploadsStream(List<String> workerIds) => _db
      .collection('documents_verify')
      .where(FieldPath.documentId, whereIn: workerIds)
      .snapshots()
      .map((snap) => {for (final doc in snap.docs) doc.id: WorkerVerificationRules.uploadsFromRecord(doc.data())});

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
      final snap = await typesQuery().get();
      final types = WorkerVerificationRules.requiredTypesFrom(snap.docs.map((d) => MapEntry(d.id, d.data())));
      return WorkerDocumentTypes(types, failed: DocumentType.unreadable(isEmpty: snap.docs.isEmpty, isFromCache: snap.metadata.isFromCache));
    } catch (e) {
      log('Worker document types not read: $e');
      return const WorkerDocumentTypes([], failed: true);
    }
  }

  /// The required types read from the SERVER (never a cached list): an
  /// assignment is validated against the admin's current configuration.
  static Future<WorkerDocumentTypes> requiredTypesFromServer() async {
    try {
      final snap = await typesQuery().get(const GetOptions(source: Source.server));
      return WorkerDocumentTypes(WorkerVerificationRules.requiredTypesFrom(snap.docs.map((d) => MapEntry(d.id, d.data()))));
    } catch (e) {
      log('Worker document types not read from the server: $e');
      return const WorkerDocumentTypes([], failed: true);
    }
  }

  /// For the "Assign worker" list: why each of [workers] (this provider's
  /// worker records, as read) may not be given an order, null = may be.
  /// Computed from the workers' documents_verify records and the current
  /// required types ([WorkerVerificationRules.assignmentRefusal]); when the
  /// documents cannot be read, the worker is NOT offered.
  static Future<Map<String, WorkerAssignmentRefusal?>> assignmentRefusals(List<({String id, Map<String, dynamic> data})> workers) async {
    final bool? required = await verificationRequired();
    final WorkerDocumentTypes types = required == false ? const WorkerDocumentTypes([]) : await requiredTypesFromServer();
    Map<String, Map<String, dynamic>> records = {};
    bool recordsFailed = false;
    if (required != false && types.types.isNotEmpty) {
      try {
        records = await _recordsOf(workers.map((w) => w.id).toList());
      } catch (e) {
        log('Worker documents not read: $e');
        recordsFailed = true;
      }
    }
    return {
      for (final w in workers)
        w.id: WorkerVerificationRules.assignmentRefusal(
          workerData: w.data,
          providerId: providerId,
          verificationRequired: required,
          types: types.types,
          typesLoadFailed: types.failed,
          record: records[w.id],
          recordLoadFailed: recordsFailed,
        ),
    };
  }

  /// Which of [workers] may be given a job now (the Worker app's gate: the
  /// overall status computed from the required documents is Verified, or
  /// verification is off). When the state cannot be read, the worker is NOT
  /// offered (the assignment would land on a worker whose app hides it).
  static Future<Set<String>> assignableWorkerIds(List<({String id, Map<String, dynamic> data})> workers) async {
    final refusals = await assignmentRefusals(workers);
    return refusals.entries.where((e) => e.value == null).map((e) => e.key).toSet();
  }

  /// The whole documents_verify records of [workerIds], 30 ids per query.
  static Future<Map<String, Map<String, dynamic>>> _recordsOf(List<String> workerIds) async {
    final Map<String, Map<String, dynamic>> out = {};
    final ids = workerIds.where((id) => id.trim().isNotEmpty && !id.contains('/')).toSet().toList();
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db.collection('documents_verify').where(FieldPath.documentId, whereIn: chunk).get(const GetOptions(source: Source.server));
      for (final doc in snap.docs) {
        out[doc.id] = doc.data();
      }
    }
    return out;
  }

  /// Assigns [order] to [workerId] ONLY when the worker may be given an order
  /// at this moment: one transaction re-reads the worker record (own worker),
  /// the verification setting and the worker's LIVE `documents_verify`
  /// record, and checks them against the required types read from the server
  /// just before ([WorkerVerificationRules.assignmentRefusal]). The order is
  /// written (status "Order Assigned", workerId) in the same transaction, so
  /// a rejection or a re-upload that lands meanwhile is never missed.
  /// Returns null when assigned, else the reason; throws when it could not be
  /// written (offline).
  static Future<WorkerAssignmentRefusal?> assignWorker({required OnProviderOrderModel order, required String workerId, required String assignedStatus}) async {
    final WorkerDocumentTypes types = await requiredTypesFromServer();
    final String me = providerId;
    return _db.runTransaction<WorkerAssignmentRefusal?>((tx) async {
      final workerSnap = await tx.get(workerRef(workerId));
      final settingsSnap = await tx.get(settingsRef());
      final bool? required = WorkerVerificationRules.verificationRequiredFrom(exists: settingsSnap.exists, isFromCache: settingsSnap.metadata.isFromCache, data: settingsSnap.data());
      final verifySnap = await tx.get(verifyRef(workerId));
      final WorkerAssignmentRefusal? refusal = WorkerVerificationRules.assignmentRefusal(
        workerData: workerSnap.data(),
        providerId: me,
        verificationRequired: required,
        types: types.types,
        typesLoadFailed: types.failed,
        record: verifySnap.data(),
      );
      if (refusal != null) return refusal;
      order.workerId = workerId;
      order.status = assignedStatus;
      tx.set(_db.collection(PROVIDER_ORDER).doc(order.id), order.toJson(), SetOptions(merge: true));
      return null;
    });
  }

  /// Runs one review action ([plan] on the stored `documents`) for
  /// [workerId], then pushes the decision to the worker.
  static Future<WorkerReviewResult> review({
    required String workerId,
    required WorkerReviewAction action,
    required List<DocumentType> types,
    required WorkerReviewOutcome Function(dynamic storedDocuments, bool? currentFlag, String reviewerId, Timestamp at) plan,
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
        // Never review (or write into) another holder's record.
        if (verifySnap.exists && !WorkerVerificationRules.isWorkerRecord(verifySnap.data())) {
          return const WorkerReviewOutcome(refusal: WorkerReviewRefusal.notWorkerRecord);
        }
        final WorkerReviewOutcome planned = plan(verifySnap.data()?['documents'], wasVerified, reviewer, Timestamp.now());
        if (planned.refused) return planned;
        if (planned.changedIds.isNotEmpty) {
          final Map<String, dynamic> data = {'id': workerId, 'type': WorkerVerificationRules.workerType, 'documents': planned.documents};
          tx.set(verifyRef(workerId), data, SetOptions(mergeFields: data.keys.map((k) => FieldPath([k])).toList()));
        }
        // isDocumentVerify recalculated from the required documents
        // (WorkerVerificationStatusRules.flagAfterReview), in the same
        // transaction.
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
