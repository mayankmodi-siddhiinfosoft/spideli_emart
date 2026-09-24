import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constant/constant.dart';
import '../../controllers/sign_up_controller.dart';
import 'package:get/get.dart';
import 'login_screen.dart';
import 'mobile_login_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<SignUpController>(
      init: SignUpController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final type = controller.type.value;
        final isSocial = type == "google" || type == "apple";
        final isMobile = type == "mobileNumber";
        final hidePasswords = isSocial || isMobile;
        final passwordHidden = controller.passwordVisible.value;
        final confirmHidden = controller.conformPasswordVisible.value;
        final isoCode = controller.countryISOCodeEditingController.value.text;

        final nameFields = [
          DsTextField(
            label: "First Name*".tr,
            hint: "Jerome".tr,
            controller: controller.firstNameEditingController.value,
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          DsTextField(
            label: "Last Name*".tr,
            hint: "Bell".tr,
            controller: controller.lastNameEditingController.value,
            prefixIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
        ];

        return AuthScaffold(
          eyebrow: "Create account",
          title: "Sign up to explore all our services and start shopping, riding, and more.".tr,
          icon: Icons.person_add_alt_1_rounded,
          actions: [AuthSkipButton(onPressed: () => Get.to(() => LocationPermissionScreen()))],
          footer: AuthFooterLink(
            text: "Already have an account?".tr,
            linkText: "Log in".tr,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Get.offAll(() => const LoginScreen());
              },
          ),
          children: [
            if (isSocial || isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.lg),
                child: DsInlineAlert(
                  tone: DsTone.info,
                  icon: isMobile ? Icons.smartphone_rounded : Icons.verified_user_outlined,
                  message: isMobile ? "Your mobile number is already verified.".tr : "Your account is verified, just complete your profile.".tr,
                ),
              ),
            DsFormSection(
              title: "Personal details".tr,
              icon: Icons.person_outline_rounded,
              children: [
                if (l.isTablet || l.isDesktop)
                  DsAdaptiveGrid(minItemWidth: 200, equalHeight: false, children: nameFields)
                else
                  ...nameFields,
                DsTextField(
                  label: "Email Address*".tr,
                  hint: "jerome014@gmail.com",
                  enabled: !isSocial,
                  controller: controller.emailEditingController.value,
                  focusNode: controller.emailFocusNode,
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                DsTextField(
                  label: "Mobile Number*".tr,
                  hint: "Enter Mobile number".tr,
                  enabled: !isMobile,
                  controller: controller.phoneNUmberEditingController.value,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
                  bottomSpacing: 0,
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                        },
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                        },
                        initialSelection: isoCode.isNotEmpty ? isoCode : Constant.defaultCountryCode,
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        enabled: !isMobile,
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
              ],
            ),
            hidePasswords
                ? const SizedBox()
                : DsFormSection(
                  title: "Security".tr,
                  icon: Icons.lock_outline_rounded,
                  children: [
                    AuthPasswordField(
                      label: "Password*".tr,
                      hint: "Enter password".tr,
                      controller: controller.passwordEditingController.value,
                      focusNode: controller.passwordFocusNode,
                      obscured: passwordHidden,
                      onToggle: () {
                        controller.passwordVisible.value = !controller.passwordVisible.value;
                      },
                    ),
                    AuthPasswordField(
                      label: "Confirm Password*".tr,
                      hint: "Enter confirm password".tr,
                      controller: controller.conformPasswordEditingController.value,
                      obscured: confirmHidden,
                      onToggle: () {
                        controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.xs),
                      child: Text("Use at least 6 characters.".tr, style: t.caption),
                    ),
                  ],
                ),
            DsFormSection(
              title: "Referral".tr,
              icon: Icons.card_giftcard_rounded,
              children: [
                DsTextField(
                  label: "Referral Code".tr,
                  hint: "Enter referral code".tr,
                  controller: controller.referralCodeEditingController.value,
                  prefixIcon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  bottomSpacing: 0,
                ),
              ],
            ),
            const DsGap(DsSpace.xl),
            DsButton.primary(
              label: "Sign up".tr,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () {
                if (controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber") {
                  if (controller.firstNameEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter first name".tr);
                  } else if (controller.lastNameEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter last name".tr);
                  } else if (controller.emailEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter valid email".tr);
                  } else if (controller.phoneNUmberEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter Phone number".tr);
                  } else {
                    controller.signUpWithEmailAndPassword();
                  }
                } else {
                  if (controller.firstNameEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter first name".tr);
                  } else if (controller.lastNameEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter last name".tr);
                  } else if (controller.emailEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter valid email".tr);
                  } else if (controller.phoneNUmberEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter Phone number".tr);
                  } else if (controller.passwordEditingController.value.text.trim().length < 6) {
                    ShowToastDialog.showToast("Please enter minimum 6 characters password".tr);
                  } else if (controller.passwordEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter password".tr);
                  } else if (controller.conformPasswordEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter Confirm password".tr);
                  } else if (controller.passwordEditingController.value.text.trim() != controller.conformPasswordEditingController.value.text.trim()) {
                    ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                  } else {
                    controller.signUpWithEmailAndPassword();
                  }
                }
              },
            ),
            DsDivider(label: "or continue with".tr, spacing: DsSpace.xl),
            AuthAltButton(
              label: "Mobile number".tr,
              icon: Icon(Icons.smartphone_rounded, size: 20, color: c.textPrimary),
              onPressed: () => Get.to(() => const MobileLoginScreen()),
            ),
          ],
        );
      },
    );
  }
}
