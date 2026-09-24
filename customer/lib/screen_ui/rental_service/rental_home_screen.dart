import 'package:customer/utils/region_service.dart';

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/rental_home_controller.dart';
import '../../models/rental_vehicle_type.dart';
import '../../themes/show_toast_dialog.dart';
import '../../utils/utils.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../auth_screens/login_screen.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;

import 'widget/rental_common_widgets.dart';

/// Rental home (archetype A — service home): a gradient hero with the greeting,
/// an overlapping "pickup + when" card, then the vehicle types as media cards.
/// The Continue action sits in a sticky bar and opens the package sheet.
class RentalHomeScreen extends StatelessWidget {
  const RentalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RentalHomeController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<RentalVehicleType> vehicleTypes = controller.vehicleTypes.toList();
        final String? selectedTypeId = controller.selectedVehicleType.value?.id;
        final String whenLabel = Constant.formatTimestamp(Timestamp.fromDate(controller.selectedDate.value));
        return DsScaffold.hero(
          onBack: () {
            log(":: Login  :: 22");
            Get.offAll(const ServiceListScreen());
          },
          hero: const _RentalHero(),
          heroOverlap: _TripCard(controller: controller, whenLabel: whenLabel),
          slivers: [
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: DsSkeletonList(itemCount: 4),
                ),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                bottom: DsSpace.xxl,
                sliver: SliverList.list(
                  children: [
                    DsSectionHeader(
                      title: "Select Your Vehicle Type".tr,
                      icon: Icons.directions_car_filled_outlined,
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                    ),
                    for (int i = 0; i < vehicleTypes.length; i++)
                      DsFadeSlideIn(
                        index: i,
                        child: _VehicleTypeCard(
                          vehicleType: vehicleTypes[i],
                          selected: selectedTypeId == vehicleTypes[i].id,
                          onTap: () {
                            controller.selectedVehicleType.value = controller.vehicleTypes[i];
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
          bottomBar: loading
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Continue".tr,
                    trailingIcon: Icons.arrow_forward_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      final sourceText = controller.sourceTextEditController.value.text.trim();
                      if (Constant.userModel == null) {
                        ShowToastDialog.showToast("Please login to continue".tr);
                        return;
                      }
                      if (sourceText.isEmpty) {
                        ShowToastDialog.showToast("Please select source location".tr);
                        return;
                      }

                      if (controller.selectedVehicleType.value == null) {
                        ShowToastDialog.showToast("Please select a vehicle type".tr);
                        return;
                      }

                      await controller.getRentalPackage();

                      if (controller.rentalPackages.isEmpty) {
                        ShowToastDialog.showToast("No preference available for the selected vehicle type".tr);
                        return;
                      }

                      // Open bottom sheet if packages exist
                      Get.bottomSheet(selectPreferences(controller), isScrollControlled: true, backgroundColor: Colors.transparent);
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget selectPreferences(RentalHomeController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.40,
      minChildSize: 0.40,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        // Built lazily: its own observer so package selection repaints.
        return DsObserve(
          builder: (context) => RentalSheetShell(
            title: "Select Preferences".tr,
            showClose: false,
            footer: DsButton.primary(
              label: "Continue".tr,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () {
                Get.bottomSheet(paymentBottomSheet(controller), isScrollControlled: true, backgroundColor: Colors.transparent);
              },
            ),
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.zero,
              itemCount: controller.rentalPackages.length,
              itemBuilder: (context, index) {
                final package = controller.rentalPackages[index];
                return Obx(
                  () => _PackageTile(
                    name: package.name ?? "",
                    description: package.description ?? "",
                    price: Constant.amountShow(amount: package.baseFare.toString(), currency: controller.quoteCurrency),
                    selected: controller.selectedPackage.value?.id == package.id,
                    onTap: () => controller.selectedPackage.value = package,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget paymentBottomSheet(RentalHomeController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      // Start height
      minChildSize: 0.30,
      // Minimum height
      maxChildSize: 0.8,
      // Maximum height
      expand: false,
      // Prevents full-screen takeover
      builder: (context, scrollController) {
        final t = context.dsText;
        // Reads of controller observables happen in this lazily-run builder.
        return DsObserve(
          builder: (context) => RentalSheetShell(
            title: "Select Payment Method".tr,
            footer: DsButton.primary(
              label: "Continue".tr,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                if (controller.selectedPaymentMethod.value.isEmpty) {
                  ShowToastDialog.showToast("Please select a payment method".tr);
                  return;
                }

                // Only check wallet if payment method is wallet
                if (controller.selectedPaymentMethod.value == "wallet") {
                  num walletAmount = controller.userModel.value.walletAmount ?? 0;
                  num baseFare = double.tryParse(controller.selectedPackage.value?.baseFare.toString() ?? "0") ?? 0;

                  if (walletAmount < baseFare) {
                    ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                    return;
                  }
                }
                // Complete the order
                controller.completeOrder();
              },
            ),
            // Payment options list
            child: ListView(
              padding: EdgeInsets.zero,
              controller: scrollController,
              children: [
                Text("Preferred Payment".tr, style: t.overline),
                const DsGap(DsSpace.sm),

                if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                  DsCard.outlined(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                    child: Column(
                      children: [
                        Visibility(visible: controller.walletSettingModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.wallet, "assets/images/ic_wallet.png")),
                        Visibility(visible: controller.cashOnDeliverySettingModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.cod, "assets/images/ic_cash.png")),
                      ],
                    ),
                  ),

                if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DsGap(DsSpace.lg),
                      Text("Other Payment Options".tr, style: t.overline),
                      const DsGap(DsSpace.sm),
                    ],
                  ),

                // Other gateways
                DsCard.outlined(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                  child: Column(
                    children: [
                      Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                      Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                      Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                      Visibility(visible: controller.mercadoPagoModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png")),
                      Visibility(visible: controller.flutterWaveModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png")),
                      Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, "assets/images/payfast.png")),
                      Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, "assets/images/razorpay.png")),
                      Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, "assets/images/midtrans.png")),
                      Visibility(visible: controller.orangeMoneyModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png")),
                      Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, "assets/images/xendit.png")),
                    ],
                  ),
                ),
                const DsGap(DsSpace.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  Obx cardDecoration(RentalHomeController controller, PaymentGateway value, String image) {
    return Obx(
      () => RentalPaymentRow(
        image: image,
        name: value.name,
        selected: controller.selectedPaymentMethod.value == value.name,
        walletAmount: value.name == "wallet"
            ? Constant.amountShow(amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString(), currency: RegionService.customerCurrency)
            : null,
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
      ),
    );
  }
}

/// Greeting (or "Login") on the gradient.
class _RentalHero extends StatelessWidget {
  const _RentalHero();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Constant.userModel == null
            ? InkWell(
                borderRadius: DsRadius.brXs,
                onTap: () {
                  Get.offAll(const LoginScreen());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Login".tr, style: t.labelSm.withColor(Colors.white)),
                      const DsGap(DsSpace.xs),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              )
            : Text(Constant.userModel!.fullName(), style: t.labelSm.withColor(Colors.white.withValues(alpha: 0.88))),
        const DsGap(DsSpace.xs),
        Text("Rent a vehicle".tr, style: t.display.withColor(Colors.white)),
      ],
    );
  }
}

/// Overlapping card: pickup location picker + when to start.
class _TripCard extends StatelessWidget {
  final RentalHomeController controller;
  final String whenLabel;

  const _TripCard({required this.controller, required this.whenLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    // The pickup field is read from the controller inside this child widget's
    // own build, so it needs its own observer.
    return DsObserve(
      builder: (context) => DsCard(
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsTextField(
              label: "Pickup Location".tr,
              hint: "Your current location".tr,
              controller: controller.sourceTextEditController.value,
              readOnly: true,
              prefix: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
                child: Icon(Icons.stop_circle_outlined, color: c.successStrong),
              ),
              suffix: const Icon(Icons.map_outlined),
              bottomSpacing: DsSpace.md,
              onTap: () async {
                if (Constant.selectedMapType == 'osm') {
                  final result = await Get.to(() => MapPickerPage());
                  if (result != null) {
                    final firstPlace = result;

                    if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                      final address = firstPlace.address;
                      final lat = firstPlace.coordinates.latitude;
                      final lng = firstPlace.coordinates.longitude;
                      controller.sourceTextEditController.value.text = address;
                      controller.departureLatLongOsm.value = latlong.LatLng(lat, lng);
                    } else {
                      ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                    }
                  }
                } else {
                  Get.to(LocationPickerScreen())!.then((value) async {
                    if (value != null) {
                      SelectedLocationModel selectedLocationModel = value;

                      if (Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                        controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                        controller.departureLatLong.value = latlong.LatLng(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                      } else {
                        ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                      }
                    }
                  });
                }
              },
            ),
            DsListTile(
              title: whenLabel,
              subtitle: "Pickup time".tr,
              leadingIcon: Icons.event_rounded,
              leadingTone: DsTone.brand,
              padding: EdgeInsets.zero,
              trailing: Text("Change".tr, style: t.link),
              onTap: () => controller.pickDateTime(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable vehicle type with its icon, name and description.
class _VehicleTypeCard extends StatelessWidget {
  final RentalVehicleType vehicleType;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleTypeCard({required this.vehicleType, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      borderColor: selected ? c.brand : null,
      color: selected ? c.brandSoft : null,
      semanticLabel: vehicleType.name ?? '',
      onTap: onTap,
      child: Row(
        children: [
          DsImage(url: vehicleType.rentalVehicleIcon.toString(), height: 60, width: 60, radius: DsRadius.sm, errorIcon: Icons.directions_car_outlined),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${vehicleType.name}", style: t.titleSm),
                const DsGap(DsSpace.xxs),
                Text("${vehicleType.description}", style: t.bodySm),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, size: 22, color: selected ? c.brand : c.textMuted),
        ],
      ),
    );
  }
}

/// One rental package inside the preferences sheet.
class _PackageTile extends StatelessWidget {
  final String name;
  final String description;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _PackageTile({required this.name, required this.description, required this.price, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      borderColor: selected ? c.brand : null,
      color: selected ? c.brandSoft : null,
      semanticLabel: name,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleSm),
                const DsGap(DsSpace.xs),
                Text(description, style: t.bodySm),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          Text(price, style: t.title.tabular),
        ],
      ),
    );
  }
}
