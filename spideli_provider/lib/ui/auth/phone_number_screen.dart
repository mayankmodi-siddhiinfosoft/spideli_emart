import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/phone_number_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_layout.dart';
import 'package:spideliprovider/ui/signUp/signup_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX(
      init: PhoneNumberController(),
      builder: (controller) {
        return DsScaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(backgroundColor: c.background),
          maxContentWidth: null,
          body: AuthShell(
            children: [
              // Dialled-in header: a phone crest instead of the generic
              // logo, so this step is visibly "verify your number".
              const DsIconWell(icon: Icons.smartphone_rounded, tone: DsTone.brand, size: 56),
              const DsGap(DsSpace.xl),
              Text("Welcome Back! 👋".tr, style: t.display),
              const DsGap(DsSpace.xs),
              Text("Log in to continue enjoying delicious food delivered to your doorstep.".tr, style: t.bodyLg.withColor(c.textSecondary)),
              const DsGap(32),
              DsTextField(
                label: 'Phone Number'.tr,
                controller: controller.phoneNUmberEditingController.value,
                hint: 'Enter Phone Number'.tr,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                prefix: CountryCodePicker(
                  onInit: (value) {
                    controller.countryCodeEditingController.value.text = value?.dialCode ?? defaultCountryCode;
                  },
                  onChanged: (value) {
                    controller.countryCodeEditingController.value.text = value.dialCode.toString();
                  },
                  dialogTextStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                  dialogBackgroundColor: c.surfaceRaised,
                  initialSelection: controller.countryCodeEditingController.value.text,
                  comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                  textStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                  searchDecoration: InputDecoration(iconColor: c.textPrimary),
                  searchStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                ),
              ),
              const DsGap(DsSpace.xl),
              DsButton.primary(
                label: "Send OTP".tr,
                expand: true,
                size: DsButtonSize.lg,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () async {
                  if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter mobile number".tr);
                  } else {
                    controller.sendCode();
                  }
                },
              ),
              DsDivider(label: "or".tr, spacing: DsSpace.xxl),
              DsButton.secondary(
                label: "Continue with Email".tr,
                expand: true,
                icon: Icons.mail_outline_rounded,
                onPressed: () async {
                  Get.back();
                },
              ),
            ],
          ),
          bottomBar: DsStickyBar(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Platform.isAndroid ? 0 : 10),
              child: Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  children: [
                    TextSpan(text: 'Didn’t have an account?'.tr, style: t.bodyStrong),
                    const WidgetSpan(child: SizedBox(width: 10)),
                    TextSpan(
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Get.to(const SignupScreen());
                        },
                      text: 'Sign up'.tr,
                      style: t.label.withColor(c.brandStrong).copyWith(decoration: TextDecoration.underline, decorationColor: c.brandStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
