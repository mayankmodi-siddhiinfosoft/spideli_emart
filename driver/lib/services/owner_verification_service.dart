import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

export 'package:driver/services/owner_verification_rules.dart' show OwnerVerificationOutcome, OwnerVerificationResult;

/// A company owner reviewing the documents of its OWN drivers
/// (`users.ownerId` == the owner's uid; every action re-checks it on the
/// driver's live record and refuses anyone else).
///
/// The rules (what is required, what approving / rejecting changes) are in
/// [OwnerVerificationRules]. Each action is one Firestore transaction that
/// writes `documents_verify/{driverId}` (`documents`, `id`, `type: driver`;
/// merged: the record's other fields and every entry's extra fields are
/// kept) and, when it changes, `users/{driverId}.isDocumentVerify` =
/// overall status is verified ([DriverDocumentStatus.flagAfterReview])
/// together, so the two can never diverge. A record of another holder type
/// (`worker`, `owner`, ...) is never touched ([DocumentRecordType]). The driver is then told with a
/// `dynamic_notification` template ([OwnerVerificationPush]) and a record in
/// `users/{driverId}/notifications`.
class OwnerVerificationService {
  OwnerVerificationService._();

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  /// The documents [driver] has to provide: exactly what the driver app asks
  /// that driver to upload (`FireStoreUtils.documentTypesFor`: `driver`, plus
  /// `vehicle` for a cab / rental driver). Throws when the read fails, so a
  /// failed read is never mistaken for "nothing required".
  static Future<List<DocumentModel>> getRequiredDocuments(UserModel driver) =>
      FireStoreUtils.getDocumentListForTypes(FireStoreUtils.documentTypesFor(driver), throwOnError: true);

  /// The documents [driverId] uploaded (`documents_verify/{driverId}`, a
  /// `driver` record), null when there are none or the record belongs to
  /// another holder type. Throws when the read fails.
  static Future<DriverDocumentModel?> getDriverDocuments(String driverId) async {
    if (driverId.isEmpty) return null;
    final snap = await _db.collection(CollectionName.documentsVerify).doc(driverId).get();
    final Map<String, dynamic>? data = snap.data();
    if (!snap.exists || data == null || !DocumentRecordType.belongsTo(data['type'], DocumentRecordType.driver)) return null;
    return DriverDocumentModel.fromJson(data);
  }

  /// [driverId]'s live profile when it is one of the signed-in owner's
  /// company drivers, else null. Throws when the read fails.
  static Future<UserModel?> getOwnDriver(String driverId) async {
    final String id = driverId.trim();
    if (id.isEmpty) return null;
    final snap = await _db.collection(CollectionName.users).doc(id).get();
    final Map<String, dynamic>? data = snap.data();
    if (!snap.exists || data == null) return null;
    if (!OwnerVerificationRules.isOwnersDriverData(id, data['ownerId'], FireStoreUtils.getCurrentUid())) return null;
    return UserModel.fromJson({...data, 'id': id});
  }

  /// Approves one uploaded document. `isDocumentVerify` becomes true only
  /// when this completes the driver's required set, false while another
  /// required document is still missing, pending, rejected or expired.
  static Future<OwnerVerificationResult> approveDocument({required String driverId, required String documentId}) async {
    final _Applied? applied = await _apply(
      driverId,
      (required, docs, reviewer, now) => OwnerVerificationRules.approveOne(required: required, docs: docs, documentId: documentId, reviewedBy: reviewer, reviewedAt: now),
    );
    if (applied == null) return const OwnerVerificationResult(OwnerVerificationOutcome.failed);
    if (!applied.plan.writes) return applied.result;

    final bool verifiedNow = applied.plan.setVerified == true && !applied.wasVerified;
    await _notifyDriver(
      applied,
      template: verifiedNow ? OwnerVerificationPush.documentsVerified : OwnerVerificationPush.documentApproved,
      documentId: documentId,
      status: verifiedNow ? 'all_approved' : 'approved',
    );
    return applied.result;
  }

