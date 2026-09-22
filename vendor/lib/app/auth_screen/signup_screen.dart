import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/widgets/auth_layout.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/signup_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

import '../../constant/constant.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SignupController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final plain = context.dsLayout.isWide;
        final isSocial = controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber";
        return AuthLayout(
          title: "Create an Account".tr,
          subtitle: "Join spideli Store today and start managing your orders effortlessly.".tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsFormSection(
                title: 'Personal details'.tr,
                plain: plain,
                icon: Icons.person_outline_rounded,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AuthField(
                          label: 'First Name'.tr,
                          controller: controller.firstNameEditingController.value,
                          hint: 'Enter First Name'.tr,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: AuthField(
                          label: 'Last Name'.tr,
                          controller: controller.lastNameEditingController.value,
                          hint: 'Enter Last Name'.tr,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  AuthField(
                    label: 'Email Address'.tr,
                    keyboardType: TextInputType.emailAddress,
                    controller: controller.emailEditingController.value,
                    hint: 'Enter Email Address'.tr,
                    enabled: controller.type.value == "google" || controller.type.value == "apple" ? false : true,
                    prefixIcon: Icons.mail_outline_rounded,
                  ),
                  AuthField(
                    label: 'Phone Number'.tr,
                    controller: controller.phoneNUmberEditingController.value,
                    hint: 'Enter Phone Number'.tr,
                    enabled: controller.type.value == "mobileNumber" ? false : true,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                    prefix: CountryCodePicker(
                      onInit: (value) {
                        controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                        controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                      },
                      enabled: controller.type.value == "mobileNumber" ? false : true,
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
                ],
              ),
              AnimatedSize(
                duration: DsMotion.of(context, DsMotion.base),
                curve: DsMotion.standard,
                alignment: Alignment.topCenter,
                child: isSocial
                    ? const SizedBox(width: double.infinity)
                    : DsFormSection(
                        title: 'Security'.tr,
                        plain: plain,
                        icon: Icons.shield_outlined,
                        children: [
                          AuthField(
                            label: 'Password'.tr,
                            controller: controller.passwordEditingController.value,
                            hint: 'Enter Password'.tr,
                            obscureText: controller.passwordVisible.value,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffix: AuthVisibilityToggle(
                              obscured: controller.passwordVisible.value,
                              onTap: () {
                                controller.passwordVisible.value = !controller.passwordVisible.value;
                              },
                            ),
                          ),
                          AuthField(
                            label: 'Confirm Password'.tr,
                            controller: controller.conformPasswordEditingController.value,
                            hint: 'Enter Confirm Password'.tr,
                            obscureText: controller.conformPasswordVisible.value,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffix: AuthVisibilityToggle(
                              obscured: controller.conformPasswordVisible.value,
                              onTap: () {
                                controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              const DsGap(DsSpace.sm),
              DsButton.primary(
                label: "Signup".tr,
                size: DsButtonSize.lg,
                expand: true,
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () async {
                  if (controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber") {
                    if (controller.firstNameEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter first name".tr);
                    } else if (controller.lastNameEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter last name".tr);
                    } else if (controller.emailEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter valid email".tr);
                    } else if (controller.phoneNUmberEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter phone number".tr);
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
                    } else if (controller.passwordEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter password".tr);
                    } else if (controller.conformPasswordEditingController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter confirm password".tr);
                    } else if (controller.passwordEditingController.value.text.trim() != controller.conformPasswordEditingController.value.text.trim()) {
                      ShowToastDialog.showToast("Password and confirm password doesn't match".tr);
                    } else {
                      controller.signUpWithEmailAndPassword();
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
