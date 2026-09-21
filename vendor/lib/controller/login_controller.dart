import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';
import 'package:flutter/material.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailEditingControllerOwner = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingControllerOwner = TextEditingController().obs;
  RxBool passwordVisibleOwner = true.obs;

  Rx<TextEditingController> emailEditingControllerEmployee = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingControllerEmployee = TextEditingController().obs;
  RxBool passwordVisible = true.obs;

  RxInt selectedTabbar = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  Future<void> onwerloginWithEmailAndPassword() async {
    ShowToastDialog.showLoader("Please wait.".tr);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailEditingControllerOwner.value.text.toLowerCase().trim(),
        password: passwordEditingControllerOwner.value.text.trim(),
      );
      UserModel? userModel = await FireStoreUtils.getUserProfile(credential.user!.uid);
      if (userModel != null) {
        if (userModel.role == Constant.userRoleVendor) {
          if (userModel.active == true) {
            userModel.fcmToken = await NotificationService.getToken();
            await FireStoreUtils.updateUser(userModel);
            bool isPlanExpire = false;
            if (userModel.subscriptionPlan?.id != null) {
              if (userModel.subscriptionExpiryDate == null) {
                if (userModel.subscriptionPlan?.expiryDay == '-1') {
                  isPlanExpire = false;
                } else {
                  isPlanExpire = true;
                }
              } else {
                DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
                isPlanExpire = expiryDate.isBefore(DateTime.now());
              }
            } else {
              isPlanExpire = true;
            }

            if (userModel.sectionId != null) {
              await FireStoreUtils.getSectionById(userModel.sectionId.toString()).then((value) {
                if (value != null) {
                  Constant.selectedSection = value;
                }
              });
            }

            if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
              if (userModel.sectionId!.isEmpty && Constant.isSubscriptionModelApplied == false) {
                Get.offAll(const DashBoardScreen());
              } else {
                Get.offAll(const SubscriptionPlanScreen());
              }
            } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
              Get.offAll(const DashBoardScreen());
            } else {
              Get.offAll(const AppNotAccessScreen());
            }
          } else {
            await FirebaseAuth.instance.signOut();
            ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
          }
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast("This user is not created in store application.".tr);
        }
      }
    } on FirebaseAuthException catch (e) {
      print(e.code);
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.".tr);
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided for that user.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid Email.".tr);
      }
    }
    ShowToastDialog.closeLoader();
  }

  Future<void> employeeloginWithEmailAndPassword() async {
    ShowToastDialog.showLoader("Please wait.".tr);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailEditingControllerEmployee.value.text.toLowerCase().trim(),
        password: passwordEditingControllerEmployee.value.text.trim(),
      );
      UserModel? userModel = await FireStoreUtils.getUserProfile(credential.user!.uid);
      if (userModel != null) {
        if (userModel.role == Constant.userRoleEmployee) {
          if (userModel.active == true) {
            userModel.fcmToken = await NotificationService.getToken();
            await FireStoreUtils.updateUser(userModel);
            VendorModel? vendor = await FireStoreUtils.getVendorById(userModel.vendorID!);
            bool isPlanExpire = false;
            if (vendor?.subscriptionPlan?.id != null) {
              if (vendor?.subscriptionExpiryDate == null) {
                if (vendor?.subscriptionPlan?.expiryDay == '-1') {
                  isPlanExpire = false;
                } else {
                  isPlanExpire = true;
                }
              } else {
                DateTime expiryDate = vendor!.subscriptionExpiryDate!.toDate();
                isPlanExpire = expiryDate.isBefore(DateTime.now());
              }
            } else {
              isPlanExpire = true;
            }
            if (vendor?.sectionId != null) {
              await FireStoreUtils.getSectionById(vendor!.sectionId.toString()).then((value) {
                if (value != null) {
                  Constant.selectedSection = value;
                }
              });
            }

            if (vendor?.subscriptionPlanId == null || isPlanExpire == true) {
              if (userModel.sectionId!.isEmpty && Constant.isSubscriptionModelApplied == false) {
                Get.offAll(const DashBoardScreen());
              }
            } else if (vendor?.subscriptionPlan?.features?.ownerMobileApp == true) {
              Get.offAll(const DashBoardScreen());
            } else {
              Get.offAll(const AppNotAccessScreen());
            }
          } else {
            await FirebaseAuth.instance.signOut();
            ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
          }
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast("This user is not created in restaurant application.".tr);
        }
      }
    } on FirebaseAuthException catch (e) {
      print(e.code);
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.".tr);
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided for that user.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid Email.".tr);
      }
    }
    ShowToastDialog.closeLoader();
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("please wait...".tr);
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
          Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
        } else {
          await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
              if (userModel!.role == Constant.userRoleVendor) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  bool isPlanExpire = false;
                  if (userModel.subscriptionPlan?.id != null) {
                    if (userModel.subscriptionExpiryDate == null) {
                      if (userModel.subscriptionPlan?.expiryDay == '-1') {
                        isPlanExpire = false;
                      } else {
                        isPlanExpire = true;
                      }
                    } else {
                      DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
                      isPlanExpire = expiryDate.isBefore(DateTime.now());
                    }
                  } else {
                    isPlanExpire = true;
                  }
                  if (userModel.sectionId != null) {
                    await FireStoreUtils.getSectionById(userModel.sectionId.toString()).then((value) {
                      if (value != null) {
                        Constant.selectedSection = value;
                      }
                    });
                  }

                  if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
                    if (userModel.sectionId!.isEmpty && Constant.isSubscriptionModelApplied == false) {
                      Get.offAll(const DashBoardScreen());
                    } else {
                      Get.offAll(const SubscriptionPlanScreen());
                    }
                  } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
                    Get.offAll(const DashBoardScreen());
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
              UserModel userModel = UserModel();
              userModel.id = value.user!.uid;
              userModel.email = value.user!.email;
              userModel.firstName = value.user!.displayName?.split(' ').first;
              userModel.lastName = value.user!.displayName?.split(' ').last;
              userModel.provider = 'google';

              Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "google"});
            }
          });
        }
      }
    });
  }

  Future<void> loginWithApple() async {
    ShowToastDialog.showLoader("please wait...".tr);
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
          await FireStoreUtils.userExistOrNot(userCredential.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);
              if (userModel!.role == Constant.userRoleVendor) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  bool isPlanExpire = false;
                  if (userModel.subscriptionPlan?.id != null) {
                    if (userModel.subscriptionExpiryDate == null) {
                      if (userModel.subscriptionPlan?.expiryDay == '-1') {
                        isPlanExpire = false;
                      } else {
                        isPlanExpire = true;
                      }
                    } else {
                      DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
                      isPlanExpire = expiryDate.isBefore(DateTime.now());
                    }
                  } else {
                    isPlanExpire = true;
                  }
                  if (userModel.sectionId != null) {
                    await FireStoreUtils.getSectionById(userModel.sectionId.toString()).then((value) {
                      if (value != null) {
                        Constant.selectedSection = value;
                      }
                    });
                  }

                  if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
                    if (userModel.sectionId!.isEmpty && Constant.isSubscriptionModelApplied == false) {
                      Get.offAll(const DashBoardScreen());
                    } else {
                      Get.offAll(const SubscriptionPlanScreen());
                    }
                  } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
                    Get.offAll(const DashBoardScreen());
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
              UserModel userModel = UserModel();
              userModel.id = userCredential.user!.uid;
              userModel.email = appleCredential.email;
              userModel.firstName = appleCredential.givenName;
              userModel.lastName = appleCredential.familyName;
              userModel.provider = 'apple';

              Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "apple"});
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

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
