import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/cab_home_controller.dart';
import 'package:driver/models/user_model.dart';
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
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:timelines_plus/timelines_plus.dart';

class CabHomeScreen extends StatelessWidget {
  const CabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final dashController = Get.put(CabDashBoardController());
    return GetX(
      init: CabHomeController(),
      builder: (controller) {
        return Scaffold(
          body: controller.isLoading.value
              ? Constant.loader()
              : Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
                  ? Obx(() {
                      final isDark = themeController.isDark.value;
                      return Padding(
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
                                CabDashBoardController dashBoardController = Get.put(CabDashBoardController());
                                dashBoardController.drawerIndex.value = 4;
                              },
                            ),
                          ],
                        ),
                      );
                    })
                  : Column(
                      children: [
                        Obx(() {
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
                              padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppThemeData.danger50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
                                    style: TextStyle(
                                      color: AppThemeData.grey900,
                                      fontSize: 14,
                                      fontFamily: AppThemeData.semiBold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < minDeposit) {
                            // Owner-driver case
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppThemeData.danger50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
                                    style: TextStyle(
                                      color: AppThemeData.grey900,
                                      fontSize: 14,
                                      fontFamily: AppThemeData.semiBold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox();
                          }
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
                                              GetBuilder<CabHomeController>(
                                                builder: (c) => flutterMap.MarkerLayer(markers: c.osmMarkers),
                                              ),
                                              GetBuilder<CabHomeController>(
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
                                            "${'Redirect'} ${Constant.mapType == "google" ? "Google Map" : Constant.mapType == "googleGo" ? "Google Go" : Constant.mapType == "waze" ? "Waze Map" : Constant.mapType == "mapswithme" ? "MapsWithMe Map" : Constant.mapType == "yandexNavi" ? "VandexNavi Map" : Constant.mapType == "yandexMaps" ? "Vandex Map" : ""}"
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
                                                    name: controller.currentOrder.value.sourceLocationName.toString(),
                                                    latitude: controller.currentOrder.value.sourceLocation!.latitude ?? 0.0,
                                                    longLatitude: controller.currentOrder.value.sourceLocation!.longitude ?? 0.0);
                                              } else if (controller.currentOrder.value.status == Constant.orderInTransit) {
                                                Utils.redirectMap(
                                                    name: controller.currentOrder.value.destinationLocationName.toString(),
                                                    latitude: controller.currentOrder.value.destinationLocation!.latitude ?? 0.0,
                                                    longLatitude: controller.currentOrder.value.destinationLocation!.longitude ?? 0.0);
                                              }
                                            } else {
                                              Utils.redirectMap(
                                                  name: controller.currentOrder.value.sourceLocationName.toString(),
                                                  latitude: controller.currentOrder.value.sourceLocation!.latitude ?? 0.0,
                                                  longLatitude: controller.currentOrder.value.sourceLocation!.longitude ?? 0.0);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        Obx(
                          () => controller.currentOrder.value.id != null &&
                                  (controller.currentOrder.value.status == Constant.driverPending || controller.currentOrder.value.status == Constant.orderPlaced)
                              ? showDriverBottomSheet(isDark, controller)
                              : Container(),
                        ),
                        Obx(
                          () => controller.shouldShowOrderSheet ? buildOrderActionsCard(isDark, controller) : const SizedBox(),
                        ),
                        // Obx(
                        //   () => controller.currentOrder.value.id != null && controller.currentOrder.value.status != Constant.driverPending
                        //       ? buildOrderActionsCard(isDark, controller)
                        //       : Container(),
                        // ),
                      ],
                    ),
        );
      },
    );
  }

  Padding showDriverBottomSheet(bool isDark, CabHomeController controller) {
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
                                  controller.currentOrder.value.author!.fullName(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  "${controller.currentOrder.value.sourceLocationName}",
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
                                  "Destination".tr,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  controller.currentOrder.value.destinationLocationName.toString(),
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
                    "${double.parse(controller.currentOrder.value.distance.toString()).toStringAsFixed(2)} ${Constant.distanceType}",
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "Ride Type".tr,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppThemeData.regular,
                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    controller.currentOrder.value.rideType ?? '',
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
                        if (controller.driverModel.value.ownerId != null && controller.driverModel.value.ownerId!.isNotEmpty) {
                          if (controller.ownerModel.value.walletAmount != null && controller.ownerModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
                            controller.acceptOrder();
                          } else {
                            ShowToastDialog.showToast("Your owner has to maintain minimum {amount} wallet balance to accept the cab booking. Please contact your owner"
                                .trParams({"amount": Constant.ownerMinimumDepositToRideAccept.toString()}).tr);
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

  Container buildOrderActionsCard(isDark, CabHomeController controller) {
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
                                  controller.currentOrder.value.author!.fullName(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  "${controller.currentOrder.value.sourceLocationName}",
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
                          Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Constant.makePhoneCall(controller.currentOrder.value.author!.phoneNumber.toString());
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
                              SizedBox(
                                height: 10,
                              ),
                              InkWell(
                                onTap: () async {
                                  ShowToastDialog.showLoader("Please wait".tr);

                                  UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID.toString());
                                  UserModel? driver = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId.toString());

                                  ShowToastDialog.closeLoader();

                                  Get.to(const ChatScreen(), arguments: {
                                    "customerName": customer!.fullName(),
                                    "restaurantName": driver!.fullName(),
                                    "orderId": controller.currentOrder.value.id,
                                    "restaurantId": driver.id,
                                    "customerId": customer.id,
                                    "customerProfileImage": customer.profilePictureURL ?? "",
                                    "restaurantProfileImage": driver.profilePictureURL ?? "",
                                    "token": customer.fcmToken,
                                    "chatType": "Driver",
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
                                                controller.currentOrder.value.author!.fullName(),
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 16,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                              Text(
                                                "${controller.currentOrder.value.sourceLocationName}",
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
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Destination".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 16,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                              Text(
                                                controller.currentOrder.value.destinationLocationName.toString(),
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
                                          onTap: () async {
                                            ShowToastDialog.showLoader("Please wait".tr);

                                            UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID.toString());
                                            UserModel? driver = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId.toString());

                                            ShowToastDialog.closeLoader();

                                            Get.to(const ChatScreen(), arguments: {
                                              "customerName": customer!.fullName(),
                                              "restaurantName": driver!.fullName(),
                                              "orderId": controller.currentOrder.value.id,
                                              "restaurantId": driver.id,
                                              "customerId": customer.id,
                                              "customerProfileImage": customer.profilePictureURL ?? "",
                                              "restaurantProfileImage": driver.profilePictureURL ?? "",
                                              "token": customer.fcmToken,
                                              "chatType": "Driver",
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
                      controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod" ? "Cash on delivery".tr : "Online".tr,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Ride Type".tr,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontFamily: AppThemeData.regular,
                          color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      controller.currentOrder.value.rideType ?? '',
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
                showVerifyPassengerDialog(Get.context!, isDark, controller);
              } else {
                if (controller.currentOrder.value.paymentMethod!.toLowerCase() == "cod") {
                  showConfirmCashPaymentDialog(Get.context!, isDark, onConfirm: () {
                    controller.completeRide();
                  });
                } else if (controller.currentOrder.value.paymentStatus == true) {
                  controller.completeRide();
                } else {
                  ShowToastDialog.showToast("Customer payment is pending".tr);
                }
              }
            },
            child: Container(
              color: AppThemeData.primary300,
              width: Responsive.width(100, Get.context!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  controller.currentOrder.value.status == Constant.orderShipped || controller.currentOrder.value.status == Constant.driverAccepted
                      ? Constant.enableOTPTripStart
                          ? "Verify Code to customer".tr
                          : "Pickup Customer".tr
                      : "Complete Ride".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
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

  void showVerifyPassengerDialog(BuildContext context, bool isDark, CabHomeController controller) {
    if (Constant.enableOTPTripStart == false) {
      controller.onRideStatus();
      return;
    }
    PinInputController otpController = PinInputController();

    Get.dialog(
      Dialog(
        backgroundColor: isDark
            ? AppThemeData.greyDark50 // 👈 dark background
            : AppThemeData.grey50,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20), // keeps margin around
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: Responsive.width(90, context),
          constraints: BoxConstraints(
            maxWidth: Responsive.width(90, context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Verify Passenger".tr, style: AppThemeData.boldTextStyle(fontSize: 22, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                    InkWell(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(Icons.close),
                    )
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Enter the OTP shared by the customer to begin the trip".tr,
                  textAlign: TextAlign.start,
                  style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 14),
                ),
                SizedBox(height: 20),
                MaterialPinField(
                  length: 4,
                  pinController: otpController,
                  keyboardType: TextInputType.phone,
                  enableAutofill: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  hintCharacter: "-",
                  theme: MaterialPinTheme(
                    cellSize: const Size(50, 50),
                    shape: MaterialPinShape.outlined,
                    borderRadius: BorderRadius.circular(10),
                    textStyle: TextStyle(
                      fontFamily: AppThemeData.regular,
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    ),
                    hintStyle: TextStyle(
                      fontFamily: AppThemeData.regular,
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    ),
                    fillColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                    borderColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                    focusedBorderColor: AppThemeData.primary300,
                    cursorColor: AppThemeData.primary300,
                  ),
                  onChanged: (value) {},
                  onCompleted: (pin) async {
                    // OTP completed
                  },
                ),
                SizedBox(height: 25),
                RoundedButtonFill(
                  title: "Start Ride".tr,
                  height: 5.5,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
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
                )
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  void showConfirmCashPaymentDialog(BuildContext context, bool isDark, {required VoidCallback onConfirm}) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: isDark
            ? AppThemeData.greyDark50 // 👈 dark background
            : AppThemeData.grey50, // 👈 light background
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Confirm Cash Payment".tr,
                      style: AppThemeData.boldTextStyle(
                        fontSize: 20,
                        color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close, size: 22),
                  )
                ],
              ),

              const SizedBox(height: 12),

              // Message
              Text(
                "Are you sure you received the cash from the passenger?".tr,
                style: AppThemeData.mediumTextStyle(
                  fontSize: 14,
                  color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Cancel".tr,
                      color: isDark ? AppThemeData.grey600 : AppThemeData.grey300,
                      textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      height: 5,
                      onPress: () {
                        Get.back();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Complete Ride".tr,
                      color: AppThemeData.driverApp300,
                      textColor: AppThemeData.grey50,
                      height: 5,
                      onPress: () {
                        Get.back();
                        onConfirm();
                      },
                      // onPress: () {
                      //   if (controller.currentOrder.value.paymentStatus == true) {
                      //     Get.back();
                      //     onConfirm();
                      //   } else {
                      //     ShowToastDialog.showToast("Customer payment is pending".tr);
                      //   }
                      // },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
