import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/app/owner_screen/carrier_setup_screen.dart';
import 'package:driver/controllers/carrier_settings_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// The owner's "Carrier settings" (APP-DEV-BRIEF 12 Oct 2026 section 6): the
/// carrier the admin bound to this owner account, its price per region
/// (the four prices and the five door / pickup-point values), the delivery
/// scopes and the service parameters. With none bound yet, the owner sets
/// one up ([CarrierSetupScreen], 13 Oct 2026).
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
        final bool published = controller.published.value;
        final String carrierId = controller.carrierId.value;
        final List<String> pricedRegions = controller.pricedRegionIds.toList();
        final Map<String, String> regionLabels = Map<String, String>.from(controller.regionLabels);
        final Map<String, String> errors = Map<String, String>.from(controller.errors);

        return DsScaffold(
          title: 'Carrier settings'.tr,
          subtitle: 'Carrier Management for Parcel Delivery'.tr,
          body: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                  child: DsSkeletonForm(fields: 6),
                )
              : !controller.isOwner.value
                  ? DsEmptyState(
                      icon: Icons.lock_outline_rounded,
                      tone: DsTone.brand,
                      title: "Carrier settings are for company owners only.".tr,
                    )
              : !linked
                  ? DsEmptyState(
                      icon: Icons.local_shipping_outlined,
                      tone: DsTone.brand,
                      title: "You have not set up your carrier yet.".tr,
                      message: "Enter your carrier's details to receive parcel orders from customers.".tr,
                      actionLabel: "Set up your carrier".tr,
                      actionIcon: Icons.add_business_outlined,
                      onAction: () async {
                        final created = await Get.to(() => const CarrierSetupScreen());
                        if (created == true) controller.load();
                      },
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
                                  DsIconWell(
                                    icon: verified ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                                    tone: verified ? DsTone.success : DsTone.warning,
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(verified ? "Verified carrier".tr : "Verification pending".tr, style: context.dsText.titleSm.w700),
                                        Text(published ? "Published".tr : "Not published".tr, style: context.dsText.bodySm),
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

                            // ── Identity ──────────────────────────────────────────
                            DsFormSection(
                              title: "Carrier Identity".tr,
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
                                  prefix: CountryCodePicker(
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
                                DsTextField(
                                  label: 'Email Address'.tr,
                                  hint: 'Enter carrier email address'.tr,
                                  controller: controller.controllerFor('email'),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  bottomSpacing: 0,
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),

                            // ── Delivery Scopes ───────────────────────────────────
                            DsFormSection(
                              title: "Delivery Scopes".tr,
                              subtitle: "Select the operational scopes this carrier handles (at least one required).".tr,
                              icon: Icons.alt_route_rounded,
                              children: [
                                _scopeCheckbox(
                                  context,
                                  title: 'Within City'.tr,
                                  subtitle: 'Local deliveries inside the same city'.tr,
                                  checked: controller.deliveryScopes.contains(CarrierSettingsController.scopeCity),
                                  onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeCity),
                                ),
                                const DsGap(DsSpace.sm),
                                _scopeCheckbox(
                                  context,
                                  title: 'Between Cities'.tr,
                                  subtitle: 'Intercity deliveries across different cities'.tr,
                                  checked: controller.deliveryScopes.contains(CarrierSettingsController.scopeIntercity),
                                  onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeIntercity),
                                ),
                                const DsGap(DsSpace.sm),
                                _scopeCheckbox(
                                  context,
                                  title: 'Between Countries'.tr,
                                  subtitle: 'Cross-border deliveries between countries'.tr,
                                  checked: controller.deliveryScopes.contains(CarrierSettingsController.scopeIntercountry),
                                  onTap: () => controller.toggleDeliveryScope(CarrierSettingsController.scopeIntercountry),
                                ),
                                if (errors.containsKey('deliveryScopes')) ...[
                                  const DsGap(DsSpace.sm),
                                  Text(
                                    errors['deliveryScopes']!,
                                    style: context.dsText.caption.copyWith(color: context.dsColors.danger),
                                  ),
                                ],
                              ],
                            ),
                            const DsGap(DsSpace.lg),

                            // ── Pricing ───────────────────────────────────────────
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
                              DsFormSection(
                                title: "Pricing per region".tr,
                                subtitle: "Each region you serve has its own prices, in that region's currency. Leave a door / pickup-point value empty to use the region's default; 0 means free.".tr,
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
                                    _regionField(controller, errors, regionId, 'minimumCharge', 'Minimum Charge'.tr, 'e.g. 1000'),
                                    _regionField(controller, errors, regionId, 'volumetricDivisor', 'Volumetric Divisor'.tr, controller.regionHint(regionId, 'volumetricDivisor')),
                                    _regionField(controller, errors, regionId, 'homePickupCharge', 'Home Pickup Charge'.tr, controller.regionHint(regionId, 'homePickupCharge')),
                                    _regionField(controller, errors, regionId, 'pointDropoffCharge', 'Point Drop-off Charge'.tr, controller.regionHint(regionId, 'pointDropoffCharge')),
                                    _regionField(controller, errors, regionId, 'homeDeliveryCharge', 'Home Delivery Charge'.tr, controller.regionHint(regionId, 'homeDeliveryCharge')),
                                    _regionField(
                                      controller,
                                      errors,
                                      regionId,
                                      'pointCollectionCharge',
                                      'Point Collection Charge'.tr,
                                      controller.regionHint(regionId, 'pointCollectionCharge'),
                                      last: regionId == pricedRegions.last,
                                    ),
                                    if (regionId != pricedRegions.last) const DsGap(DsSpace.md),
                                  ],
                                ],
                              ),
                            const DsGap(DsSpace.lg),

                            // ── Service Parameters ────────────────────────────────
                            DsFormSection(
                              title: "Service Parameters".tr,
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

                            // ── Regions (no documents here: the administrator
                            // checks the company, the app submits none) ─────────
                            DsFormSection(
                              title: "Regions served".tr,
                              icon: Icons.map_outlined,
                              children: [
                                if (controller.code.value.isNotEmpty)
                                  DsInfoRow(label: 'Carrier Code'.tr, value: controller.code.value, divider: true),
                                DsInfoRow(
                                  label: 'Regions'.tr,
                                  value: controller.regionNames.isEmpty ? '—' : controller.regionNames.join(', '),
                                ),
                              ],
                            ),
                            if (carrierId.isNotEmpty) ...[
                              const DsGap(DsSpace.lg),
                              DsInlineAlert(
                                tone: DsTone.info,
                                icon: Icons.info_outline_rounded,
                                message: "${'Carrier reference'.tr}: $carrierId",
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
          bottomBar: (isLoading || !linked || !controller.isOwner.value)
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Save Changes".tr,
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
        return unit;
    }
  }

  static Widget _scopeCheckbox(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool checked,
    required VoidCallback onTap,
  }) {
    final c = DsColors.of(context);
    final t = context.dsText;
    return DsCard(
      onTap: onTap,
      borderColor: checked ? c.brand : null,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            activeColor: c.brand,
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
