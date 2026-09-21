import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/app_not_access_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/constants.dart';
import '../services/notification_service.dart';
import '../services/preferences.dart';

class SignUpController extends GetxController {
  File? image;
  dynamic auto_approve_provider = false;

  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;

  Rx<User> userModel = User().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    getData();
    super.onInit();
  }

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber.toString();
        countryCodeEditingController.value.text = userModel.value.countryCode.toString();
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email;
        firstNameEditingController.value.text = userModel.value.firstName;
        lastNameEditingController.value.text = userModel.value.lastName;
      }
    }
  }

  getData() async {
    await FireStoreUtils.firestore.collection(Setting).doc('provider').get().then((value) {
      auto_approve_provider = value.data()!['auto_approve_provider'];
      update();
    });
  }

  /// if the fields are validated and location is enabled we create a new user
  /// and navigate to [ContainerScreen] else we show error
  signUpWithEmailAndPassword(BuildContext context) async {
    if (type.value == "google" || type.value == "apple" || type.value == "mobileNumber") {
      userModel.value.firstName = firstNameEditingController.value.text.toString();
      userModel.value.lastName = lastNameEditingController.value.text.toString();
      userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
      userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
      userModel.value.role = USER_ROLE_PROVIDER;
      userModel.value.fcmToken = await NotificationService.getToken();
      userModel.value.active = auto_approve_provider == true ? true : false;
      userModel.value.countryCode = countryCodeEditingController.value.text;
      userModel.value.createdAt = Timestamp.now();
      userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';

      await FireStoreUtils.updateCurrentUser(userModel.value).then((value) async {
        if (auto_approve_provider == true) {
          if (value?.active == true) {
            value?.active = true;
            Preferences.setString(Preferences.passwordKey, passwordEditingController.value.text.toString());
            await FireStoreUtils.updateCurrentUser(value!);
            MyAppState.currentUser = value;
            if (MyAppState.currentUser!.sectionId.isNotEmpty) {
              await FireStoreUtils.getSectionsById(MyAppState.currentUser!.sectionId).then(
                (value) {
                  if (value != null) {
                    selectedSectionModel = value;
                  }
                },
              );
            }
            if (MyAppState.currentUser?.subscriptionPlanId == null && isSubscriptionModelApplied == false) {
              Get.offAll(const DashBoardScreen(), arguments: {'user': MyAppState.currentUser});
            } else if (value.subscriptionPlanId == null || isExpire(value) == true) {
              if (isSubscriptionModelApplied == false) {
                Get.offAll(const DashBoardScreen(), arguments: {'user': value});
              } else {
                Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false});
              }
            } else if (value.subscriptionPlan?.features?.ownerMobileApp == true) {
              Get.offAll(const DashBoardScreen(), arguments: {'user': value});
            } else {
              Get.offAll(const AppNotAccessScreen());
            }
          } else {
            showAlertDialog(context, 'Signup Successfull'.tr, "Thank you for sign up, your application is under approval so please wait till that approve.".tr, true, login: true);
          }
        } else {
          showAlertDialog(context, 'Signup Successfull'.tr, "Thank you for sign up, your application is under approval so please wait till that approve.".tr, true, login: true);
        }
      });
    } else {
      ShowToastDialog.showLoader('Creating new account, Please wait...'.tr);
      dynamic result = await FireStoreUtils.firebaseSignUpWithEmailAndPassword(emailEditingController.value.text.toString().trim(), passwordEditingController.value.text.toString().trim(), image,
          firstNameEditingController.value.text.toString(), lastNameEditingController.value.text.toString(), phoneNUmberEditingController.value.text.toString(), auto_approve_provider);
      ShowToastDialog.closeLoader();
      if (result != null && result is User) {
        if (auto_approve_provider == true) {
          if (result.active == true) {
            result.active = true;
            Preferences.setString(Preferences.passwordKey, passwordEditingController.value.text.toString());
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
            if (MyAppState.currentUser?.subscriptionPlanId == null && isSubscriptionModelApplied == false) {
              Get.offAll(const DashBoardScreen(), arguments: {'user': MyAppState.currentUser});
            } else if (result.subscriptionPlanId == null || isExpire(result) == true) {
              if ((selectedSectionModel != null && selectedSectionModel!.adminCommision!.enable == false) && isSubscriptionModelApplied == false) {
                Get.offAll(const DashBoardScreen(), arguments: {'user': result});
              } else {
                Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false});
              }
            } else if (result.subscriptionPlan?.features?.ownerMobileApp == true) {
              Get.offAll(const DashBoardScreen(), arguments: {'user': result});
            } else {
              Get.offAll(const AppNotAccessScreen());
            }
          } else {
            showAlertDialog(context, 'Signup Successfull'.tr, "Thank you for sign up, your application is under approval so please wait till that approve.".tr, true, login: true);
          }
        } else {
          showAlertDialog(context, 'Signup Successfull'.tr, "Thank you for sign up, your application is under approval so please wait till that approve.".tr, true, login: true);
        }
      } else if (result != null && result is String) {
        showAlertDialog(context, 'Failed'.tr, result, true);
      } else {
        showAlertDialog(context, 'Failed'.tr, "Couldn't sign up".tr, true);
      }
    }
  }

  /// dispose text controllers to avoid memory leaks
  @override
  void dispose() {
    passwordEditingController.value.dispose();
    image = null;
    super.dispose();
  }
}
