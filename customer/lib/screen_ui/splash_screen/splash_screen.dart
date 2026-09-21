import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/assets.dart';
import '../../controllers/splash_controller.dart';
import '../../themes/app_them_data.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppThemeData.primary350,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(AppAssets.icAppLogo, height: 120, width: 120),
                const SizedBox(height: 12),
                Text("spideli".tr, style: TextStyle(color: AppThemeData.grey50, fontSize: 24, fontFamily: AppThemeData.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
