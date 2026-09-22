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
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/ui/documents/provider_documents_screen.dart';
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

  // Items are identified by [DrawerItem.id], not by position, so adding one
  // (Documents, spec 10) can't shift the screens of the others.
  final drawerItems = [
    DrawerItem('Booking List'.tr, "assets/icons/ic_order.svg", id: 'bookings'),
    DrawerItem('All Service'.tr, "assets/icons/ic_log.svg", id: 'services'),
    DrawerItem('Worker'.tr, "assets/icons/ic_worker.svg", id: 'workers'),
    DrawerItem('Documents'.tr, "assets/icons/ic_check.svg", id: 'documents'),
    DrawerItem('Coupon'.tr, "assets/icons/ic_worker.svg", id: 'coupons'),
    DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg", id: 'wallet'),
    if (selectedSectionModel?.adminCommision?.enable == true || isSubscriptionModelApplied == true) DrawerItem('Subscription'.tr, "assets/icons/ic_subscription.svg", id: 'subscription'),
    DrawerItem('Subscription History'.tr, "assets/icons/ic_history.svg", id: 'subscriptionHistory'),
    DrawerItem('Withdraw Method'.tr, "assets/icons/ic_wallet.svg", id: 'withdrawMethod'),
    DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg", id: 'profile'),
    DrawerItem('My Inbox'.tr, "assets/icons/ic_chat.svg", id: 'inbox'),
    DrawerItem('Help & Support'.tr, "assets/icons/ic_help_support.svg", id: 'help'),
    DrawerItem('Terms and Condition'.tr, "assets/icons/terms_and_conditions.svg", id: 'terms'),
    DrawerItem('Privacy policy'.tr, "assets/icons/privacy_policy.svg", id: 'privacy'),
    DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg", id: 'logout'),
  ];

  getDrawerItemWidget(int pos) {
    final String id = (pos >= 0 && pos < drawerItems.length) ? drawerItems[pos].id : '';
    switch (id) {
      case 'bookings':
        return const BookingListScreen();
      case 'services':
        return const AllServiceScreen();
      case 'workers':
        return const AllWorkersScreen();
      case 'documents':
        return const ProviderDocumentsScreen();
      case 'coupons':
        return const CouponList();
      case 'wallet':
        return const WalletScreen();
      case 'subscription':
        return const SubscriptionPlanScreen(isDrawer: true);
      case 'subscriptionHistory':
        return const SubscriptionHistoryScreen();
      case 'withdrawMethod':
        return const BankDetailsScreen();
      case 'profile':
        return const ProfileScreen();
      case 'inbox':
        return const InboxScreen();
      case 'help':
        return HelpSupportScreen();
      case 'terms':
        return const TermsAndCondition();
      case 'privacy':
        return const PrivacyPolicy();
      default:
        return const Text("Error");
    }
  }

  RxInt selectedDrawerIndex = 0.obs;

  onSelectItem(int index) async {
    if (index >= 0 && index < drawerItems.length && drawerItems[index].id == 'logout') {
      _showLogoutDialog();
    } else {
      selectedDrawerIndex.value = index;
      Get.back();
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
            RegionService.clearProvider();

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
    // Provider's management zone -> live currency for services, wallet, plans.
    await RegionService.apply(MyAppState.currentUser);
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
  String id;

  DrawerItem(this.title, this.icon, {this.id = ''});
}
