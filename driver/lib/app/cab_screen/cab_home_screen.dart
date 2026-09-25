import 'package:driver/utils/region_service.dart';
import 'package:driver/app/cab_screen/widget/cab_ride_extras.dart';
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/cab_home_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Archetype A/B/C – full-bleed map with a docked [DsMapPanel] that switches
/// between the incoming request card, the live-trip panel and nothing.
class CabHomeScreen extends StatelessWidget {
  const CabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final dashController = Get.put(CabDashBoardController());
    return GetX(
      init: CabHomeController(),
      builder: (controller) {
        final c = context.dsColors;
        return Scaffold(
          backgroundColor: c.background,
          body: controller.isLoading.value
              ? const _CabHomeSkeleton()
              : Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
              ? Obx(() {
                  // The isDark read is what re-runs this branch on theme change.
                  themeController.isDark.value;
                  return _documentPendingView(context);
                })
              : Stack(
                  children: [
                    Positioned.fill(child: _mapLayer(context, controller)),
                    // Wallet / owner-wallet warning over the map.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Obx(() {
                          final user = dashController.userModel.value;
                          final controllerOwner = controller.ownerModel.value;

                          final num wallet = user.walletAmount ?? 0.0;
                          final num ownerWallet = controllerOwner.walletAmount ?? 0.0;
                          final String? ownerId = user.ownerId;

                          final num minDeposit = double.parse(Constant.minimumDepositToRideAccept);

                          // 🧠 Logic:
                          // If individual driver → check driver's own wallet
                          // If owner driver → check owner's wallet
                          if ((ownerId == null || ownerId.isEmpty) && wallet < minDeposit) {
                            // Individual driver case
                            return Padding(
                              padding: const EdgeInsets.all(DsSpace.md),
                              child: DsInlineAlert(
                                tone: DsTone.danger,
                                icon: Icons.account_balance_wallet_outlined,
                                message:
                                    "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
                              ),
                            );
                          } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < minDeposit) {
                            // Owner-driver case
                            return Padding(
                              padding: const EdgeInsets.all(DsSpace.md),
                              child: DsInlineAlert(
                                tone: DsTone.danger,
                                icon: Icons.account_balance_wallet_outlined,
                                message: "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
                              ),
                            );
                          } else {
                            return const SizedBox();
                          }
                        }),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Obx(
                                () =>
                                    controller.currentOrder.value.id != null &&
                                        (controller.currentOrder.value.status == Constant.driverPending || controller.currentOrder.value.status == Constant.orderPlaced)
                                    ? showDriverBottomSheet(context, controller)
                                    : Container(),
                              ),
                              Obx(() => controller.shouldShowOrderSheet ? buildOrderActionsCard(context, controller) : const SizedBox()),
                              // Obx(
                              //   () => controller.currentOrder.value.id != null && controller.currentOrder.value.status != Constant.driverPending
                              //       ? buildOrderActionsCard(isDark, controller)
                              //       : Container(),
                              // ),
                            ],
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

  /// Archetype L – verification still pending.
  Widget _documentPendingView(BuildContext context) {
    return Center(
      child: DsResponsive(
        // Fill the Center, and center the content inside it.
        alignment: Alignment.center,
        padded: true,
        maxWidth: 480,
        child: SingleChildScrollView(
          child: DsEmptyState(
            tone: DsTone.warning,
            illustration: SvgPicture.asset("assets/icons/ic_document.svg"),
            title: "Document Verification in Pending".tr,
            message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
            actionLabel: "View Status".tr,
            actionIcon: Icons.arrow_forward_rounded,
            onAction: () async {
              CabDashBoardController dashBoardController = Get.put(CabDashBoardController());
              dashBoardController.drawerIndex.value = 4;
            },
          ),
        ),
      ),
    );
  }

  /// The map (or the external-navigation placeholder) exactly as before – only
  /// the recenter control is restyled.
  Widget _mapLayer(BuildContext context, CabHomeController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    if (Constant.mapType == "inappmap") {
      return Stack(
        children: [
          Constant.selectedMapType == "osm"
              ? flutterMap.FlutterMap(
                  mapController: controller.osmMapController,
                  options: flutterMap.MapOptions(initialCenter: controller.current.value, initialZoom: 16),
                  children: [
                    flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spideli.driver'),
                    // GetBuilder works inside flutter_map's LayoutBuilder; Obx does not
                    GetBuilder<CabHomeController>(builder: (c) => flutterMap.MarkerLayer(markers: c.osmMarkers)),
                    GetBuilder<CabHomeController>(
                      builder: (c) {
                        if (c.routePoints.isNotEmpty && c.currentOrder.value.id != null) {
                          return flutterMap.PolylineLayer(
                            polylines: [flutterMap.Polyline(points: c.routePoints, strokeWidth: 7.0, color: DsColors.of(context).brand)],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                )
              : GoogleMap(
                  onMapCreated: (mapController) {
                    controller.mapController = mapController;
                    final lat = controller.current.value.latitude != 0.0 ? controller.current.value.latitude : (Constant.locationDataFinal?.latitude ?? 0.0);
                    final lng = controller.current.value.longitude != 0.0 ? controller.current.value.longitude : (Constant.locationDataFinal?.longitude ?? 0.0);
                    controller.mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 15, bearing: double.parse('${controller.driverModel.value.rotation ?? '0.0'}'))),
                    );
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  polylines: Set<Polyline>.of(controller.polyLines.values),
                  markers: controller.markers.values.toSet(),
                  initialCameraPosition: CameraPosition(
                    zoom: 15,
                    target: LatLng(
                      controller.current.value.latitude != 0.0 ? controller.current.value.latitude : (Constant.locationDataFinal?.latitude ?? 0.0),
                      controller.current.value.longitude != 0.0 ? controller.current.value.longitude : (Constant.locationDataFinal?.longitude ?? 0.0),
                    ),
                  ),
                ),
          if (Constant.mapType == "inappmap" && Constant.selectedMapType == "osm")
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + DsSpace.xxl,
              end: DsSpace.lg,
              child: DsMapButton(
                icon: Icons.my_location_rounded,
                semanticLabel: 'My location'.tr,
                onPressed: () {
                  try {
                    controller.animateToSource();
                  } catch (e) {
                    // ignore
                  }
                },
              ),
            ),
        ],
      );
    }

    final String mapName = Constant.mapType == "google"
        ? "Google Map"
        : Constant.mapType == "googleGo"
        ? "Google Go"
        : Constant.mapType == "waze"
        ? "Waze Map"
        : Constant.mapType == "mapswithme"
        ? "MapsWithMe Map"
        : Constant.mapType == "yandexNavi"
        ? "VandexNavi Map"
        : Constant.mapType == "yandexMaps"
        ? "Vandex Map"
        : "";
    return Container(
      color: c.background,
      alignment: Alignment.center,
      child: DsResponsive(
        padded: true,
        maxWidth: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: DsFadeSlideIn.stagger([
              SvgPicture.asset("assets/images/ic_location_map.svg"),
              const DsGap(DsSpace.xl),
              Text("${'Navigate with'.tr} $mapName", textAlign: TextAlign.center, style: t.headline),
              const DsGap(DsSpace.sm),
              Text("${'Easily find your destination with a single tap redirect to'.tr}  $mapName ${'for seamless navigation.'.tr}", textAlign: TextAlign.center, style: t.bodySecondary),
              const DsGap(DsSpace.xxxl),
              DsButton.primary(
                label: "${'Redirect'} $mapName".tr,
                icon: Icons.navigation_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  if (controller.currentOrder.value.id != null) {
                    if (controller.currentOrder.value.status != Constant.driverPending) {
                      if (controller.currentOrder.value.status == Constant.orderShipped) {
                        Utils.redirectMap(
                          name: controller.currentOrder.value.sourceLocationName.toString(),
                          latitude: controller.currentOrder.value.sourceLocation!.latitude ?? 0.0,
                          longLatitude: controller.currentOrder.value.sourceLocation!.longitude ?? 0.0,
                        );
                      } else if (controller.currentOrder.value.status == Constant.orderInTransit) {
                        Utils.redirectMap(
                          name: controller.currentOrder.value.destinationLocationName.toString(),
                          latitude: controller.currentOrder.value.destinationLocation!.latitude ?? 0.0,
                          longLatitude: controller.currentOrder.value.destinationLocation!.longitude ?? 0.0,
                        );
                      }
                    } else {
                      Utils.redirectMap(
                        name: controller.currentOrder.value.sourceLocationName.toString(),
                        latitude: controller.currentOrder.value.sourceLocation!.latitude ?? 0.0,
                        longLatitude: controller.currentOrder.value.sourceLocation!.longitude ?? 0.0,
                      );
                    }
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Opens the ride chat with the customer (same arguments as the chat buttons).
  Future<void> openCustomerChat(CabHomeController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);
    UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID.toString());
    UserModel? driver = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId.toString());
    ShowToastDialog.closeLoader();
    if (customer == null || driver == null) return;
    Get.to(
      const ChatScreen(),
      arguments: {
        "customerName": customer.fullName(),
        "restaurantName": driver.fullName(),
        "orderId": controller.currentOrder.value.id,
        "restaurantId": driver.id,
        "customerId": customer.id,
        "customerProfileImage": customer.profilePictureURL ?? "",
        "restaurantProfileImage": driver.profilePictureURL ?? "",
        "token": customer.fcmToken,
        "chatType": "Driver",
      },
    );
  }

  /// Chat entry used by the destination / live-trip rows (unchanged arguments).
  Future<void> _openChat(CabHomeController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);

    UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID.toString());
    UserModel? driver = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId.toString());

    ShowToastDialog.closeLoader();

    Get.to(
      const ChatScreen(),
      arguments: {
        "customerName": customer!.fullName(),
        "restaurantName": driver!.fullName(),
        "orderId": controller.currentOrder.value.id,
        "restaurantId": driver.id,
        "customerId": customer.id,
        "customerProfileImage": customer.profilePictureURL ?? "",
        "restaurantProfileImage": driver.profilePictureURL ?? "",
        "token": customer.fcmToken,
        "chatType": "Driver",
      },
    );
  }

  /// Archetype B – incoming ride request.
  Widget showDriverBottomSheet(BuildContext context, CabHomeController controller) {
    final order = controller.currentOrder.value;
    final metrics = <DsTripMetric>[
      DsTripMetric(icon: Icons.route_rounded, value: "${double.parse(order.distance.toString()).toStringAsFixed(2)} ${Constant.distanceType}", label: "Trip Distance".tr),
      if (!(order.tipAmount == null || order.tipAmount!.isEmpty || double.parse(order.tipAmount.toString()) <= 0))
        DsTripMetric(
          icon: Icons.volunteer_activism_outlined,
          value: Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.tipAmount),
          label: "Tips".tr,
        ),
      DsTripMetric(icon: Icons.local_taxi_rounded, value: order.rideType ?? '', label: "Ride Type".tr),
    ];

    return DsMapPanel(
      showHandle: false,
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
      child: DsRequestCard(
        margin: EdgeInsets.zero,
        title: "New ride request".tr,
        section: DsSection.cab,
        sectionLabel: "Cab".tr,
        stops: [
          DsRouteStop(kind: DsStopKind.pickup, label: order.author!.fullName(), address: "${order.sourceLocationName}"),
          DsRouteStop(kind: DsStopKind.drop, label: "Destination".tr, address: order.destinationLocationName.toString()),
        ],
        metrics: metrics,
        extra: CabRideExtras.hasContent(order)
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: CabRideExtras(order: order, isDark: context.dsIsDark),
                ),
              )
            : null,
        rejectLabel: "Reject".tr,
        onReject: () {
          controller.rejectWithReason();
        },
        acceptLabel: "Accept".tr,
        onAccept: () {
          if (controller.driverModel.value.ownerId != null && controller.driverModel.value.ownerId!.isNotEmpty) {
            if (controller.ownerModel.value.walletAmount != null && controller.ownerModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
              controller.acceptOrder();
            } else {
              ShowToastDialog.showToast(
                "Your owner has to maintain minimum {amount} wallet balance to accept the cab booking. Please contact your owner".trParams({
                  "amount": Constant.ownerMinimumDepositToRideAccept.toString(),
                }).tr,
              );
            }
          } else {
            if (controller.driverModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
              controller.acceptOrder();
            } else {
              ShowToastDialog.showToast("You don't have sufficient balance in your wallet.");
            }
          }
        },
      ),
    );
  }

  /// Archetype C – live trip panel.
  Widget buildOrderActionsCard(BuildContext context, CabHomeController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final order = controller.currentOrder.value;

    double totalAmount = 0.0;
    double discount = 0.0;
    double subTotal = 0.0;
    double taxAmount = 0.0;
    subTotal = double.parse(controller.currentOrder.value.subTotal.toString());
    discount = double.parse(controller.currentOrder.value.discount ?? '0.0');

    if (controller.currentOrder.value.taxSetting != null) {
      for (var element in controller.currentOrder.value.taxSetting!) {
        taxAmount = (taxAmount + Constant.calculateTax(amount: (subTotal - discount).toString(), taxModel: element));
      }
    }

    totalAmount = (subTotal - discount) + taxAmount;

    final bool atPickup = order.status == Constant.orderShipped || order.status == Constant.driverAccepted;

    final callOrChatButton = DsIconButton(
      icon: order.writtenCommunicationOnly == true ? Icons.chat_bubble_outline_rounded : Icons.call_outlined,
      semanticLabel: order.writtenCommunicationOnly == true ? "Chat with customer".tr : "Call customer".tr,
      variant: DsIconButtonVariant.brand,
      onPressed: () {
        if (controller.currentOrder.value.writtenCommunicationOnly == true) {
          openCustomerChat(controller);
        } else {
          Constant.makePhoneCall(controller.currentOrder.value.author!.phoneNumber.toString());
        }
      },
    );
    final chatButton = DsIconButton(icon: Icons.forum_outlined, semanticLabel: "Chat with customer".tr, variant: DsIconButtonVariant.tonal, onPressed: () => _openChat(controller));

    final actionLabel = atPickup
        ? Constant.enableOTPTripStart
              ? "Verify Code to customer".tr
              : "Pickup Customer".tr
        : "Complete Ride".tr;

    return DsMapPanel(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
      header: Row(
        children: [
          Expanded(
            child: DsStatusChip(label: (order.status ?? '').tr, status: order.status, pulse: true),
          ),
          Text(
            Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: totalAmount.toString()),
            style: t.titleSm.w700.tabular,
          ),
        ],
      ),
      actions: DsSlideToConfirm(
        label: actionLabel,
        icon: atPickup ? Icons.person_pin_circle_outlined : Icons.flag_rounded,
        tone: atPickup ? DsTone.brand : DsTone.success,
        onConfirmed: () async {
          if (controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted) {
            showVerifyPassengerDialog(Get.context!, controller);
          } else {
            if (controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod") {
              showConfirmCashPaymentDialog(
                Get.context!,
                onConfirm: () {
                  controller.completeRide();
                },
              );
            } else if (controller.currentOrder.value.paymentStatus == true) {
              controller.completeRide();
            } else {
              ShowToastDialog.showToast("Customer payment is pending".tr);
            }
          }
        },
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.48),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (atPickup)
                Row(
                  children: [
                    DsIconWell(icon: Icons.person_outline_rounded, tone: DsTone.brand),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.author!.fullName(), style: t.titleSm),
                          Text("${order.sourceLocationName}", style: t.bodySm),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    callOrChatButton,
                    const DsGap(DsSpace.sm),
                    chatButton,
                  ],
                )
              else
                DsRouteStops(
                  stops: [
                    DsRouteStop(kind: DsStopKind.pickup, label: order.author!.fullName(), address: "${order.sourceLocationName}", trailing: callOrChatButton),
                    DsRouteStop(kind: DsStopKind.drop, label: "Destination".tr, address: order.destinationLocationName.toString(), trailing: chatButton),
                  ],
                ),
              if (CabRideExtras.hasContent(order)) ...[
                const DsGap(DsSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: CabRideExtras(
                      order: order,
                      isDark: context.dsIsDark,
                      // Stops are reached after the customer is picked up.
                      onStopReached: order.status == Constant.orderInTransit ? (index) => controller.markStopReached(index) : null,
                    ),
                  ),
                ),
              ],
              const DsGap(DsSpace.md),
              const DsDivider(spacing: DsSpace.xs),
              DsInfoRow(label: "Payment Type".tr, value: order.paymentMethod!.toLowerCase() == "cod" ? "Cash on delivery".tr : "Online".tr),
              DsInfoRow(label: "Ride Type".tr, value: order.rideType ?? ''),
              if (order.paymentMethod!.toLowerCase() == "cod")
                DsInfoRow(
                  label: "Collect Payment from customer".tr,
                  value: Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: totalAmount.toString()),
                  emphasize: true,
                ),
              if (!(order.tipAmount == null || order.tipAmount!.isEmpty || double.parse(order.tipAmount.toString()) <= 0))
                DsInfoRow(
                  label: "Tips".tr,
                  value: Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.tipAmount),
                  valueTone: DsTone.success,
                ),
              if (atPickup)
                Align(
                  alignment: Alignment.centerRight,
                  child: DsButton.ghost(label: "Cancel ride".tr, icon: Icons.cancel_outlined, size: DsButtonSize.sm, color: c.dangerStrong, onPressed: () => controller.cancelAcceptedRide()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void showVerifyPassengerDialog(BuildContext context, CabHomeController controller) {
    if (Constant.enableOTPTripStart == false) {
      controller.onRideStatus();
      return;
    }
    PinInputController otpController = PinInputController();
    final c = DsColors.of(context);

    Get.dialog(
      DsDialog(
        title: "Verify Passenger".tr,
        message: "Enter the OTP shared by the customer to begin the trip".tr,
        icon: Icons.password_rounded,
        content: MaterialPinField(
          length: 4,
          pinController: otpController,
          keyboardType: TextInputType.phone,
          enableAutofill: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          hintCharacter: "-",
          theme: MaterialPinTheme(
            cellSize: const Size(50, 50),
            shape: MaterialPinShape.outlined,
            borderRadius: DsRadius.brMd,
            textStyle: DsTypography.title.copyWith(color: c.textPrimary),
            hintStyle: DsTypography.title.copyWith(color: c.textMuted),
            fillColor: c.surfaceAlt,
            borderColor: c.border,
            focusedBorderColor: c.brand,
            cursorColor: c.brand,
          ),
          onChanged: (value) {},
          onCompleted: (pin) async {
            // OTP completed
          },
        ),
        secondaryLabel: "Cancel".tr,
        onSecondary: () {
          Get.back();
        },
        primaryLabel: "Start Ride".tr,
        onPrimary: () async {
          if (otpController.text.length < 4) {
            ShowToastDialog.showToast("Please enter valid OTP".tr);
            return;
          }
          if (otpController.text != controller.currentOrder.value.otpCode) {
            ShowToastDialog.showToast("Please enter valid OTP".tr);
            return;
          }
          controller.onRideStatus();
        },
      ),
      barrierDismissible: true,
    );
  }

  void showConfirmCashPaymentDialog(BuildContext context, {required VoidCallback onConfirm}) {
    Get.dialog(
      DsDialog(
        title: "Confirm Cash Payment".tr,
        message: "Are you sure you received the cash from the passenger?".tr,
        icon: Icons.payments_outlined,
        tone: DsTone.success,
        secondaryLabel: "Cancel".tr,
        onSecondary: () {
          Get.back();
        },
        primaryLabel: "Complete Ride".tr,
        onPrimary: () {
          Get.back();
          onConfirm();
        },
      ),
      barrierDismissible: false,
    );
  }
}

/// Map-shaped skeleton: a shimmering surface with a panel placeholder.
class _CabHomeSkeleton extends StatelessWidget {
  const _CabHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Stack(
      children: [
        Positioned.fill(
          child: DsShimmer(child: Container(color: c.shimmerBase)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: DsMapPanel(
            showHandle: false,
            child: DsShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [DsSkeleton.line(width: 160, height: 16), const DsGap(DsSpace.md), DsSkeleton.box(height: 72), const DsGap(DsSpace.md), DsSkeleton.box(height: 56)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
