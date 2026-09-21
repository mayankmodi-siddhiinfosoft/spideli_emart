import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/login/login_screen.dart';
import 'package:spideliprovider/ui/signUp/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Image.asset(
              'assets/images/app_logo.png',
              // color: Color(COLOR_PRIMARY),
              fit: BoxFit.cover,
              height: 140,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 8),
            child: Text(
              'Welcome to Provider App'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.colorWhite, fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          //   child: Text(
          //     'Accept orders and manage your store products.'.tr(),
          //     style: TextStyle(fontSize: 18),
          //     textAlign: TextAlign.center,
          //   ).tr(),
          // ),
          Padding(
            padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorWhite,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    side: BorderSide(
                      color: AppColors.colorWhite,
                    ),
                  ),
                ),
                child: Text(
                  'Log In'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorPrimary,
                  ),
                ),
                onPressed: () {
                  Get.to(const LoginScreen());
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 20, bottom: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    side: BorderSide(
                      color: AppColors.colorWhite,
                    ),
                  ),
                ),
                child: Text(
                  'Sign Up'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorWhite,
                  ),
                ),
                onPressed: () {
                  Get.to(SignupScreen());
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
