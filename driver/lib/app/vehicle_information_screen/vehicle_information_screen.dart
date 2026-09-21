import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/vehicle_information_controller.dart';

class VehicleInformationScreen extends StatelessWidget {
  final String serviceType;

  const VehicleInformationScreen({
    super.key,
    this.serviceType = 'delivery-service',
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetBuilder<VehicleInformationController>(
        init: VehicleInformationController(initialServiceType: serviceType),
        tag: serviceType,
        builder: (controller) {
          final isOwnerDriver = controller.userModel.value.ownerId != null &&
              controller.userModel.value.ownerId!.isNotEmpty;

          return Scaffold(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.grey100,
            body: controller.isLoading.value
                ? Center(child: Constant.loader())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Service badge ──────────────────────────────────
                        Row(
                          children: [
                            Icon(Icons.directions_car_rounded,
                                size: 16, color: AppThemeData.primary300),
                            const SizedBox(width: 6),
                            Text(
                              controller.selectedService.value,
                              style: TextStyle(
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 13,
                                color: AppThemeData.primary300,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Section cards (with per-section car details) ──
                        ...controller.driverSections.map((section) {
                          final sid = section.id ?? '';
                          final vehicleTypes =
                              controller.vehicleTypesPerSection[sid] ?? <VehicleType>[].obs;
                          final selectedVehicle =
                              controller.selectedVehiclePerSection[sid] ?? VehicleType().obs;

                          return _SectionCard(
                            section: section,
                            vehicleTypes: vehicleTypes,
                            selectedVehicle: selectedVehicle,
                            serviceType: serviceType,
                            selectedRideType: controller.selectedRideTypePerSection[sid] ?? RxString('ride'),
                            isOwnerDriver: isOwnerDriver,
                            isDark: isDark,
                            carMakesList: controller.carMakesList,
                            selectedCarMakes: controller.selectedCarMakesPerSection[sid] ?? Rx<CarMakes>(CarMakes()),
                            carModelList: controller.carModelListPerSection[sid] ?? <CarModel>[].obs,
                            selectedCarModel: controller.selectedCarModelPerSection[sid] ?? Rx<CarModel>(CarModel()),
                            carPlateController: controller.carPlatePerSection[sid]?.value ?? TextEditingController(),
                            onCarMakesChanged: (v) {
                              controller.selectedCarMakesPerSection[sid]?.value = v!;
                              controller.getCarModelForSection(sid);
                              controller.update();
                            },
                            onCarModelChanged: (v) {
                              controller.selectedCarModelPerSection[sid]?.value = v!;
                              controller.update();
                            },
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
            bottomNavigationBar: isOwnerDriver || controller.isLoading.value
                ? const SizedBox.shrink()
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        onPressed: () => controller.saveVehicleInformation(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeData.primary300,
                          minimumSize: Size(Responsive.width(100, context), 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Save".tr,
                          style: TextStyle(
                            color: AppThemeData.grey50,
                            fontSize: 16,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      );
    });
  }
}

// ── Section card widget ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final SectionModel section;
  final RxList<VehicleType> vehicleTypes;
  final Rx<VehicleType> selectedVehicle;
  final String serviceType;
  final RxString selectedRideType;
  final bool isOwnerDriver;
  final bool isDark;
  final RxList<CarMakes> carMakesList;
  final Rx<CarMakes> selectedCarMakes;
  final RxList<CarModel> carModelList;
  final Rx<CarModel> selectedCarModel;
  final TextEditingController carPlateController;
  final ValueChanged<CarMakes?> onCarMakesChanged;
  final ValueChanged<CarModel?> onCarModelChanged;

  const _SectionCard({
    required this.section,
    required this.vehicleTypes,
    required this.selectedVehicle,
    required this.serviceType,
    required this.selectedRideType,
    required this.isOwnerDriver,
    required this.isDark,
    required this.carMakesList,
    required this.selectedCarMakes,
    required this.carModelList,
    required this.selectedCarModel,
    required this.carPlateController,
    required this.onCarMakesChanged,
    required this.onCarModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
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
                    fontSize: 15,
                    color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vehicle type dropdown
          if (vehicleTypes.isEmpty)
            Text(
              "No vehicle types for this section".tr,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey500,
              ),
            )
          else
            _DropdownField<VehicleType>(
              label: "Vehicle Type".tr,
              value: selectedVehicle.value,
              items: vehicleTypes,
              isDark: isDark,
              enabled: !isOwnerDriver,
              onChanged: (v) => selectedVehicle.value = v!,
            ),

          // Ride type (cab only)
          if (serviceType == 'cab-service' &&
              (section.rideType == 'ride' ||
                  section.rideType == 'intercity' ||
                  section.rideType == 'both')) ...[
            const SizedBox(height: 12),
            Text(
              "Ride Type".tr,
              style: TextStyle(
                fontFamily: AppThemeData.semiBold,
                fontSize: 13,
                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (section.rideType == 'ride' || section.rideType == 'both')
                  _RideTypeOption(
                    label: 'Ride'.tr,
                    value: 'ride',
                    groupValue: selectedRideType.value,
                    isDark: isDark,
                    onChanged: (v) => selectedRideType.value = v!,
                  ),
                if (section.rideType == 'intercity' || section.rideType == 'both')
                  _RideTypeOption(
                    label: 'Intercity'.tr,
                    value: 'intercity',
                    groupValue: selectedRideType.value,
                    isDark: isDark,
                    onChanged: (v) => selectedRideType.value = v!,
                  ),
                if (section.rideType == 'both')
                  _RideTypeOption(
                    label: 'Both'.tr,
                    value: 'both',
                    groupValue: selectedRideType.value,
                    isDark: isDark,
                    onChanged: (v) => selectedRideType.value = v!,
                  ),
              ],
            ),
          ],

          // ── Per-section Car Details ──────────────────────────────
          const SizedBox(height: 16),
          _SectionTitle(label: "Car Details".tr, isDark: isDark),
          const SizedBox(height: 12),
          _DropdownField<CarMakes>(
            label: "Car Brand".tr,
            value: selectedCarMakes.value,
            items: carMakesList,
            isDark: isDark,
            enabled: !isOwnerDriver,
            onChanged: onCarMakesChanged,
          ),
          const SizedBox(height: 12),
          _DropdownField<CarModel>(
            label: "Car Model".tr,
            value: selectedCarModel.value,
            items: carModelList,
            isDark: isDark,
            enabled: !isOwnerDriver,
            onChanged: onCarModelChanged,
          ),
          const SizedBox(height: 12),
          TextFieldWidget(
            title: 'Car Plate Number'.tr,
            controller: carPlateController,
            hintText: 'e.g. GJ05JH9405'.tr,
            textInputAction: TextInputAction.done,
            enable: !isOwnerDriver,
          ),
        ],
      ),
    ));
  }
}

class _RideTypeOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _RideTypeOption({
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

// ── Shared card container ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionTitle({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppThemeData.primary300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 15,
            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey800,
          ),
        ),
      ],
    );
  }
}

// ── Reusable dropdown ─────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final bool isDark;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.isDark,
    required this.enabled,
    required this.onChanged,
  });

  String _labelFor(T item) {
    if (item is String) return item;
    if (item is SectionModel) return item.name ?? '';
    if (item is VehicleType) return item.name ?? '';
    if (item is CarMakes) return item.name ?? '';
    if (item is CarModel) return item.name ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final borderColor = isDark ? AppThemeData.greyDark400 : AppThemeData.grey300;
    final fillColor = isDark ? AppThemeData.greyDark100 : AppThemeData.grey50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 13,
            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: items.contains(value) ? value : null,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          dropdownColor: isDark ? AppThemeData.greyDark100 : AppThemeData.surface,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppThemeData.primary300, width: 1.5),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontFamily: AppThemeData.medium,
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: borderColor),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                _labelFor(item),
                style: TextStyle(fontSize: 14, color: textColor, fontFamily: AppThemeData.medium),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
