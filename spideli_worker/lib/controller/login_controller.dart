import 'dart:developer';

import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/helper.dart';
import 'package:spideliworker/ui/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  /// login with email and password with firebase
  /// @param email user email
  /// @param password user password
  Future<void> loginWithEmailAndPassword({required String email, required String password, required BuildContext context}) async {
    await showProgress(context, 'Logging in, please wait...'.tr, false);
    dynamic result = await FireStoreUtils.loginWithEmailAndPassword(email.trim(), password.trim());
    await hideProgress();
    if (result != null && result is User) {
      if (result.active == true) {
        await FireStoreUtils.updateCurrentUser(result);
        log("result ans:${result.fcmToken}");
        MyAppState.currentUser = result;
        Get.offAll(const DashBoardScreen(), arguments: {'user': result});
      } else {
        ShowToastDialog.showToast("Your account is deactivate.Please contact to administrator");
      }
    } else if (result != null && result is String) {
      showAlertDialog("Couldn't Authenticate".tr, result, true);
    } else {
      showAlertDialog("Couldn't Authenticate".tr, 'Login failed, Please try again.'.tr, true);
      log("result ans:$result");
    }
  }
}
