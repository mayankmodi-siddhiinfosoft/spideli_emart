import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/ui/add_service/all_services_screen.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/ui/bank_details/bank_details_Screen.dart';
import 'package:spideliprovider/ui/booking_list/booking_list_screen.dart';
import 'package:spideliprovider/ui/chat_screen/inbox_screen.dart';
import 'package:spideliprovider/ui/coupon/coupon_list.dart';
import 'package:spideliprovider/ui/help_support_screen/help_support_screen.dart';
import 'package:spideliprovider/ui/privacyPolicy/privacy_policy.dart';
import 'package:spideliprovider/ui/profile/profile_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_history_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/ui/termsAndCondition/terms_and_codition.dart';
import 'package:spideliprovider/ui/wallet/wallet_screen.dart';
import 'package:spideliprovider/ui/worker/worker_list.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/show_toast_dialog.dart';
import '../themes/custom_dialog_box.dart';

class DashBoardController extends GetxController {
  RxBool isLoading = true.obs;

  final drawerItems = [
    DrawerItem('Booking List'.tr, "assets/icons/ic_order.svg"),
    DrawerItem('All Service'.tr, "assets/icons/ic_log.svg"),
    DrawerItem('Worker'.tr, "assets/icons/ic_worker.svg"),
    DrawerItem('Coupon'.tr, "assets/icons/ic_worker.svg"),
    DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
    if (selectedSectionModel?.adminCommision?.enable == true || isSubscriptionModelApplied == true) DrawerItem('Subscription'.tr, "assets/icons/ic_subscription.svg"),
    DrawerItem('Subscription History'.tr, "assets/icons/ic_history.svg"),
    DrawerItem('Withdraw Method'.tr, "assets/icons/ic_wallet.svg"),
    DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
    DrawerItem('My Inbox'.tr, "assets/icons/ic_chat.svg"),
    DrawerItem('Help & Support'.tr, "assets/icons/ic_help_support.svg"),
    DrawerItem('Terms and Condition'.tr, "assets/icons/terms_and_conditions.svg"),
    DrawerItem('Privacy policy'.tr, "assets/icons/privacy_policy.svg"),
    DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
  ];

  getDrawerItemWidget(int pos) {
    if (selectedSectionModel?.adminCommision?.enable == true || isSubscriptionModelApplied == true) {
      switch (pos) {
        case 0:
          return const BookingListScreen();
        case 1:
          return const AllServiceScreen();
        case 2:
          return const AllWorkersScreen();
        case 3:
          return const CouponList();
        case 4:
          return const WalletScreen();
        case 5:
          return const SubscriptionPlanScreen(isDrawer: true);
        case 6:
          return const SubscriptionHistoryScreen();
        case 7:
          return const BankDetailsScreen();
        case 8:
          return const ProfileScreen();
        case 9:
          return const InboxScreen();
        case 10:
          return HelpSupportScreen();
        case 11:
          return const PrivacyPolicy();
        case 12:
          return const PrivacyPolicy();
        default:
          return const Text("Error");
      }
    } else {
      switch (pos) {
        case 0:
          return const BookingListScreen();
        case 1:
          return const AllServiceScreen();
        case 2:
          return const AllWorkersScreen();
        case 3:
          return const CouponList();
        case 4:
          return const WalletScreen();
        case 5:
          return const SubscriptionHistoryScreen();
        case 6:
          return const BankDetailsScreen();
        case 7:
          return const ProfileScreen();
        case 8:
          return const InboxScreen();
        case 9:
          return HelpSupportScreen();
        case 10:
          return const TermsAndCondition();
        case 11:
          return const PrivacyPolicy();
        default:
          return const Text("Error");
      }
    }
  }

  RxInt selectedDrawerIndex = 0.obs;

  // onSelectItem(int index) async {
  //   if (selectedSectionModel?.adminCommision?.enable == true || isSubscriptionModelApplied == true) {
  //     if (index == 12) {
  //       MyAppState.currentUser = null;
  //       await auth.FirebaseAuth.instance.signOut();
  //       Preferences.clearSharPreference();
  //       Get.offAll(AuthScreen());
  //     } else {
  //       selectedDrawerIndex.value = index;
  //     }
  //     Get.back();
  //   } else {
  //     if (index == 11) {
  //       MyAppState.currentUser = null;
  //       await auth.FirebaseAuth.instance.signOut();
  //       Preferences.clearSharPreference();
  //       Get.offAll(AuthScreen());
  //     } else {
  //       selectedDrawerIndex.value = index;
  //     }
  //     Get.back();
  //   }
  // }

  onSelectItem(int index) async {
    if (selectedSectionModel?.adminCommision?.enable == true || isSubscriptionModelApplied == true) {
      if (index == 13) {
        _showLogoutDialog();
      } else {
        selectedDrawerIndex.value = index;
        Get.back();
      }
    } else {
      if (index == 12) {
        _showLogoutDialog();
      } else {
        selectedDrawerIndex.value = index;
        Get.back();
      }
    }
  }

  void _showLogoutDialog() {
    Get.back(); // close drawer first

    Get.dialog(
      CustomDialogBox(
        title: "Log out".tr,
        descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
        positiveString: "Log out".tr,
        negativeString: "Cancel".tr,
        positiveClick: () async {
          ShowToastDialog.showLoader("Logging out...".tr);

          try {
            MyAppState.currentUser?.fcmToken = "";
            if (MyAppState.currentUser != null) {
              await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
            }

            await auth.FirebaseAuth.instance.signOut();
            Preferences.clearSharPreference();

            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Logged out successfully!".tr);

            Get.offAll(() => AuthScreen());
          } catch (e) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Error while logging out: $e".tr);
          }
        },
        negativeClick: () {
          Get.back(); // close dialog
        },
        img: Image.asset(
          'assets/images/ic_logout.gif',
          height: 50,
          width: 50,
        ),
      ),
      barrierDismissible: false, // prevents closing by tapping outside
    );
  }

  Rx<User> user = User().obs;
  RxString userId = ''.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    getData();
    super.onInit();
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      if (argumentData['user'] != null) {
        user.value = argumentData['user'];
      }
      if (argumentData['userId'] != null) {
        userId.value = argumentData['userId'];
      }
    }
    update();
  }

  getData() async {
    await FireStoreUtils.getCurrentUser(MyAppState.currentUser == null ? userId.value : MyAppState.currentUser!.id).then((value) {
      MyAppState.currentUser = value;
      user.value = value!;
    });
    FireStoreUtils.getPlaceHolderImage();
    isLoading.value = false;
  }

  Rx<DateTime> currentBackPressTime = DateTime.now().obs;

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime.value) > const Duration(seconds: 2)) {
      currentBackPressTime.value = now;
      Get.showSnackbar(
        GetSnackBar(
          message: "Double press to exit".tr,
          snackPosition: SnackPosition.TOP,
        ),
      );
      return Future.value(false);
    }
    return Future.value(true);
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}
