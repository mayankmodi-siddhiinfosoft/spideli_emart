import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/splash_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset("assets/images/ic_logo.png", height: 140),
                  const SizedBox(height: 14),
                  Text(
                    "Welcome to spideli Store".tr,
                    textAlign: TextAlign.center,
                    style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 18),
                  ),
                  Text(
                    "Your spideli, Your Products, Delivered Fast!".tr,
                    textAlign: TextAlign.center,
                    style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
