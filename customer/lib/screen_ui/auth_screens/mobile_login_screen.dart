import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constant/assets.dart';
import '../../constant/constant.dart';
import '../../controllers/mobile_login_controller.dart';

class MobileLoginScreen extends StatelessWidget {
  const MobileLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<MobileLoginController>(
      init: MobileLoginController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isoCode = controller.countryISOCodeController.value.text;

        return AuthScaffold(
          eyebrow: "Mobile login",
          title: "Use your mobile number to Log in easily and securely.".tr,
          icon: Icons.smartphone_rounded,
          leading: DsBackButton(
            onPressed: () {
              Get.back();
            },
          ),
          actions: [AuthSkipButton(onPressed: () => Get.to(() => LocationPermissionScreen()))],
          footer: AuthFooterLink(
            text: "Didn't have an account? ".tr,
            linkText: "Sign up".tr,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Get.offAll(() => const SignUpScreen());
              },
          ),
          children: [
            DsCard(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
              child: DsTextField(
                label: "Mobile Number*".tr,
                hint: "Enter Mobile number".tr,
                controller: controller.mobileController.value,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
                prefix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountryCodePicker(
                      onInit: (value) {
                        controller.countryCodeController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                        controller.countryISOCodeController.value.text = value?.code ?? Constant.defaultCountryCode;
                      },
                      onChanged: (value) {
                        controller.countryCodeController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                        controller.countryISOCodeController.value.text = value.code ?? Constant.defaultCountryCode;
                      },
                      initialSelection: isoCode.isNotEmpty ? isoCode : Constant.defaultCountryCode,
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      textStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary, fontSize: 15),
                      dialogTextStyle: DsTypography.body.copyWith(color: c.textPrimary, fontSize: 16),
                      searchStyle: DsTypography.body.copyWith(color: c.textPrimary, fontSize: 16),
                      dialogBackgroundColor: c.surfaceRaised,
                      padding: EdgeInsets.zero,
                    ),
                    Container(height: 24, width: 1, color: c.border),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const DsGap(DsSpace.md),
            Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(child: Text("We will send you a one time verification code.".tr, style: t.caption)),
              ],
            ),
            const DsGap(DsSpace.xl),
            DsButton.primary(label: "Send Code".tr, size: DsButtonSize.lg, expand: true, icon: Icons.send_rounded, onPressed: controller.sendOtp),
            DsDivider(label: "or continue with".tr, spacing: DsSpace.xl),
            AuthAltButton(
              label: "Email address".tr,
              icon: Image.asset(AppAssets.icMessage, width: 20, height: 18, color: c.textPrimary),
              onPressed: () => Get.to(() => const SignUpScreen()),
            ),
          ],
        );
      },
    );
  }
}
