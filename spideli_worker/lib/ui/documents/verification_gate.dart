import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/documents/documents_screen.dart';

/// The one check in front of every job action and of going online (spec
/// 3.6): waits for the live verification state when it is still loading (a
/// push tap can open a job before the dashboard has read it), and when the
/// worker may not work explains why with a link to the Documents screen.
/// A verified worker (or verification off) is never stopped.
class VerificationGate {
  VerificationGate._();

  /// True when the action may run. [message] says what is blocked.
  static Future<bool> allows({required String message}) async {
    final VerificationController controller = VerificationController.ensure();
    bool known = !controller.isLoading.value;
    if (!known) {
      ShowToastDialog.showLoader('Please wait...'.tr);
      try {
        known = await controller.whenLoaded();
      } finally {
        ShowToastDialog.closeLoader();
      }
    }
    if (known && controller.canReceiveJobs) return true;
    await DsDialog.show(DsDialog(
      title: 'Verification required'.tr,
      message: known ? message.tr : 'Could not check your documents. Check your connection and try again.'.tr,
      icon: Icons.badge_outlined,
      tone: DsTone.warning,
      primaryLabel: 'My documents'.tr,
      onPrimary: () {
        Get.back();
        Get.to(() => const DocumentsScreen(isBack: true));
      },
      secondaryLabel: 'Close'.tr,
      onSecondary: () => Get.back(),
    ));
    return false;
  }
}
