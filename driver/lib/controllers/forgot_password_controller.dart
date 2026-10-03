import 'dart:developer';

import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/utils/login_validation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPasswordController extends GetxController {
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;

  /// The message (translation key) under the email field; cleared as soon as
  /// the user edits it.
  final RxnString emailError = RxnString();

  /// A second tap while the request is running is ignored.
  bool _sending = false;

  void onEmailChanged(String _) => emailError.value = null;

  Future<void> forgotPassword() async {
    if (_sending) return;
    final String email = emailEditingController.value.text.trim();
    // Checked before any request: nothing is sent for an empty field (only
    // spaces counts as empty) or a malformed address.
    final String? invalid = LoginValidation.emailError(email);
    emailError.value = invalid;
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }
    _sending = true;
    ShowToastDialog.showLoader("Please wait".tr);
    String? error;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Only the code is used: Firebase's own text is never shown. The loader
      // used to stay up after any error here.
      log("Password reset failed: ${e.code}");
      error = LoginValidation.resetErrorMessage(e.code);
    } catch (e) {
      log("Password reset failed: $e");
      error = LoginValidation.genericError;
    } finally {
      ShowToastDialog.closeLoader();
      _sending = false;
    }
    // Toasts after the loader closes (EasyLoading shows one overlay at a time).
    if (error != null) {
      if (!isClosed && (error == LoginValidation.emailInvalid || error == LoginValidation.emailRequired || error == LoginValidation.noAccountForEmail)) {
        emailError.value = error;
      }
      ShowToastDialog.showToast(error.tr);
      return;
    }
    ShowToastDialog.showToast('${'Reset Password link sent your'.tr} $email ${'email'.tr}');
    Get.back();
  }
}
