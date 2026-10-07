import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/controllers/carrier_settings_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Client point 18 — the carrier settings a company registered in the driver
/// app maintains itself (admin spec §11, `delivery_carriers`).
///
/// Archetype H: grouped `DsFormSection`s over a sticky save. Verification is
/// read-only: only the admin panel may verify a carrier.
class CarrierSettingsScreen extends StatelessWidget {
  const CarrierSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CarrierSettingsController(),
      builder: (CarrierSettingsController controller) {
        final bool isLoading = controller.isLoading.value;
        final bool linked = controller.carrier.value != null;
        final bool verified = controller.isVerified.value;
        final String carrierId = controller.carrierId.value;
        final List<String> pricedRegions = controller.pricedRegionIds.toList();
        final Map<String, String> regionLabels = Map<String, String>.from(controller.regionLabels);
        final Map<String, String> errors = Map<String, String>.from(controller.errors);

        return DsScaffold(
          title: 'Carrier Settings'.tr,
          subtitle: 'Your delivery company on the platform'.tr,
          body: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                  child: DsSkeletonForm(fields: 6),
                )
              : !linked
                  ? DsEmptyState(
                      icon: Icons.local_shipping_outlined,
                      tone: DsTone.warning,
                      title: "No carrier is linked to your company yet".tr,
                      message:
                          "Your company is not registered as a carrier in the admin panel, so there are no carrier settings to manage here. Ask the administrator to create the carrier and link it to your account."
                              .tr,
                      actionLabel: "Check again".tr,
                      actionIcon: Icons.refresh_rounded,
                      onAction: controller.load,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      child: DsResponsive(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: DsFadeSlideIn.stagger([
                            DsCard.tinted(
                              tone: verified ? DsTone.success : DsTone.warning,
                              child: Row(
                                children: [
                                  DsIconWell(icon: verified ? Icons.verified_rounded : Icons.hourglass_bottom_rounded, tone: verified ? DsTone.success : DsTone.warning),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(verified ? "Verified carrier".tr : "Verification pending".tr, style: context.dsText.titleSm.w700),
                                        Text(
                                          "Only the administrator can change this.".tr,
                                          style: context.dsText.bodySm,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.lg),
                            DsFormSection(
                              title: "Identity".tr,
                              icon: Icons.local_shipping_outlined,
                              children: [
                                DsTextField(
                                  label: 'Carrier Name'.tr,
                                  hint: 'Enter carrier name'.tr,
                                  requiredMark: true,
                                  controller: controller.controllerFor('name'),
                                  errorText: controller.errors['name'],
                                  textInputAction: TextInputAction.next,
                                ),
                                DsTextField(
                                  label: 'Phone Number'.tr,
                                  hint: 'Enter phone number'.tr,
                                  controller: controller.controllerFor('phone'),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                                  textInputAction: TextInputAction.next,
                                  bottomSpacing: 0,
                                  prefix: CountryCodePicker(
                                    // Start-up selection: recorded, never counted as a change.
                                    onInit: (value) => controller.onPickerShown(value?.dialCode),
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
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            if (pricedRegions.isEmpty)
                              DsFormSection(
                                title: "Pricing".tr,
                                icon: Icons.payments_outlined,
                                children: [
                                  _numberField(controller, 'baseCharge', 'Base Charge'.tr, 'e.g. 500'),
                                  _numberField(controller, 'perKmCharge', 'Charge per km'.tr, 'e.g. 75'),
                                  _numberField(controller, 'perKgCharge', 'Charge per kg'.tr, 'e.g. 200'),
                                  _numberField(controller, 'minimumCharge', 'Minimum Charge'.tr, 'e.g. 1000', last: true),
                                ],
                              )
                            else
                              // Report Doc 43: one price list per region served.
                              DsFormSection(
                                title: "Pricing per region".tr,
                                subtitle: "Each region you serve has its own prices.".tr,
                                icon: Icons.payments_outlined,
                                children: [
                                  for (final regionId in pricedRegions) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                      child: Text(regionLabels[regionId] ?? regionId, style: context.dsText.titleSm),
                                    ),
                                    _regionField(controller, errors, regionId, 'baseCharge', 'Base Charge'.tr, 'e.g. 500'),
                                    _regionField(controller, errors, regionId, 'perKmCharge', 'Charge per km'.tr, 'e.g. 75'),
                                    _regionField(controller, errors, regionId, 'perKgCharge', 'Charge per kg'.tr, 'e.g. 200'),
                                    _regionField(controller, errors, regionId, 'minimumCharge', 'Minimum Charge'.tr, 'e.g. 1000',
                                        last: regionId == pricedRegions.last),
                                  ],
                                ],
                              ),
                            const DsGap(DsSpace.lg),
                            DsFormSection(
                              title: "Service".tr,
                              icon: Icons.tune_rounded,
                              children: [
                                _numberField(controller, 'maxWeight', 'Maximum Weight (kg)'.tr, 'e.g. 30'),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _numberField(controller, 'minDeliveryTime', 'Minimum Delivery Time'.tr, 'e.g. 1')),
                                    const DsGap(DsSpace.md),
                                    Expanded(child: _numberField(controller, 'maxDeliveryTime', 'Maximum Delivery Time'.tr, 'e.g. 3')),
                                  ],
                                ),
                                DsDropdown<String>(
                                  label: 'Delivery Time Unit'.tr,
                                  hint: 'Select'.tr,
                                  value: controller.deliveryTimeUnit.value.isEmpty ? null : controller.deliveryTimeUnit.value,
                                  items: controller.deliveryTimeUnitOptions
                                      .map((unit) => DropdownMenuItem<String>(value: unit, child: Text(_unitLabel(unit))))
                                      .toList(),
                                  onChanged: controller.setDeliveryTimeUnit,
                                ),
                                DsTextField(
                                  label: 'Conditions'.tr,
                                  hint: 'Conditions of carriage'.tr,
                                  controller: controller.controllerFor('conditions'),
                                  minLines: 3,
                                  maxLines: 6,
                                  textInputAction: TextInputAction.newline,
                                  bottomSpacing: 0,
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            DsFormSection(
                              title: "Registration".tr,
                              subtitle: "Verified by the administrator. Contact them to change these.".tr,
                              icon: Icons.badge_outlined,
                              children: [
                                DsInfoRow(label: 'Carrier Code'.tr, value: _orDash(controller.code.value), divider: true),
                                DsInfoRow(
                                  label: 'Regions'.tr,
                                  value: controller.regionNames.isEmpty ? '—' : controller.regionNames.join(', '),
                                  divider: true,
                                ),
                                DsInfoRow(label: 'Operating Licence'.tr, value: _withFile(controller, 'operatingLicence'), divider: true),
                                DsInfoRow(label: 'Commercial Register'.tr, value: _withFile(controller, 'commercialRegister'), divider: true),
                                DsInfoRow(label: 'Unique ID Number'.tr, value: _withFile(controller, 'uniqueIdNumber')),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            DsInlineAlert(
                              tone: DsTone.info,
                              icon: Icons.info_outline_rounded,
                              message: "${'Carrier reference'.tr}: $carrierId",
                            ),
                          ]),
                        ),
                      ),
                    ),
          bottomBar: isLoading || !linked
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Save".tr,
                    icon: Icons.check_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    loading: controller.isSaving.value,
                    onPressed: controller.save,
                  ),
                ),
        );
      },
    );
  }

  static Widget _numberField(CarrierSettingsController controller, String field, String label, String hint, {bool last = false}) {
    return DsTextField(
      label: label,
      hint: hint,
      controller: controller.controllerFor(field),
      errorText: controller.errors[field],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      bottomSpacing: last ? 0 : DsSpace.lg,
    );
  }

  static Widget _regionField(CarrierSettingsController controller, Map<String, String> errors, String regionId, String field, String label, String hint,
      {bool last = false}) {
    return DsTextField(
      label: label,
      hint: hint,
      controller: controller.regionControllerFor(regionId, field),
      errorText: errors[CarrierSettingsController.regionKey(regionId, field)],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      bottomSpacing: last ? 0 : DsSpace.lg,
    );
  }

  static String _unitLabel(String unit) {
    switch (unit) {
      case 'hours':
        return 'Hours'.tr;
      case 'days':
        return 'Days'.tr;
      default:
        return unit; // a value the panel stored that is not ours, shown as is
    }
  }

  static String _orDash(String value) => value.isEmpty ? '—' : value;

  static String _withFile(CarrierSettingsController controller, String field) {
    final String number = controller.identification[field] ?? '';
    final bool hasFile = controller.identificationFiles['${field}File'] ?? false;
    final String file = hasFile ? 'Document on file'.tr : 'No document'.tr;
    return number.isEmpty ? file : '$number · $file';
  }
}
