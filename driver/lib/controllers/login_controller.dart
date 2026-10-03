import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_sign_in.dart';
import 'package:driver/utils/login_validation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> loginWithEmailAndPassword() async {
    final String email = emailEditingController.value.text.toLowerCase().trim();
    final String password = passwordEditingController.value.text.trim();
    // Checked before any request: nothing is sent with an empty field or a
    // malformed email.
    final String? invalid = LoginValidation.validate(email, password);
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    String? message;
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final String? uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        message = "Something went wrong. Please try again.";
      } else {
        final AccountResult result = await DriverSignIn.open(uid);
        if (result.outcome == AccountOutcome.missing) {
          await DriverSignIn.signOutQuietly();
          message = "This user is not created in driver application.";
        } else {
          message = result.message;
        }
      }
    } on FirebaseAuthException catch (e) {
      log("Email login failed: ${e.code}");
      message = DriverSignIn.authErrorMessage(e);
    } catch (e) {
      // Anything else used to escape this method with the loader still up:
      // the "endless loading" drivers reported.
      log("Email login failed: $e");
      await DriverSignIn.signOutQuietly();
      message = "Something went wrong. Please try again.";
    } finally {
      ShowToastDialog.closeLoader();
    }
    // Shown after the loader closes: EasyLoading shows one overlay at a time,
    // so a toast shown before closeLoader() was dismissed with it.
    if (message != null) ShowToastDialog.showToast(message.tr);
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await signInWithGoogle().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        if (value.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email;
          userModel.firstName = value.user!.displayName?.split(' ').first;
          userModel.lastName = value.user!.displayName?.split(' ').last;
          userModel.provider = 'google';

          ShowToastDialog.closeLoader();
          Get.to(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
        } else {
          await _continueExistingAccount(value.user!.uid, () {
            UserModel userModel = UserModel();
            userModel.id = value.user!.uid;
            userModel.email = value.user!.email;
            userModel.firstName = value.user!.displayName?.split(' ').first;
            userModel.lastName = value.user!.displayName?.split(' ').last;
            userModel.provider = 'google';

            Get.to(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
          });
        }
      }
    });
  }

  Future<void> loginWithApple() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await signInWithApple().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        Map<String, dynamic> map = value;
        AuthorizationCredentialAppleID appleCredential = map['appleCredential'];
        UserCredential userCredential = map['userCredential'];
        if (userCredential.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = userCredential.user!.uid;
          userModel.email = appleCredential.email;
          userModel.firstName = appleCredential.givenName;
          userModel.lastName = appleCredential.familyName;
          userModel.provider = 'apple';

          ShowToastDialog.closeLoader();
          Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "apple"});
        } else {
          await _continueExistingAccount(userCredential.user!.uid, () {
            UserModel userModel = UserModel();
            userModel.id = userCredential.user!.uid;
            userModel.email = appleCredential.email;
            userModel.firstName = appleCredential.givenName;
            userModel.lastName = appleCredential.familyName;
            userModel.provider = 'apple';

            Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "apple"});
          });
        }
      }
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      if (googleUser.id.isEmpty) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Google / Apple sign-in for an account Firebase already knew: opens the
  /// driver's dashboard, or [toSignup] when there is no driver profile yet.
  /// Never leaves the loader up and never throws.
  Future<void> _continueExistingAccount(String uid, void Function() toSignup) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final AccountResult result;
    try {
      result = await DriverSignIn.open(uid);
    } finally {
      ShowToastDialog.closeLoader();
    }
    if (result.outcome == AccountOutcome.missing) {
      toSignup();
    } else if (result.message != null) {
      ShowToastDialog.showToast(result.message!.tr);
    }
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
        // webAuthenticationOptions: WebAuthenticationOptions(clientId: clientID, redirectUri: Uri.parse(redirectURL)),
      );

      // Create an `OAuthCredential` from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(idToken: appleCredential.identityToken, rawNonce: rawNonce, accessToken: appleCredential.authorizationCode);

      // Sign in the user with Firebase. If the nonce we generated earlier does
      // not match the nonce in `appleCredential.identityToken`, sign in will fail.
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {"appleCredential": appleCredential, "userCredential": userCredential};
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }
}
