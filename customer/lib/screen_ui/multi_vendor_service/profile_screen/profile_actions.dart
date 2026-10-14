import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_profile_controller.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/push_token_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

/// The account actions of the profile screens - the app's Profile tab and
/// Spideli Finance's Profile tab run the same code, so both behave alike.
abstract final class ProfileActions {
  /// Shares the store links of the app.
  static void shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text:
            '${'Check out spideli, the ultimate all-in-one multi-vendor eBusiness platform.'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
        subject: 'Look what I made!'.tr,
      ),
    );
  }

  /// Asks the store for the in-app rating sheet.
  static void rateApp() => InAppReview.instance.requestReview();

  /// Asks first, then signs out on this phone and opens the login screen.
  static void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDialogBox(
          title: "Log out".tr,
          descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
          positiveString: "Log out".tr,
          negativeString: "Cancel".tr,
          positiveClick: () async {
            // Clears users/{uid}.fcmToken only while it is still this
            // phone's token (field-level). A whole-user save with '' wiped
            // the token of a phone the customer had signed in on since.
            await PushTokenSync.clearOnSignOut();
            Constant.userModel = null;
            await FirebaseAuth.instance.signOut();
            Get.offAll(const LoginScreen());
          },
          negativeClick: () {
            Get.back();
          },
          img: Image.asset('assets/images/ic_logout.gif', height: 50, width: 50),
        );
      },
    );
  }

  /// Asks first (it cannot be undone), then deletes the account on the
  /// website's server and in Firebase.
  static void confirmDeleteAccount(BuildContext context, MyProfileController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDialogBox(
          title: "Delete Account".tr,
          descriptions: "Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data.".tr,
          positiveString: "Delete".tr,
          negativeString: "Cancel".tr,
          positiveClick: () async {
            ShowToastDialog.showLoader("Please wait...".tr);
            await controller.deleteUserFromServer();
            await FireStoreUtils.deleteUser().then((value) {
              ShowToastDialog.closeLoader();
              if (value == true) {
                ShowToastDialog.showToast("Account deleted successfully".tr);
                Get.offAll(const LoginScreen());
              } else {
                ShowToastDialog.showToast("Contact Administrator".tr);
              }
            });
          },
          negativeClick: () {
            Get.back();
          },
          img: Image.asset('assets/icons/delete_dialog.gif', height: 50, width: 50),
        );
      },
    );
  }
}
