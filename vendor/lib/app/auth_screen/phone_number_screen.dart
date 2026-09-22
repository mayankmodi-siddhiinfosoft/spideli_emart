import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/auth_screen/widgets/auth_layout.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/phone_number_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

import '../../constant/constant.dart';

class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: PhoneNumberController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return AuthLayout(
          heroIcon: Icons.phone_iphone_rounded,
          title: "Welcome Back! 👋".tr,
          subtitle: "Log in to continue enjoying delicious food delivered to your doorstep.".tr,
          footer: AuthFooterPrompt(
            question: 'Didn’t have an account?'.tr,
            action: 'Sign up'.tr,
            onTap: () {
              Get.to(const SignupScreen());
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Phone Number'.tr,
                controller: controller.phoneNUmberEditingController.value,
                hint: 'Enter Phone Number'.tr,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                autofillHints: const [AutofillHints.telephoneNumberNational],
                prefix: CountryCodePicker(
                  onInit: (value) {
                    controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                    controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                  },
                  onChanged: (value) {
                    controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                    controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                  },
                  dialogTextStyle: t.bodyStrong.withColor(c.textPrimary),
                  dialogBackgroundColor: c.surfaceRaised,
                  initialSelection: controller.countryISOCodeEditingController.value.text,
                  comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                  textStyle: t.bodyStrong.withColor(c.textPrimary),
                  searchDecoration: InputDecoration(iconColor: c.textPrimary),
                  searchStyle: t.bodyStrong.withColor(c.textPrimary),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.sms_outlined, size: 18, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text('We will text you a one-time code to verify this number.'.tr, style: t.bodySm.withColor(c.textMuted))),
                ],
              ),
              const DsGap(DsSpace.xxl),
              DsButton.primary(
                label: "Send OTP".tr,
                size: DsButtonSize.lg,
                expand: true,
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
        );
      },
    );
  }
}
