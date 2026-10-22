import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/wholesale_entitlement.dart';
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

  static const String kindCompany = "company";
  static const String kindAssociation = "association";

  static Map<String, dynamic>? get profile => Constant.userModel?.businessProfile;

  /// null = never requested.
  static String? get status => profile?['status']?.toString();

  /// True only for an approved business profile.
  static bool get isApproved => status == statusApproved;

  /// Kind of business account: "company" | "association", defaults to "company".
  static String get kind => profile?['kind']?.toString() ?? kindCompany;

  static bool get isCompany => kind == kindCompany;
  static bool get isAssociation => kind == kindAssociation;

  /// Only an approved company can create a professional tontine.
  static bool get canCreateProfessionalTontine => isApproved && isCompany;

  /// Only an approved association can create an association tontine.
  static bool get canCreateAssociationTontine => isApproved && isAssociation;

  /// Documents attached to the business profile (e.g. statutes for associations).
  static List<Map<String, dynamic>> get documents =>
      profile?['documents'] is List ? (profile!['documents'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  /// Refreshes the session copy from Firestore (the admin may have decided).
  ///
  /// This is the moment the account's business status can change, so the
  /// session's wholesale entitlement (WEB spec §19) is recomputed from the very
  /// document just read - an approval or a refusal takes effect without signing
  /// out, and it costs no second read.
  static Future<Map<String, dynamic>?> refresh() async {
    final String uid = FireStoreUtils.getCurrentUid();
    final doc = await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).get();
    final data = doc.data();
    final raw = data?['businessProfile'];
    final Map<String, dynamic>? p = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (Constant.userModel != null) {
      Constant.userModel!.businessProfile = p;
      Constant.userModel!.accountType = data?['accountType']?.toString();
    }
    WholesaleEntitlement.applyDocument(uid, data);
    return p;
  }

  /// Uploads the registration document image to Storage.
  static Future<String> uploadDocument(File file, {String prefix = 'business_documents'}) async {
    final uid = FireStoreUtils.getCurrentUid();
    final ref = FirebaseStorage.instance.ref().child('$prefix/$uid/${const Uuid().v4()}.jpg');
    final snap = await ref.putFile(file);
    return snap.ref.getDownloadURL();
  }

  /// Submits (or re-submits) the request: `accountType: "business"` and a
  /// pending `businessProfile`. Field update only.
  static Future<void> submit({
    required String companyName,
    required String registrationNumber,
    required String documentUrl,
    String kind = kindCompany,
    List<Map<String, dynamic>>? documents,
  }) async {
    final Map<String, dynamic> p = {
      'companyName': companyName,
      'registrationNumber': registrationNumber,
      'documentUrl': documentUrl,
      'kind': kind,
      if (documents != null && documents.isNotEmpty) 'documents': documents,
      'status': statusPending,
      'submittedAt': Timestamp.now(),
    };
    await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).update({'accountType': 'business', 'businessProfile': p});
    if (Constant.userModel != null) {
      Constant.userModel!.accountType = 'business';
      Constant.userModel!.businessProfile = p;
    }
    // A pending request grants nothing (WEB spec §19), and the cached verdict
    // must not outlive the change either way.
    WholesaleEntitlement.invalidate();
  }
}
