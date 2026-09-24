import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/vehicle_information_controller.dart';

/// Archetype G – vehicle information: a service header, then one card per
/// section with its vehicle type, ride type and car details. Fleet drivers
/// see the same data read-only (no Save bar), exactly as before.
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
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds this screen when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetBuilder<VehicleInformationController>(
        init: VehicleInformationController(initialServiceType: serviceType),
        tag: serviceType,
        builder: (controller) {
          final c = context.dsColors;
          final isOwnerDriver = controller.userModel.value.ownerId != null &&
              controller.userModel.value.ownerId!.isNotEmpty;

          return Scaffold(
            backgroundColor: c.background,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                child: DsSkeletonForm(fields: 4),
              ),
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.huge),
                child: DsResponsive(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      // ── Service badge ──────────────────────────────────
                      Row(
                        children: [
                          DsSectionBadge(
                            section: DsSection.fromServiceType(serviceType),
                            label: controller.selectedService.value,
                          ),
                          const Spacer(),
                          if (isOwnerDriver)
                            DsBadge(
                              label: "Managed by your fleet owner".tr,
                              tone: DsTone.info,
                              icon: Icons.lock_outline_rounded,
                              small: true,
                            ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

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
                      if (controller.driverSections.isEmpty)
                        DsEmptyState(
                          icon: Icons.directions_car_outlined,
                          title: "No vehicle types for this section".tr,
                          compact: true,
                        ),
                      const DsGap(DsSpace.lg),
                    ], offset: const Offset(0, 18)),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: isOwnerDriver || controller.isLoading.value
                ? const SizedBox.shrink()
                : DsStickyBar(
                    child: DsButton.primary(
                      label: "Save".tr,
                      icon: Icons.check_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () => controller.saveVehicleInformation(),
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
    // Every observable below is read synchronously inside this Obx closure.
    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      final types = vehicleTypes.toList();
      final VehicleType vehicle = selectedVehicle.value;
      final String rideType = selectedRideType.value;
      final makes = carMakesList.toList();
      final CarMakes make = selectedCarMakes.value;
      final models = carModelList.toList();
      final CarModel model = selectedCarModel.value;
      final showRideType = serviceType == 'cab-service' &&
          (section.rideType == 'ride' || section.rideType == 'intercity' || section.rideType == 'both');

      return Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.md),
        child: DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  DsIconWell(icon: Icons.directions_car_rounded, tone: DsTone.brand, size: 40),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Text(
                      section.name ?? '',
                      style: t.titleSm,
                    ),
                  ),
                ],
              ),
              const DsGap(DsSpace.lg),

              // Vehicle type dropdown
              if (types.isEmpty)
                Text(
                  "No vehicle types for this section".tr,
                  style: t.bodySm,
                )
              else
                _DropdownField<VehicleType>(
                  label: "Vehicle Type".tr,
                  value: vehicle,
                  items: types,
                  enabled: !isOwnerDriver,
                  onChanged: (v) => selectedVehicle.value = v!,
                ),

              // Ride type (cab only)
              if (showRideType) ...[
                const DsGap(DsSpace.md),
                DsFieldLabel("Ride Type".tr),
                Row(
                  children: [
                    if (section.rideType == 'ride' || section.rideType == 'both')
                      _RideTypeOption(
                        label: 'Ride'.tr,
                        value: 'ride',
                        groupValue: rideType,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'intercity' || section.rideType == 'both')
                      _RideTypeOption(
                        label: 'Intercity'.tr,
                        value: 'intercity',
                        groupValue: rideType,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                    if (section.rideType == 'both')
                      _RideTypeOption(
                        label: 'Both'.tr,
                        value: 'both',
                        groupValue: rideType,
                        onChanged: (v) => selectedRideType.value = v!,
                      ),
                  ],
                ),
              ],

              // ── Per-section Car Details ──────────────────────────────
              const DsGap(DsSpace.lg),
              DsDivider(spacing: DsSpace.sm),
              const DsGap(DsSpace.md),
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: c.brandStrong),
                  const DsGap(DsSpace.sm),
                  Text("Car Details".tr, style: t.titleSm),
                ],
              ),
              const DsGap(DsSpace.lg),
              _DropdownField<CarMakes>(
                label: "Car Brand".tr,
                value: make,
                items: makes,
                enabled: !isOwnerDriver,
                onChanged: onCarMakesChanged,
              ),
              const DsGap(DsSpace.md),
              _DropdownField<CarModel>(
                label: "Car Model".tr,
                value: model,
                items: models,
                enabled: !isOwnerDriver,
                onChanged: onCarModelChanged,
              ),
              const DsGap(DsSpace.md),
              DsTextField(
                label: 'Car Plate Number'.tr,
                controller: carPlateController,
                hint: 'e.g. GJ05JH9405'.tr,
                textInputAction: TextInputAction.done,
                enabled: !isOwnerDriver,
                prefixIcon: Icons.confirmation_number_outlined,
                textCapitalization: TextCapitalization.characters,
                bottomSpacing: 0,
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Selectable ride-type pill (cab sections).
class _RideTypeOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RideTypeOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final selected = groupValue == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: DsSpace.sm),
        child: DsCard.outlined(
          onTap: () => onChanged(value),
          borderColor: selected ? c.brand : null,
          color: selected ? c.brandSoft : null,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.md),
          semanticLabel: label,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: selected ? t.bodyStrong.withColor(c.brandStrong) : t.bodyStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable dropdown ─────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
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
    final t = context.dsText;
    return DsDropdown<T>(
      label: label,
      value: items.contains(value) ? value : null,
      onChanged: enabled ? onChanged : null,
      bottomSpacing: 0,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(_labelFor(item), style: t.bodyStrong),
        );
      }).toList(),
    );
  }
}
