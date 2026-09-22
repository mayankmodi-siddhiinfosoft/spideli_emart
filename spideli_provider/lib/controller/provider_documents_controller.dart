import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';

/// Company information + document verification of the provider (spec 3.6, 10).
///
/// Reuses the eMart document system the driver and store apps already use:
/// types from `documents` (`type == "provider"`, `enable == true`), uploads in
/// `documents_verify/{uid}.documents[]` with `status` "uploaded" (= pending
/// review), which the admin panel turns into "approved" / "rejected". The two
/// documents the spec requires are added when the panel has not configured
/// them, and mirrored on the user doc (`commercialRegister`,
/// `commercialRegisterFile`, `uniqueIdNumber`, `uniqueIdNumberFile`).
class ProviderDocumentsController extends GetxController {
  static const String documentsCollection = 'documents';
  static const String documentsVerifyCollection = 'documents_verify';
  static const String documentOwnerType = 'provider';

  RxBool isLoading = true.obs;
  Rx<User?> user = Rx<User?>(null);
  RxList<DocumentType> types = <DocumentType>[].obs;
  RxMap<String, UploadedDocument> uploads = <String, UploadedDocument>{}.obs;

  Rx<TextEditingController> companyName = TextEditingController().obs;
  RxString selectedRegionId = ''.obs;

  String get uid => FireStoreUtils.getCurrentUid();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      await RegionService.ensureLoaded();
      final User? current = await FireStoreUtils.getCurrentUser(uid);
      user.value = current;
      companyName.value.text = current?.companyName ?? '';
      selectedRegionId.value = current?.regionId ?? '';

      final List<DocumentType> list = [];
      try {
        final snap = await FireStoreUtils.firestore.collection(documentsCollection).where('type', isEqualTo: documentOwnerType).get();
        for (final doc in snap.docs) {
          final t = DocumentType.fromJson(doc.data(), docId: doc.id);
          if (t.enable && t.id.isNotEmpty) list.add(t);
        }
      } catch (e) {
        log("Provider document types not loaded: $e");
      }
      if (!list.any(DocumentType.coversCommercialRegister)) list.insert(0, DocumentType.commercialRegister());
      if (!list.any(DocumentType.coversUniqueIdNumber)) {
        list.insert(list.first.id == DocumentType.commercialRegisterId ? 1 : 0, DocumentType.uniqueIdNumber());
      }
      types.value = list;

