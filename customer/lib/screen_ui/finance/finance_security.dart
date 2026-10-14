import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Re-authentication before sensitive finance actions (showing card
/// details, deleting a card, withdrawals, limits). The user confirms their
/// identity with the method they signed in with; the server then checks the
/// ID token's `auth_time` (.claude/FINANCE-APP-CONTRACT.md section 14.4).
abstract final class FinanceReauth {
  /// The window the server accepts; the app asks again a little earlier.
  static const Duration fresh = Duration(minutes: 4);

  /// True when the user signed in recently or confirmed their identity now.
  static Future<bool> confirm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final DateTime? authTime = (await user.getIdTokenResult()).authTime;
      if (authTime != null && DateTime.now().difference(authTime) < fresh) return true;
    } catch (_) {
      // Unknown: ask.
    }
    final providers = user.providerData.map((p) => p.providerId).toSet();
    try {
      final bool ok;
      if (providers.contains('password') && (user.email ?? '').isNotEmpty) {
        ok = await _password(user);
      } else if (providers.contains('phone') && (user.phoneNumber ?? '').isNotEmpty) {
        ok = await _phone(user);
      } else if (providers.contains('google.com')) {
        ok = await _google(user);
      } else if (providers.contains('apple.com')) {
        ok = await _apple(user);
      } else {
        ShowToastDialog.showToast("Sign in again to continue.".tr);
        return false;
      }
      if (ok) await user.getIdToken(true);
      return ok;
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(_message(e.code).tr);
      return false;
    } catch (_) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not confirm your identity.".tr);
      return false;
    }
  }

  static String _message(String code) => switch (code) {
        'wrong-password' || 'invalid-credential' => 'Incorrect password.',
        'invalid-verification-code' => 'Invalid code.',
        'user-mismatch' => 'Use the account you are signed in with.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        _ => 'Could not confirm your identity.',
      };

  static Future<void> _reauth(User user, AuthCredential credential) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await user.reauthenticateWithCredential(credential);
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  static Future<bool> _password(User user) async {
    final ctrl = TextEditingController();
    final String? password = await finSheet<String>(
      title: "Confirm it is you".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("For your security, enter your password.".tr, style: DsTypography.body),
          const DsGap(DsSpace.md),
          DsTextField(label: "Password".tr, controller: ctrl, obscurable: true, obscureText: true, autofocus: true),
          DsButton.primary(label: "Confirm".tr, expand: true, onPressed: () => Get.back(result: ctrl.text)),
        ],
      ),
    );
    if (password == null || password.isEmpty) return false;
    await _reauth(user, EmailAuthProvider.credential(email: user.email!, password: password));
    return true;
  }

  static Future<String?> _askCode(String phone) {
    final ctrl = TextEditingController();
    return finSheet<String>(
      title: "Confirm it is you".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("${"Enter the code sent by SMS to".tr} $phone", style: DsTypography.body),
          const DsGap(DsSpace.md),
          DsTextField(label: "Code".tr, controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
          DsButton.primary(label: "Confirm".tr, expand: true, onPressed: () => Get.back(result: ctrl.text.trim())),
        ],
      ),
    );
  }

  static Future<bool> _phone(User user) async {
    final done = Completer<bool>();
    bool asking = false;
    void finish(bool ok) {
      if (done.isCompleted) return;
      done.complete(ok);
    }

    ShowToastDialog.showLoader("Please wait...".tr);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: user.phoneNumber!,
      verificationCompleted: (credential) async {
        // Android read the SMS itself.
        try {
          await user.reauthenticateWithCredential(credential);
          if (asking) Get.back();
          finish(true);
        } catch (_) {
          // The user can still type the code.
        }
      },
      verificationFailed: (e) {
        ShowToastDialog.closeLoader();
        if (!done.isCompleted) done.completeError(e);
      },
      codeSent: (verificationId, _) async {
        ShowToastDialog.closeLoader();
        asking = true;
        final code = await _askCode(user.phoneNumber!);
        asking = false;
        if (done.isCompleted) return;
        if (code == null || code.isEmpty) return finish(false);
        try {
          await _reauth(user, PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
          finish(true);
        } catch (e) {
          if (!done.isCompleted) done.completeError(e);
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return done.future;
  }

  static Future<bool> _google(User user) async {
    final g = GoogleSignIn.instance;
    try {
      await g.initialize();
    } catch (_) {
      // Already initialised.
    }
    final account = await g.authenticate();
    await _reauth(user, GoogleAuthProvider.credential(idToken: account.authentication.idToken));
    return true;
  }

  static Future<bool> _apple(User user) async {
    final rawNonce = generateNonce();
    final apple = await SignInWithApple.getAppleIDCredential(scopes: const [], nonce: sha256.convert(utf8.encode(rawNonce)).toString());
    await _reauth(user, OAuthProvider('apple.com').credential(idToken: apple.identityToken, rawNonce: rawNonce, accessToken: apple.authorizationCode));
    return true;
  }
}

/// Hides sensitive data from screenshots, screen recording and the
/// recent-apps preview while it is on screen: Android FLAG_SECURE; on iOS a
/// plain cover in the app switcher (AppDelegate.swift).
abstract final class FinanceSecureScreen {
  static const MethodChannel _channel = MethodChannel('spideli/secure_screen');

  static Future<void> enable() => _invoke('enable');

  static Future<void> disable() => _invoke('disable');

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
    } on MissingPluginException {
      // Other platforms: nothing to set.
    } on PlatformException {
      // Best effort.
    }
  }
}
