import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/ui/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:spideliprovider/ui/on_boarding_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/app_not_access_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
  }

  redirectScreen() async {
    if (await FireStoreUtils.isMaintenanceMode() == true) {
      Get.offAll(() => MaintenanceModeScreen());
      return;
    } else {
      if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
        Get.offAll(const OnBoardingScreen());
      } else {
        auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);

          if (user != null && user.role == USER_ROLE_PROVIDER) {
            if (user.active == true) {
              user.active = true;
              user.role = USER_ROLE_PROVIDER;
              FireStoreUtils.firebaseMessaging.getToken().then((value) async {
                user.fcmToken = value!;
                await FireStoreUtils.firestore.collection(USERS).doc(user.id).update({"fcmToken": user.fcmToken});
              });
              MyAppState.currentUser = user;
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
              } else if (user.subscriptionPlanId == null || isExpire(user) == true) {
                if ((selectedSectionModel?.adminCommision?.enable == false || selectedSectionModel?.id == null) && isSubscriptionModelApplied == false) {
                  Get.offAll(const DashBoardScreen(), arguments: {'user': user});
                } else {
                  Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": MyAppState.currentUser?.sectionId.isEmpty == true ? false : true});
                }
              } else if (user.subscriptionPlan?.features?.ownerMobileApp == true && isExpire(user) == false) {
                Get.offAll(const DashBoardScreen(), arguments: {'user': user});
              } else {
                Get.offAll(const AppNotAccessScreen());
              }
            } else {
              user.lastOnlineTimestamp = Timestamp.now();
              await FireStoreUtils.firestore.collection(USERS).doc(user.id).update({"fcmToken": ""});

              MyAppState.currentUser = null;
              Get.offAll(AuthScreen());
            }
          } else {
            Get.offAll(AuthScreen());
          }
        } else {
          Get.offAll(AuthScreen());
        }
      }
    }
  }
}
