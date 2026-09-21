import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showAlertDialog(String title, String content, bool addOkButton, {bool? login}) {
  Widget? okButton;
  if (addOkButton) {
    okButton = TextButton(
      child:  Text('OK'.tr),
      onPressed: () {
        if (login == true) {
          Get.offAll(const LoginScreen());
        } else {
          Get.back();
        }
      },
    );
  }
  Get.defaultDialog(title: title, content: Text(content), actions: [if (okButton != null) okButton], radius: 10.0);
}
