import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/app_not_access_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/notification_service.dart';
import '../ui/signUp/signup_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  /// login with email and password with firebase
  /// @param email user email
  /// @param password user password
  loginWithEmailAndPassword({required String email, required String password, required BuildContext context}) async {
    ShowToastDialog.showLoader('Logging in, please wait...'.tr);
    dynamic result = await FireStoreUtils.loginWithEmailAndPassword(email.trim(), password.trim());
    ShowToastDialog.closeLoader();
    if (result != null && result is User && result.role == 'provider') {
      if (result.active == true) {
        result.active = true;
        Preferences.setString(Preferences.passwordKey, password);
        await FireStoreUtils.updateCurrentUser(result);
        print("result ans:" + result.fcmToken);
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
        showAlertDialog(context, 'Your account has been disabled, Please contact to admin.'.tr, "", true);
      }
    } else if (result != null && result is String) {
      showAlertDialog(context, "Couldn't Authenticate".tr, result, true);
    } else {
      showAlertDialog(context, "Couldn't Authenticate".tr, 'Login failed, Please try again.'.tr, true);
      print("result ans:" + result.toString());
    }
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
                  userModel?.fcmToken = await NotificationService.getToken();
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
                  userModel?.fcmToken = await NotificationService.getToken();
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
