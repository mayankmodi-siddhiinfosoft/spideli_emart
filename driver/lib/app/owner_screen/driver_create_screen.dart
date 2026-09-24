import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/driver_create_controller.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/car_model.dart' show CarModel;

/// Archetype H – multi-step-feeling creation form: grouped `DsFormSection`s,
/// selectable section tiles, one vehicle card per selected section and a
/// sticky primary action.
class DriverCreateScreen extends StatelessWidget {
  const DriverCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DriverCreateController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isEdit = controller.driverModel.value.id != null &&
            controller.driverModel.value.id!.isNotEmpty;

        // Read eagerly inside the tracked builder so the tiles rebuild.
        final ownerSections = controller.ownerSections.toList();
        final sectionTiles = <Widget>[
          for (var i = 0; i < ownerSections.length; i++)
            _SectionChoiceTile(
              index: i,
              title: ownerSections[i].name ?? '',
              subtitle: controller.serviceFlagLabel(ownerSections[i].serviceTypeFlag),
              serviceTypeFlag: ownerSections[i].serviceTypeFlag,
              selected: controller.isSectionSelected(ownerSections[i]),
              onTap: () async {
                await controller.toggleSection(ownerSections[i]);
              },
            ),
        ];

        return DsScaffold(
          title: isEdit ? 'Update Driver'.tr : 'Create Driver'.tr,
          subtitle: isEdit ? controller.driverModel.value.fullName() : 'Add a driver to your fleet'.tr,
          body: controller.isLoading.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                  child: DsSkeletonForm(fields: 6),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section selection (owner's sections only) ────
                      DsFormSection(
                        title: "Select Sections".tr,
                        icon: Icons.grid_view_rounded,
                        children: [
                          if (ownerSections.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(DsSpace.md),
                              child: Text("No sections available".tr, style: t.bodySecondary),
                            )
                          else
                            DsAdaptiveGrid(minItemWidth: 260, children: sectionTiles),
                        ],
                      ),

                      // ── Per-section vehicle cards (for selected cab / rental sections) ─
                      ...controller.selectedSections
                          .where((s) => controller.sectionNeedsVehicle(s))
                          .map((section) {
                        final sid = section.id ?? '';
                        final vehicleTypes =
                            controller.vehicleTypesPerSection[sid] ??
                                <VehicleType>[].obs;
                        final selectedVehicle =
                            controller.selectedVehiclePerSection[sid] ??
                                VehicleType().obs;
                        final selectedRideType =
                            controller.selectedRideTypePerSection[sid] ??
                                RxString('ride');
                        final selectedCarMakes =
                            controller.selectedCarMakesPerSection[sid] ??
                                Rx<CarMakes>(CarMakes());
                        final carModels =
                            controller.carModelListPerSection[sid] ??
                                <CarModel>[].obs;
                        final selectedCarModel =
                            controller.selectedCarModelPerSection[sid] ??
                                Rx<CarModel>(CarModel());
                        final carPlate =
                            controller.carPlatePerSection[sid] ??
                                Rx<TextEditingController>(
                                    TextEditingController());

                        return _SectionVehicleCard(
                          section: section,
                          vehicleTypes: vehicleTypes,
                          selectedVehicle: selectedVehicle,
                          isCab: section.serviceTypeFlag == 'cab-service',
                          selectedRideType: selectedRideType,
                          carMakesList: controller.carMakesList,
                          selectedCarMakes: selectedCarMakes,
                          carModels: carModels,
                          selectedCarModel: selectedCarModel,
                          carPlate: carPlate,
                          onBrandChanged: () =>
                              controller.getCarModelForSection(sid),
                        );
                      }),

                      // ── Driver profile ────────────────────────────────
                      DsFormSection(
                        title: 'Driver Details'.tr,
                        icon: Icons.badge_outlined,
                        children: [
                          // ── Zone ─────────────────────────────────────
                          DsDropdown<ZoneModel>(
                            label: "Zone".tr,
                            hint: 'Select zone'.tr,
                            prefixIcon: Icons.map_outlined,
                            value: controller.selectedZone.value.id == null
                                ? null
                                : controller.selectedZone.value,
                            items: controller.zoneList
                                .map((item) => DropdownMenuItem<ZoneModel>(
                                      value: item,
                                      child: Text(item.name ?? '', overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              controller.selectedZone.value = v!;
                              controller.update();
                            },
                          ),

                          // ── Name ──────────────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DsTextField(
                                  label: 'First Name'.tr,
                                  controller:
                                      controller.firstNameEditingController.value,
                                  hint: 'Enter First Name'.tr,
                                  prefixIcon: Icons.person_outline,
                                ),
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: DsTextField(
                                  label: 'Last Name'.tr,
                                  controller:
                                      controller.lastNameEditingController.value,
                                  hint: 'Enter Last Name'.tr,
                                  prefixIcon: Icons.person_outline,
                                ),
                              ),
                            ],
                          ),

                          // ── Email ─────────────────────────────────────
                          DsTextField(
                            label: 'Email Address'.tr,
                            keyboardType: TextInputType.emailAddress,
                            controller: controller.emailEditingController.value,
                            hint: 'Enter Email Address'.tr,
                            enabled: !isEdit,
                            prefixIcon: Icons.mail_outline,
                          ),

                          // ── Phone ─────────────────────────────────────
                          DsTextField(
                            label: 'Phone Number'.tr,
                            controller:
                                controller.phoneNUmberEditingController.value,
                            hint: 'Enter Phone Number'.tr,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    signed: true, decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp('[0-9]')),
                            ],
                            prefix: CountryCodePicker(
                              onInit: (value) {
                                controller
                                    .countryCodeEditingController
                                    .value
                                    .text = value?.dialCode ??
                                    Constant.defaultCountryCode;
                                controller
                                    .countryISOCodeEditingController
                                    .value
                                    .text = value?.code ??
                                    Constant.defaultCountryCode;
                              },
                              onChanged: (value) {
                                controller
                                    .countryCodeEditingController
                                    .value
                                    .text = value.dialCode ??
                                    Constant.defaultCountryCode;
                                controller
                                    .countryISOCodeEditingController
                                    .value
                                    .text = value.code ??
                                    Constant.defaultCountryCode;
                              },
                              dialogTextStyle: t.bodyStrong,
                              dialogBackgroundColor: c.surfaceRaised,
                              initialSelection: controller
                                  .countryISOCodeEditingController.value.text,
                              comparator: (a, b) =>
                                  b.name!.compareTo(a.name.toString()),
                              textStyle: t.bodyStrong,
                              searchDecoration: InputDecoration(iconColor: c.iconDefault),
                              searchStyle: t.bodyStrong,
                            ),
                          ),
                        ],
                      ),

                      // ── Password (create only) ────────────────────────
                      if (!isEdit)
                        DsFormSection(
                          title: 'Security'.tr,
                          icon: Icons.lock_outline_rounded,
                          children: [
                            _PasswordField(
                              label: 'Password'.tr,
                              hint: 'Enter Password'.tr,
                              controller:
                                  controller.passwordEditingController.value,
                              obscured: controller.passwordVisible.value,
                              onToggle: () => controller.passwordVisible.value =
                                  !controller.passwordVisible.value,
                            ),
                            _PasswordField(
                              label: 'Confirm Password'.tr,
                              hint: 'Enter Confirm Password'.tr,
                              controller: controller
                                  .conformPasswordEditingController.value,
                              obscured:
                                  controller.conformPasswordVisible.value,
                              onToggle: () =>
                                  controller.conformPasswordVisible.value =
                                      !controller
                                          .conformPasswordVisible.value,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

          // ── Save button ───────────────────────────────────────────
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: 'Save'.tr,
              icon: Icons.check_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () => _onSave(controller, isEdit),
            ),
          ),
        );
      },
    );
  }

  void _onSave(DriverCreateController controller, bool isEdit) {
    if (controller.selectedSections.isEmpty) {
      ShowToastDialog.showToast("Please select at least one section".tr);
      return;
    }
    if (controller.firstNameEditingController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter first name".tr);
      return;
    } else if (controller.lastNameEditingController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter last name".tr);
      return;
    } else if (controller.emailEditingController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter email address".tr);
      return;
    } else if (!GetUtils.isEmail(controller.emailEditingController.value.text)) {
      ShowToastDialog.showToast("Please enter valid email address".tr);
      return;
    } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter phone number".tr);
      return;
    } else if (controller.selectedZone.value.id == null) {
      ShowToastDialog.showToast("Please select zone".tr);
      return;
    }

    if (!isEdit) {
      if (controller.passwordEditingController.value.text.isEmpty) {
        ShowToastDialog.showToast("Please enter password".tr);
        return;
      } else if (controller.passwordEditingController.value.text.length < 6) {
        ShowToastDialog.showToast("Password must be at least 6 characters".tr);
        return;
      } else if (controller.conformPasswordEditingController.value.text.isEmpty) {
        ShowToastDialog.showToast("Please enter confirm password".tr);
        return;
      } else if (controller.passwordEditingController.value.text !=
          controller.conformPasswordEditingController.value.text) {
        ShowToastDialog.showToast("Password and confirm password do not match".tr);
        return;
      }
    }

    for (final section in controller.selectedSections) {
      if (!controller.sectionNeedsVehicle(section)) continue;
      final sid = section.id ?? '';
      final name = section.name ?? '';
      if (controller.selectedVehiclePerSection[sid]?.value.id == null) {
        ShowToastDialog.showToast(
            "Please select vehicle type for $name".tr);
        return;
      }
      if (controller.selectedCarMakesPerSection[sid]?.value.id == null) {
        ShowToastDialog.showToast("Please select car brand for $name".tr);
        return;
      }
      if (controller.selectedCarModelPerSection[sid]?.value.id == null) {
        ShowToastDialog.showToast("Please select car model for $name".tr);
        return;
      }
      final plate =
          controller.carPlatePerSection[sid]?.value.text.trim() ?? '';
      if (plate.isEmpty) {
        ShowToastDialog.showToast(
            "Please enter car plat number for $name".tr);
        return;
      }
    }

    if (isEdit) {
      controller.updateDriver();
    } else {
      controller.signUp();
    }
  }
}

