import 'dart:async';
import 'dart:developer';

import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/notification_service.dart';
import 'package:spideliworker/ui/dashboard/dashboard_screen.dart';
import 'package:spideliworker/utils/login_validation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Signs in with [email] and [password]: the worker, null (no worker
/// document) or a message key, as [FireStoreUtils.loginWithEmailAndPassword].
typedef LoginSignIn = Future<dynamic> Function(String email, String password);

/// Sends the "Forgot password" email to [email].
typedef LoginSendResetEmail = Future<void> Function(String email);

class LoginController extends GetxController {
  /// [signIn] and [sendResetEmail] default to Firebase; tests pass fakes.
  LoginController({LoginSignIn? signIn, LoginSendResetEmail? sendResetEmail})
      : _signIn = signIn ?? FireStoreUtils.loginWithEmailAndPassword,
        _sendResetEmail = sendResetEmail ?? ((email) => auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email));

  final LoginSignIn _signIn;
  final LoginSendResetEmail _sendResetEmail;

  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  /// Inline messages (translation keys) under the email and password fields;
  /// null hides them. Editing a field clears its own message.
  final RxnString emailError = RxnString();
  final RxnString passwordError = RxnString();

  /// Why the last sign-in failed (a translation key), shown above the Log In
  /// button; cleared by editing either field or signing in again.
  final RxnString formError = RxnString();

  /// Inline message under the "Forgot password" email field.
  final RxnString resetEmailError = RxnString();

  /// A sign-in or reset request is in flight: further taps are ignored.
  bool _busy = false;

  void onEmailChanged(String _) {
    emailError.value = null;
    formError.value = null;
  }

  void onPasswordChanged(String _) {
    passwordError.value = null;
    formError.value = null;
  }

  /// The reset dialog edits the login email field too.
  void onResetEmailChanged(String value) {
    resetEmailError.value = null;
    onEmailChanged(value);
  }

  /// login with email and password with firebase
  /// @param email user email
  /// @param password user password
  Future<void> loginWithEmailAndPassword({required String email, required String password}) async {
    if (_busy) return;
    // Checked before any request: nothing is sent with an empty field or a
    // malformed email. Each field shows its own message under it; the toast
    // gives the form's ("Please enter your email and password." when both
    // are empty).
    formError.value = null;
    emailError.value = LoginValidation.emailError(email);
    passwordError.value = LoginValidation.passwordError(password);
    final String? invalid = LoginValidation.validate(email, password);
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }

    _busy = true;
    ShowToastDialog.showLoader('Logging in, please wait...'.tr);
    String failure = LoginValidation.genericError;
    try {
      final dynamic result = await _signIn(email.trim(), password.trim());
      if (result is User) {
        if (result.active == true) {
          await FireStoreUtils.updateCurrentUser(result);
          MyAppState.currentUser = result;
          // This device's FCM token on the worker's document (field-level).
          // Not awaited: on iOS it waits for the APNs token. Never throws.
          unawaited(NotificationService.syncTokenToUserDoc());
          Get.offAll(const DashBoardScreen(), arguments: {'user': result});
          return;
        }
        failure = LoginValidation.accountDisabled;
      } else if (result is String) {
        failure = result;
      } else {
        // No worker profile for this account: the generic message.
        failure = LoginValidation.genericError;
      }
    } catch (e, s) {
      log('Login failed: $e$s');
      failure = LoginValidation.genericError;
    } finally {
      // Closed on every path, success included.
      ShowToastDialog.closeLoader();
      _busy = false;
    }
    // A wrong email, a wrong password or both: the same message, never
    // Firebase's text.
    formError.value = failure;
    ShowToastDialog.showToast(failure.tr);
  }

  /// "Forgot password": the same email checks as login, then the reset email.
  /// True when it was sent and the dialog may close.
  Future<bool> sendPasswordResetEmail() async {
    if (_busy) return false;
    final String email = emailController.value.text.trim().toLowerCase();
    final String? invalid = LoginValidation.emailError(email);
    resetEmailError.value = invalid;
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return false;
    }

    _busy = true;
    ShowToastDialog.showLoader('Sending Email...'.tr);
    String? failure;
    try {
      await _sendResetEmail(email);
    } on auth.FirebaseAuthException catch (e, s) {
      log('Password reset failed: $e$s');
      failure = LoginValidation.passwordResetErrorMessage(e.code);
    } catch (e, s) {
      log('Password reset failed: $e$s');
      failure = LoginValidation.genericError;
    } finally {
      ShowToastDialog.closeLoader();
      _busy = false;
    }
    if (failure != null) {
      if (failure == LoginValidation.emailInvalid || failure == LoginValidation.emailRequired) {
        resetEmailError.value = failure;
      }
      ShowToastDialog.showToast(failure.tr);
      return false;
    }
    ShowToastDialog.showToast('Please check your email.'.tr);
    return true;
  }
}
