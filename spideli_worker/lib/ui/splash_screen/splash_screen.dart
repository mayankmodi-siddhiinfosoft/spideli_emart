import 'package:spideliworker/controller/splash_controller.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
        init: SplashController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.colorWhite,
            body: Center(
                child: Image.asset(
              "assets/images/app_logo.png",
              width: 200,
            )),
          );
        });
  }
}