// ── Password field (visibility driven by the controller's observable) ─────────

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsFieldLabel(label),
          TextFormField(
            controller: controller,
            obscureText: obscured,
            style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
            decoration: DsInputDecoration.of(
              context,
              hint: hint,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: obscured ? 'Show password'.tr : 'Hide password'.tr,
                icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selectable section tile ───────────────────────────────────────────────────

class _SectionChoiceTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final String? serviceTypeFlag;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChoiceTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.serviceTypeFlag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final section = DsSection.fromServiceType(serviceTypeFlag);
    final accent = c.section(section);
    return DsFadeSlideIn(
      index: index,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.all(DsSpace.md),
        semanticLabel: '$title, $subtitle',
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(12)),
              child: Icon(section.icon, size: 20, color: accent.strong),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.titleSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const DsGap(DsSpace.xxs),
                  Text(subtitle, style: t.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const DsGap(DsSpace.sm),
            AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.fast),
              curve: DsMotion.standard,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? c.brand : Colors.transparent,
                border: Border.all(color: selected ? c.brand : c.borderStrong, width: 1.6),
                borderRadius: DsRadius.brXs,
              ),
              child: selected ? Icon(Icons.check_rounded, size: 16, color: c.onBrand) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Per-section vehicle card ──────────────────────────────────────────────────

class _SectionVehicleCard extends StatelessWidget {
  final SectionModel section;
  final RxList<VehicleType> vehicleTypes;
  final Rx<VehicleType> selectedVehicle;
  final bool isCab;
  final RxString selectedRideType;
  final RxList<CarMakes> carMakesList;
  final Rx<CarMakes> selectedCarMakes;
  final RxList<CarModel> carModels;
  final Rx<CarModel> selectedCarModel;
  final Rx<TextEditingController> carPlate;
  final VoidCallback onBrandChanged;

  const _SectionVehicleCard({
    required this.section,
    required this.vehicleTypes,
    required this.selectedVehicle,
    required this.isCab,
    required this.selectedRideType,
    required this.carMakesList,
    required this.selectedCarMakes,
    required this.carModels,
    required this.selectedCarModel,
    required this.carPlate,
    required this.onBrandChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final accent = c.section(DsSection.fromServiceType(section.serviceTypeFlag));
    return Obx(() => DsCard.outlined(
          margin: const EdgeInsets.only(bottom: DsSpace.lg),
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: accent.main, borderRadius: DsRadius.brPill),
                  ),
                  const DsGap(DsSpace.sm),
                  Expanded(
                    child: Text(section.name ?? '', style: t.titleSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.directions_car_outlined, size: 20, color: c.textMuted),
                ],
              ),
              const DsGap(DsSpace.lg),

              // Vehicle type dropdown
              if (vehicleTypes.isEmpty)
                Text("No vehicle types for this section".tr, style: t.bodySecondary)
              else
                DsDropdown<VehicleType>(
                  label: 'Vehicle Type'.tr,
                  hint: 'Vehicle Type'.tr,
                  bottomSpacing: 0,
                  value: vehicleTypes.contains(selectedVehicle.value)
                      ? selectedVehicle.value
                      : null,
                  items: vehicleTypes
                      .map((item) => DropdownMenuItem<VehicleType>(
                            value: item,
                            child: Text(item.name ?? '', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => selectedVehicle.value = v!,
                ),

              // Ride type radios (cab only, based on section.rideType)
              if (isCab &&
                  (section.rideType == 'ride' ||
                      section.rideType == 'intercity' ||
                      section.rideType == 'both')) ...[
                const DsGap(DsSpace.lg),
                DsFieldLabel("Ride Type".tr),
                Row(
                  children: [
                    if (section.rideType == 'ride' ||
                        section.rideType == 'both')
                      _RideOption(
                        label: 'Ride'.tr,
                        value: 'ride',
                        groupValue: selectedRideType.value,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'intercity' ||
                        section.rideType == 'both')
                      _RideOption(
                        label: 'Intercity'.tr,
                        value: 'intercity',
                        groupValue: selectedRideType.value,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'both')
                      _RideOption(
                        label: 'Both'.tr,
                        value: 'both',
                        groupValue: selectedRideType.value,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                  ],
                ),
              ],

              // Car brand
              const DsGap(DsSpace.lg),
              DsDropdown<CarMakes>(
                label: 'Car Brand'.tr,
                hint: 'Car Brand'.tr,
                bottomSpacing: 0,
                value: selectedCarMakes.value.id == null
                    ? null
                    : selectedCarMakes.value,
                items: carMakesList
                    .map((item) => DropdownMenuItem<CarMakes>(
                          value: item,
                          child: Text(item.name ?? '', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    selectedCarMakes.value = v;
                    onBrandChanged();
                  }
                },
              ),

              // Car model
              const DsGap(DsSpace.lg),
              DsDropdown<CarModel>(
                key: ValueKey('carModel_${selectedCarMakes.value.id}_${carModels.length}'),
                label: 'Car Model'.tr,
                hint: 'Car Model'.tr,
                bottomSpacing: 0,
                value: selectedCarModel.value.id == null
                    ? null
                    : selectedCarModel.value,
                items: carModels
                    .map((item) => DropdownMenuItem<CarModel>(
                          value: item,
                          child: Text(item.name ?? '', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedCarModel.value = v;
                },
              ),

              // Car plate number
              const DsGap(DsSpace.lg),
              DsTextField(
                label: 'Car Plate Number'.tr,
                controller: carPlate.value,
                hint: 'Enter Car Plate Number'.tr,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                bottomSpacing: 0,
              ),
            ],
          ),
        ));
  }
}

/// Radio-style choice chip: selected only when it matches [groupValue], so an
/// unset ride type stays visibly unselected (same as the old radio list).
class _RideOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RideOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final selected = value == groupValue;
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
        child: Semantics(
          selected: selected,
          child: DsPressable(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.fast),
              curve: DsMotion.standard,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              decoration: BoxDecoration(
                color: selected ? c.brandSoft : c.surfaceAlt,
                borderRadius: DsRadius.brMd,
                border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.6 : 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? c.brand : c.textMuted,
                  ),
                  const DsGap(DsSpace.xs),
                  Flexible(
                    child: Text(
                      label,
                      style: selected ? t.label.withColor(c.brandStrong) : t.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
