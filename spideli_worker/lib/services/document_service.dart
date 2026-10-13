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
/// * `providers_workers/{uid}.isDocumentVerify == true` = verified, set by the
///   admin panel or by the worker's provider once every required document is
///   approved. This app never writes it.
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

  /// Status of one document type given what the worker uploaded. Rejected
  /// first (its reason is shown); then expired (stored as such, or past its
  /// `expireAt`, whether approved or still waiting); nothing sent = not
  /// submitted; approved; anything else sent is pending review.
  static VerificationStatus statusOf(Documents? uploaded, {DateTime? now}) {
    if (uploaded == null) return VerificationStatus.notSubmitted;
    final String status = (uploaded.status ?? '').trim().toLowerCase();
    if (status == 'rejected') return VerificationStatus.rejected;
    if (!uploaded.hasFile) return VerificationStatus.notSubmitted;
    if (status == 'expired') return VerificationStatus.expired;
    final Timestamp? expiry = uploaded.expiryDate;
    if (expiry != null && expiry.toDate().isBefore(now ?? DateTime.now())) return VerificationStatus.expired;
    if (status == 'approved' || status == 'verified') return VerificationStatus.approved;
    return VerificationStatus.pending;
  }

  /// Overall status over the REQUIRED types only (enabled `worker` types; an
  /// upload for a type disabled since is ignored, so it cannot lock the
  /// worker): any rejected > any expired > any not submitted > any pending >
  /// approved. `isDocumentVerify == true` (admin or provider approval) counts
  /// as approved unless a document is rejected or expired. With no document
  /// type configured nothing has been verified: approved only when
  /// `isDocumentVerify` is set, otherwise not submitted.
  static VerificationStatus overallStatus(List<DocumentModel> types, WorkerDocumentModel? uploaded, {bool? isDocumentVerify, DateTime? now}) {
    if (types.isEmpty) return isDocumentVerify == true ? VerificationStatus.approved : VerificationStatus.notSubmitted;
    final statuses = types.map((t) => statusOf(uploaded?.documentFor(t.id), now: now)).toList();
    VerificationStatus result;
    if (statuses.contains(VerificationStatus.rejected)) {
      result = VerificationStatus.rejected;
    } else if (statuses.contains(VerificationStatus.expired)) {
      result = VerificationStatus.expired;
    } else if (statuses.contains(VerificationStatus.notSubmitted)) {
      result = VerificationStatus.notSubmitted;
    } else if (statuses.contains(VerificationStatus.pending)) {
      result = VerificationStatus.pending;
    } else {
      result = VerificationStatus.approved;
    }
    if (isDocumentVerify == true && result != VerificationStatus.rejected && result != VerificationStatus.expired) {
      return VerificationStatus.approved;
    }
    return result;
  }

  /// Whether the worker may see the active jobs, start one and go online
  /// (spec 3.6). The Provider app's worker review and job assignment apply
  /// the same rule.
  /// * Verification off ([verificationRequired] false): always.
  /// * Not known yet (null: the settings have not been read): treated as on.
  /// * The admin's worker document types were read and there are none:
  ///   nothing could be uploaded or approved, so the worker is not locked out
  ///   for good (the displayed status stays "not submitted").
  /// * Otherwise only when [overallStatus] is approved. A failed type read
  ///   ([typesLoadFailed]) keeps the gate closed until the types arrive.
  static bool canReceiveJobs({
    required bool? verificationRequired,
    required List<DocumentModel> types,
    required bool typesLoadFailed,
    WorkerDocumentModel? uploaded,
    bool? isDocumentVerify,
    DateTime? now,
  }) {
    if (verificationRequired == false) return true;
    if (types.isEmpty && !typesLoadFailed) return true;
    return overallStatus(types, uploaded, isDocumentVerify: isDocumentVerify, now: now) == VerificationStatus.approved;
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

  /// Adds or replaces the entry for [document.documentId] in
  /// `documents_verify/{uid}` with status "uploaded" (pending review), in a
  /// transaction on the stored list ([mergeUpload]), writing only `id`,
  /// `type` and `documents` so any other field on the record survives.
  static Future<void> submitDocument(String uid, Documents document) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(verifyRef(uid));
      final dynamic stored = snap.data()?['documents'];
      final List<dynamic> list = mergeUpload(stored is List ? List<dynamic>.from(stored) : <dynamic>[], document);
      final Map<String, dynamic> data = {'id': uid, 'type': workerType, 'documents': list};
      tx.set(verifyRef(uid), data, SetOptions(mergeFields: data.keys.map((k) => FieldPath([k])).toList()));
    });
  }
}
