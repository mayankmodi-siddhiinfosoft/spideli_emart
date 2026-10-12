import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class FleetVerificationStats {
  final int totalDrivers;
  final int verifiedCount;
  final int pendingCount;
  final int rejectedCount;
  final int notSubmittedCount;

  const FleetVerificationStats({
    this.totalDrivers = 0,
    this.verifiedCount = 0,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.notSubmittedCount = 0,
  });
}

class OwnerVerificationService {
  static final FirebaseFirestore _db = FireStoreUtils.fireStore;

  /// Loads required document types configured for drivers (strictly type == "driver",
  /// excluding company owner or vehicle documents).
  static Future<List<DocumentModel>> getRequiredDocuments() async {
    try {
      // 1. Query Firestore for documents matching type 'driver'
      final List<DocumentModel> typedDocs = await FireStoreUtils.getDocumentListForTypes(['driver']);
      if (typedDocs.isNotEmpty) {
        return typedDocs;
      }

      // 2. Fallback in case 'type' is not indexed in some Firestore projects
      final snap = await _db
          .collection(CollectionName.documents)
          .where('enable', isEqualTo: true)
          .get();
      final all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return DocumentModel.fromJson(data);
      }).toList();

      // Filter to only driver-type documents (exclude 'owner' or other non-driver types)
      final driverDocs = all.where((d) => d.type?.toLowerCase() == 'driver').toList();
      if (driverDocs.isNotEmpty) {
        return driverDocs;
      }

