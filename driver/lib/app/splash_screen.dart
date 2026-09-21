import 'package:driver/controllers/splash_controller.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppThemeData.primary300,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/ic_logo.png",
                  height: 100,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  "Welcome to spideli Driver".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 24, fontFamily: AppThemeData.bold),
                ),
                Text(
                  "Your Favorite Ride, Parcel, Rental & Item Delivered Fast!".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
