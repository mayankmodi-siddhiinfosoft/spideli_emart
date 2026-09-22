import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Business (verified) customer accounts - spec 8.2 "restriction of wholesale
/// prices to Business customers (verified accounts)".
///
/// The customer submits a request; the ADMIN PANEL verifies it by setting
/// `businessProfile.status` to "approved" or "rejected" (+ `rejectionReason`).
/// Only an approved profile unlocks `wholesaleBusinessOnly` prices.
class BusinessAccount {
  BusinessAccount._();

  static const String statusPending = "pending";
  static const String statusApproved = "approved";
  static const String statusRejected = "rejected";

  static Map<String, dynamic>? get profile => Constant.userModel?.businessProfile;

  /// null = never requested.
  static String? get status => profile?['status']?.toString();

  /// True only for an approved business profile.
  static bool get isApproved => status == statusApproved;

  /// Refreshes the session copy from Firestore (the admin may have decided).
  static Future<Map<String, dynamic>?> refresh() async {
    final doc = await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).get();
    final data = doc.data();
    final raw = data?['businessProfile'];
    final Map<String, dynamic>? p = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (Constant.userModel != null) {
      Constant.userModel!.businessProfile = p;
      Constant.userModel!.accountType = data?['accountType']?.toString();
    }
    return p;
  }

  /// Uploads the registration document image to Storage.
  static Future<String> uploadDocument(File file) async {
    final uid = FireStoreUtils.getCurrentUid();
    final ref = FirebaseStorage.instance.ref().child('business_documents/$uid/${const Uuid().v4()}.jpg');
    final snap = await ref.putFile(file);
    return snap.ref.getDownloadURL();
  }

  /// Submits (or re-submits) the request: `accountType: "business"` and a
  /// pending `businessProfile`. Field update only.
  static Future<void> submit({required String companyName, required String registrationNumber, required String documentUrl}) async {
    final Map<String, dynamic> p = {
      'companyName': companyName,
      'registrationNumber': registrationNumber,
      'documentUrl': documentUrl,
      'status': statusPending,
      'submittedAt': Timestamp.now(),
    };
    await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).update({'accountType': 'business', 'businessProfile': p});
    if (Constant.userModel != null) {
      Constant.userModel!.accountType = 'business';
      Constant.userModel!.businessProfile = p;
    }
  }
}
