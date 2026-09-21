import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePasswordController extends GetxController {
  RxBool isLoading = false.obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;

  Future<void> forgotPassword() async {
    try {
      if (emailEditingController.value.text.trim().isEmpty) {
        ShowToastDialog.showToast("Please enter a valid email.".tr);
        return;
      }
      ShowToastDialog.showLoader("Please wait".tr);
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailEditingController.value.text.trim(),
      );
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast('${'Reset Password link sent your'.tr} ${emailEditingController.value.text} ${'email'.tr}');
      DashBoardController dashBoardController = Get.put(DashBoardController());
      dashBoardController.drawerIndex.value = 0;
      Get.offAll(DashBoardScreen());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast('No user found for that email.'.tr);
      } else {
        ShowToastDialog.showToast(e.message ?? 'An error occurred'.tr);
      }
      ShowToastDialog.closeLoader();
    }
  }
}
