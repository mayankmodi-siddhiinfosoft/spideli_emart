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
                                  textInputAction: TextInputAction.next,
                                ),
                                DsTextField(
                                  label: 'Contact Person'.tr,
                                  hint: 'Enter the contact person'.tr,
                                  controller: controller.controllerFor('contactName'),
                                  textInputAction: TextInputAction.next,
                                  bottomSpacing: 0,
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            DsFormSection(
                              title: "Contact".tr,
                              icon: Icons.contact_phone_outlined,
                              children: [
                                DsTextField(
                                  label: 'Phone Number'.tr,
                                  hint: 'Enter phone number'.tr,
                                  controller: controller.controllerFor('phone'),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                                  textInputAction: TextInputAction.next,
                                ),
                                DsTextField(
                                  label: 'Email'.tr,
                                  hint: 'Enter email address'.tr,
                                  controller: controller.controllerFor('email'),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  bottomSpacing: 0,
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            DsFormSection(
                              title: "Service".tr,
                              icon: Icons.tune_rounded,
                              children: [
                                DsTextField(
                                  label: 'Rates'.tr,
                                  hint: 'e.g. 1500 per kg'.tr,
                                  controller: controller.controllerFor('rates'),
                                  textInputAction: TextInputAction.next,
                                ),
                                DsTextField(
                                  label: 'Maximum Weight'.tr,
                                  hint: 'e.g. 30 kg'.tr,
                                  controller: controller.controllerFor('maxWeight'),
                                  textInputAction: TextInputAction.next,
                                ),
                                DsTextField(
                                  label: 'Delivery Times'.tr,
                                  hint: 'e.g. 24 - 48 hours'.tr,
                                  controller: controller.controllerFor('deliveryTimes'),
                                  textInputAction: TextInputAction.next,
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
}
