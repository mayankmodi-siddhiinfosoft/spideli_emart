import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';

/// Worker document verification (spec 3.6 / 11), on the same collections the
/// Driver app uses:
/// * `documents` (admin-configured types), filtered on `type == "worker"` and
///   `enable == true`;
/// * `documents_verify/{workerUid}` `{ id, type: "worker", documents: [...] }`;
/// * `settings/document_verification_settings.isWorkerVerification` turns the
///   requirement on (same pattern as `isDriverVerification` /
///   `isStoreVerification`); absent or false = no gate;
/// * `providers_workers/{uid}.isDocumentVerify`: kept in sync with the
///   required documents -- set true by the admin panel or the worker's
///   provider once every required document is approved; this app only ever
///   LOWERS it (a submission that leaves the worker unverified). It never
///   makes the worker Verified on its own while verification is on
///   ([WorkerVerificationStatusRules.overall]).
/// Contract: `.claude/DOCUMENT-VERIFICATION-WORKER.md`.
class DocumentService {
  DocumentService._();

  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static const String workerType = 'worker';
  static const String settingsDocument = 'document_verification_settings';
  static const String settingsField = 'isWorkerVerification';

  /// Largest side of a picked document photo: readable, a few hundred KB
  /// instead of a 12 MP original.
  static const double maxImageSide = 1920;

  /// An upload that has not finished by then is cancelled and reported, so the
  /// loader never spins for Storage's 10-minute retry window.
  static const Duration uploadTimeout = Duration(minutes: 2);

  static DocumentReference<Map<String, dynamic>> settingsRef() => _db.collection(Setting).doc(settingsDocument);

  static Query<Map<String, dynamic>> typesQuery() => _db.collection(DOCUMENTS).where('type', isEqualTo: workerType).where('enable', isEqualTo: true);

  /// Whether verification is on, from the settings document: `true` / `false`
  /// when known, null when it is not -- a snapshot served from the device
  /// cache that does not hold the document has not reached the server.
  static bool? verificationRequiredFrom({required bool exists, required bool isFromCache, Map<String, dynamic>? data}) {
    if (!exists) return isFromCache ? null : false;
    return data?[settingsField] == true;
  }

  /// An empty `documents` answer served from the cache means the types were
  /// not read (offline on a device that never loaded them), not that the
  /// admin set up none.
  static bool typesUnreadable({required bool isEmpty, required bool isFromCache}) => isEmpty && isFromCache;

  /// Pure part of the type query: builds the types from `(docId, data)`
  /// pairs, skipping any without an id or not an enabled worker type (the
  /// query already filters; this keeps a stray row from becoming an upload
  /// key). Report Doc 36/41: uploads are made only against these ids; there
  /// is no built-in fallback type.
  static List<DocumentModel> documentTypesFrom(Iterable<MapEntry<String, Map<String, dynamic>>> docs) {
    final List<DocumentModel> list = [];
    for (final doc in docs) {
      if (doc.value['type']?.toString() != workerType || doc.value['enable'] != true) continue;
      final type = DocumentModel.fromJson(doc.value, docId: doc.key);
      if ((type.id ?? '').isEmpty) continue;
      list.add(type);
    }
    return list;
  }

  static DocumentReference<Map<String, dynamic>> verifyRef(String uid) => _db.collection(DOCUMENTS_VERIFY).doc(uid);

  /// Status of one document type given what the worker uploaded
  /// ([WorkerVerificationStatusRules.documentState], shared with the Provider
  /// app): rejected first (its reason is shown); then not submitted (nothing
  /// sent); expired (stored as such, or past its `expireAt`, whether approved
  /// or still waiting); approved; anything else sent is pending review.
  static VerificationStatus statusOf(Documents? uploaded, {DateTime? now}) => stateOf(uploaded, now: now).asVerificationStatus;

  /// [statusOf] as the shared state.
  static WorkerDocumentState stateOf(Documents? uploaded, {DateTime? now}) => WorkerVerificationStatusRules.documentState(
        exists: uploaded != null,
        status: uploaded?.status,
        hasFile: uploaded?.hasFile ?? false,
        expireAt: uploaded?.expiryDate?.toDate(),
        now: now ?? DateTime.now(),
      );

