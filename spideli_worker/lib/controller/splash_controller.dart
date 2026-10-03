import 'dart:async';

import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/notification_service.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/ui/dashboard/dashboard_screen.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:spideliworker/ui/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:spideliworker/ui/on_boarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
  }

  Future<void> redirectScreen() async {
    if (await FireStoreUtils.isMaintenanceMode() == true) {
      Get.offAll(() => MaintenanceModeScreen());
      return;
    } else {
      if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
        Get.offAll(const OnBoardingScreen());
      } else {
        auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          User? user = await FireStoreUtils.getWorkerCurrentUser(firebaseUser.uid);

          if (user != null) {
            if (user.active == true) {
              user.active = true;
              // Not awaited: on iOS getting the token waits for the APNs token
              // (up to ~10 s) and must not hold the dashboard back. It shares
              // the launch's sync started in main.dart, and never throws.
              unawaited(NotificationService.syncTokenToUserDoc());
              MyAppState.currentUser = user;
              Get.offAll(const DashBoardScreen(), arguments: {'user': user});
              // A push tapped while the app was killed opens now, on top of
              // the dashboard (opening it earlier, it was replaced by it).
              NotificationService.openPendingTap();
            } else {
              // Only this device's token, and only the fcmToken field.
              await NotificationService.clearTokenOnSignOut();
              await auth.FirebaseAuth.instance.signOut();
              MyAppState.currentUser = null;
              Get.offAll(const LoginScreen());
            }
          } else {
            Get.offAll(const LoginScreen());
          }
        } else {
          Get.offAll(const LoginScreen());
        }
      }
    }
  }
}
