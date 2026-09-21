import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';

class AppNotAccessScreen extends StatelessWidget {
  const AppNotAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                ),
                child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_payment_card.svg")),
              ),
              const SizedBox(height: 20),
              Text(
                "Access denied".tr,
                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.semiBold, fontSize: 20),
              ),
              const SizedBox(height: 20),
              Constant.showEmptyView(message: "Your current subscription plan doesn't include access to this app. Upgrade to get access now".tr, isDark: isDark),
              const SizedBox(height: 40),
              RoundedButtonFill(
                width: 60,
                title: "Upgrade Plan".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                onPress: () async {
                  Get.to(const SubscriptionPlanScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