  /// The states of the REQUIRED documents ([types]: the enabled `worker`
  /// types; an upload for a type disabled since is ignored, so it cannot lock
  /// the worker).
  static List<WorkerDocumentState> requiredStates(List<DocumentModel> types, WorkerDocumentModel? uploaded, {DateTime? now}) =>
      types.map((t) => stateOf(uploaded?.documentFor(t.id), now: now)).toList();

  /// Overall status ([WorkerVerificationStatusRules.overall]): computed from
  /// the REQUIRED documents only. `isDocumentVerify == true` alone never makes
  /// the worker Verified while verification is on: a pending, missing,
  /// rejected or expired required document keeps them unverified.
  static WorkerOverallStatus overallStatus(List<DocumentModel> types, WorkerDocumentModel? uploaded, {bool? isDocumentVerify, bool? verificationRequired, DateTime? now}) =>
      WorkerVerificationStatusRules.overall(requiredStates(types, uploaded, now: now), isDocumentVerify: isDocumentVerify, verificationRequired: verificationRequired);

  /// Whether the worker may see the active jobs, start one and go online
  /// (spec 3.6), [WorkerVerificationStatusRules.canReceiveJobs]; the Provider
  /// app's job assignment applies the same rule.
  /// * Verification off ([verificationRequired] false): always.
  /// * Not known yet (null: the settings have not been read): treated as on.
  /// * The admin's worker document types were read and there are none:
  ///   nothing could be uploaded or approved, so the worker is not locked out.
  /// * The types could not be read ([typesLoadFailed] with none known): closed.
  /// * Otherwise only when [overallStatus] is Verified.
  static bool canReceiveJobs({
    required bool? verificationRequired,
    required List<DocumentModel> types,
    required bool typesLoadFailed,
    WorkerDocumentModel? uploaded,
    bool? isDocumentVerify,
    DateTime? now,
  }) =>
      WorkerVerificationStatusRules.canReceiveJobs(
        verificationRequired: verificationRequired,
        noRequiredTypes: types.isEmpty,
        typesLoadFailed: typesLoadFailed,
        overall: overallStatus(types, uploaded, isDocumentVerify: isDocumentVerify, verificationRequired: verificationRequired, now: now),
      );

  /// The worker's own record from `documents_verify/{uid}`: null when there
  /// is none, or when the record belongs to another holder type (driver,
  /// owner, vendor, provider) -- never read as the worker's.
  static WorkerDocumentModel? uploadedFrom(Map<String, dynamic>? data) {
    if (data == null || !WorkerVerificationStatusRules.isWorkerRecordType(data['type'])) return null;
    return WorkerDocumentModel.fromJson(data);
  }

  /// Uploads one document photo to `workerDocument/{uid}/...`. Throws on a
  /// failure, and after [uploadTimeout] (the upload is then cancelled).
  static Future<String> uploadFile(File file, String uid) async {
    final String name = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final Reference ref = FirebaseStorage.instance.ref().child('workerDocument/$uid/$name');
    final UploadTask task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    try {
      final TaskSnapshot snapshot = await task.timeout(uploadTimeout);
      return await snapshot.ref.getDownloadURL();
    } on TimeoutException {
      unawaited(task.cancel().catchError((_) => false));
      rethrow;
    }
  }

