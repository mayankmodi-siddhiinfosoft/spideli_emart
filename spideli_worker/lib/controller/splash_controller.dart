import 'dart:async';

import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
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
              FireStoreUtils.firebaseMessaging.getToken().then((value) async {
                user.fcmToken = value!;
                await FireStoreUtils.firestore.collection(WORKERS).doc(user.id).update({"fcmToken": user.fcmToken});
              });
              MyAppState.currentUser = user;
              Get.offAll(const DashBoardScreen(), arguments: {'user': user});
            } else {
              await FireStoreUtils.firestore.collection(WORKERS).doc(user.id).update({"fcmToken": ""});
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
