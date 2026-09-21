import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/forgot_password_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ForgotPasswordController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Forgot Password".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                ),
                Text(
                  "No worries!! We’ll send you reset instructions".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.regular),
                ),
                const SizedBox(height: 32),
                TextFieldWidget(
                  title: 'Email Address'.tr,
                  controller: controller.emailEditingController.value,
                  hintText: 'Enter email address'.tr,
                  prefix: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(height: 32),
                RoundedButtonFill(
                  title: "Forgot Password".tr,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
                    if (controller.emailEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter valid email".tr);
                    } else {
                      controller.forgotPassword();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
