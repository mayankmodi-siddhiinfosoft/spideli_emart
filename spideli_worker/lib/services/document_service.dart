import 'dart:developer';
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
///   `isStoreVerification`); absent or false = today's behaviour, no gate;
/// * `providers_workers/{uid}.isDocumentVerify == true` = approved by the
///   admin (same flag the Driver app uses on its user doc).
class DocumentService {
  DocumentService._();

  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static const String workerType = 'worker';

  static Future<bool> isVerificationRequired() async {
    try {
      final data = (await _db.collection(Setting).doc('document_verification_settings').get()).data();
      return data?['isWorkerVerification'] == true;
    } catch (e) {
      log('DocumentService settings failed: $e');
      return false;
    }
  }

  /// Admin-configured worker document types; a built-in identity document
  /// when none is configured (spec 3.6: "Identity document").
  static Future<List<DocumentModel>> getDocumentTypes() async {
    final List<DocumentModel> list = [];
    try {
      final snap = await _db.collection(DOCUMENTS).where('type', isEqualTo: workerType).where('enable', isEqualTo: true).get();
      for (final doc in snap.docs) {
        list.add(DocumentModel.fromJson(doc.data(), docId: doc.id));
      }
    } catch (e) {
      log('DocumentService document types failed: $e');
    }
    if (list.isEmpty) list.add(DocumentModel.identityDocument());
    return list;
  }

  static DocumentReference<Map<String, dynamic>> _verifyRef(String uid) => _db.collection(DOCUMENTS_VERIFY).doc(uid);

  static Stream<WorkerDocumentModel?> watchWorkerDocuments(String uid) =>
      _verifyRef(uid).snapshots().map((snap) => snap.exists && snap.data() != null ? WorkerDocumentModel.fromJson(snap.data()!) : null);

  static Future<WorkerDocumentModel?> getWorkerDocuments(String uid) async {
    final snap = await _verifyRef(uid).get();
    return snap.exists && snap.data() != null ? WorkerDocumentModel.fromJson(snap.data()!) : null;
  }

  /// Status of one document type given what the worker uploaded.
  static VerificationStatus statusOf(Documents? uploaded) {
    if (uploaded == null || (uploaded.frontImage ?? '').isEmpty && (uploaded.backImage ?? '').isEmpty) {
      return VerificationStatus.notSubmitted;
    }
    switch (uploaded.status) {
      case 'rejected':
        return VerificationStatus.rejected;
      case 'approved':
        final expiry = uploaded.expiryDate;
        if (expiry != null && expiry.toDate().isBefore(DateTime.now())) return VerificationStatus.expired;
        return VerificationStatus.approved;
      default:
        return VerificationStatus.pending;
    }
  }

  /// Overall status: any rejected > any expired > any not submitted > any
  /// pending > approved. `isDocumentVerify == true` on the worker (admin
  /// approval) counts as approved unless a document is rejected or expired.
  static VerificationStatus overallStatus(List<DocumentModel> types, WorkerDocumentModel? uploaded, {bool? isDocumentVerify}) {
    final statuses = types.map((t) => statusOf(uploaded?.documentFor(t.id))).toList();
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

  static Future<String> uploadFile(File file, String uid) async {
    final String name = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final Reference ref = FirebaseStorage.instance.ref().child('workerDocument/$uid/$name');
    final TaskSnapshot task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Adds or replaces the entry for [document.documentId] in
  /// `documents_verify/{uid}` with status "uploaded" (pending review), in a
  /// transaction, writing only `id`, `type` and `documents` so any other
  /// panel-written field on the doc survives.
  static Future<void> submitDocument(String uid, Documents document) async {
    document.status = 'uploaded';
    document.rejectionReason = null;
    document.extra.removeWhere((k, _) => k == 'rejectReason' || k == 'reason');
    document.uploadedAt = Timestamp.now();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_verifyRef(uid));
      final List<dynamic> raw = (snap.data()?['documents'] is List) ? List<dynamic>.from(snap.data()!['documents']) : [];
      final int index = raw.indexWhere((e) => e is Map && e['documentId']?.toString() == document.documentId);
      if (index >= 0) {
        raw[index] = document.toJson();
      } else {
        raw.add(document.toJson());
      }
      final Map<String, dynamic> data = {'id': uid, 'type': workerType, 'documents': raw};
      tx.set(_verifyRef(uid), data, SetOptions(mergeFields: data.keys.map((k) => FieldPath([k])).toList()));
    });
  }
}
