import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared alert dialog. Signature and behaviour are unchanged (OK → back, or
/// `Get.offAll(LoginScreen)` when [login] is true); visuals use [DsDialog].
void showAlertDialog(String title, String content, bool addOkButton, {bool? login}) {
  DsDialog.show(
    DsDialog(
      title: title,
      message: content,
      icon: Icons.info_outline_rounded,
      primaryLabel: addOkButton ? 'OK'.tr : null,
      onPrimary: addOkButton
          ? () {
              if (login == true) {
                Get.offAll(const LoginScreen());
              } else {
                Get.back();
              }
            }
          : null,
    ),
  );
}
