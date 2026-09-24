import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/app/auth_screen/widgets/auth_shell.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/phone_number_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../constant/constant.dart';

/// Archetype H – phone sign-in: one field, one action.
class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: PhoneNumberController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return DsScaffold(
            appBar: const DsAppBar(),
            body: AuthShell(
              icon: Icons.smartphone_rounded,
              title: "Log In Using Your Mobile Number".tr,
              subtitle: "Enter your mobile number to quickly access your account and start managing your deliveries.".tr,
              highlights: [
                "One-time code, no password to remember".tr,
                "Your number stays private".tr,
              ],
              link: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Didn’t Have an account?'.tr, style: t.bodyStrong),
                    const WidgetSpan(child: SizedBox(width: 6)),
                    TextSpan(
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Get.to(const SignupScreen());
                        },
                      text: 'Sign up'.tr,
                      style: t.link,
                    ),
                  ],
                ),
              ),
              children: [
                DsFormSection(
                  children: [
                    DsTextField(
                      label: 'Phone Number'.tr,
                      controller: controller.phoneNUmberEditingController.value,
                      hint: 'Enter Phone Number'.tr,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                      ],
                      bottomSpacing: 0,
                      prefix: CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                        },
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                        },
                        dialogTextStyle: t.bodyStrong,
                        dialogBackgroundColor: c.surfaceRaised,
                        initialSelection: controller.countryISOCodeEditingController.value.text,
                        comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                        textStyle: t.bodyStrong,
                        searchDecoration: InputDecoration(iconColor: c.textPrimary),
                        searchStyle: t.bodyStrong,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.xl),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Log in with'.tr, style: t.bodyStrong),
                        const WidgetSpan(child: SizedBox(width: 6)),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Get.offAll(const LoginScreen());
                            },
                          text: 'E-mail'.tr,
                          style: t.link,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Send Code".tr,
                icon: Icons.send_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () {
                  if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter mobile number".tr);
                  } else {
                    controller.sendCode();
                  }
                },
              ),
            ),
          );
        });
  }
}
