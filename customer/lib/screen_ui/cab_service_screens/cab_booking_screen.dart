import 'package:customer/utils/region_service.dart';

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_coupon_code_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:customer/controllers/cab_ride_options.dart';
import 'package:customer/screen_ui/cab_service_screens/widget/cab_ride_options_widgets.dart';
import 'package:customer/widget/cancel_reason_sheet.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong;

import '../../constant/constant.dart';
import '../../controllers/cab_booking_controller.dart';
import '../../controllers/cab_dashboard_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/show_toast_dialog.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';

import 'package:location/location.dart';

/// City ride booking and live ride (archetype D — live ride / map tracking):
/// a full-bleed map with a floating back control and one DS panel per step —
/// where to, vehicle, payment, confirm, dispatch and the live driver card.
///
/// Every panel is built lazily by [DraggableScrollableSheet], i.e. after the
/// enclosing `GetX` builder has finished tracking, so each one runs inside its
/// own [DsObserve] and the controller reads in it stay reactive.
class CabBookingScreen extends StatelessWidget {
  const CabBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CabBookingController(),
      builder: (controller) {
        return Scaffold(
          body: controller.isLoading.value
              ? Constant.loader()
              : Stack(
                  children: [
                    Constant.selectedMapType == "osm"
                        ? flutter_map.FlutterMap(
                            mapController: controller.mapOsmController,
                            options: flutter_map.MapOptions(
                              initialCenter: Constant.currentLocation != null
                                  ? latlong.LatLng(Constant.currentLocation!.latitude, Constant.currentLocation!.longitude)
                                  : controller.currentOrder.value.id != null
                                  ? latlong.LatLng(
                                      double.parse(controller.currentOrder.value.sourceLocation!.latitude.toString()),
                                      double.parse(controller.currentOrder.value.sourceLocation!.longitude.toString()),
                                    )
                                  : latlong.LatLng(41.4219057, -102.0840772),
                              initialZoom: 10,
                            ),
                            children: [
                              flutter_map.TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: Platform.isAndroid ? "com.spideli.customer" : "com.spideli.customer.ios",
                              ),
                              flutter_map.MarkerLayer(markers: controller.osmMarker),
                              if (controller.routePoints.isNotEmpty)
                                flutter_map.PolylineLayer(
                                  polylines: [flutter_map.Polyline(points: controller.routePoints, strokeWidth: 5.0, color: Colors.blue)],
                                ),
                            ],
                          )
                        : GoogleMap(
                            onMapCreated: (googleMapController) {
                              controller.mapController = googleMapController;

                              if (Constant.currentLocation != null) {
                                controller.setDepartureMarker(Constant.currentLocation!.latitude, Constant.currentLocation!.longitude);
                                controller.searchPlaceNameGoogle();
                              }
                            },
                            initialCameraPosition: CameraPosition(target: controller.currentPosition.value, zoom: 14),
                            myLocationEnabled: true,
                            zoomControlsEnabled: true,
                            zoomGesturesEnabled: true,
                            polylines: Set<Polyline>.of(controller.polyLines.values),
                            markers: controller.markers.toSet(), // reactive marker set
                          ),
                    Positioned(
                      top: 50,
                      left: Constant.isRtl ? null : 20,
                      right: Constant.isRtl ? 20 : null,
                      child: CabMapButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        semanticLabel: "Back".tr,
                        onPressed: () {
                          if (controller.bottomSheetType.value == "vehicleSelection") {
                            controller.bottomSheetType.value = "location";
                          } else if (controller.bottomSheetType.value == "payment") {
                            controller.bottomSheetType.value = "vehicleSelection";
                          } else if (controller.bottomSheetType.value == "conformRide") {
                            controller.bottomSheetType.value = "payment";
                          } else if (controller.bottomSheetType.value == "waitingDriver" || controller.bottomSheetType.value == "driverDetails") {
                            Get.back(result: true);
                          } else {
                            Get.back();
                          }
                        },
                      ),
                    ),
                    controller.bottomSheetType.value == "location"
                        ? searchLocationBottomSheet(context, controller)
                        : controller.bottomSheetType.value == "vehicleSelection"
                        ? vehicleSelection(context, controller)
                        : controller.bottomSheetType.value == "payment"
                        ? paymentBottomSheet(context, controller)
                        : controller.bottomSheetType.value == "conformRide"
                        ? conformBottomSheet(context)
                        : controller.bottomSheetType.value == "waitingForDriver"
                        ? waitingDialog(context, controller)
                        : controller.bottomSheetType.value == "driverDetails"
                        ? driverDialog(context, controller)
                        : SizedBox(),
                  ],
                ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- step 1

  Widget searchLocationBottomSheet(BuildContext context, CabBookingController controller) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.36,
        // Start height
        minChildSize: 0.36,
        // Minimum height
        maxChildSize: 0.8,
        // Maximum height
        expand: false,
        builder: (context, scrollController) {
          return DsObserve(
            builder: (context) {
              final t = context.dsText;
              return CabSheetShell(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Text("Where to?".tr, style: t.title),
                    const DsGap(DsSpace.md),
                    CabRouteFields(
                      pickup: CabAddressRow(
                        controller: controller.sourceTextEditController.value,
                        hint: "Pickup Location".tr,
                        isPickup: true,
                        onTap: () async {
                          if (Constant.selectedMapType == 'osm') {
                            final result = await Get.to(() => MapPickerPage());
                            if (result != null) {
                              controller.sourceTextEditController.value.text = '';
                              final firstPlace = result;
                              if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                                final lat = firstPlace.coordinates.latitude;
                                final lng = firstPlace.coordinates.longitude;
                                final address = firstPlace.address;
                                controller.sourceTextEditController.value.text = address.toString();
                                controller.setDepartureMarker(lat, lng);
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
                                  controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                } else {
                                  ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                                }
                              }
                            });
                          }
                        },
                      ),
                      destination: CabAddressRow(
                        controller: controller.destinationTextEditController.value,
                        hint: "Destination Location".tr,
                        isPickup: false,
                        onTap: () async {
                          if (Constant.selectedMapType == 'osm') {
                            final result = await Get.to(() => MapPickerPage());
                            if (result != null) {
                              controller.destinationTextEditController.value.text = '';
                              final firstPlace = result;
                              final lat = firstPlace.coordinates.latitude;
                              final lng = firstPlace.coordinates.longitude;
                              final address = firstPlace.address;
                              controller.destinationTextEditController.value.text = address.toString();
                              controller.setDestinationMarker(lat, lng);
                            }
                          } else {
                            Get.to(LocationPickerScreen())!.then((value) async {
                              if (value != null) {
                                SelectedLocationModel selectedLocationModel = value;

                                controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    // Stops A, B, … (spec 4.8): route and fare go through them.
                    CabStopsEditor(controller: controller),
                    const DsGap(DsSpace.lg),
                    DsButton.primary(
                      label: "Continue".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () {
                        if (controller.sourceTextEditController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please select source location".tr);
                        } else if (controller.destinationTextEditController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please select destination location".tr);
                        } else {
                          controller.bottomSheetType.value = "vehicleSelection";
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- step 2

  Widget vehicleSelection(BuildContext context, CabBookingController controller) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.40,
        minChildSize: 0.40,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return DsObserve(
            builder: (context) {
              final t = context.dsText;
              return CabSheetShell(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: Text("Select Your Vehicle Type".tr, style: t.title, textAlign: TextAlign.start),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: controller.vehicleTypes.length,
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: DsSpace.xl),
                        controller: scrollController,
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) {
                          VehicleType vehicleType = controller.vehicleTypes[index];
                          return Obx(
                            () => Padding(
                              padding: const EdgeInsets.only(bottom: DsSpace.md),
                              child: _VehicleRow(
                                vehicleType: vehicleType,
                                selected: controller.selectedVehicleType.value.id == vehicleType.id,
                                distanceLabel: "${controller.distance.toStringAsFixed(2)}${'km'.tr}",
                                durationLabel: controller.duration.value,
                                fare: Constant.amountShow(amount: controller.getAmount(vehicleType).toString(), currency: controller.rideCurrency),
                                onTap: () {
                                  controller.selectedVehicleType.value = controller.vehicleTypes[index];
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Obx(
                      () => DsButton.primary(
                        label: 'pay_amount'.trParams({
                          'amount': controller.selectedVehicleType.value.id == null
                              ? Constant.amountShow(amount: "0.0", currency: controller.rideCurrency)
                              : Constant.amountShow(amount: controller.getAmount(controller.selectedVehicleType.value).toString(), currency: controller.rideCurrency),
                        }),
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () async {
                          if (controller.selectedVehicleType.value.id != null) {
                            controller.calculateTotalAmount();
                            controller.bottomSheetType.value = "payment";
                          } else {
                            ShowToastDialog.showToast("Please select a vehicle type first.".tr);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- step 3

  Widget paymentBottomSheet(BuildContext context, CabBookingController controller) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.30,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return DsObserve(
            builder: (context) {
              final t = context.dsText;
              final hasPreferred = controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true;
              return CabSheetShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("Select Payment Method".tr, style: t.title)),
                        DsIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: "Close".tr,
                          variant: DsIconButtonVariant.tonal,
                          size: 36,
                          onPressed: () {
                            Get.back();
                          },
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.lg),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        controller: scrollController,
                        children: [
                          if (hasPreferred) ...[
                            Text("Preferred Payment".tr, textAlign: TextAlign.start, style: t.overline),
                            const DsGap(DsSpace.sm),
                            DsCard.outlined(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                              child: Column(
                                children: [
                                  Visibility(visible: controller.walletSettingModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.wallet, "assets/images/ic_wallet.png")),
                                  Visibility(
                                    visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.cod, "assets/images/ic_cash.png"),
                                  ),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.lg),
                            Text("Other Payment Options".tr, textAlign: TextAlign.start, style: t.overline),
                            const DsGap(DsSpace.sm),
                          ],
                          DsCard.outlined(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            child: Column(
                              children: [
                                Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                                Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                                Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                                Visibility(
                                  visible: controller.mercadoPagoModel.value.isEnabled == true,
                                  child: cardDecoration(controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png"),
                                ),
                                Visibility(
                                  visible: controller.flutterWaveModel.value.isEnable == true,
                                  child: cardDecoration(controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png"),
                                ),
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
                    DsButton.primary(
                      label: "Continue".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () async {
                        if (controller.selectedPaymentMethod.value.isEmpty) {
                          ShowToastDialog.showToast("Please select a payment method".tr);
                          return;
                        }
                        if (controller.selectedPaymentMethod.value == "wallet") {
                          num walletAmount = controller.userModel.value.walletAmount ?? 0;
                          if (walletAmount <= 0) {
                            ShowToastDialog.showToast("Insufficient wallet balance. Please select another payment method.".tr);
                            return;
                          }
                        }
                        if (controller.currentOrder.value.id != null) {
                          controller.bottomSheetType.value = "driverDetails";
                        } else {
                          controller.bottomSheetType.value = "conformRide";
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- step 4

  Widget conformBottomSheet(BuildContext context) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return GetX(
            init: CabBookingController(),
            builder: (controller) {
              final t = context.dsText;
              return CabSheetShell(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          Text("Review your ride".tr, style: t.title),
                          const DsGap(DsSpace.md),
                          CabRouteFields(
                            pickup: CabAddressRow(
                              controller: controller.sourceTextEditController.value,
                              hint: "Pickup Location".tr,
                              isPickup: true,
                              onTap: () async {
                                if (Constant.selectedMapType == 'osm') {
                                  final result = await Get.to(() => MapPickerPage());
                                  if (result != null) {
                                    controller.sourceTextEditController.value.text = '';
                                    final firstPlace = result;
                                    final lat = firstPlace.coordinates.latitude;
                                    final lng = firstPlace.coordinates.longitude;
                                    final address = firstPlace.address;
                                    controller.sourceTextEditController.value.text = address.toString();
                                    controller.setDepartureMarker(lat, lng);
                                  }
                                } else {
                                  Get.to(LocationPickerScreen())!.then((value) async {
                                    if (value != null) {
                                      SelectedLocationModel selectedLocationModel = value;

                                      controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                    }
                                  });
                                }
                              },
                            ),
                            destination: CabAddressRow(
                              controller: controller.destinationTextEditController.value,
                              hint: "Destination Location".tr,
                              isPickup: false,
                              onTap: () async {
                                if (Constant.selectedMapType == 'osm') {
                                  final result = await Get.to(() => MapPickerPage());
                                  if (result != null) {
                                    controller.destinationTextEditController.value.text = '';
                                    final firstPlace = result;
                                    final lat = firstPlace.coordinates.latitude;
                                    final lng = firstPlace.coordinates.longitude;
                                    final address = firstPlace.address;
                                    controller.destinationTextEditController.value.text = address.toString();
                                    controller.setDestinationMarker(lat, lng);
                                  }
                                } else {
                                  Get.to(LocationPickerScreen())!.then((value) async {
                                    if (value != null) {
                                      SelectedLocationModel selectedLocationModel = value;

                                      controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          if (controller.stops.isNotEmpty) ...[DsCard.outlined(child: CabStopsSummary(controller: controller)), const DsGap(DsSpace.md)],
                          CabTripOptionsSection(controller: controller),
                          const DsGap(DsSpace.md),
                          _PromoSection(
                            couponController: controller.couponCodeTextEditController.value,
                            onViewAll: () {
                              Get.to(CabCouponCodeScreen())!.then((value) {
                                if (value != null) {
                                  controller.couponCodeTextEditController.value.text = value.code ?? '';
                                  double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                                  if (couponAmount < controller.subTotal.value) {
                                    controller.selectedCouponModel.value = value;
                                    controller.calculateTotalAmount();
                                  } else {
                                    ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                  }
                                }
                              });
                            },
                            onRedeem: () async {
                              if (controller.couponCodeTextEditController.value.text.trim().isEmpty) {
                                ShowToastDialog.showToast("Please enter a coupon code".tr);
                                return;
                              }

                              List matchedCoupons = controller.cabCouponList
                                  .where((element) => element.code!.toLowerCase().trim() == controller.couponCodeTextEditController.value.text.toLowerCase().trim())
                                  .toList();

                              if (matchedCoupons.isNotEmpty) {
                                CouponModel couponModel = matchedCoupons.first;

                                if (couponModel.expiresAt != null && couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                  double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);

                                  if (couponAmount < controller.subTotal.value) {
                                    controller.selectedCouponModel.value = couponModel;
                                    controller.discount.value = couponAmount;
                                    controller.calculateTotalAmount();
                                    ShowToastDialog.showToast("Coupon applied successfully".tr);
                                    controller.update();
                                  } else {
                                    ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                  }
                                } else {
                                  ShowToastDialog.showToast("This coupon code has been expired".tr);
                                }
                              } else {
                                ShowToastDialog.showToast("Invalid coupon code".tr);
                              }
                            },
                          ),
                          const DsGap(DsSpace.md),
                          DsCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Order Summary".tr, style: t.overline),
                                const DsGap(DsSpace.md),
                                CabBillRow(
                                  label: "Subtotal".tr,
                                  value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: controller.rideCurrency),
                                ),
                                CabBillRow(
                                  label: "Discount".tr,
                                  labelSuffix: controller.selectedCouponModel.value.id == null ? "" : "(${controller.selectedCouponModel.value.code})",
                                  value: Constant.amountShow(amount: controller.discount.value.toString(), currency: controller.rideCurrency),
                                  valueColor: context.dsColors.dangerStrong,
                                ),
                                if (Constant.platformFeeModel?.enable == true)
                                  CabBillRow(
                                    label: "Platform fee".tr,
                                    value: Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: controller.rideCurrency),
                                  ),
                                CabBillRow(
                                  label: "Tax amount".tr,
                                  value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: controller.rideCurrency),
                                  onTap: () {
                                    showBillBifurcationDialog(context, controller);
                                  },
                                ),

                                // Tax List
                                const DsDivider(spacing: DsSpace.lg),
                                CabBillRow(
                                  label: "Order Total".tr,
                                  value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.rideCurrency),
                                  emphasize: true,
                                ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.xl),
                          DsCard.outlined(
                            padding: const EdgeInsets.all(DsSpace.md),
                            child: Row(
                              children: [
                                CabGatewayLogo(
                                  method: controller.selectedPaymentMethod.value,
                                  image: controller.selectedPaymentMethod.value == '' ? '' : cabGatewayAsset(controller.selectedPaymentMethod.value),
                                ),
                                const DsGap(DsSpace.lg),
                                Expanded(
                                  child: Text(controller.selectedPaymentMethod.value.tr, textAlign: TextAlign.start, style: context.dsText.bodyStrong),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    DsButton.primary(
                      label: "Confirm Booking".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () async {
                        final error = controller.validateRideOptions();
                        if (error != null) {
                          ShowToastDialog.showToast(error);
                          return;
                        }
                        controller.placeOrder();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- step 5

  Widget waitingDialog(BuildContext context, CabBookingController controller) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.4,
        maxChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return DsObserve(
            builder: (context) {
              return CabSheetShell(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The assigned driver cancelled: back to dispatch, not final.
                      DriverCancelledBanner(order: controller.currentOrder.value),
                      const DsGap(DsSpace.sm),
                      Center(
                        child: DsStatusChip(label: "Waiting for driver....".tr, tone: DsTone.info, pulse: true),
                      ),
                      Center(child: Image.asset('assets/loader.gif', width: controller.currentOrder.value.isDriverCancelledRedispatch ? 150 : 250)),
                      DsButton.dangerTonal(
                        label: "Cancel Ride".tr,
                        icon: Icons.close_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () async {
                          // Mandatory reason (spec 4.8); field update guarded by the ride's
                          // current status (a driver acceptance that just landed wins).
                          final reason = await CancelReasonSheet.show();
                          if (reason == null) return;
                          try {
                            if (controller.currentOrder.value.id != null) {
                              ShowToastDialog.showLoader("Please wait".tr);
                              final error = await CabRideCancellation.cancel(controller.currentOrder.value.id!, reason.toFields());
                              ShowToastDialog.closeLoader();
                              if (error != null) {
                                ShowToastDialog.showToast(error);
                                return;
                              }
                            }
                            controller.currentOrder.update((order) {
                              if (order != null) {
                                order.status = Constant.orderRejected;
                                order.cancelReason = reason.reason;
                                order.cancelReasonCode = reason.code;
                                order.cancelledBy = 'customer';
                              }
                            });
                            controller.resetRideOptions();

                            controller.bottomSheetType.value = "";
                            controller.polyLines.clear();
                            controller.markers.clear();
                            controller.osmMarker.clear();
                            controller.routePoints.clear();
                            controller.sourceTextEditController.value.clear();
                            controller.destinationTextEditController.value.clear();
                            controller.departureLatLong.value = const LatLng(0.0, 0.0);
                            controller.destinationLatLong.value = const LatLng(0.0, 0.0);
                            controller.departureLatLongOsm.value = latlong.LatLng(0.0, 0.0);
                            controller.destinationLatLongOsm.value = latlong.LatLng(0.0, 0.0);

                            // 4. Reset user’s in-progress order
                            if (Constant.userModel != null) {
                              Constant.userModel?.inProgressOrderID = null;
                              await FireStoreUtils.updateUser(Constant.userModel!);
                            }
                            ShowToastDialog.showToast("Ride cancelled successfully".tr);
                            // Get.offAll(const CabDashboardScreen());
                            Get.back();
                            CabDashboardController cabDashboardController = Get.put(CabDashboardController());
                            cabDashboardController.selectedIndex.value = 0;
                          } catch (e) {
                            ShowToastDialog.showToast("Failed to cancel ride".tr);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- step 6

  Widget driverDialog(BuildContext context, CabBookingController controller) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return DsObserve(
            builder: (context) {
              final c = context.dsColors;
              final t = context.dsText;
              final order = controller.currentOrder.value;
              return CabSheetShell(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          CabRouteFields(
                            pickup: CabAddressRow(controller: controller.sourceTextEditController.value, hint: "Pickup Location".tr, isPickup: true),
                            destination: CabAddressRow(controller: controller.destinationTextEditController.value, hint: "Destination Location".tr, isPickup: false),
                          ),
                          const DsGap(DsSpace.md),
                          // Stops progress, passengers, instructions, rider (spec 4.8).
                          CabRideExtrasView(order: order),
                          const DsGap(DsSpace.md),
                          if (Constant.isEnableOTPTripStart == true) ...[
                            DsCard.tinted(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Otp :".tr, style: t.bodySecondary),
                                  Text(order.otpCode ?? '', style: t.metric.withColor(c.brandStrong).tabular),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.md),
                          ],
                          if (order.driver != null) ...[
                            DsCard.outlined(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CabDriverIdentity(
                                    name: order.driver?.fullName(),
                                    photoUrl: order.driver?.profilePictureURL,
                                    vehicle: order.driver?.vehicleDetails?[order.sectionId ?? ''],
                                    rating: controller.driverModel.value.averageRating.toStringAsFixed(1),
                                  ),
                                  const DsGap(DsSpace.lg),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DsButton.tonal(
                                          label: "Call".tr,
                                          icon: Icons.call_rounded,
                                          expand: true,
                                          onPressed: () {
                                            Constant.makePhoneCall(controller.currentOrder.value.driver!.phoneNumber.toString());
                                          },
                                        ),
                                      ),
                                      const DsGap(DsSpace.md),
                                      Expanded(
                                        child: DsButton.tonal(
                                          label: "Chat".tr,
                                          icon: Icons.chat_bubble_outline_rounded,
                                          expand: true,
                                          onPressed: () async {
                                            ShowToastDialog.showLoader("Please wait...".tr);

                                            UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID ?? '');
                                            UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId ?? '');

                                            ShowToastDialog.closeLoader();

                                            Get.to(
                                              const ChatScreen(),
                                              arguments: {
                                                "senderName": customer?.fullName(),
                                                "receivedName": driverUser?.fullName(),
                                                "orderId": controller.currentOrder.value.id,
                                                "receivedId": driverUser?.id,
                                                "senderId": customer?.id,
                                                "senderProfileUrl": customer?.profilePictureURL,
                                                "receivedProfileUrl": driverUser?.profilePictureURL,
                                                "token": driverUser?.fcmToken,
                                                "chatType": Constant.userRoleDriver,
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.md),
                          ],
                          DsCard.outlined(
                            padding: const EdgeInsets.all(DsSpace.md),
                            onTap: () {
                              controller.bottomSheetType.value = 'payment';
                            },
                            child: Row(
                              children: [
                                CabGatewayLogo(method: controller.selectedPaymentMethod.value, image: cabGatewayAsset(controller.selectedPaymentMethod.value)),
                                const DsGap(DsSpace.lg),
                                Expanded(
                                  child: Text(controller.selectedPaymentMethod.value.tr, textAlign: TextAlign.start, style: t.bodyStrong),
                                ),
                                Text("Change".tr, textAlign: TextAlign.start, style: t.link),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          DsCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Order Summary".tr, style: t.overline),
                                const DsGap(DsSpace.md),
                                CabBillRow(
                                  label: "Subtotal".tr,
                                  value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: controller.rideCurrency),
                                ),
                                CabBillRow(
                                  label: "Discount".tr,
                                  value: Constant.amountShow(amount: controller.discount.value.toString(), currency: controller.rideCurrency),
                                  valueColor: c.dangerStrong,
                                ),
                                if (Constant.platformFeeModel?.enable == true)
                                  CabBillRow(
                                    label: "Platform fee".tr,
                                    value: Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: controller.rideCurrency),
                                  ),
                                CabBillRow(
                                  label: "Tax amount".tr,
                                  value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: controller.rideCurrency),
                                  onTap: () {
                                    showBillBifurcationDialog(context, controller);
                                  },
                                ),
                                const DsDivider(spacing: DsSpace.lg),
                                CabBillRow(
                                  label: "Order Total".tr,
                                  value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.rideCurrency),
                                  emphasize: true,
                                ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.md),
                        ],
                      ),
                    ),
                    Obx(() {
                      if (controller.currentOrder.value.status == Constant.orderInTransit) {
                        return Column(
                          children: [
                            DsButton.danger(
                              label: "SOS".tr,
                              icon: Icons.call,
                              expand: true,
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                ShowToastDialog.showLoader("Please wait...".tr);

                                LocationData location = await controller.currentLocation.value.getLocation();

                                await FireStoreUtils.getSOS(controller.currentOrder.value.id ?? '').then((value) async {
                                  if (value == false) {
                                    await FireStoreUtils.setSos(controller.currentOrder.value.id ?? '', UserLocation(latitude: location.latitude, longitude: location.longitude)).then((_) {
                                      ShowToastDialog.closeLoader();
                                      messenger.showSnackBar(
                                        SnackBar(content: Text("Your SOS request has been submitted to admin".tr), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
                                      );
                                    });
                                  } else {
                                    ShowToastDialog.closeLoader();
                                    messenger.showSnackBar(SnackBar(content: Text("Your SOS request is already submitted".tr), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
                                  }
                                });
                              },
                            ),
                            const DsGap(DsSpace.md),
                          ],
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    Obx(() {
                      if (controller.currentOrder.value.status == Constant.orderInTransit && controller.currentOrder.value.paymentStatus == false) {
                        return DsButton.primary(
                          label: "Pay Now".tr,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () async {
                            if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                              controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                              controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                              controller.payStackPayment(controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                              controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                              controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                              controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                              controller.completeOrder();
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                              if (Constant.userModel!.walletAmount == null || Constant.userModel!.walletAmount! < controller.totalAmount.value) {
                                ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                              } else {
                                controller.completeOrder();
                              }
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                              controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                              controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                              controller.xenditPayment(context, controller.totalAmount.value.toString());
                            } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                              RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((value) {
                                if (value == null) {
                                  Get.back();
                                  ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                                } else {
                                  CreateRazorPayOrderModel result = value;
                                  controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                                }
                              });
                            } else {
                              ShowToastDialog.showToast("Please select payment method".tr);
                            }
                          },
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- fragments

  /// One gateway row. [DsObserve] (not `Obx(() => Builder(...))`) so the
  /// `selectedPaymentMethod` read below is tracked by the observer that is
  /// running while it happens.
  Widget cardDecoration(CabBookingController controller, PaymentGateway value, String image) {
    return DsObserve(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        final selected = controller.selectedPaymentMethod.value == value.name;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: DsRadius.brMd,
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.xs),
                child: Row(
                  children: [
                    CabGatewayLogo(image: image, method: value.name, size: 50, selected: selected),
                    const DsGap(DsSpace.md),
                    value.name == "wallet"
                        ? Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                                Text(
                                  Constant.amountShow(
                                    amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString(),
                                    currency: RegionService.customerCurrency,
                                  ),
                                  textAlign: TextAlign.start,
                                  style: t.labelSm.withColor(c.brandStrong).tabular,
                                ),
                              ],
                            ),
                          )
                        : Expanded(
                            child: Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                          ),
                    Radio(
                      value: value.name,
                      groupValue: controller.selectedPaymentMethod.value,
                      activeColor: c.brand,
                      onChanged: (value) {
                        controller.selectedPaymentMethod.value = value.toString();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showBillBifurcationDialog(BuildContext context, CabBookingController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.receipt_long_rounded,
          tone: DsTone.info,
          content: Column(
            children: [
              CabBillRow(
                label: "Tax on Order Total".tr,
                value: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: controller.rideCurrency),
              ),
              const DsDivider(spacing: DsSpace.xl),
              CabBillRow(
                label: "Tax on Platform Fee".tr,
                value: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: controller.rideCurrency),
              ),
              const DsDivider(spacing: DsSpace.xl),
              CabBillRow(
                label: "Total Tax Amount".tr,
                value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: controller.rideCurrency),
                valueColor: context.dsColors.brandStrong,
                emphasize: true,
              ),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}

/// One vehicle class in the selection list: artwork, name, distance and
/// duration, and the fare for this ride.
class _VehicleRow extends StatelessWidget {
  final VehicleType vehicleType;
  final bool selected;
  final String distanceLabel;
  final String durationLabel;
  final String fare;
  final VoidCallback onTap;

  const _VehicleRow({required this.vehicleType, required this.selected, required this.distanceLabel, required this.durationLabel, required this.fare, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: "${vehicleType.name}",
      color: selected ? c.brandSoft : null,
      borderColor: selected ? c.brand : null,
      padding: const EdgeInsets.all(DsSpace.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: DsRadius.brSm,
            child: CachedNetworkImage(
              imageUrl: vehicleType.vehicleIcon.toString(),
              height: 60,
              width: 60,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.brSm,
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) => DsSkeleton.box(height: 60, width: 60, radius: DsRadius.sm),
              errorWidget: (context, url, error) => ClipRRect(
                borderRadius: DsRadius.brSm,
                child: Image.network(Constant.placeHolderImage, fit: BoxFit.cover),
              ),
              fit: BoxFit.cover,
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${vehicleType.name}", style: t.titleSm),
                const DsGap(DsSpace.xxs),
                Row(
                  children: [
                    Icon(Icons.straighten_rounded, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Text(distanceLabel, style: t.caption.tabular),
                    const DsGap(DsSpace.md),
                    Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Flexible(
                      child: Text(durationLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.tabular),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Text(fare, style: t.titleSm.tabular),
        ],
      ),
    );
  }
}

/// Promo code: jump to the coupon list or type a code and redeem it.
class _PromoSection extends StatelessWidget {
  final TextEditingController couponController;
  final VoidCallback onViewAll;
  final Future<void> Function() onRedeem;

  const _PromoSection({required this.couponController, required this.onViewAll, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text("Promo code".tr, style: t.titleSm)),
            DsButton.ghost(label: "View All".tr, size: DsButtonSize.sm, trailingIcon: Icons.chevron_right_rounded, onPressed: onViewAll),
          ],
        ),
        const DsGap(DsSpace.sm),
        DsCard.tinted(
          tone: DsTone.success,
          padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.sm, DsSpace.sm),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 20, color: c.successStrong),
              const DsGap(DsSpace.md),
              Expanded(
                child: TextFormField(
                  controller: couponController,
                  style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Write coupon Code'.tr,
                    hintStyle: DsTypography.bodyStrong.copyWith(color: c.textMuted),
                  ),
                ),
              ),
              const DsGap(DsSpace.sm),
              DsButton.primary(label: "Redeem now".tr, size: DsButtonSize.sm, onPressed: () => onRedeem()),
            ],
          ),
        ),
      ],
    );
  }
}
