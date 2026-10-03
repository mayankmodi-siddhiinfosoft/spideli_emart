import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/login_validation.dart';

class ForgotPasswordController extends GetxController {
  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;

  /// Inline message under the email field (translation key, null = none).
  final RxnString emailError = RxnString();
  final RxBool isLoading = false.obs;

  void onEmailChanged(String _) {
    if (emailError.value != null) emailError.value = null;
  }

  Future<void> forgotPassword() async {
    if (isLoading.value) return;
    final email = emailEditingController.value.text.trim();

    // Checked before any request: nothing is sent for an empty or malformed
    // address. Shown under the field and as a toast.
    final String? invalid = LoginValidation.validateEmail(email);
    emailError.value = invalid;
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }

    String? message;
    bool sent = false;
    try {
      isLoading.value = true;
      ShowToastDialog.showLoader("Please wait...".tr);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      sent = true;
    } on FirebaseException catch (e) {
      // Firebase's own text (e.message) is never shown.
      debugPrint("Password reset failed: ${e.plugin}/${e.code}");
      message = LoginValidation.passwordResetErrorMessage(e.code);
    } catch (e) {
      debugPrint("Password reset failed: ${e.runtimeType}");
      message = LoginValidation.genericError;
    } finally {
      isLoading.value = false;
      ShowToastDialog.closeLoader();
    }
    // Toasts after the loader closes (EasyLoading has a single overlay).
    if (sent) {
      ShowToastDialog.showToast(
        'reset_password_link_sent'.trParams({'email': email}),
      );
      Get.back();
    } else if (message != null) {
      ShowToastDialog.showToast(message.tr);
    }
  }
}