      final verify = await FireStoreUtils.firestore.collection(documentsVerifyCollection).doc(uid).get();
      final Map<String, UploadedDocument> map = {};
      final raw = verify.data()?['documents'];
      if (raw is List) {
        for (final e in raw.whereType<Map>()) {
          final d = UploadedDocument.fromJson(Map<String, dynamic>.from(e));
          if (d.documentId.isNotEmpty) map[d.documentId] = d;
        }
      }
      // Built-in documents uploaded before (or by the panel) on the user doc only.
      _fillFromUser(map, DocumentType.commercialRegisterId, current?.commercialRegisterFile, current?.commercialRegister);
      _fillFromUser(map, DocumentType.uniqueIdNumberId, current?.uniqueIdNumberFile, current?.uniqueIdNumber);
      uploads.value = map;
    } catch (e, s) {
      log("Provider documents not loaded: $e", stackTrace: s);
    }
    isLoading.value = false;
    update();
  }

  void _fillFromUser(Map<String, UploadedDocument> map, String id, String? file, String? number) {
    if (map.containsKey(id) || (file ?? '').isEmpty) return;
    map[id] = UploadedDocument(documentId: id, frontImage: file, number: number, status: 'uploaded');
  }

  UploadedDocument? uploadFor(DocumentType type) => uploads[type.id];

  DocumentStatus statusFor(DocumentType type) => uploadFor(type)?.verificationStatus ?? DocumentStatus.notSubmitted;

  /// Overall state for the header: approved once the panel verified the
  /// account (`isDocumentVerify`) or every document is approved.
  DocumentStatus get overallStatus {
    if (user.value?.isDocumentVerify == true) return DocumentStatus.approved;
    final statuses = types.map(statusFor).toList();
    if (statuses.isEmpty) return DocumentStatus.notSubmitted;
    if (statuses.contains(DocumentStatus.rejected)) return DocumentStatus.rejected;
    if (statuses.contains(DocumentStatus.expired)) return DocumentStatus.expired;
    if (statuses.contains(DocumentStatus.notSubmitted)) return DocumentStatus.notSubmitted;
    if (statuses.every((s) => s == DocumentStatus.approved)) return DocumentStatus.approved;
    return DocumentStatus.pendingReview;
  }

  /// Region can be chosen here only when the account has none yet (older
  /// accounts); afterwards the admin panel owns it.
  bool get canPickRegion => RegionService.hasRegions && (user.value?.regionId ?? '').isEmpty;

  Future<bool> saveCompanyInfo() async {
    final Map<String, dynamic> data = {'companyName': companyName.value.text.trim()};
    if (canPickRegion && selectedRegionId.value.isNotEmpty) data['regionId'] = selectedRegionId.value;
    try {
      await FireStoreUtils.writeUserFields(uid, data);
      user.value?.companyName = data['companyName'];
      if (data['regionId'] != null) {
        user.value?.regionId = data['regionId'];
        if (MyAppState.currentUser?.id == uid) {
          MyAppState.currentUser?.regionId = data['regionId'];
          await RegionService.apply(MyAppState.currentUser);
        }
      }
      if (MyAppState.currentUser?.id == uid) MyAppState.currentUser?.companyName = data['companyName'];
      update();
      return true;
    } catch (e) {
      log("Company information not saved: $e");
      return false;
    }
  }

  Future<String> _uploadFile(File file, String documentId, String side) async {
    final Reference ref = FireStoreUtils.storage.child('$STORAGE_ROOT/provider/documents/$uid/${documentId}_${side}_${getUuid()}.jpg');
    final TaskSnapshot snapshot = await ref.putFile(file);
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads a (new or replacement) document and marks it pending review.
  Future<bool> submit({required DocumentType type, File? front, File? back, String? number, DateTime? expiry}) async {
    try {
      final UploadedDocument previous = uploadFor(type) ?? UploadedDocument(documentId: type.id);
      final UploadedDocument entry = UploadedDocument(
        documentId: type.id,
        frontImage: front != null ? await _uploadFile(front, type.id, 'front') : previous.frontImage,
        backImage: back != null ? await _uploadFile(back, type.id, 'back') : previous.backImage,
        status: 'uploaded',
        number: (number ?? '').trim().isEmpty ? previous.number : number!.trim(),
        expireAt: expiry != null ? Timestamp.fromDate(expiry) : (type.hasExpiry ? null : previous.expireAt),
        submittedAt: Timestamp.now(),
        extra: Map<String, dynamic>.from(previous.extra)..removeWhere((k, _) => UploadedDocument.reasonKeys.contains(k)),
      );

      final docRef = FireStoreUtils.firestore.collection(documentsVerifyCollection).doc(uid);
      await FireStoreUtils.firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final List<Map<String, dynamic>> list = [];
        final raw = snap.data()?['documents'];
        if (raw is List) {
          for (final e in raw.whereType<Map>()) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
        final index = list.indexWhere((e) => e['documentId']?.toString() == type.id);
        if (index >= 0) {
          list[index] = entry.toJson();
        } else {
          list.add(entry.toJson());
        }
        tx.set(docRef, {'id': uid, 'type': documentOwnerType, 'documents': list}, SetOptions(merge: true));
      });

      if (type.isBuiltIn) {
        await FireStoreUtils.writeUserFields(uid, {
          if (entry.number != null) type.userField!: entry.number,
          if ((entry.frontImage ?? '').isNotEmpty) '${type.userField!}File': entry.frontImage,
        });
      }
      uploads[type.id] = entry;
      update();
      return true;
    } catch (e, s) {
      log("Document upload failed: $e", stackTrace: s);
      return false;
    }
  }
}
