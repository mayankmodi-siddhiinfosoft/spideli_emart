import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/auth_screen/phone_number_screen.dart';
import 'package:driver/app/auth_screen/widgets/auth_shell.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../constant/constant.dart';

/// Archetype H – registration: a long form broken into labelled DS sections
/// (role, sections, vehicles, identity, company, password) so the driver
/// always knows where they are. Tablets get the brand panel + 440-wide form.
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: SignupController(),
        builder: (SignupController controller) {
          final c = context.dsColors;
          final t = context.dsText;

          // Every observable is read here, inside the tracked builder, and the
          // values are handed to the presentational widgets below.
          final String role = controller.selectedValue.value;
          final bool isCompany = controller.isCompany;
          final String type = controller.type.value;
          final bool isSocial = type == "google" || type == "apple";
          final bool isMobileSignup = type == "mobileNumber";
          final bool passwordObscured = controller.passwordVisible.value;
          final bool confirmObscured = controller.conformPasswordVisible.value;
          final List<SectionModel> sections = controller.visibleSections.toList();
          final bool sectionsLoading = controller.allSections.isEmpty;
          final List<RegionModel> regions = controller.regionList.toList();
          final RegionModel? selectedRegion = controller.selectedRegion.value;
          final List<ZoneModel> zones = controller.zoneList.toList();
          final ZoneModel selectedZone = controller.selectedZone.value;

          final vehicleSections = role == "Individual"
              ? controller.selectedSections.where((s) => controller.sectionNeedsVehicle(s)).toList()
              : <SectionModel>[];

          return DsScaffold(
            appBar: const DsAppBar(),
            body: AuthShell(
              icon: Icons.person_add_alt_1_rounded,
              title: "Create an Account".tr,
              subtitle: "Sign up now to start your journey as a spideli driver and begin earning with every delivery.".tr,
              highlights: [
                "Pick the services you want to work in".tr,
                "Get paid for every completed job".tr,
              ],
              link: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Already Have an account?'.tr, style: t.bodyStrong),
                    const WidgetSpan(child: SizedBox(width: 6)),
                    TextSpan(
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Get.offAll(const LoginScreen());
                        },
                      text: 'Log in'.tr,
                      style: t.link,
                    ),
                  ],
                ),
              ),
              children: [
                // ── Individual / Company ─────────────────────────────────
                DsFormSection(
                  title: 'Continue as'.tr,
                  icon: Icons.badge_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceTile(
                            label: 'Individual'.tr,
                            icon: Icons.person_outline_rounded,
                            selected: role == 'Individual',
                            onTap: () => controller.onRoleChanged('Individual'),
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: _ChoiceTile(
                            label: 'Company'.tr,
                            icon: Icons.apartment_rounded,
                            selected: role == 'Company',
                            onTap: () => controller.onRoleChanged('Company'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),

                // ── Section selection ─────────────────────────────────────
                DsFormSection(
                  title: "Select Sections".tr,
                  icon: Icons.grid_view_rounded,
                  children: [
                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(DsSpace.lg),
                        child: Center(
                          child: Text(
                            sectionsLoading ? "Loading sections...".tr : "No sections available".tr,
                            style: t.bodySecondary,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < sections.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : DsSpace.sm),
                          child: _SectionCheckRow(
                            title: sections[i].name ?? '',
                            subtitle: controller.serviceFlagLabel(sections[i].serviceTypeFlag),
                            checked: controller.isSectionSelected(sections[i]),
                            onTap: () async {
                              await controller.toggleSection(sections[i]);
                            },
                          ),
                        ),
                  ],
                ),
                const DsGap(DsSpace.lg),

                // ── Per-section vehicle type + car details (cab / rental) ──
                ...vehicleSections.map((section) {
                  final sid = section.id!;
                  final vehicles = controller.vehicleTypesPerSection[sid] ?? [];
                  final selectedVehicle = controller.selectedVehiclePerSection[sid];
                  final sectionCarMakes = controller.selectedCarMakesPerSection[sid];
                  final sectionCarModels = controller.carModelListPerSection[sid] ?? <CarModel>[].obs;
                  final sectionCarModel = controller.selectedCarModelPerSection[sid];
                  final sectionCarPlate = controller.carPlatePerSection[sid];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.lg),
                    child: DsFormSection(
                      title: section.name ?? '',
                      icon: Icons.directions_car_outlined,
                      children: [
                        if (vehicles.isNotEmpty)
                          DsDropdown<VehicleType>(
                            label: 'Vehicle Type'.tr,
                            hint: 'Vehicle Type'.tr,
                            value: selectedVehicle,
                            onChanged: (value) {
                              if (value != null) {
                                controller.selectedVehiclePerSection[sid] = value;
                                controller.update();
                              }
                            },
                            items: vehicles.map((item) => DropdownMenuItem<VehicleType>(value: item, child: Text(item.name.toString()))).toList(),
                          ),
                        DsDropdown<CarMakes>(
                          label: 'Car Brand'.tr,
                          hint: 'Car Brand'.tr,
                          value: sectionCarMakes?.value.id == null ? null : sectionCarMakes?.value,
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedCarMakesPerSection[sid]?.value = value;
                              controller.getCarModelForSection(sid);
                              controller.update();
                            }
                          },
                          items: controller.carMakesList.map((item) => DropdownMenuItem<CarMakes>(value: item, child: Text(item.name.toString()))).toList(),
                        ),
                        DsDropdown<CarModel>(
                          key: ValueKey('carModel_${sectionCarMakes?.value.id}_${sectionCarModels.length}'),
                          label: 'Car Model'.tr,
                          hint: 'Car Model'.tr,
                          value: sectionCarModel?.value.id == null ? null : sectionCarModel?.value,
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedCarModelPerSection[sid]?.value = value;
                              controller.update();
                            }
                          },
                          items: sectionCarModels.map((item) => DropdownMenuItem<CarModel>(value: item, child: Text(item.name.toString()))).toList(),
                        ),
                        DsTextField(
                          label: 'Car Plate Number'.tr,
                          controller: sectionCarPlate?.value ?? TextEditingController(),
                          hint: 'Enter Car Plate Number'.tr,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.confirmation_number_outlined,
                          bottomSpacing: 0,
                        ),
                      ],
                    ),
                  );
                }),

                // ── Identity ──────────────────────────────────────────────
                DsFormSection(
                  title: "Your details".tr,
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
                            prefixIcon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: DsTextField(
                            label: 'Last Name'.tr,
                            controller: controller.lastNameEditingController.value,
                            hint: 'Enter Last Name'.tr,
                            prefixIcon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    DsTextField(
                      label: 'Email Address'.tr,
                      keyboardType: TextInputType.emailAddress,
                      controller: controller.emailEditingController.value,
                      hint: 'Enter Email Address'.tr,
                      enabled: isSocial ? false : true,
                      prefixIcon: Icons.mail_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    DsTextField(
                      label: 'Phone Number'.tr,
                      controller: controller.phoneNUmberEditingController.value,
                      hint: 'Enter Phone Number'.tr,
                      enabled: isMobileSignup ? false : true,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                      bottomSpacing: 0,
                      prefix: CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                        },
                        enabled: isMobileSignup ? false : true,
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
                const DsGap(DsSpace.lg),

                // ── Zone / management zone ────────────────────────────────
                if (role == "Company")
                  const SizedBox()
                else ...[
                  DsFormSection(
                    title: "Zone".tr,
                    icon: Icons.map_outlined,
                    children: [
                      DsDropdown<ZoneModel>(
                        hint: 'Select zone'.tr,
                        value: selectedZone.id == null ? null : selectedZone,
                        onChanged: (value) {
                          controller.selectedZone.value = value!;
                          controller.update();
                        },
                        items: zones.map((item) => DropdownMenuItem<ZoneModel>(value: item, child: Text(item.name.toString()))).toList(),
                        bottomSpacing: 0,
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                ],

                if (regions.isNotEmpty) ...[
                  DsFormSection(
                    title: "Management zone".tr,
                    icon: Icons.account_tree_outlined,
                    children: [
                      DsDropdown<RegionModel>(
                        hint: 'Select management zone'.tr,
                        value: selectedRegion,
                        onChanged: (value) {
                          controller.selectedRegion.value = value;
                          controller.update();
                        },
                        items: regions.map((item) => DropdownMenuItem<RegionModel>(value: item, child: Text(item.displayName))).toList(),
                        bottomSpacing: 0,
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                ],

                // ── Company identification (spec 4.11) ────────────────────
                if (isCompany) ...[
                  DsFormSection(
                    title: "Company information".tr,
                    icon: Icons.apartment_rounded,
                    children: [
                      DsTextField(
                        label: 'Company Name'.tr,
                        controller: controller.companyNameController.value,
                        hint: 'Enter Company Name'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      DsTextField(
                        label: 'Operating Licence'.tr,
                        controller: controller.operatingLicenceController.value,
                        hint: 'Enter Operating Licence Number'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      DsTextField(
                        label: 'Commercial Register'.tr,
                        controller: controller.commercialRegisterController.value,
                        hint: 'Enter Commercial Register Number'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      DsTextField(
                        label: 'Unique Identification Number'.tr,
                        controller: controller.uniqueIdNumberController.value,
                        hint: 'Enter Unique Identification Number'.tr,
                        textInputAction: TextInputAction.next,
                        bottomSpacing: 0,
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                  DsFormSection(
                    title: "Company documents".tr,
                    icon: Icons.folder_open_rounded,
                    children: [
                      ...SignupController.companyFileFields.entries.map((entry) {
                        final picked = controller.companyFiles[entry.key];
                        return _CompanyFileRow(
                          title: entry.value.tr,
                          fileName: picked == null ? "Not uploaded".tr : picked.split('/').last,
                          uploaded: picked != null,
                          onPick: (source) => controller.pickCompanyFile(entry.key, source),
                        );
                      }),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                ],

                // ── Password (email sign-up only) ─────────────────────────
                if (isSocial || isMobileSignup)
                  const SizedBox()
                else
                  DsFormSection(
                    title: 'Password'.tr,
                    icon: Icons.lock_outline_rounded,
                    children: [
                      _PasswordField(
                        label: 'Password'.tr,
                        hint: 'Enter Password'.tr,
                        controller: controller.passwordEditingController.value,
                        obscured: passwordObscured,
                        textInputAction: TextInputAction.next,
                        onToggle: () => controller.passwordVisible.value = !controller.passwordVisible.value,
                      ),
                      const DsGap(DsSpace.lg),
                      _PasswordField(
                        label: 'Confirm Password'.tr,
                        hint: 'Enter Confirm Password'.tr,
                        controller: controller.conformPasswordEditingController.value,
                        obscured: confirmObscured,
                        textInputAction: TextInputAction.next,
                        onToggle: () => controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value,
                      ),
                    ],
                  ),
              ],
            ),
            bottomBar: DsStickyBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Log in with'.tr, style: t.bodyStrong),
                        const WidgetSpan(child: SizedBox(width: 6)),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Get.to(const PhoneNumberScreen());
                            },
                          text: 'Mobile Number'.tr,
                          style: t.link,
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  DsButton.primary(
                    label: "Sign up".tr,
                    icon: Icons.arrow_forward_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () {
                      if (controller.selectedSections.isEmpty) {
                        ShowToastDialog.showToast("Please select at least one section".tr);
                        return;
                      }
                      if (controller.firstNameEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter first name".tr);
                      } else if (controller.lastNameEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter last name".tr);
                      } else if (controller.emailEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter valid email".tr);
                      } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter Phone number".tr);
                      } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.passwordEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter password".tr);
                      } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.conformPasswordEditingController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter Confirm password".tr);
                      } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.passwordEditingController.value.text != controller.conformPasswordEditingController.value.text) {
                        ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                      } else if (controller.selectedValue.value == "Individual" && controller.selectedZone.value.id == null) {
                        ShowToastDialog.showToast("Please select zone".tr);
                      } else if (controller.regionRequired && controller.selectedRegion.value == null) {
                        ShowToastDialog.showToast("Please select your management zone".tr);
                      } else if (controller.isCompany && controller.companyNameController.value.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter company name".tr);
                      } else if (controller.isCompany &&
                          (controller.operatingLicenceController.value.text.trim().isEmpty ||
                              controller.commercialRegisterController.value.text.trim().isEmpty ||
                              controller.uniqueIdNumberController.value.text.trim().isEmpty)) {
                        ShowToastDialog.showToast("Please enter the operating licence, commercial register and unique identification number".tr);
                      } else {
                        controller.signUpWithEmailAndPassword();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }
}

/// Selectable role tile (Individual / Company).
class _ChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      borderColor: selected ? c.brand : null,
      color: selected ? c.brandSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
      semanticLabel: label,
      child: Row(
        children: [
          Icon(icon, size: 20, color: selected ? c.brandStrong : c.iconDefault),
          const DsGap(DsSpace.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selected ? t.bodyStrong.withColor(c.brandStrong) : t.bodyStrong,
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? c.brand : c.textMuted,
          ),
        ],
      ),
    );
  }
}

/// A selectable service section with its service label.
class _SectionCheckRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback onTap;

  const _SectionCheckRow({required this.title, required this.subtitle, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      borderColor: checked ? c.brand : null,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      semanticLabel: title,
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (_) => onTap(),
          ),
          const DsGap(DsSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                if (subtitle.isNotEmpty) Text(subtitle, style: t.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Company document row: name, picked file and a camera / gallery menu.
class _CompanyFileRow extends StatelessWidget {
  final String title;
  final String fileName;
  final bool uploaded;
  final ValueChanged<ImageSource> onPick;

  const _CompanyFileRow({required this.title, required this.fileName, required this.uploaded, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        children: [
          DsIconWell(
            icon: uploaded ? Icons.check_circle_outline_rounded : Icons.upload_file_rounded,
            tone: uploaded ? DsTone.success : DsTone.neutral,
            size: 40,
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.withColor(uploaded ? c.successStrong : c.textMuted),
                ),
              ],
            ),
          ),
          PopupMenuButton<ImageSource>(
            icon: Icon(Icons.add_a_photo_outlined, color: c.brand),
            tooltip: "Camera".tr,
            onSelected: onPick,
            itemBuilder: (_) => [
              PopupMenuItem(value: ImageSource.camera, child: Text("Camera".tr)),
              PopupMenuItem(value: ImageSource.gallery, child: Text("Gallery".tr)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Password field whose visibility flag lives on the controller.
class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscured;
  final TextInputAction textInputAction;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.textInputAction,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsFieldLabel(label),
        TextFormField(
          controller: controller,
          obscureText: obscured,
          style: t.bodyStrong,
          cursorColor: c.brand,
          textInputAction: textInputAction,
          decoration: DsInputDecoration.of(
            context,
            hint: hint,
            prefixIcon: Icons.lock_outline_rounded,
            suffix: DsIconButton(
              icon: obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              semanticLabel: label,
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