      // If no document has an explicit type string, exclude explicit 'owner' documents
      return all.where((d) => d.type?.toLowerCase() != 'owner').toList();
    } catch (e) {
      debugPrint('OwnerVerificationService.getRequiredDocuments error: $e');
      return [];
    }
  }

  /// Loads documents uploaded by a specific company driver.
  static Future<DriverDocumentModel?> getDriverDocuments(String driverId) async {
    if (driverId.isEmpty) return null;
    try {
      final snap = await _db.collection(CollectionName.documentsVerify).doc(driverId).get();
      if (snap.exists && snap.data() != null) {
        return DriverDocumentModel.fromJson(snap.data()!);
      }
    } catch (e) {
      debugPrint('OwnerVerificationService.getDriverDocuments error: $e');
    }
    return null;
  }

  /// Approves a specific document submitted by a company driver.
  /// If all required driver documents are now approved, marks `users/{driverId}.isDocumentVerify = true`.
  /// If not all required documents are approved, `users/{driverId}.isDocumentVerify` remains `false`.
  static Future<bool> approveDocument({
    required String driverId,
    required String documentId,
    required UserModel driver,
  }) async {
    try {
      final docRef = _db.collection(CollectionName.documentsVerify).doc(driverId);
      final snap = await docRef.get();
      DriverDocumentModel driverDocModel = snap.exists && snap.data() != null
          ? DriverDocumentModel.fromJson(snap.data()!)
          : DriverDocumentModel(documents: [], id: driverId);

      List<Documents> docs = driverDocModel.documents ?? [];
      final targetIndex = docs.indexWhere((d) => d.documentId == documentId);
      if (targetIndex >= 0) {
        docs[targetIndex].status = 'approved';
        docs[targetIndex].rejectReason = null;
      } else {
        docs.add(Documents(documentId: documentId, status: 'approved'));
      }
      driverDocModel.documents = docs;

      await docRef.set(driverDocModel.toJson(), SetOptions(merge: true));

      // Check if all required driver documents are now approved
      final requiredDocs = await getRequiredDocuments();
      bool allApproved = requiredDocs.isNotEmpty;
      for (final req in requiredDocs) {
        final match = docs.firstWhereOrNull((d) => d.documentId == req.id);
        if (match == null || match.verificationStatus != 'approved') {
          allApproved = false;
          break;
        }
      }

      // Update driver verification state: verified ONLY when ALL required documents are approved
      await _db.collection(CollectionName.users).doc(driverId).update({
        'isDocumentVerify': allApproved,
      });

      // Notify the driver
      final docTitle = requiredDocs.firstWhereOrNull((d) => d.id == documentId)?.title ?? 'Document';
      String token = (driver.fcmToken ?? '').trim();
      if (token.isEmpty) {
        final liveDriver = await FireStoreUtils.getUserProfile(driverId);
        token = (liveDriver?.fcmToken ?? '').trim();
      }

      final String notifTitle = allApproved ? 'All Documents Approved!'.tr : 'Document Approved'.tr;
      final String notifBody = allApproved
          ? 'All your documents have been approved by your Company Owner. You can now accept deliveries!'.tr
          : 'Your $docTitle has been approved by your Company Owner.'.tr;

      if (token.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: token,
          title: notifTitle,
          body: notifBody,
          payload: {
            'type': 'document_verification',
            'status': allApproved ? 'all_approved' : 'approved',
            'documentId': documentId,
            'title': notifTitle,
            'body': notifBody,
          },
          recipient: PushRecipient.driver,
        );
      }

      try {
        final nId = FireStoreUtils.newCustomerNotificationId(driverId);
        await FireStoreUtils.setCustomerNotification(driverId, nId, {
          'id': nId,
          'title': notifTitle,
          'body': notifBody,
          'type': 'document_verification',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('OwnerVerificationService.approveDocument error: $e');
      return false;
    }
  }

  /// Rejects a specific document submitted by a company driver with a mandatory reason.
  /// Also sets `users/{driverId}.isDocumentVerify = false` and sends a notification with the rejection reason.
  static Future<bool> rejectDocument({
    required String driverId,
    required String documentId,
    required String reason,
    required UserModel driver,
  }) async {
    try {
      final docRef = _db.collection(CollectionName.documentsVerify).doc(driverId);
      final snap = await docRef.get();
      DriverDocumentModel driverDocModel = snap.exists && snap.data() != null
          ? DriverDocumentModel.fromJson(snap.data()!)
          : DriverDocumentModel(documents: [], id: driverId);

      List<Documents> docs = driverDocModel.documents ?? [];
      final targetIndex = docs.indexWhere((d) => d.documentId == documentId);
      if (targetIndex >= 0) {
        docs[targetIndex].status = 'rejected';
        docs[targetIndex].rejectReason = reason.trim();
      } else {
        docs.add(Documents(documentId: documentId, status: 'rejected', rejectReason: reason.trim()));
      }
      driverDocModel.documents = docs;

      // Save to Firestore with rejectReason explicitly persisted
      await docRef.set(driverDocModel.toJson(), SetOptions(merge: true));

      // Revoke full account verification
      await _db.collection(CollectionName.users).doc(driverId).update({
        'isDocumentVerify': false,
      });

      // Get document title for informative notification
      final requiredDocs = await getRequiredDocuments();
      final docTitle = requiredDocs.firstWhereOrNull((d) => d.id == documentId)?.title ?? 'Document';

      String token = (driver.fcmToken ?? '').trim();
      if (token.isEmpty) {
        final liveDriver = await FireStoreUtils.getUserProfile(driverId);
        token = (liveDriver?.fcmToken ?? '').trim();
      }

      final String notifTitle = 'Document Rejected'.tr;
      final String notifBody = 'Your $docTitle was rejected by your Company Owner. Reason: $reason. Please re-upload.'.tr;

      if (token.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: token,
          title: notifTitle,
          body: notifBody,
          payload: {
            'type': 'document_verification',
            'status': 'rejected',
            'documentId': documentId,
            'reason': reason.trim(),
            'title': notifTitle,
            'body': notifBody,
          },
          recipient: PushRecipient.driver,
        );
      }

      try {
        final nId = FireStoreUtils.newCustomerNotificationId(driverId);
        await FireStoreUtils.setCustomerNotification(driverId, nId, {
          'id': nId,
          'title': notifTitle,
          'body': notifBody,
          'type': 'document_verification',
          'reason': reason.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('OwnerVerificationService.rejectDocument error: $e');
      return false;
    }
  }

  /// Approves all uploaded documents for a company driver and verifies their account.
  static Future<bool> approveAllDocuments({
    required String driverId,
    required List<DocumentModel> requiredDocs,
    required UserModel driver,
  }) async {
    try {
      final docRef = _db.collection(CollectionName.documentsVerify).doc(driverId);
      final snap = await docRef.get();
      DriverDocumentModel driverDocModel = snap.exists && snap.data() != null
          ? DriverDocumentModel.fromJson(snap.data()!)
          : DriverDocumentModel(documents: [], id: driverId);

      List<Documents> docs = driverDocModel.documents ?? [];
      for (final req in requiredDocs) {
        final idx = docs.indexWhere((d) => d.documentId == req.id);
        if (idx >= 0) {
          docs[idx].status = 'approved';
          docs[idx].rejectReason = null;
        } else {
          docs.add(Documents(documentId: req.id, status: 'approved'));
        }
      }
      driverDocModel.documents = docs;

      await docRef.set(driverDocModel.toJson(), SetOptions(merge: true));

      await _db.collection(CollectionName.users).doc(driverId).update({
        'isDocumentVerify': true,
      });

      String token = (driver.fcmToken ?? '').trim();
      if (token.isEmpty) {
        final liveDriver = await FireStoreUtils.getUserProfile(driverId);
        token = (liveDriver?.fcmToken ?? '').trim();
      }

      final String notifTitle = 'Account Verified!'.tr;
      final String notifBody = 'All your documents have been approved by your Company Owner. You can now accept deliveries!'.tr;

      if (token.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: token,
          title: notifTitle,
          body: notifBody,
          payload: {
            'type': 'document_verification',
            'status': 'all_approved',
            'title': notifTitle,
            'body': notifBody,
          },
          recipient: PushRecipient.driver,
        );
      }

      try {
        final nId = FireStoreUtils.newCustomerNotificationId(driverId);
        await FireStoreUtils.setCustomerNotification(driverId, nId, {
          'id': nId,
          'title': notifTitle,
          'body': notifBody,
          'type': 'document_verification',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('OwnerVerificationService.approveAllDocuments error: $e');
      return false;
    }
  }
}