  /// Rejects one document with [reason] (mandatory). A rejected required
  /// document revokes the account's verification (status: action required).
  static Future<OwnerVerificationResult> rejectDocument({required String driverId, required String documentId, required String reason}) async {
    final _Applied? applied = await _apply(
      driverId,
      (required, docs, reviewer, now) => OwnerVerificationRules.reject(required: required, docs: docs, documentId: documentId, reason: reason, reviewedBy: reviewer, reviewedAt: now),
    );
    if (applied == null) return const OwnerVerificationResult(OwnerVerificationOutcome.failed);
    if (!applied.plan.writes) return applied.result;

    await _notifyDriver(applied, template: OwnerVerificationPush.documentRejected, documentId: documentId, status: 'rejected', reason: reason);
    return applied.result;
  }

  /// Approves every required document the driver uploaded that is waiting
  /// for review, and verifies the account only when afterwards every
  /// required document is uploaded and approved. Otherwise the result is
  /// [OwnerVerificationOutcome.incomplete] with the titles still
  /// outstanding, and the account is not verified.
  static Future<OwnerVerificationResult> approveAllDocuments({required String driverId}) async {
    final _Applied? applied = await _apply(
      driverId,
      (required, docs, reviewer, now) => OwnerVerificationRules.approveAll(required: required, docs: docs, reviewedBy: reviewer, reviewedAt: now),
    );
    if (applied == null) return const OwnerVerificationResult(OwnerVerificationOutcome.failed);
    if (!applied.plan.writes) return applied.result;

    if (applied.plan.outcome == OwnerVerificationOutcome.done) {
      if (!applied.wasVerified || applied.plan.approvedIds.isNotEmpty) {
        await _notifyDriver(applied, template: OwnerVerificationPush.documentsVerified, status: 'all_approved');
      }
    } else {
      for (final String id in applied.plan.approvedIds) {
        await _notifyDriver(applied, template: OwnerVerificationPush.documentApproved, documentId: id, status: 'approved');
      }
    }
    return applied.result;
  }

  // ── The transaction ───────────────────────────────────────────────────────

  /// Reads the driver (owner check), its required documents and, in one
  /// transaction, its live `users` record and `documents_verify` entries;
  /// applies [plan] and writes both documents together. Null when a read or
  /// the write failed (nothing changed).
  static Future<_Applied?> _apply(String driverId, DocumentReviewPlan Function(List<DocumentModel> required, List<Documents> docs, String reviewer, Timestamp now) plan) async {
    final String ownerUid = FireStoreUtils.getCurrentUid();
    final String id = driverId.trim();
    try {
      final UserModel? driver = await getOwnDriver(id);
      if (driver == null) {
        log("Owner verification refused: $id is not a driver of this company.");
        return _Applied.refused(OwnerVerificationOutcome.notYourDriver);
      }
      final List<DocumentModel> required = await getRequiredDocuments(driver);

      final DocumentReference<Map<String, dynamic>> userRef = _db.collection(CollectionName.users).doc(id);
      final DocumentReference<Map<String, dynamic>> docRef = _db.collection(CollectionName.documentsVerify).doc(id);
      DocumentReviewPlan result = const DocumentReviewPlan(OwnerVerificationOutcome.failed);
      bool wasVerified = false;
      String token = '';
      await _db.runTransaction((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> userSnap = await tx.get(userRef);
        final DocumentSnapshot<Map<String, dynamic>> docSnap = await tx.get(docRef);
        final Map<String, dynamic>? user = userSnap.data();
        if (!userSnap.exists || user == null || !OwnerVerificationRules.isOwnersDriverData(id, user['ownerId'], ownerUid)) {
          result = const DocumentReviewPlan(OwnerVerificationOutcome.notYourDriver);
          return;
        }
        wasVerified = user['isDocumentVerify'] == true;
        token = (user['fcmToken'] ?? '').toString().trim();
        final Map<String, dynamic>? record = docSnap.exists ? docSnap.data() : null;
        if (record != null && !DocumentRecordType.belongsTo(record['type'], DocumentRecordType.driver)) {
          // Another holder's documents (a worker, an owner): never mixed in.
          log("Owner verification refused: documents_verify/$id is a '${record['type']}' record.");
          result = const DocumentReviewPlan(OwnerVerificationOutcome.failed);
          return;
        }
        final List<Documents> docs = DocumentRecordType.entriesOf(record, DocumentRecordType.driver);
        result = plan(required, docs, ownerUid, Timestamp.now());
        if (!result.writes) return;
        // Field-level merge: `documents`, `id` and the holder type only; the
        // record's other fields stay, and every entry keeps its extra fields.
        tx.set(
          docRef,
          <String, dynamic>{'id': id, 'type': DocumentRecordType.driver, 'documents': result.documents.map((d) => d.toJson()).toList()},
          SetOptions(merge: true),
        );
        final bool? flag = result.setVerified;
        if (flag != null && flag != wasVerified) tx.update(userRef, <String, dynamic>{'isDocumentVerify': flag});
      });
      if (result.writes) {
        DocumentStatusCache.put(id, DriverDocumentStatus.overall(required: required, docs: result.documents, flag: result.setVerified ?? wasVerified));
      }
      return _Applied(driver: driver, required: required, plan: result, wasVerified: wasVerified, token: token);
    } catch (e) {
      log("Owner verification of $id failed: $e");
      return null;
    }
  }

