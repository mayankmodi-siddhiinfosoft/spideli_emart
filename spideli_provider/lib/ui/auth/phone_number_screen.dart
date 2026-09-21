import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/phone_number_controller.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/round_button_fill.dart';
import 'package:spideliprovider/ui/signUp/signup_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/text_field_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
        init: PhoneNumberController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Back! 👋".tr,
                    style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                  ),
                  Text(
                    "Log in to continue enjoying delicious food delivered to your doorstep.".tr,
                    style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.regular),
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  TextFieldWidget(
                    title: 'Phone Number'.tr,
                    controller: controller.phoneNUmberEditingController.value,
                    hintText: 'Enter Phone Number'.tr,
                    textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    ],
                    prefix: CountryCodePicker(
                      onInit: (value) {
                        controller.countryCodeEditingController.value.text = value?.dialCode ?? defaultCountryCode;
                      },
                      onChanged: (value) {
                        controller.countryCodeEditingController.value.text = value.dialCode.toString();
                      },
                      dialogTextStyle: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontWeight: FontWeight.w500, fontFamily: AppThemeData.medium),
                      dialogBackgroundColor: themeChange.getTheme() ? AppThemeData.grey800 : AppThemeData.grey100,
                      initialSelection: controller.countryCodeEditingController.value.text,
                      comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                      textStyle: TextStyle(fontSize: 14, color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                      searchDecoration: InputDecoration(iconColor: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900),
                      searchStyle: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontWeight: FontWeight.w500, fontFamily: AppThemeData.medium),
                    ),
                  ),
                  const SizedBox(
                    height: 36,
                  ),
                  RoundedButtonFill(
                    title: "Send OTP".tr,
                    color: AppColors.colorPrimary,
                    textColor: AppThemeData.grey50,
                    onPress: () async {
                      if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter mobile number".tr);
                      } else {
                        controller.sendCode();
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          child: Text(
                            "or".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeChange.getTheme() ? AppThemeData.grey500 : AppThemeData.grey400,
                              fontSize: 16,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  RoundedButtonFill(
                    title: "Continue with Email".tr,
                    color: themeChange.getTheme() ? AppThemeData.grey700 : AppThemeData.grey200,
                    textColor: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                    onPress: () async {
                      Get.back();
                    },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.symmetric(vertical: Platform.isAndroid ? 10 : 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                            text: 'Didn’t have an account?'.tr,
                            style: TextStyle(
                              color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                            )),
                        const WidgetSpan(
                            child: SizedBox(
                          width: 10,
                        )),
                        TextSpan(
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Get.to(const SignupScreen());
                              },
                            text: 'Sign up'.tr,
                            style: TextStyle(
                                color: AppColors.colorPrimary,
                                fontFamily: AppThemeData.bold,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.colorPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
