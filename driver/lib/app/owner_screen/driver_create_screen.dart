import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/driver_create_controller.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../models/car_model.dart' show CarModel;
import '../../themes/responsive.dart' show Responsive;

class DriverCreateScreen extends StatelessWidget {
  const DriverCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DriverCreateController(),
      builder: (controller) {
        final isEdit = controller.driverModel.value.id != null &&
            controller.driverModel.value.id!.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? 'Update Driver'.tr : 'Create Driver'.tr),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),

                            // ── Section selection (owner's sections only) ────
                            _Label("Select Sections".tr, isDark),
                            const SizedBox(height: 6),
                            controller.ownerSections.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      "No sections available".tr,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppThemeData.grey400
                                            : AppThemeData.grey600,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppThemeData.grey900
                                          : AppThemeData.grey50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? AppThemeData.greyDark400
                                            : AppThemeData.grey400,
                                      ),
                                    ),
                                    child: Column(
                                      children: controller.ownerSections.map((section) {
                                        final isChecked =
                                            controller.isSectionSelected(section);
                                        return CheckboxListTile(
                                          dense: true,
                                          title: Text(
                                            section.name ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppThemeData.grey50
                                                  : AppThemeData.grey900,
                                              fontFamily: AppThemeData.medium,
                                            ),
                                          ),
                                          subtitle: Text(
                                            controller.serviceFlagLabel(
                                                section.serviceTypeFlag),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppThemeData.grey400
                                                  : AppThemeData.grey600,
                                              fontFamily: AppThemeData.regular,
                                            ),
                                          ),
                                          value: isChecked,
                                          activeColor: AppThemeData.primary300,
                                          checkColor: Colors.white,
                                          onChanged: (_) async {
                                            await controller.toggleSection(section);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                            const SizedBox(height: 12),

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
                                isDark: isDark,
                              );
                            }),

                            // ── Zone ─────────────────────────────────────────
                            _Label("Zone".tr, isDark),
                            const SizedBox(height: 6),
                            _Dropdown<ZoneModel>(
                              hint: 'Select zone'.tr,
                              value: controller.selectedZone.value.id == null
                                  ? null
                                  : controller.selectedZone.value,
                              items: controller.zoneList,
                              label: (item) => item.name ?? '',
                              isDark: isDark,
                              onChanged: (v) {
                                controller.selectedZone.value = v!;
                                controller.update();
                              },
                            ),
                            const SizedBox(height: 10),

                            // ── Name ──────────────────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: TextFieldWidget(
                                    title: 'First Name'.tr,
                                    controller:
                                        controller.firstNameEditingController.value,
                                    hintText: 'Enter First Name'.tr,
                                    prefix: _svgIcon(
                                        "assets/icons/ic_user.svg", isDark),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFieldWidget(
                                    title: 'Last Name'.tr,
                                    controller:
                                        controller.lastNameEditingController.value,
                                    hintText: 'Enter Last Name'.tr,
                                    prefix: _svgIcon(
                                        "assets/icons/ic_user.svg", isDark),
                                  ),
                                ),
                              ],
                            ),

                            // ── Email ─────────────────────────────────────────
                            TextFieldWidget(
                              title: 'Email Address'.tr,
                              textInputType: TextInputType.emailAddress,
                              controller: controller.emailEditingController.value,
                              hintText: 'Enter Email Address'.tr,
                              enable: !isEdit,
                              prefix:
                                  _svgIcon("assets/icons/ic_mail.svg", isDark),
                            ),

                            // ── Phone ─────────────────────────────────────────
                            TextFieldWidget(
                              title: 'Phone Number'.tr,
                              controller:
                                  controller.phoneNUmberEditingController.value,
                              hintText: 'Enter Phone Number'.tr,
                              textInputType:
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
                                dialogTextStyle: TextStyle(
                                  color: isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: AppThemeData.medium,
                                ),
                                dialogBackgroundColor: isDark
                                    ? AppThemeData.grey800
                                    : AppThemeData.grey100,
                                initialSelection: controller
                                    .countryISOCodeEditingController.value.text,
                                comparator: (a, b) =>
                                    b.name!.compareTo(a.name.toString()),
                                textStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                                  fontFamily: AppThemeData.medium,
                                ),
                                searchDecoration: InputDecoration(
                                    iconColor: isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900),
                                searchStyle: TextStyle(
                                  color: isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: AppThemeData.medium,
                                ),
                              ),
                            ),

                            // ── Password (create only) ────────────────────────
                            if (!isEdit) ...[
                              TextFieldWidget(
                                title: 'Password'.tr,
                                controller:
                                    controller.passwordEditingController.value,
                                hintText: 'Enter Password'.tr,
                                obscureText: controller.passwordVisible.value,
                                prefix: _svgIcon(
                                    "assets/icons/ic_lock.svg", isDark),
                                suffix: _passwordToggle(
                                  controller.passwordVisible.value,
                                  isDark,
                                  () => controller.passwordVisible.value =
                                      !controller.passwordVisible.value,
                                ),
                              ),
                              TextFieldWidget(
                                title: 'Confirm Password'.tr,
                                controller: controller
                                    .conformPasswordEditingController.value,
                                hintText: 'Enter Confirm Password'.tr,
                                obscureText:
                                    controller.conformPasswordVisible.value,
                                prefix: _svgIcon(
                                    "assets/icons/ic_lock.svg", isDark),
                                suffix: _passwordToggle(
                                  controller.conformPasswordVisible.value,
                                  isDark,
                                  () =>
                                      controller.conformPasswordVisible.value =
                                          !controller
                                              .conformPasswordVisible.value,
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── Save button ───────────────────────────────────────────
                    InkWell(
                      onTap: () => _onSave(controller, isEdit),
                      child: Container(
                        color: AppThemeData.primary300,
                        width: Responsive.width(100, context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Save'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppThemeData.grey50,
                            fontSize: 16,
                            fontFamily: AppThemeData.medium,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
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

  Widget _svgIcon(String asset, bool isDark) => Padding(
        padding: const EdgeInsets.all(12),
        child: SvgPicture.asset(
          asset,
          colorFilter: ColorFilter.mode(
            isDark ? AppThemeData.grey300 : AppThemeData.grey600,
            BlendMode.srcIn,
          ),
        ),
      );

  Widget _passwordToggle(bool visible, bool isDark, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: onTap,
          child: SvgPicture.asset(
            visible
                ? "assets/icons/ic_password_show.svg"
                : "assets/icons/ic_password_close.svg",
            colorFilter: ColorFilter.mode(
              isDark ? AppThemeData.grey300 : AppThemeData.grey600,
              BlendMode.srcIn,
            ),
          ),
        ),
      );

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
  final bool isDark;

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
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppThemeData.greyDark50 : AppThemeData.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppThemeData.primary300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.name ?? '',
                      style: TextStyle(
                        fontFamily: AppThemeData.semiBold,
                        fontSize: 14,
                        color: isDark
                            ? AppThemeData.greyDark900
                            : AppThemeData.grey800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Vehicle type dropdown
              if (vehicleTypes.isEmpty)
                Text(
                  "No vehicle types for this section".tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppThemeData.greyDark400
                        : AppThemeData.grey500,
                  ),
                )
              else
                _Dropdown<VehicleType>(
                  hint: 'Vehicle Type'.tr,
                  value: vehicleTypes.contains(selectedVehicle.value)
                      ? selectedVehicle.value
                      : null,
                  items: vehicleTypes,
                  label: (item) => item.name ?? '',
                  isDark: isDark,
                  onChanged: (v) => selectedVehicle.value = v!,
                ),

              // Ride type radios (cab only, based on section.rideType)
              if (isCab &&
                  (section.rideType == 'ride' ||
                      section.rideType == 'intercity' ||
                      section.rideType == 'both')) ...[
                const SizedBox(height: 10),
                Text(
                  "Ride Type".tr,
                  style: TextStyle(
                    fontFamily: AppThemeData.semiBold,
                    fontSize: 13,
                    color: isDark
                        ? AppThemeData.greyDark900
                        : AppThemeData.grey700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (section.rideType == 'ride' ||
                        section.rideType == 'both')
                      _RideOption(
                        label: 'Ride'.tr,
                        value: 'ride',
                        groupValue: selectedRideType.value,
                        isDark: isDark,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'intercity' ||
                        section.rideType == 'both')
                      _RideOption(
                        label: 'Intercity'.tr,
                        value: 'intercity',
                        groupValue: selectedRideType.value,
                        isDark: isDark,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'both')
                      _RideOption(
                        label: 'Both'.tr,
                        value: 'both',
                        groupValue: selectedRideType.value,
                        isDark: isDark,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                  ],
                ),
              ],

              // Car brand
              const SizedBox(height: 10),
              _Dropdown<CarMakes>(
                hint: 'Car Brand'.tr,
                value: selectedCarMakes.value.id == null
                    ? null
                    : selectedCarMakes.value,
                items: carMakesList,
                label: (item) => item.name ?? '',
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    selectedCarMakes.value = v;
                    onBrandChanged();
                  }
                },
              ),

              // Car model
              const SizedBox(height: 10),
              _Dropdown<CarModel>(
                key: ValueKey('carModel_${selectedCarMakes.value.id}_${carModels.length}'),
                hint: 'Car Model'.tr,
                value: selectedCarModel.value.id == null
                    ? null
                    : selectedCarModel.value,
                items: carModels,
                label: (item) => item.name ?? '',
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) selectedCarModel.value = v;
                },
              ),

              // Car plate number
              const SizedBox(height: 10),
              TextFieldWidget(
                title: 'Car Plate Number'.tr,
                controller: carPlate.value,
                hintText: 'Enter Car Plate Number'.tr,
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
        ));
  }
}

class _RideOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _RideOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RadioListTile<String>(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey800,
          ),
        ),
        value: value,
        groupValue: groupValue,
        activeColor: AppThemeData.primary300,
        onChanged: onChanged,
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppThemeData.semiBold,
        fontSize: 14,
        color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final bool isDark;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.label,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? AppThemeData.greyDark400 : AppThemeData.grey400;
    return DropdownButtonFormField<T>(
      hint: Text(
        hint,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
          fontFamily: AppThemeData.regular,
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down),
      dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor, width: 1.2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor)),
      ),
      value: value,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
        fontFamily: AppThemeData.medium,
      ),
      onChanged: onChanged,
      items: items.map((item) {
        return DropdownMenuItem<T>(value: item, child: Text(label(item)));
      }).toList(),
    );
  }
}