  /// The `documents` list after the worker (re)submits [document]: the entry
  /// with the same `documentId` is replaced IN PLACE (one entry per type, any
  /// duplicates of it left by older builds are dropped), every other entry is
  /// kept exactly as stored. Fields of the stored entry that this app does
  /// not manage (`number`, panel fields) are carried over; the previous
  /// decision ([Documents.reviewKeys]) is not -- the new submission is
  /// "uploaded", without a reason.
  static List<dynamic> mergeUpload(List<dynamic> stored, Documents document, {Timestamp? now}) {
    final String id = document.documentId ?? '';
    final List<dynamic> out = [];
    Map<String, dynamic>? previous;
    int? at;
    for (final entry in stored) {
      if (entry is Map && entry['documentId']?.toString() == id) {
        if (at == null) {
          at = out.length;
          previous = Map<String, dynamic>.from(entry);
          out.add(null);
        }
        continue;
      }
      out.add(entry);
    }
    final Map<String, dynamic> carried = {...?previous, ...document.extra}..removeWhere((k, _) => Documents.reviewKeys.contains(k) || k == 'expiryDate' || k == 'uploadedAt');
    final Documents entry = Documents(
      documentId: id,
      frontImage: document.frontImage,
      backImage: document.backImage,
      status: 'uploaded',
      expiryDate: document.expiryDate,
      submittedAt: now ?? Timestamp.now(),
      extra: carried..removeWhere((k, _) => const ['documentId', 'frontImage', 'backImage', 'status', 'expireAt', 'submittedAt'].contains(k)),
    );
    if (at == null) {
      out.add(entry.toJson());
    } else {
      out[at] = entry.toJson();
    }
    return out;
  }

  /// What one submission writes ([planSubmit]).
  ///
  /// [documents]: the whole merged list ([mergeUpload]); [setVerified]:
  /// `providers_workers.isDocumentVerify` to write (only ever false), null =
  /// leave it.
  static ({List<dynamic> documents, bool? setVerified}) planSubmit({
    required List<dynamic> stored,
    required Documents document,
    required List<DocumentModel> requiredTypes,
    bool? currentFlag,
    Timestamp? at,
    DateTime? now,
  }) {
    final List<dynamic> list = mergeUpload(stored, document, now: at);
    final WorkerDocumentModel after = WorkerDocumentModel.fromJson({'documents': list});
    return (
      documents: list,
      setVerified: WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: requiredStates(requiredTypes, after, now: now), current: currentFlag),
    );
  }

  /// Adds or replaces the entry for [document.documentId] in
  /// `documents_verify/{uid}` with status "uploaded" (pending review, never
  /// auto-approved; the previous reason and review are cleared), in ONE
  /// transaction that also re-reads `providers_workers/{uid}`:
  /// * the record must be the worker's (`type` "worker", or none yet):
  ///   another holder's record is never touched ([WorkerRecordTypeConflict]);
  /// * only `id`, `type` and `documents` are written, so any other field on
  ///   the record survives;
  /// * when the worker is then no longer Verified by the REQUIRED documents
  ///   ([requiredTypes]), `isDocumentVerify` is set false in the same
  ///   transaction ([WorkerVerificationStatusRules.flagAfterWorkerSubmit]: a
  ///   worker may lower, never raise, their own flag).
  static Future<void> submitDocument(String uid, Documents document, {required List<DocumentModel> requiredTypes}) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(verifyRef(uid));
      final workerSnap = await tx.get(workerRef(uid));
      final Map<String, dynamic>? stored = snap.data();
      if (stored != null && !WorkerVerificationStatusRules.isWorkerRecordType(stored['type'])) {
        throw WorkerRecordTypeConflict(stored['type']?.toString() ?? '');
      }
      final dynamic storedList = stored?['documents'];
      final dynamic flag = workerSnap.data()?['isDocumentVerify'];
      final plan = planSubmit(
        stored: storedList is List ? List<dynamic>.from(storedList) : <dynamic>[],
        document: document,
        requiredTypes: requiredTypes,
        currentFlag: flag is bool ? flag : null,
      );
      final Map<String, dynamic> data = {'id': uid, 'type': workerType, 'documents': plan.documents};
      tx.set(verifyRef(uid), data, SetOptions(mergeFields: data.keys.map((k) => FieldPath([k])).toList()));
      if (plan.setVerified == false && workerSnap.exists) {
        tx.update(workerRef(uid), {'isDocumentVerify': false});
      }
    });
  }

  static DocumentReference<Map<String, dynamic>> workerRef(String uid) => _db.collection(WORKERS).doc(uid);
}

/// `documents_verify/{uid}` holds another holder's record (driver, owner,
/// vendor, provider): the worker's upload is refused rather than mixed in.
class WorkerRecordTypeConflict implements Exception {
  final String type;

  const WorkerRecordTypeConflict(this.type);

  @override
  String toString() => 'documents_verify record has type "$type", not "worker"';
}
