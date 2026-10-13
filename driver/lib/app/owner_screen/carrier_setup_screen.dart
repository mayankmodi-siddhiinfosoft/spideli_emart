import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/controllers/carrier_settings_controller.dart';
import 'package:driver/controllers/carrier_setup_controller.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/carrier_settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// "Set up your carrier" (13 Oct 2026): the company owner enters its own
/// carrier details. Returns `true` (Get.back result) once the carrier is
/// created and bound; Carrier settings then shows it with its prices per
/// region. The carrier is offered to customers only after the
/// administrator verifies and publishes it.
class CarrierSetupScreen extends StatelessWidget {
  const CarrierSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CarrierSetupController(),
      builder: (CarrierSetupController controller) {
        final Map<String, String> errors = Map<String, String>.from(controller.errors);
        final Map<String, String> picked = Map<String, String>.from(controller.pickedFiles);
        final List<String> checkedRegions = controller.regionIds.toList();
        final List<String> scopes = controller.deliveryScopes.toList();

        return DsScaffold(
          title: 'Set up your carrier'.tr,
          subtitle: 'Carrier Management for Parcel Delivery'.tr,
          body: controller.isLoading.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                  child: DsSkeletonForm(fields: 6),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  child: DsResponsive(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        DsInlineAlert(
                          tone: DsTone.info,
                          icon: Icons.local_shipping_outlined,
                          message: "Enter your carrier's details. Customers can choose your carrier once the administrator has verified and published it.".tr,
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Identity ──────────────────────────────────────────
                        DsFormSection(
                          title: "Carrier Identity".tr,
                          icon: Icons.local_shipping_outlined,
                          children: [
                            _imageRow(context, controller, picked, 'photo', 'Carrier Logo'.tr),
                            const DsGap(DsSpace.lg),
                            DsTextField(
                              label: 'Carrier Name'.tr,
                              hint: 'Enter carrier name'.tr,
                              requiredMark: true,
                              controller: controller.controllerFor('name'),
                              errorText: errors['name'],
                              textInputAction: TextInputAction.next,
                            ),
                            DsTextField(
                              label: 'Phone Number'.tr,
                              hint: 'Enter phone number'.tr,
                              requiredMark: true,
                              controller: controller.controllerFor('phone'),
                              errorText: errors['phone'],
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                              textInputAction: TextInputAction.next,
                              prefix: CountryCodePicker(
                                onInit: (value) {
                                  if (controller.countryCode.value.isEmpty) controller.setCountryCode(value?.dialCode);
                                },
                                onChanged: (value) => controller.setCountryCode(value.dialCode),
                                initialSelection: controller.pickerInitialSelection.isEmpty ? null : controller.pickerInitialSelection,
                                dialogTextStyle: context.dsText.bodyStrong,
                                dialogBackgroundColor: context.dsColors.surfaceRaised,
                                comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                                textStyle: context.dsText.bodyStrong,
                                searchDecoration: InputDecoration(iconColor: context.dsColors.iconDefault),
                                searchStyle: context.dsText.bodyStrong,
                              ),
                            ),
                            DsTextField(
                              label: 'Email Address'.tr,
                              hint: 'Enter carrier email address'.tr,
                              controller: controller.controllerFor('email'),
                              errorText: errors['email'],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              bottomSpacing: 0,
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Regions ───────────────────────────────────────────
                        DsFormSection(
                          title: "Regions served".tr,
                          subtitle: "Select the regions where your carrier delivers (at least one).".tr,
                          icon: Icons.map_outlined,
                          children: [
                            if (controller.regions.isEmpty)
                              Text("No region is available yet. Please contact Spideli.".tr, style: context.dsText.bodySm)
                            else
                              for (final region in controller.regions) ...[
                                _checkTile(
                                  context,
                                  title: region.name ?? region.id ?? '',
                                  subtitle: '',
                                  checked: checkedRegions.contains(region.id),
                                  onTap: () => controller.toggleRegion(region.id ?? ''),
                                ),
                                if (region != controller.regions.last) const DsGap(DsSpace.sm),
                              ],
                            if (errors.containsKey('regionIds')) _error(context, errors['regionIds']!),
                          ],
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Pricing per region (required to create) ───────────
                        DsFormSection(
                          title: "Pricing per region".tr,
                          subtitle: "Each region you serve has its own prices, in that region's currency. Leave a door / pickup-point value empty to use the region's default; 0 means free.".tr,
                          icon: Icons.payments_outlined,
                          children: [
                            if (checkedRegions.isEmpty)
                              Text("Select a region to enter its prices.".tr, style: context.dsText.bodySm)
                            else
                              for (final regionId in checkedRegions) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                  child: Text(controller.regionLabel(regionId), style: context.dsText.titleSm),
                                ),
                                _priceField(controller, errors, regionId, 'baseCharge', 'Base Charge'.tr, 'e.g. 500', required: true),
                                _priceField(controller, errors, regionId, 'perKmCharge', 'Charge per km'.tr, 'e.g. 75', required: true),
                                _priceField(controller, errors, regionId, 'perKgCharge', 'Charge per kg'.tr, 'e.g. 200', required: true),
                                _priceField(controller, errors, regionId, 'minimumCharge', 'Minimum Charge'.tr, 'e.g. 1000', required: true),
                                _priceField(controller, errors, regionId, 'volumetricDivisor', 'Volumetric Divisor'.tr, controller.regionHint(regionId, 'volumetricDivisor')),
                                _priceField(controller, errors, regionId, 'homePickupCharge', 'Home Pickup Charge'.tr, controller.regionHint(regionId, 'homePickupCharge')),
                                _priceField(controller, errors, regionId, 'pointDropoffCharge', 'Point Drop-off Charge'.tr, controller.regionHint(regionId, 'pointDropoffCharge')),
                                _priceField(controller, errors, regionId, 'homeDeliveryCharge', 'Home Delivery Charge'.tr, controller.regionHint(regionId, 'homeDeliveryCharge')),
                                _priceField(controller, errors, regionId, 'pointCollectionCharge', 'Point Collection Charge'.tr, controller.regionHint(regionId, 'pointCollectionCharge'),
                                    last: regionId == checkedRegions.last),
                                if (regionId != checkedRegions.last) const DsGap(DsSpace.md),
                              ],
                          ],
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Delivery Scopes ───────────────────────────────────
                        DsFormSection(
                          title: "Delivery Scopes".tr,
                          subtitle: "Select the operational scopes this carrier handles (at least one required).".tr,
                          icon: Icons.alt_route_rounded,
                          children: [
                            _checkTile(
                              context,
                              title: 'Within City'.tr,
                              subtitle: 'Local deliveries inside the same city'.tr,
                              checked: scopes.contains(CarrierSettingsController.scopeCity),
                              onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeCity),
                            ),
                            const DsGap(DsSpace.sm),
                            _checkTile(
                              context,
                              title: 'Between Cities'.tr,
                              subtitle: 'Intercity deliveries across different cities'.tr,
                              checked: scopes.contains(CarrierSettingsController.scopeIntercity),
                              onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeIntercity),
                            ),
                            const DsGap(DsSpace.sm),
                            _checkTile(
                              context,
                              title: 'Between Countries'.tr,
                              subtitle: 'Cross-border deliveries between countries'.tr,
                              checked: scopes.contains(CarrierSettingsController.scopeIntercountry),
                              onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeIntercountry),
                            ),
                            if (errors.containsKey(DeliveryCarrierModel.scopesField)) _error(context, errors[DeliveryCarrierModel.scopesField]!),
                          ],
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Service Parameters ────────────────────────────────
                        DsFormSection(
                          title: "Service Parameters".tr,
                          icon: Icons.tune_rounded,
                          children: [
                            _numberField(controller, errors, 'maxWeight', 'Maximum Weight (kg)'.tr, 'e.g. 30'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _numberField(controller, errors, 'minDeliveryTime', 'Minimum Delivery Time'.tr, 'e.g. 1')),
                                const DsGap(DsSpace.md),
                                Expanded(child: _numberField(controller, errors, 'maxDeliveryTime', 'Maximum Delivery Time'.tr, 'e.g. 3')),
                              ],
                            ),
                            DsDropdown<String>(
                              label: 'Delivery Time Unit'.tr,
                              hint: 'Select'.tr,
                              value: controller.deliveryTimeUnit.value.isEmpty ? null : controller.deliveryTimeUnit.value,
                              items: DeliveryCarrierModel.deliveryTimeUnits
                                  .map((unit) => DropdownMenuItem<String>(value: unit, child: Text(unit == 'days' ? 'Days'.tr : 'Hours'.tr)))
                                  .toList(),
                              onChanged: controller.setDeliveryTimeUnit,
                            ),
                            DsTextField(
                              label: 'Conditions'.tr,
                              hint: 'Conditions of carriage or special delivery terms'.tr,
                              controller: controller.controllerFor('conditions'),
                              minLines: 3,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              bottomSpacing: 0,
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),

                        // ── Registration ──────────────────────────────────────
                        DsFormSection(
                          title: "Company Registration".tr,
                          subtitle: "Checked by the administrator before your carrier is verified.".tr,
                          icon: Icons.badge_outlined,
                          children: [
                            for (final (field, label) in [
                              ('operatingLicence', 'Operating Licence'.tr),
                              ('commercialRegister', 'Commercial Register'.tr),
                              ('uniqueIdNumber', 'Unique ID Number'.tr),
                            ]) ...[
                              DsTextField(
                                label: label,
                                hint: label,
                                controller: controller.controllerFor(field),
                                textInputAction: TextInputAction.next,
                                bottomSpacing: DsSpace.sm,
                              ),
                              _imageRow(context, controller, picked, '${field}File', 'Document photo'.tr),
                              if (field != 'uniqueIdNumber') const DsGap(DsSpace.lg),
                            ],
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Create carrier".tr,
                    icon: Icons.check_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    loading: controller.isSaving.value,
                    onPressed: controller.isSaving.value
                        ? null
                        : () async {
                            if (await controller.submit()) Get.back(result: true);
                          },
                  ),
                ),
        );
      },
    );
  }

  static Widget _error(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.only(top: DsSpace.sm),
        child: Text(message, style: context.dsText.caption.copyWith(color: context.dsColors.danger)),
      );

  static Widget _numberField(CarrierSetupController controller, Map<String, String> errors, String field, String label, String hint) {
    return DsTextField(
      label: label,
      hint: hint,
      controller: controller.controllerFor(field),
      errorText: errors[field],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
    );
  }

  static Widget _priceField(CarrierSetupController controller, Map<String, String> errors, String regionId, String field, String label, String hint,
      {bool required = false, bool last = false}) {
    return DsTextField(
      label: label,
      hint: hint,
      requiredMark: required,
      controller: controller.regionControllerFor(regionId, field),
      errorText: errors[CarrierSettingsForm.regionKey(regionId, field)],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      bottomSpacing: last ? 0 : DsSpace.lg,
    );
  }

  /// A picked image (thumbnail + remove) or an "Add photo" button.
  static Widget _imageRow(BuildContext context, CarrierSetupController controller, Map<String, String> picked, String field, String label) {
    final c = context.dsColors;
    final String? path = picked[field];
    return Row(
      children: [
        ClipRRect(
          borderRadius: DsRadius.brMd,
          child: Container(
            width: 56,
            height: 56,
            color: c.surfaceAlt,
            child: path == null ? Icon(Icons.image_outlined, color: c.textMuted) : Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
        const DsGap(DsSpace.md),
        Expanded(child: Text(label, style: context.dsText.bodyStrong)),
        if (path != null)
          DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Remove'.tr, onPressed: () => controller.removeImage(field))
        else
          DsButton.tonal(
            label: 'Add photo'.tr,
            icon: Icons.add_a_photo_outlined,
            size: DsButtonSize.sm,
            onPressed: () => DsBottomSheet.show(
              title: label,
              child: Row(
                children: [
                  Expanded(
                    child: DsButton.secondary(
                      label: 'camera'.tr,
                      icon: Icons.camera_alt_rounded,
                      expand: true,
                      onPressed: () => controller.pickImage(field, ImageSource.camera),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: DsButton.secondary(
                      label: 'gallery'.tr,
                      icon: Icons.photo_library_rounded,
                      expand: true,
                      onPressed: () => controller.pickImage(field, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static Widget _checkTile(BuildContext context, {required String title, required String subtitle, required bool checked, required VoidCallback onTap}) {
    final c = DsColors.of(context);
    final t = context.dsText;
    return DsCard(
      onTap: onTap,
      borderColor: checked ? c.brand : null,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      child: Row(
        children: [
          Checkbox(value: checked, activeColor: c.brand, onChanged: (_) => onTap()),
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
