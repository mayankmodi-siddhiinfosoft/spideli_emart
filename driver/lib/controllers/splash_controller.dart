import 'dart:async';
import 'dart:developer';

import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:driver/app/on_boarding_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/driver_sign_in.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
  }

  Future<void> redirectScreen() async {
    try {
      await _redirect();
    } finally {
      // A notification tap that opened the app is handled after this
      // navigation, or this navigation would replace the screen it opened.
      NotificationService.onAppRouted();
    }
  }

  Future<void> _redirect() async {
    bool maintenance = false;
    try {
      maintenance = await FireStoreUtils.isMaintenanceMode() == true;
    } catch (e) {
      // A failed check used to leave the splash screen up for ever.
      log("Maintenance check failed: $e");
    }
    if (maintenance) {
      Get.offAll(() => MaintenanceModeScreen());
      return;
    }
    if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
      Get.offAll(const OnboardingScreen());
      return;
    }
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      Get.offAll(const LoginScreen());
      return;
    }
    // The same path as every sign-in (token and topics included). It never
    // throws: a profile that is missing, not a driver's, not approved or
    // unreadable goes back to login. A profile that failed to parse used to
    // leave this screen up for ever.
    final AccountResult result = await DriverSignIn.open(uid);
    if (result.outcome == AccountOutcome.opened) return;
    if (result.outcome == AccountOutcome.missing) await DriverSignIn.signOutQuietly();
    Get.offAll(const LoginScreen());
    if (result.outcome == AccountOutcome.inactive && result.message != null) {
      ShowToastDialog.showToast(result.message!.tr);
    }
  }
}
