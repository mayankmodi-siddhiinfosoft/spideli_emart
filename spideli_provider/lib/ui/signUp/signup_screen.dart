import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/signup_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_layout.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constant/show_toast_dialog.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX(
      init: SignUpController(),
      builder: (controller) {
        // All observable reads happen here, in the tracked builder.
        final String type = controller.type.value;
        final bool social = type == "google" || type == "apple";
        final bool fromPhone = type == "mobileNumber";
        final bool hasPasswordStep = !(social || fromPhone);
        final bool passwordVisible = controller.passwordVisible.value;
        final bool confirmVisible = controller.conformPasswordVisible.value;
        final String selectedRegionId = controller.selectedRegionId.value;
        final List<DropdownMenuItem<String>> regionItems = controller.regions.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.displayName))).toList();

        return DsScaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(backgroundColor: c.background),
          maxContentWidth: null,
          body: AuthShell(
            cardOnWide: false,
            maxFormWidth: 560,
            children: [
              // Intro block: badge + headline, so the form reads as a
              // short guided flow rather than a wall of inputs.
              Row(
                children: [
                  const DsIconWell(icon: Icons.person_add_alt_1_outlined, tone: DsTone.brand, size: 48),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Create an Account".tr, style: t.headline),
                        const DsGap(DsSpace.xxs),
                        Text("Join spideli Provider App today and start managing your orders effortlessly.".tr, style: t.bodySm),
                      ],
                    ),
                  ),
                ],
              ),
              const DsGap(DsSpace.xl),
              DsFormSection(
                title: 'Your details'.tr,
                icon: Icons.badge_outlined,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DsTextField(
                          label: 'First Name'.tr,
                          controller: controller.firstNameEditingController.value,
                          hint: 'Enter First Name'.tr,
                          textCapitalization: TextCapitalization.words,
                          prefix: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset("assets/icons/ic_user.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DsTextField(
                          label: 'Last Name'.tr,
                          controller: controller.lastNameEditingController.value,
                          hint: 'Enter Last Name'.tr,
                          textCapitalization: TextCapitalization.words,
                          prefix: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset("assets/icons/ic_user.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  DsTextField(
                    label: 'Email Address'.tr,
                    keyboardType: TextInputType.emailAddress,
                    controller: controller.emailEditingController.value,
                    hint: 'Enter Email Address'.tr,
                    enabled: social ? false : true,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                    ),
                  ),
                  DsTextField(
                    label: 'Phone Number'.tr,
                    controller: controller.phoneNUmberEditingController.value,
                    hint: 'Enter Phone Number'.tr,
                    enabled: fromPhone ? false : true,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                    bottomSpacing: DsSpace.none,
                    prefix: CountryCodePicker(
                      onInit: (value) {
                        controller.countryCodeEditingController.value.text = value?.dialCode ?? defaultCountryCode;
                      },
                      enabled: fromPhone ? false : true,
                      onChanged: (value) {
                        controller.countryCodeEditingController.value.text = value.dialCode ?? defaultCountryCode;
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
                ],
              ),
              if (hasPasswordStep) ...[
                DsFormSection(
                  title: 'Security'.tr,
                  icon: Icons.lock_outline_rounded,
                  children: [
                    AuthPasswordField(
                      label: 'Password'.tr,
                      hint: 'Enter Password'.tr,
                      controller: controller.passwordEditingController.value,
                      obscure: passwordVisible,
                      onToggle: () {
                        controller.passwordVisible.value = !controller.passwordVisible.value;
                      },
                    ),
                    AuthPasswordField(
                      label: 'Confirm Password'.tr,
                      hint: 'Enter Confirm Password'.tr,
                      bottomSpacing: DsSpace.none,
                      controller: controller.conformPasswordEditingController.value,
                      obscure: confirmVisible,
                      onToggle: () {
                        controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                      },
                    ),
                  ],
                ),
              ],
              // Company information + management zone (spec 10: "Register (zone) > Company information").
              DsFormSection(
                title: 'Company information'.tr,
                icon: Icons.business_outlined,
                children: [
                  DsTextField(
                    label: 'Company Name'.tr,
                    controller: controller.companyNameEditingController.value,
                    hint: 'Enter Company Name (optional)'.tr,
                    bottomSpacing: regionItems.isEmpty ? DsSpace.none : DsSpace.lg,
                    prefixIcon: Icons.business_outlined,
                  ),
                  if (regionItems.isNotEmpty)
                    DsDropdown<String>(
                      label: 'Management Zone'.tr,
                      hint: 'Select the zone you operate in'.tr,
                      value: selectedRegionId.isEmpty ? null : selectedRegionId,
                      items: regionItems,
                      onChanged: (value) => controller.selectedRegionId.value = value ?? '',
                    ),
                ],
              ),
              const DsGap(DsSpace.xxl),
            ],
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Signup".tr,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                if (controller.regionRequired && controller.selectedRegionId.value.isEmpty) {
                  ShowToastDialog.showToast("Please select your management zone".tr);
                  return;
                }
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
                    controller.signUpWithEmailAndPassword(context);
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
                    controller.signUpWithEmailAndPassword(context);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
