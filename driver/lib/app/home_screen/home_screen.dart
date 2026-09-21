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
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timelines_plus/timelines_plus.dart';

class HomeScreen extends StatelessWidget {
  final bool? isAppBarShow;

  const HomeScreen({super.key, this.isAppBarShow});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final dashController = Get.put(DashBoardController());
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: HomeController(),
        builder: (controller) {
          return Scaffold(
            appBar: isAppBarShow == true
                ? AppBar(
                    backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    centerTitle: false,
                    iconTheme: const IconThemeData(color: AppThemeData.grey900, size: 20),
                    title: Text(
                      "Order".tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18, fontFamily: AppThemeData.medium),
                    ),
                  )
                : null,
            body: controller.isLoading.value
                ? Constant.loader()
                : controller.driverModel.value.vendorID?.isEmpty == true &&
                       
                        controller.driverModel.value.isDocumentVerify == false &&
                        controller.driverModel.value.isAutoVerify == false
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(120),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: SvgPicture.asset("assets/icons/ic_document.svg"),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              "Document Verification in Pending".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            RoundedButtonFill(
                              title: "View Status".tr,
                              width: 55,
                              height: 5.5,
                              color: AppThemeData.primary300,
                              textColor: AppThemeData.grey50,
                              onPress: () async {
                                DashBoardController dashBoardController = Get.put(DashBoardController());
                                dashBoardController.drawerIndex.value = 4;
                              },
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Obx(() {
                            num wallet = dashController.userModel.value.walletAmount ?? 0.0;
                            return Constant.userModel?.vendorID?.isEmpty == true && wallet < double.parse(Constant.minimumDepositToRideAccept)
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                        decoration: BoxDecoration(color: AppThemeData.danger50, borderRadius: BorderRadius.circular(10)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "${'You have to minimum'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'wallet amount to receiving Order'.tr}",
                                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                                          ),
                                        )),
                                  )
                                : const SizedBox();
                          }),
                          // Constant.userModel?.vendorID?.isEmpty == true &&
                          //         double.parse(Constant.userModel!.walletAmount == null ? "0.0" : Constant.userModel!.walletAmount.toString()) <
                          //             double.parse(Constant.minimumDepositToRideAccept)
                          //     ? Padding(
                          //         padding: const EdgeInsets.all(8.0),
                          //         child: Text(
                          //           "${'You have to minimum'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'wallet amount to receiving Order'.tr}",
                          //           style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                          //         ),
                          //       )
                          //     : const SizedBox(),
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
                                        Positioned(
                                          top: 20,
                                          right: 20,
                                          child: FloatingActionButton(
                                            heroTag: 'center_osm',
                                            onPressed: () {
                                              try {
                                                controller.animateToSource();
                                              } catch (e) {
                                                // ignore
                                              }
                                            },
                                            child: const Icon(Icons.my_location),
                                          ),
                                        ),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset("assets/images/ic_location_map.svg"),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          "${'Navigate with'.tr} ${Constant.mapType == "google" ? "Google Map" : Constant.mapType == "googleGo" ? "Google Go" : Constant.mapType == "waze" ? "Waze Map" : Constant.mapType == "mapswithme" ? "MapsWithMe Map" : Constant.mapType == "yandexNavi" ? "VandexNavi Map" : Constant.mapType == "yandexMaps" ? "Vandex Map" : ""}",
                                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                                        ),
                                        Text(
                                          "${'Easily find your destination with a single tap redirect to'.tr}  ${Constant.mapType == "google" ? "Google Map" : Constant.mapType == "googleGo" ? "Google Go" : Constant.mapType == "waze" ? "Waze Map" : Constant.mapType == "mapswithme" ? "MapsWithMe Map" : Constant.mapType == "yandexNavi" ? "VandexNavi Map" : Constant.mapType == "yandexMaps" ? "Vandex Map" : ""} ${'for seamless navigation.'.tr}",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.regular),
                                        ),
                                        const SizedBox(
                                          height: 30,
                                        ),
                                        RoundedButtonFill(
                                          title:
                                              "${'Redirect'.tr} ${Constant.mapType == "google" ? "Google Map" : Constant.mapType == "googleGo" ? "Google Go" : Constant.mapType == "waze" ? "Waze Map" : Constant.mapType == "mapswithme" ? "MapsWithMe Map" : Constant.mapType == "yandexNavi" ? "VandexNavi Map" : Constant.mapType == "yandexMaps" ? "Vandex Map" : ""}"
                                                  .tr,
                                          width: 55,
                                          height: 5.5,
                                          color: AppThemeData.primary300,
                                          textColor: AppThemeData.grey50,
                                          onPress: () async {
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
                          controller.currentOrder.value.id != null && controller.currentOrder.value.status == Constant.driverPending ? showDriverBottomSheet(isDark, controller) : Container(),
                          controller.currentOrder.value.id != null &&
                                  (controller.currentOrder.value.status == Constant.driverAccepted ||
                                      controller.currentOrder.value.status == Constant.orderShipped ||
                                      controller.currentOrder.value.status == Constant.orderInTransit)
                              ? buildOrderActionsCard(isDark, controller)
                              : Container(),
                        ],
                      ),
          );
        },
      );
    });
  }

  Padding showDriverBottomSheet(bool isDark, HomeController controller) {
    double distanceInMeters = Geolocator.distanceBetween(controller.currentOrder.value.vendor!.latitude ?? 0.0, controller.currentOrder.value.vendor!.longitude ?? 0.0,
        controller.currentOrder.value.address!.location!.latitude ?? 0.0, controller.currentOrder.value.address!.location!.longitude ?? 0.0);
    double kilometer = distanceInMeters / 1000;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: ShapeDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Timeline.tileBuilder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                theme: TimelineThemeData(
                  nodePosition: 0,
                  // indicatorPosition: 0,
                ),
                builder: TimelineTileBuilder.connected(
                  contentsAlign: ContentsAlign.basic,
                  indicatorBuilder: (context, index) {
                    return index == 0
                        ? Container(
                            decoration: ShapeDecoration(
                              color: AppThemeData.primary50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(120),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                "assets/icons/ic_building.svg",
                                colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                              ),
                            ),
                          )
                        : Container(
                            decoration: ShapeDecoration(
                              color: AppThemeData.carRent50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(120),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                "assets/icons/ic_location.svg",
                                colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                              ),
                            ),
                          );
                  },
                  connectorBuilder: (context, index, connectorType) {
                    return const DashedLineConnector(
                      color: AppThemeData.grey300,
                      gap: 3,
                    );
                  },
                  contentsBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: index == 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${controller.currentOrder.value.vendor!.title}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  "${controller.currentOrder.value.vendor!.location}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Deliver to the".tr,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  controller.currentOrder.value.author!.fullName(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 14,
                                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                  ),
                                ),
                                Text(
                                  controller.currentOrder.value.address!.getFullAddress(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                  itemCount: 2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "Trip Distance".tr,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppThemeData.regular,
                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    "${double.parse(kilometer.toString()).toStringAsFixed(2)} ${Constant.distanceType}",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: AppThemeData.semiBold,
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Visibility(
                visible: (controller.driverModel.value.vendorID?.isEmpty == true),
                child: Column(children: [
                  const SizedBox(
                    height: 5,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "Delivery Charge".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: AppThemeData.regular,
                            color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        Constant.amountShow(amount: controller.currentOrder.value.deliveryCharge),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontFamily: AppThemeData.semiBold,
                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(
                height: 5,
              ),
              controller.currentOrder.value.tipAmount == null || controller.currentOrder.value.tipAmount!.isEmpty || double.parse(controller.currentOrder.value.tipAmount.toString()) <= 0
                  ? const SizedBox()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "Tips".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.regular,
                              color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          Constant.amountShow(amount: controller.currentOrder.value.tipAmount),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: AppThemeData.semiBold,
                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Reject".tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.grey50,
                      onPress: () {
                        controller.rejectOrder();
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Accept".tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.success400,
                      textColor: AppThemeData.grey50,
                      onPress: () {
                        controller.acceptOrder();
                      },
                    ),
                  )
                ],
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Container buildOrderActionsCard(isDark, HomeController controller) {
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

    return Container(
      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted
                    ? Row(
                        children: [
                          Container(
                            decoration: ShapeDecoration(
                              color: AppThemeData.primary50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(120),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                "assets/icons/ic_building.svg",
                                colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${controller.currentOrder.value.vendor!.title}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  "${controller.currentOrder.value.vendor!.location}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          InkWell(
                            onTap: () {
                              Constant.makePhoneCall(controller.currentOrder.value.vendor!.phonenumber.toString());
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: ShapeDecoration(
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  borderRadius: BorderRadius.circular(120),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SvgPicture.asset("assets/icons/ic_phone_call.svg"),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Timeline.tileBuilder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        theme: TimelineThemeData(
                          nodePosition: 0,
                          // indicatorPosition: 0,
                        ),
                        builder: TimelineTileBuilder.connected(
                          contentsAlign: ContentsAlign.basic,
                          indicatorBuilder: (context, index) {
                            return index == 0
                                ? Container(
                                    decoration: ShapeDecoration(
                                      color: AppThemeData.primary50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(120),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: SvgPicture.asset(
                                        "assets/icons/ic_building.svg",
                                        colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: ShapeDecoration(
                                      color: AppThemeData.carRent50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(120),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: SvgPicture.asset(
                                        "assets/icons/ic_location.svg",
                                        colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                          },
                          connectorBuilder: (context, index, connectorType) {
                            return const DashedLineConnector(
                              color: AppThemeData.grey300,
                              gap: 3,
                            );
                          },
                          contentsBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: index == 0
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${controller.currentOrder.value.vendor!.title}",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 16,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                              Text(
                                                "${controller.currentOrder.value.vendor!.location}",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.medium,
                                                  fontSize: 14,
                                                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Constant.makePhoneCall(controller.currentOrder.value.vendor!.phonenumber.toString());
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: SvgPicture.asset("assets/icons/ic_phone_call.svg"),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Deliver to the".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 16,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                              Text(
                                                controller.currentOrder.value.author?.fullName() ?? '',
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 14,
                                                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                ),
                                              ),
                                              Text(
                                                controller.currentOrder.value.address!.getFullAddress(),
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.medium,
                                                  fontSize: 14,
                                                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Constant.makePhoneCall(controller.currentOrder.value.author!.phoneNumber.toString());
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: SvgPicture.asset("assets/icons/ic_phone_call.svg"),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        InkWell(
                                          onTap: () async {
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
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: SvgPicture.asset("assets/icons/ic_wechat.svg"),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                            );
                          },
                          itemCount: 2,
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Payment Type".tr,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontFamily: AppThemeData.regular,
                          color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod" ? "Cash on delivery" : "Online",
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppThemeData.semiBold,
                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ),
                controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod"
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Collect Payment from customer".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontFamily: AppThemeData.regular,
                                color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            Constant.amountShow(amount: totalAmount.toString()),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(),
                const SizedBox(
                  height: 5,
                ),
                controller.currentOrder.value.tipAmount == null || controller.currentOrder.value.tipAmount!.isEmpty || double.parse(controller.currentOrder.value.tipAmount.toString()) <= 0
                    ? const SizedBox()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Tips".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontFamily: AppThemeData.regular,
                                color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            Constant.amountShow(amount: controller.currentOrder.value.tipAmount),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
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
            child: Container(
              color: AppThemeData.primary300,
              width: Responsive.width(100, Get.context!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted
                      ? "Reached store for Pickup".tr
                      : controller.driverModel.value.vendorID?.isEmpty == true
                          ? "Reached the Customers Door Steps".tr
                          : "Order Delivered".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey900,
                    fontSize: 16,
                    fontFamily: AppThemeData.semiBold,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
