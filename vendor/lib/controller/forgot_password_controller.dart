import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/utils/login_validation.dart';

class ForgotPasswordController extends GetxController {
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;

  /// Shown under the email field (a translation key, null = no error);
  /// cleared as the user edits.
  final RxnString emailError = RxnString();

  /// True while the reset request is running: a second tap is ignored.
  bool _sending = false;

  void emailEdited() => emailError.value = null;

  Future<void> forgotPassword() async {
    if (_sending) return;
    final String email = emailEditingController.value.text.trim();
    // Checked before any request: nothing is sent with an empty or
    // malformed email.
    final String? invalid = LoginValidation.validateEmail(email);
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
      // Firebase's own text is never shown; any other code used to leave the
      // loader up with no message.
      log("Password reset failed: ${e.code}");
      error = LoginValidation.resetErrorMessage(e.code);
    } catch (e) {
      log("Password reset failed: $e");
      error = LoginValidation.genericError;
    } finally {
      ShowToastDialog.closeLoader();
      _sending = false;
    }
    // Shown after the loader closes: EasyLoading has one overlay.
    if (error != null) {
      if (error == LoginValidation.noAccountForEmail || error == LoginValidation.emailInvalid) emailError.value = error;
      ShowToastDialog.showToast(error.tr);
      return;
    }
    ShowToastDialog.showToast(LoginValidation.resetLinkSent.trParams({'email': email}));
    Get.back();
  }
}
