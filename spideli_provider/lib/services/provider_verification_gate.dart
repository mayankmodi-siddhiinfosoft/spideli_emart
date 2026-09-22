import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/ui/documents/provider_documents_screen.dart';

/// Spec 3.6: "Unverified actors cannot … receive jobs." An unverified provider cannot accept or start bookings.
///
/// Turned on by `settings/document_verification_settings.isProviderVerification` (same pattern as the
/// Driver/Store/Worker `isDriverVerification` / `isStoreVerification` / `isWorkerVerification` flags):
/// * `true`  → blocked until the admin sets `users.isDocumentVerify == true` (or `isAutoVerify == true`).
/// * `false` → never blocked (today's behaviour).
/// * absent  → blocked only when the admin configured provider documents (`documents` with
///   `type == "provider"`, `enable == true`) AND the user doc explicitly says `isDocumentVerify == false`.
/// Any read error → not blocked (never lock anyone out on a failure).
class ProviderVerificationGate {
  ProviderVerificationGate._();

  static Future<bool> isBlocked() async {
    try {
      final uid = FireStoreUtils.getCurrentUid();
      final settings = (await FireStoreUtils.firestore.collection(Setting).doc('document_verification_settings').get()).data();
      final flag = settings?['isProviderVerification'];
      if (flag == false) return false;

      final user = (await FireStoreUtils.firestore.collection(USERS).doc(uid).get()).data() ?? {};
      if (user['isDocumentVerify'] == true || user['isAutoVerify'] == true) return false;
      if (flag == true) return true;

      if (user['isDocumentVerify'] != false) return false;
      final types = await FireStoreUtils.firestore.collection('documents').where('type', isEqualTo: 'provider').where('enable', isEqualTo: true).limit(1).get();
      return types.docs.isNotEmpty;
    } catch (e) {
      log('ProviderVerificationGate: $e');
      return false;
    }
  }

  /// Returns true (and explains why, with a link to the Documents screen) when the action must not run.
  static Future<bool> blocks() async {
    if (!await isBlocked()) return false;
    await Get.dialog(
      AlertDialog(
        title: Text('Verification required'.tr),
        content: Text('Your documents have not been verified yet. You cannot accept or start bookings until the administrator approves them.'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Close'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => Scaffold(appBar: AppBar(title: Text('Documents'.tr)), body: const ProviderDocumentsScreen()));
            },
            child: Text('My documents'.tr),
          ),
        ],
      ),
    );
    return true;
  }
}