  // ── Telling the driver ────────────────────────────────────────────────────

  /// The template push to the driver (general driver channel; a tap opens the
  /// driver's own documents) and its `users/{driverId}/notifications` record
  /// with the same filled text. No template: no push, no record (logged).
  /// Never throws.
  static Future<void> _notifyDriver(_Applied applied, {required String template, String? documentId, required String status, String? reason}) async {
    final String driverId = applied.driver.id ?? '';
    try {
      final String documentTitle = applied.required.firstWhereOrNull((d) => d.id == documentId)?.title ?? '';
      final UserModel? owner = Constant.userModel ?? await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      final Map<String, String> values = OwnerVerificationPush.values(
        documentTitle: documentTitle,
        companyName: await CarrierDispatchService.companyNameFor(owner),
        reason: reason,
      );
      final ({String title, String body})? text = await SendNotification.templateText(template, values);
      if (text == null) {
        log("Push '$template' not sent: no dynamic_notification template for it.");
        return;
      }
      Map<String, String> data = PushMessage.stringData({
        'type': OwnerVerificationPush.driverDataType,
        'status': status,
        if ((documentId ?? '').isNotEmpty) 'documentId': documentId,
        if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
      }, type: template);
      try {
        final String id = FireStoreUtils.newCustomerNotificationId(driverId);
        final Map<String, String> withId = {...data, 'notificationId': id};
        await FireStoreUtils.setCustomerNotification(
          driverId,
          id,
          OwnerVerificationPush.record(id: id, title: text.title, body: text.body, template: template, data: withId, createdAt: FieldValue.serverTimestamp(), status: status),
        ).timeout(const Duration(seconds: 8));
        data = withId;
      } on TimeoutException {
        log("Notification record for '$template' still pending.");
      } catch (e) {
        log("Notification record for '$template' not written: $e");
      }
      await SendNotification.sendFcmMessage(template, applied.token, data, recipient: PushRecipient.driver, placeholders: values);
    } catch (e) {
      log("Push '$template' to the driver failed: $e");
    }
  }
}

class _Applied {
  final UserModel driver;
  final List<DocumentModel> required;
  final DocumentReviewPlan plan;
  final bool wasVerified;
  final String token;

  const _Applied({required this.driver, required this.required, required this.plan, required this.wasVerified, required this.token});

  _Applied.refused(OwnerVerificationOutcome outcome)
      : driver = UserModel(),
        required = const [],
        plan = DocumentReviewPlan(outcome),
        wasVerified = false,
        token = '';

  OwnerVerificationResult get result {
    final bool verified = plan.writes ? (plan.setVerified ?? wasVerified) : wasVerified;
    return OwnerVerificationResult(
      plan.outcome,
      verified: verified,
      completed: plan.writes && plan.setVerified == true,
      outstanding: plan.outstanding.map((d) => (d.title ?? '').trim()).where((t) => t.isNotEmpty).toList(),
    );
  }
}
