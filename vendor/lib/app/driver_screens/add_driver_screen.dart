import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_driver_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddDriverController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isEdit = controller.driverModel.value.id != null;
        final title = controller.driverModel.value.id == null ? "Add Delivery Man".tr : "Edit Delivery Man".tr;
        if (controller.isLoading.value) {
          return DsScaffold(
            title: title,
            maxContentWidth: DsLayout.contentMax,
            body: const DsSkeletonForm(fields: 6),
          );
        }
        return DsScaffold(
          title: title,
          maxContentWidth: DsLayout.contentMax,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.sm, context.dsLayout.gutter, DsSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                // ── Intro ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.lg),
                  child: Row(
                    children: [
                      DsIconWell(icon: isEdit ? Icons.manage_accounts_outlined : Icons.delivery_dining_rounded, size: 52),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: t.title.withColor(c.textPrimary)),
                            if (isEdit)
                              Text(controller.emailEditingController.value.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(c.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Name fields ──────────────────────────
                DsFormSection(
                  title: 'Personal details'.tr,
                  icon: Icons.person_outline_rounded,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DsTextField(
                            label: 'First Name'.tr,
                            controller: controller.firstNameEditingController.value,
                            hint: 'Enter First Name'.tr,
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: DsTextField(
                            label: 'Last Name'.tr,
                            controller: controller.lastNameEditingController.value,
                            hint: 'Enter Last Name'.tr,
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Email + Phone ────────────────────────
                DsFormSection(
                  title: 'Contact'.tr,
                  icon: Icons.contact_phone_outlined,
                  children: [
                    DsTextField(
                      readOnly: (controller.driverModel.value.id != null && controller.driverModel.value.id != ''),
                      label: 'Email Address'.tr,
                      keyboardType: TextInputType.emailAddress,
                      controller: controller.emailEditingController.value,
                      hint: 'Enter Email Address'.tr,
                      prefixIcon: Icons.mail_outline_rounded,
                      suffix: (controller.driverModel.value.id != null && controller.driverModel.value.id != '') ? Icon(Icons.lock_outline_rounded, size: 18, color: c.textMuted) : null,
                    ),
                    DsTextField(
                      label: 'Phone Number'.tr,
                      controller: controller.phoneNUmberEditingController.value,
                      hint: 'Enter Phone Number'.tr,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                      prefix: CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                        },
                        enabled: true,
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                        },
                        dialogTextStyle: t.bodyStrong.withColor(c.textPrimary),
                        dialogBackgroundColor: c.surfaceRaised,
                        initialSelection: controller.countryISOCodeEditingController.value.text,
                        comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                        textStyle: t.bodyStrong.withColor(c.textPrimary),
                        searchDecoration: DsInputDecoration.of(context, prefixIcon: Icons.search_rounded),
                        searchStyle: t.bodyStrong.withColor(c.textPrimary),
                      ),
                    ),
                  ],
                ),

                // ── Sections (display only) ──────────────
                if (controller.vendorSections.isNotEmpty)
                  DsFormSection(
                    title: "Sections".tr,
                    icon: Icons.category_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: Wrap(
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.sm,
                          children: controller.vendorSections.map((section) {
                            return DsBadge(
                              label: "${section.name ?? section.id ?? ''} (${controller.serviceFlagLabel(section.serviceTypeFlag)})",
                              tone: DsTone.brand,
                              icon: Icons.check_circle_rounded,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                // ── Password fields (create only) ───────
                Visibility(
                  visible: controller.driverModel.value.id == null,
                  child: DsFormSection(
                    title: 'Security'.tr,
                    icon: Icons.lock_outline_rounded,
                    children: [
                      _PasswordField(
                        label: 'Password'.tr,
                        hint: 'Enter Password'.tr,
                        controller: controller.passwordEditingController.value,
                        obscure: controller.passwordVisible.value,
                        onToggle: () {
                          controller.passwordVisible.value = !controller.passwordVisible.value;
                        },
                      ),
                      _PasswordField(
                        label: 'Confirm Password'.tr,
                        hint: 'Enter Confirm Password'.tr,
                        controller: controller.conformPasswordEditingController.value,
                        obscure: controller.conformPasswordVisible.value,
                        onToggle: () {
                          controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () async {
                if (controller.firstNameEditingController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter first name".tr);
                } else if (controller.lastNameEditingController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter last name".tr);
                } else if (controller.emailEditingController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter valid email".tr);
                } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter Phone number".tr);
                } else if (controller.passwordEditingController.value.text.isEmpty && controller.driverModel.value.id == null) {
                  ShowToastDialog.showToast("Please enter password".tr);
                } else if (controller.conformPasswordEditingController.value.text.isEmpty && controller.driverModel.value.id == null) {
                  ShowToastDialog.showToast("Please enter Confirm password".tr);
                } else if (controller.passwordEditingController.value.text != controller.conformPasswordEditingController.value.text && controller.driverModel.value.id == null) {
                  ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                } else {
                  controller.signUpWithEmailAndPassword();
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// Password input whose obscure state lives in the controller (so the
/// existing `passwordVisible` toggles keep working).
class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordField({required this.label, required this.hint, required this.controller, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsFieldLabel(label),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            obscuringCharacter: '●',
            cursorColor: c.brand,
            style: t.bodyStrong.withColor(c.textPrimary),
            decoration: DsInputDecoration.of(
              context,
              hint: hint,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: DsIconButton(
                icon: obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                semanticLabel: obscure ? 'Show password'.tr : 'Hide password'.tr,
                onPressed: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
