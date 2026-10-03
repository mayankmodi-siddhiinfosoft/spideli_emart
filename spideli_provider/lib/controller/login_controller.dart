import 'dart:developer';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/app_not_access_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/utils/login_validation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/notification_service.dart';
import '../ui/signUp/signup_screen.dart';
import 'package:spideliprovider/ui/documents/provider_documents_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  /// Messages shown under the email / password fields and, for a failed
  /// sign-in, above the Login button. Translation keys (null = no message);
  /// cleared as soon as the user edits a field.
  Rx<String?> emailError = Rx<String?>(null);
  Rx<String?> passwordError = Rx<String?>(null);
  Rx<String?> formError = Rx<String?>(null);

  /// The message under the "Forgot password" email field.
  Rx<String?> resetEmailError = Rx<String?>(null);

  /// A sign-in or reset request is running: a second tap is ignored.
  bool _busy = false;

  void onEmailChanged(String _) {
    emailError.value = null;
    formError.value = null;
    resetEmailError.value = null;
  }

  void onPasswordChanged(String _) {
    passwordError.value = null;
    formError.value = null;
  }

  /// Sign-in failed: the same friendly message as a toast and above the
  /// Login button (it stays there until the user edits a field).
  void _showLoginError(String message) {
    formError.value = message;
    ShowToastDialog.showToast(message.tr);
  }

  /// login with email and password with firebase
  /// @param email user email
  /// @param password user password
  Future<void> loginWithEmailAndPassword({required String email, required String password, required BuildContext context}) async {
    if (_busy) return;
    // Checked before any request: nothing is sent with an empty field or a
    // malformed email. Each problem is shown under its field, and the
    // summary ("Please enter your email and password." when both are
    // empty) as a toast.
    final String? invalid = LoginValidation.validate(email, password);
    final fields = LoginValidation.fieldErrors(email, password);
    emailError.value = fields.email;
    passwordError.value = fields.password;
    formError.value = null;
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }
    _busy = true;
    ShowToastDialog.showLoader('Logging in, please wait...'.tr);
    try {
      await _loginWithEmailAndPassword(email.trim(), password.trim());
    } catch (e, s) {
      // Never the exception's own text on screen.
      log('LoginController.loginWithEmailAndPassword $e $s');
      ShowToastDialog.closeLoader();
      _showLoginError(LoginValidation.genericError);
    } finally {
      _busy = false;
    }
  }

  Future<void> _loginWithEmailAndPassword(String email, String password) async {
    dynamic result = await FireStoreUtils.loginWithEmailAndPassword(email, password);
    ShowToastDialog.closeLoader();
    if (result != null && result is User && result.role == 'provider') {
      if (result.active == true) {
        result.active = true;
        // The password is not kept on the device: the FirebaseAuth session
        // keeps the user signed in.
        await FireStoreUtils.updateCurrentUser(result);
        MyAppState.currentUser = result;
        if (MyAppState.currentUser!.sectionId.isNotEmpty) {
          await FireStoreUtils.getSectionsById(MyAppState.currentUser!.sectionId).then(
            (value) {
              if (value != null) {
                selectedSectionModel = value;
              }
            },
          );
        }

        if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) &&
            MyAppState.currentUser?.sectionId.isNotEmpty == true &&
            MyAppState.currentUser?.subscriptionPlanId == null) {
          Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
        } else if ((MyAppState.currentUser?.sectionId == null || MyAppState.currentUser?.sectionId == '' || MyAppState.currentUser?.subscriptionPlanId == null) &&
            isSubscriptionModelApplied == false) {
          Get.offAll(const DashBoardScreen(), arguments: {'user': MyAppState.currentUser});
        } else if (result.subscriptionPlanId == null || isExpire(result) == true) {
          if ((selectedSectionModel != null && selectedSectionModel?.adminCommision?.enable == false) && isSubscriptionModelApplied == false) {
            Get.offAll(const DashBoardScreen(), arguments: {'user': result});
          } else {
            Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
          }
        } else if (result.subscriptionPlan?.features?.ownerMobileApp == true) {
          Get.offAll(const DashBoardScreen(), arguments: {'user': result});
        } else {
          Get.offAll(const AppNotAccessScreen());
        }
      } else {
        // Not active yet (pending verification) or disabled: the documents
        // stay reachable so a rejected document can be uploaded again.
        Get.dialog(
          AlertDialog(
            title: Text('Your account is not active yet'.tr),
            content: Text('It may still be under verification, or disabled by the administrator. You can check your documents and their status.'.tr),
            actions: [
              TextButton(
                onPressed: () async {
                  Get.back();
                  await FirebaseAuth.instance.signOut();
                },
                child: Text('OK'.tr),
              ),
              TextButton(
                onPressed: () => Get.offAll(() => const ProviderDocumentsScreen(pendingMode: true)),
                child: Text('My documents'.tr),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    } else if (result != null && result is String) {
      // Already a friendly message (LoginValidation.authErrorMessage): a
      // wrong email, a wrong password or both give "Invalid email or
      // password."
      _showLoginError(result);
    } else {
      // No provider profile for this account (or another role).
      _showLoginError(LoginValidation.genericError);
    }
  }

  /// "Forgot password": checks the email (empty, format) before sending
  /// anything, and shows a friendly message for every failure.
  Future<void> sendPasswordResetEmail() async {
    if (_busy) return;
    final String email = emailController.value.text.trim();
    final String? invalid = LoginValidation.validateEmail(email);
    resetEmailError.value = invalid;
    if (invalid != null) {
      ShowToastDialog.showToast(invalid.tr);
      return;
    }
    _busy = true;
    ShowToastDialog.showLoader('Sending Email...'.tr);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ShowToastDialog.closeLoader();
      _passwordResetSent();
    } on FirebaseAuthException catch (e, s) {
      log('LoginController.sendPasswordResetEmail ${e.code} $s');
      ShowToastDialog.closeLoader();
      final String? message = LoginValidation.passwordResetErrorMessage(e.code, e.message);
      if (message == null) {
        // No account for this email: the same answer as for one with an
        // account, so registered emails are not revealed.
        _passwordResetSent();
      } else {
        if (message == LoginValidation.emailInvalid) resetEmailError.value = message;
        ShowToastDialog.showToast(message.tr);
      }
    } catch (e, s) {
      log('LoginController.sendPasswordResetEmail $e $s');
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(LoginValidation.genericError.tr);
    } finally {
      _busy = false;
    }
  }

  void _passwordResetSent() {
    resetEmailError.value = null;
    if (Get.isDialogOpen == true) Get.back();
    ShowToastDialog.showToast('Please check your email.'.tr);
  }

  loginWithApple(BuildContext context) async {
    try {
      ShowToastDialog.showLoader('Logging in, Please wait...'.tr);
      dynamic result = await FireStoreUtils.signInWithApple();
      ShowToastDialog.closeLoader();

      if (result != null && result is Map<String, dynamic>) {
        // Extract Apple and Firebase credentials
        // ignore: unused_local_variable
        AuthorizationCredentialAppleID appleCredential = result['appleCredential'];
        UserCredential userCredential = result['userCredential'];

        // Check if user is new
        if (userCredential.additionalUserInfo!.isNewUser) {
          User userModel = User();
          userModel.id = userCredential.user!.uid;
          userModel.email = userCredential.user!.email ?? '';
          userModel.firstName = userCredential.user!.displayName?.split(' ').first ?? '';
          userModel.lastName = userCredential.user!.displayName?.split(' ').last ?? '';
          userModel.provider = 'apple';

          ShowToastDialog.closeLoader();
          Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "apple"});
        } else {
          // Existing user flow
          await FireStoreUtils.userExistOrNot(userCredential.user!.uid).then((userExist) async {
            ShowToastDialog.closeLoader();

            if (userExist == true) {
              User? userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);

              if (userModel?.role == USER_ROLE_PROVIDER) {
                if (userModel?.active == true) {
                  // Keeps the stored token when this device has none yet (iOS,
                  // before the APNs token): '' must not replace a working one.
                  userModel?.fcmToken = await NotificationService.freshTokenOr(userModel.fcmToken);
                  await FireStoreUtils.updateCurrentUser(userModel!);
                  MyAppState.currentUser = userModel;

                  if (MyAppState.currentUser!.sectionId.isNotEmpty) {
                    await FireStoreUtils.getSectionsById(MyAppState.currentUser!.sectionId).then(
                      (value) {
                        if (value != null) {
                          selectedSectionModel = value;
                        }
                      },
                    );
                  }

                  if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) &&
                      MyAppState.currentUser?.sectionId.isNotEmpty == true &&
                      MyAppState.currentUser?.subscriptionPlanId == null) {
                    Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
                  } else if ((MyAppState.currentUser?.sectionId == null || MyAppState.currentUser?.sectionId == '' || MyAppState.currentUser?.subscriptionPlanId == null) &&
                      isSubscriptionModelApplied == false) {
                    Get.offAll(const DashBoardScreen(), arguments: {'user': MyAppState.currentUser});
                  } else if (userModel.subscriptionPlanId == null || isExpire(userModel) == true) {
                    if ((selectedSectionModel != null && selectedSectionModel?.adminCommision?.enable == false) && isSubscriptionModelApplied == false) {
                      Get.offAll(const DashBoardScreen(), arguments: {'user': userModel});
                    } else {
                      Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
                    }
                  } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
                    Get.offAll(const DashBoardScreen(), arguments: {'user': userModel});
                  } else {
                    Get.offAll(const AppNotAccessScreen());
                  }
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
                }
              } else {
                await FirebaseAuth.instance.signOut();
                ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
              }
            } else {
              // If user does not exist
              User userModel = User();
              userModel.id = userCredential.user!.uid;
              userModel.email = userCredential.user!.email ?? '';
              userModel.firstName = userCredential.user!.displayName?.split(' ').first ?? '';
              userModel.lastName = userCredential.user!.displayName?.split(' ').last ?? '';
              userModel.provider = 'apple';

              Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "apple"});
            }
          });
        }
      } else if (result != null && result is String) {
        showAlertDialog(context, 'Error'.tr, result.tr, true);
      } else {
        showAlertDialog(context, 'Error'.tr, "Couldn't login with apple.".tr, true);
      }
    } catch (e, s) {
      ShowToastDialog.closeLoader();
      print('_LoginScreen.loginWithApple $e $s');
      showAlertDialog(context, 'Error'.tr, "Couldn't login with apple.".tr, true);
    }
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("please wait...".tr);
    await signInWithGoogle().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        if (value.additionalUserInfo!.isNewUser) {
          User userModel = User();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email ?? '';
          userModel.firstName = value.user!.displayName?.split(' ').first ?? '';
          userModel.lastName = value.user!.displayName?.split(' ').last ?? '';
          userModel.provider = 'google';

          ShowToastDialog.closeLoader();
          Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
        } else {
          await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              User? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
              if (userModel?.role == USER_ROLE_PROVIDER) {
                if (userModel?.active == true) {
                  // Keeps the stored token when this device has none yet (iOS,
                  // before the APNs token): '' must not replace a working one.
                  userModel?.fcmToken = await NotificationService.freshTokenOr(userModel.fcmToken);
                  await FireStoreUtils.updateCurrentUser(userModel!);
                  MyAppState.currentUser = userModel;
                  if (MyAppState.currentUser!.sectionId.isNotEmpty) {
                    await FireStoreUtils.getSectionsById(MyAppState.currentUser!.sectionId).then(
                      (value) {
                        if (value != null) {
                          selectedSectionModel = value;
                        }
                      },
                    );
                  }

                  if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) &&
                      MyAppState.currentUser?.sectionId.isNotEmpty == true &&
                      MyAppState.currentUser?.subscriptionPlanId == null) {
                    Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
                  } else if ((MyAppState.currentUser?.sectionId == null || MyAppState.currentUser?.sectionId == '' || MyAppState.currentUser?.subscriptionPlanId == null) &&
                      isSubscriptionModelApplied == false) {
                    Get.offAll(const DashBoardScreen(), arguments: {'user': MyAppState.currentUser});
                  } else if (userModel.subscriptionPlanId == null || isExpire(userModel) == true) {
                    if ((selectedSectionModel != null && selectedSectionModel?.adminCommision?.enable == false) && isSubscriptionModelApplied == false) {
                      Get.offAll(const DashBoardScreen(), arguments: {'user': userModel});
                    } else {
                      Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
                    }
                  } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
                    Get.offAll(const DashBoardScreen(), arguments: {'user': userModel});
                  } else {
                    Get.offAll(const AppNotAccessScreen());
                  }
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
                }
              } else {
                await FirebaseAuth.instance.signOut();
                // ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
              }
            } else {
              User userModel = User();
              userModel.id = value.user!.uid;
              userModel.email = value.user!.email ?? '';
              userModel.firstName = value.user!.displayName?.split(' ').first ?? '';
              userModel.lastName = value.user!.displayName?.split(' ').last ?? '';
              userModel.provider = 'google';

              Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
            }
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
}
