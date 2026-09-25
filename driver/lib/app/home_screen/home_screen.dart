import 'package:driver/utils/region_service.dart';
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/app/home_screen/deliver_order_screen.dart';
import 'package:driver/app/home_screen/pickup_order_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/home_controller.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Archetype A / B / C — the driver's job screen. The map stays full-bleed,
/// a [DsMapButton] recentres it, and the bottom third changes with the job:
/// an incoming [DsRequestCard] while the order is pending, then a docked
/// [DsMapPanel] with the route, the people to contact and the one xl action
/// for the current step.
class HomeScreen extends StatelessWidget {
  final bool? isAppBarShow;

  const HomeScreen({super.key, this.isAppBarShow});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final dashController = Get.put(DashBoardController());
    return Obx(() {
      // Kept as the observable read that rebuilds this screen on a theme
      // change; colors now come from `context.dsColors`.
      themeController.isDark.value;
      return GetX(
        init: HomeController(),
        builder: (controller) {
          return DsScaffold(
            // Edge-to-edge: the map owns the full width on every screen size.
            maxContentWidth: null,
            appBar: isAppBarShow == true ? DsAppBar(title: "Order".tr) : null,
            body: controller.isLoading.value
                ? Constant.loader()
                : controller.driverModel.value.vendorID?.isEmpty == true &&
                        controller.driverModel.value.isDocumentVerify == false &&
                        controller.driverModel.value.isAutoVerify == false
                    ? Center(
                        child: DsEmptyState(
                          icon: Icons.assignment_outlined,
                          tone: DsTone.warning,
                          title: "Document Verification in Pending".tr,
                          message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                          actionLabel: "View Status".tr,
                          actionIcon: Icons.arrow_forward_rounded,
                          onAction: () async {
                            DashBoardController dashBoardController = Get.put(DashBoardController());
                            dashBoardController.drawerIndex.value = 4;
                          },
                        ),
                      )
                    : Column(
                        children: [
                          Obx(() {
                            num wallet = dashController.userModel.value.walletAmount ?? 0.0;
                            return Constant.userModel?.vendorID?.isEmpty == true && wallet < double.parse(Constant.minimumDepositToRideAccept)
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.sm),
                                    child: DsInlineAlert(
                                      tone: DsTone.warning,
                                      icon: Icons.account_balance_wallet_outlined,
                                      message:
                                          "${'You have to minimum'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'wallet amount to receiving Order'.tr}",
                                    ),
                                  )
                                : const SizedBox();
                          }),
                          Expanded(
                            child: Constant.mapType == "inappmap"
                                ? Stack(
                                    children: [
                                      Constant.selectedMapType == "osm"
                                          ? flutterMap.FlutterMap(
                                              mapController: controller.osmMapController,
                                              options: flutterMap.MapOptions(
                                                initialCenter: controller.current.value,
                                                initialZoom: 16,
                                              ),
                                              children: [
                                                flutterMap.TileLayer(
                                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName: 'com.spideli.driver',
                                                ),
                                                // GetBuilder works inside flutter_map's LayoutBuilder; Obx does not
                                                GetBuilder<HomeController>(
                                                  builder: (c) => flutterMap.MarkerLayer(markers: c.osmMarkers),
                                                ),
                                                GetBuilder<HomeController>(
                                                  builder: (c) {
                                                    if (c.routePoints.isNotEmpty && c.currentOrder.value.id != null) {
                                                      return flutterMap.PolylineLayer(
                                                        polylines: [
                                                          flutterMap.Polyline(
                                                            points: c.routePoints,
                                                            strokeWidth: 7.0,
                                                            color: AppThemeData.primary300,
                                                          ),
                                                        ],
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
                                                // Use current GPS position — already fetched directly from device
                                                final lat = controller.current.value.latitude != 0.0 ? controller.current.value.latitude : (Constant.locationDataFinal?.latitude ?? 0.0);
                                                final lng = controller.current.value.longitude != 0.0 ? controller.current.value.longitude : (Constant.locationDataFinal?.longitude ?? 0.0);
                                                controller.mapController!.animateCamera(
                                                  CameraUpdate.newCameraPosition(
                                                    CameraPosition(target: LatLng(lat, lng), zoom: 15, bearing: double.parse('${controller.driverModel.value.rotation ?? '0.0'}')),
                                                  ),
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
                                          top: DsSpace.xl,
                                          end: DsSpace.xl,
                                          child: DsMapButton(
                                            icon: Icons.my_location_rounded,
                                            semanticLabel: "My location".tr,
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
                                  )
                                : _externalMapPanel(context, controller),
                          ),
                          controller.currentOrder.value.id != null && controller.currentOrder.value.status == Constant.driverPending
                              ? showDriverBottomSheet(context, controller)
                              : Container(),
                          controller.currentOrder.value.id != null &&
                                  (controller.currentOrder.value.status == Constant.driverAccepted ||
                                      controller.currentOrder.value.status == Constant.orderShipped ||
                                      controller.currentOrder.value.status == Constant.orderInTransit)
                              ? buildOrderActionsCard(context, controller)
                              : Container(),
                        ],
                      ),
          );
        },
      );
    });
  }

  /// Name of the external navigation app the driver chose in settings.
  String _mapName() {
    return Constant.mapType == "google"
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
  }

  /// Shown instead of the in-app map when the driver navigates with an
  /// external app. Archetype L: one illustration, one clear xl action.
  Widget _externalMapPanel(BuildContext context, HomeController controller) {
    final t = context.dsText;
    final mapName = _mapName();
    return Center(
      child: DsResponsive(
        // Fill the Center, and center the content inside it.
        alignment: Alignment.center,
        maxWidth: DsLayout.contentMax,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: DsIconWell(icon: Icons.near_me_rounded, size: 88, circle: true)),
              const DsGap(DsSpace.xl),
              Text("${'Navigate with'.tr} $mapName", textAlign: TextAlign.center, style: t.headline),
              const DsGap(DsSpace.sm),
              Text(
                "${'Easily find your destination with a single tap redirect to'.tr}  $mapName ${'for seamless navigation.'.tr}",
                textAlign: TextAlign.center,
                style: t.bodySecondary,
              ),
              const DsGap(DsSpace.xxl),
              DsButton.primary(
                label: "${'Redirect'.tr} $mapName".tr,
                icon: Icons.navigation_rounded,
                size: DsButtonSize.xl,
                expand: true,
                onPressed: () async {
                  if (controller.currentOrder.value.id != null) {
                    if (controller.currentOrder.value.status != Constant.driverPending) {
                      if (controller.currentOrder.value.status == Constant.orderShipped) {
                        Utils.redirectMap(
                            name: controller.currentOrder.value.vendor!.title.toString(),
                            latitude: controller.currentOrder.value.vendor!.latitude ?? 0.0,
                            longLatitude: controller.currentOrder.value.vendor!.longitude ?? 0.0);
                      } else if (controller.currentOrder.value.status == Constant.orderInTransit) {
                        Utils.redirectMap(
                            name: controller.currentOrder.value.author!.firstName.toString(),
                            latitude: controller.currentOrder.value.address!.location!.latitude ?? 0.0,
                            longLatitude: controller.currentOrder.value.address!.location!.longitude ?? 0.0);
                      }
                    } else {
                      Utils.redirectMap(
                          name: controller.currentOrder.value.author!.firstName.toString(),
                          latitude: controller.currentOrder.value.vendor!.latitude ?? 0.0,
                          longLatitude: controller.currentOrder.value.vendor!.longitude ?? 0.0);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Archetype B — the incoming request, docked under the map.
  Widget showDriverBottomSheet(BuildContext context, HomeController controller) {
    double distanceInMeters = Geolocator.distanceBetween(controller.currentOrder.value.vendor!.latitude ?? 0.0, controller.currentOrder.value.vendor!.longitude ?? 0.0,
        controller.currentOrder.value.address!.location!.latitude ?? 0.0, controller.currentOrder.value.address!.location!.longitude ?? 0.0);
    double kilometer = distanceInMeters / 1000;

    final bool isFreelanceDriver = controller.driverModel.value.vendorID?.isEmpty == true;
    final String tip = controller.currentOrder.value.tipAmount ?? '';
    final bool hasTip = tip.isNotEmpty && double.parse(tip.toString()) > 0;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.md),
          child: DsRequestCard(
            title: "New Order".tr,
            section: DsSection.delivery,
            sectionLabel: Constant.sectionNameFromId(controller.currentOrder.value.sectionId),
            fare: isFreelanceDriver
                ? Constant.amountShow(
                    currency: RegionService.currencyForRecord(controller.currentOrder.value.regionId), amount: controller.currentOrder.value.deliveryCharge)
                : null,
            fareCaption: isFreelanceDriver ? "Delivery Charge".tr : null,
            stops: [
              DsRouteStop(
                kind: DsStopKind.pickup,
                label: "${controller.currentOrder.value.vendor!.title}",
                address: "${controller.currentOrder.value.vendor!.location}",
              ),
              DsRouteStop(
                kind: DsStopKind.drop,
                label: "${'Deliver to the'.tr} · ${controller.currentOrder.value.author!.fullName()}",
                address: controller.currentOrder.value.address!.getFullAddress(),
              ),
            ],
            metrics: [
              DsTripMetric(
                icon: Icons.route_rounded,
                value: "${double.parse(kilometer.toString()).toStringAsFixed(2)} ${Constant.distanceType}",
                label: "Trip Distance".tr,
              ),
              if (hasTip)
                DsTripMetric(
                  icon: Icons.volunteer_activism_outlined,
                  value: Constant.amountShow(
                      currency: RegionService.currencyForRecord(controller.currentOrder.value.regionId), amount: controller.currentOrder.value.tipAmount),
                  label: "Tips".tr,
                ),
            ],
            onReject: () {
              controller.rejectOrder();
            },
            onAccept: () {
              controller.acceptOrder();
            },
          ),
        ),
      ),
    );
  }

  /// Archetype C — the live job panel: who to reach, what to collect and the
  /// single xl action for the current step.
  Widget buildOrderActionsCard(BuildContext context, HomeController controller) {
    final t = context.dsText;

    double subTotal = 0.0;
    double couponAmount = 0.0;
    double specialDiscountAmount = 0.0;

    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double platformTaxAmount = 0.0;
    double driverDeliveryTaxAmount = 0.0;
    double totalTaxAmount = 0.0;

    double packagingCharge = 0.0;
    double deliveryCharge = 0.0;
    double deliveryTips = 0.0;
    double platformFee = 0.0;
    double deliveryCharges = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in controller.currentOrder.value.products!) {
      final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(controller.currentOrder.value.discount.toString());

    if (controller.currentOrder.value.specialDiscount != null && controller.currentOrder.value.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(
        controller.currentOrder.value.specialDiscount!['special_discount'].toString(),
      );
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (controller.currentOrder.value.taxScope == "product") {
      for (var element in controller.currentOrder.value.products!) {
        final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(
                  amount: discountedItemAmount.toString(),
                  taxModel: taxElement,
                ) *
                qty;
          } else {
            productTaxAmount += Constant.calculateTax(
              amount: discountedItemAmount.toString(),
              taxModel: taxElement,
            );
          }
        }
      }
    }

    /// ---------------- ORDER TAX ----------------
    if (controller.currentOrder.value.taxScope == "order") {
      for (var taxElement in controller.currentOrder.value.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(
          amount: (subTotal - totalDiscount).toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- CHARGES ----------------
    packagingCharge = double.parse(controller.currentOrder.value.vendor!.packagingCharge.toString());

    deliveryCharge = double.parse(controller.currentOrder.value.deliveryCharge ?? '0.0');

    deliveryTips = double.parse(controller.currentOrder.value.tipAmount ?? '0.0');

    platformFee = double.parse(controller.currentOrder.value.platformFee ?? '0.0');

    deliveryCharges = deliveryCharge;

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in controller.currentOrder.value.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(
          amount: packagingCharge.toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- PLATFORM TAX ----------------
    if (platformFee > 0) {
      for (var taxElement in controller.currentOrder.value.platformTax ?? []) {
        platformTaxAmount += Constant.calculateTax(
          amount: platformFee.toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- DELIVERY TAX ----------------
    if (controller.currentOrder.value.takeAway != true && controller.currentOrder.value.vendor?.isSelfDelivery != true) {
      for (var taxElement in controller.currentOrder.value.driverDeliveryTax ?? []) {
        driverDeliveryTaxAmount += Constant.calculateTax(
          amount: deliveryCharges.toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount + platformTaxAmount + driverDeliveryTaxAmount;

    /// ---------------- FINAL TOTAL ----------------
    num totalAmount = 0;

    if (controller.currentOrder.value.paymentMethod?.toLowerCase() != "cod") {
      totalAmount = deliveryCharge + deliveryTips + driverDeliveryTaxAmount;
    } else {
      totalAmount = (subTotal - totalDiscount) + totalTaxAmount + deliveryCharge + packagingCharge + platformFee;
    }

    final String status = controller.currentOrder.value.status.toString();
    final bool atStore = controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted;
    final bool isCod = controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod";
    final String tip = controller.currentOrder.value.tipAmount ?? '';
    final bool hasTip = tip.isNotEmpty && double.parse(tip.toString()) > 0;

    return DsMapPanel(
      header: Row(
        children: [
          Expanded(child: DsStatusChip(label: status.tr, status: status, pulse: true)),
          const DsGap(DsSpace.sm),
          Text(
            Constant.orderId(orderId: controller.currentOrder.value.id.toString()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSm.tabular,
          ),
        ],
      ),
      actions: DsButton.primary(
        label: atStore
            ? "Reached store for Pickup".tr
            : controller.driverModel.value.vendorID?.isEmpty == true
                ? "Reached the Customers Door Steps".tr
                : "Order Delivered".tr,
        icon: atStore ? Icons.storefront_rounded : Icons.flag_rounded,
        size: DsButtonSize.xl,
        expand: true,
        onPressed: () async {
          if (controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted) {
            Get.to(const PickupOrderScreen(), arguments: {"orderModel": controller.currentOrder.value})?.then((v) async {
              if (v == true) {
                OrderModel? ordermodel = await FireStoreUtils.getOrderById(controller.currentOrder.value.id!);
                if (ordermodel?.id != null) {
                  controller.currentOrder.value = ordermodel!;
                }
                controller.update();
              }
            });
          } else {
            Get.to(const DeliverOrderScreen(), arguments: {"orderModel": controller.currentOrder.value})!.then(
              (value) async {
                if (value == true) {
                  await AudioPlayerService.playSound(false);
                  controller.driverModel.value.inProgressOrderID!.remove(controller.currentOrder.value.id);
                  await FireStoreUtils.updateUser(controller.driverModel.value);
                  controller.currentOrder.value = OrderModel();
                  controller.clearMap();
                  if (Constant.singleOrderReceive == false) {
                    Get.back();
                  }
                }
              },
            );
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          atStore ? _storeRow(context, controller) : _routeWithContacts(context, controller),
          const DsGap(DsSpace.lg),
          DsInfoRow(
            label: "Payment Type".tr,
            value: isCod ? "Cash on delivery" : "Online",
            icon: isCod ? Icons.payments_outlined : Icons.credit_card_rounded,
            divider: hasTip,
          ),
          if (hasTip)
            DsInfoRow(
              label: "Tips".tr,
              icon: Icons.volunteer_activism_outlined,
              value: Constant.amountShow(
                  currency: RegionService.currencyForRecord(controller.currentOrder.value.regionId), amount: controller.currentOrder.value.tipAmount),
            ),
          if (isCod) ...[
            const DsGap(DsSpace.md),
            DsInlineAlert(
              tone: DsTone.warning,
              icon: Icons.account_balance_wallet_outlined,
              title: "Collect Payment from customer".tr,
              message: Constant.amountShow(currency: RegionService.currencyForRecord(controller.currentOrder.value.regionId), amount: totalAmount.toString()),
            ),
          ],
        ],
      ),
    );
  }

  /// Heading to the store: just the store and a way to call it.
  Widget _storeRow(BuildContext context, HomeController controller) {
    final t = context.dsText;
    return Row(
      children: [
        const DsIconWell(icon: Icons.storefront_rounded, circle: true),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${controller.currentOrder.value.vendor!.title}", style: t.titleSm.w700),
              Text("${controller.currentOrder.value.vendor!.location}", style: t.bodySm),
            ],
          ),
        ),
        const DsGap(DsSpace.sm),
        DsIconButton(
          icon: Icons.call_rounded,
          semanticLabel: "Call".tr,
          variant: DsIconButtonVariant.brand,
          onPressed: () {
            Constant.makePhoneCall(controller.currentOrder.value.vendor!.phonenumber.toString());
          },
        ),
      ],
    );
  }

  /// On the way to the customer: both stops with their contact shortcuts.
  Widget _routeWithContacts(BuildContext context, HomeController controller) {
    return DsRouteStops(
      stops: [
        DsRouteStop(
          kind: DsStopKind.pickup,
          done: true,
          label: "${controller.currentOrder.value.vendor!.title}",
          address: "${controller.currentOrder.value.vendor!.location}",
          trailing: DsIconButton(
            icon: Icons.call_rounded,
            semanticLabel: "Call".tr,
            variant: DsIconButtonVariant.outlined,
            onPressed: () {
              Constant.makePhoneCall(controller.currentOrder.value.vendor!.phonenumber.toString());
            },
          ),
        ),
        DsRouteStop(
          kind: DsStopKind.drop,
          label: "${'Deliver to the'.tr} · ${controller.currentOrder.value.author?.fullName() ?? ''}",
          address: controller.currentOrder.value.address!.getFullAddress(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIconButton(
                icon: Icons.call_rounded,
                semanticLabel: "Call".tr,
                variant: DsIconButtonVariant.outlined,
                onPressed: () {
                  Constant.makePhoneCall(controller.currentOrder.value.author!.phoneNumber.toString());
                },
              ),
              const DsGap(DsSpace.xs),
              DsIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                semanticLabel: "Chat".tr,
                variant: DsIconButtonVariant.brand,
                onPressed: () async {
                  ShowToastDialog.showLoader("Please wait".tr);

                  UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID.toString());
                  UserModel? driver = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverID.toString());

                  ShowToastDialog.closeLoader();

                  Get.to(const ChatScreen(), arguments: {
                    "senderName": driver!.fullName(),
                    "receivedName": customer!.fullName(),
                    "orderId": controller.orderModel.value.id,
                    "senderId": driver.id,
                    "receivedId": customer.id,
                    "receivedProfileUrl": customer.profilePictureURL ?? "",
                    "senderProfileUrl": driver.profilePictureURL ?? "",
                    "token": customer.fcmToken,
                    "chatType": Constant.userRoleDriver,
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
