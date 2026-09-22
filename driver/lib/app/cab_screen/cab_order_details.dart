import 'package:driver/app/cab_screen/widget/cab_ride_extras.dart';
import 'package:driver/utils/region_service.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_order_details_controller.dart';
import '../../themes/app_them_data.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as osm;
import '../../themes/theme_controller.dart';
import '../../utils/network_image_widget.dart';

class CabOrderDetails extends StatelessWidget {
  const CabOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabOrderDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Ride Details",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor: isDark ? Colors.black : Colors.white,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "${'Order Id:'.tr} ${Constant.orderId(orderId: controller.cabOrder.value.id.toString())}".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: AppThemeData.semiBold,
                            fontSize: 18,
                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${'Booking Date:'.tr}${controller.formatDate(controller.cabOrder.value.scheduleDateTime!)}".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 18,
                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Icon(Icons.stop_circle_outlined, color: Colors.green),
                                    DottedBorder(
                                      options: CustomPathDottedBorderOptions(
                                        color: Colors.grey.shade400,
                                        strokeWidth: 2,
                                        dashPattern: [4, 4],
                                        customPath: (size) => Path()
                                          ..moveTo(size.width / 2, 0)
                                          ..lineTo(size.width / 2, size.height),
                                      ),
                                      child: const SizedBox(width: 20, height: 55),
                                    ),
                                    Icon(Icons.radio_button_checked, color: Colors.red),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Source Location Name
                                          Expanded(
                                            child: Text(
                                              controller.cabOrder.value.sourceLocationName.toString(),
                                              style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppThemeData.warning300, width: 1),
                                              color: AppThemeData.warning50,
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            child: Text(
                                              controller.cabOrder.value.status.toString(),
                                              style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.warning500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 15),
                                      DottedBorder(
                                        options: CustomPathDottedBorderOptions(
                                          color: Colors.grey.shade400,
                                          strokeWidth: 2,
                                          dashPattern: [4, 4],
                                          customPath: (size) => Path()
                                            ..moveTo(0, size.height / 2) // start from left center
                                            ..lineTo(size.width, size.height / 2), // draw to right center
                                        ),
                                        child: const SizedBox(width: 295, height: 3),
                                      ),
                                      SizedBox(height: 15),
                                      Text(
                                        controller.cabOrder.value.destinationLocationName.toString(),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // map view show
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Constant.selectedMapType == "osm"
                              ? fm.FlutterMap(
                                  options: fm.MapOptions(
                                    initialCenter: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                    initialZoom: 13,
                                  ),
                                  children: [
                                    fm.TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.spideli.driver'),

                                    // Only show polyline if points exist
                                    if (controller.osmPolyline.isNotEmpty)
                                      fm.PolylineLayer(polylines: [fm.Polyline(points: controller.osmPolyline.toList(), color: Colors.blue, strokeWidth: 4)]),

                                    fm.MarkerLayer(
                                      markers: [
                                        fm.Marker(
                                          point: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                          width: 20,
                                          height: 20,
                                          child: Image.asset('assets/icons/ic_cab_pickup.png', width: 10, height: 10),
                                        ),
                                        fm.Marker(
                                          point: osm.LatLng(
                                            controller.cabOrder.value.destinationLocation!.latitude!,
                                            controller.cabOrder.value.destinationLocation!.longitude!,
                                          ),
                                          width: 20,
                                          height: 20,
                                          child: Image.asset('assets/icons/ic_cab_destination.png', width: 10, height: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : gmap.GoogleMap(
                                  initialCameraPosition: gmap.CameraPosition(
                                    target: gmap.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                    zoom: 13,
                                  ),
                                  polylines: controller.googlePolylines.toSet(),
                                  markers: controller.googleMarkers.toSet(),
                                ),
                        ),
                      ),
                      controller.cabOrder.value.driver != null
                          ? Column(
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "About Customer".tr,
                                        style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 52,
                                                height: 52,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadiusGeometry.circular(10),
                                                  child: NetworkImageWidget(
                                                    imageUrl: controller.cabOrder.value.author?.profilePictureURL ?? '',
                                                    height: 70,
                                                    width: 70,
                                                    borderRadius: 35,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 20),
                                              Text(
                                                controller.cabOrder.value.author?.fullName() ?? '',
                                                style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                              ),
                                              // Column(
                                              //   crossAxisAlignment: CrossAxisAlignment.start,
                                              //   children: [
                                              //     Text(
                                              //       controller.cabOrder.value.author?.fullName() ?? '',
                                              //       style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                              //     ),
                                              //     Text(
                                              //       "${controller.cabOrder.value.author?.vehicleType ?? ''} | ${controller.cabOrder.value.author?.carMakes.toString()}",
                                              //       style: TextStyle(
                                              //         fontFamily: AppThemeData.medium,
                                              //         color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                              //         fontSize: 14,
                                              //       ),
                                              //     ),
                                              //     Text(
                                              //       controller.cabOrder.value.driver?.carNumber ?? '',
                                              //       style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 16),
                                              //     ),
                                              //   ],
                                              // ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _iconTile(
                              controller.cabOrder.value.distance != null
                                  ? "${double.tryParse(controller.cabOrder.value.distance.toString())?.toStringAsFixed(2) ?? '--'} KM"
                                  : "-- KM",
                              "Distance".tr,
                              "assets/icons/ic_distance_parcel.svg",
                              isDark,
                            ),
                            _iconTile(controller.cabOrder.value.duration ?? '--', "Duration".tr, "assets/icons/ic_duration.svg", isDark),
                            _iconTile(
                              Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: controller.cabOrder.value.subTotal),
                              "${controller.cabOrder.value.paymentMethod}".tr,
                              "assets/icons/ic_rate_parcel.svg",
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      if (CabRideExtras.hasContent(controller.cabOrder.value, showCancellation: true)) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: CabRideExtras(order: controller.cabOrder.value, isDark: isDark, showCancellation: true),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
                            const SizedBox(height: 8),

                            // Subtotal
                            _summaryTile("Subtotal".tr, Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: controller.subTotal.value.toString()), isDark, null),

                            // Discount
                            _summaryTile("Discount".tr, Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: controller.discount.value.toString()), isDark, null),

                            // Tax List
                            ...List.generate(controller.cabOrder.value.taxSetting!.length, (index) {
                              return _summaryTile(
                                  "${controller.cabOrder.value.taxSetting![index].title} ${controller.cabOrder.value.taxSetting![index].type == 'fix' ? '' : '(${controller.cabOrder.value.taxSetting![index].tax}%)'}",
                                  Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: Constant.getTaxValue(
                                      amount: ((double.tryParse(controller.cabOrder.value.subTotal.toString()) ?? 0.0) -
                                              (double.tryParse(controller.cabOrder.value.discount.toString()) ?? 0.0))
                                          .toString(),
                                      taxModel: controller.cabOrder.value.taxSetting![index],
                                    ).toString(),
                                  ),
                                  isDark,
                                  null);
                            }),

                            const Divider(),

                            // Total
                            _summaryTile("Order Total".tr, Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: controller.totalAmount.value.toString()), isDark, null),
                            _summaryTile(
                              "Admin Commission (${controller.cabOrder.value.adminCommission}${controller.cabOrder.value.adminCommissionType == "Percentage" || controller.cabOrder.value.adminCommissionType == "percentage" ? "%" : Constant.currencyModel!.symbol})"
                                  .tr,
                              Constant.amountShow(currency: RegionService.currencyForRecord(controller.cabOrder.value.regionId), amount: controller.adminCommission.value.toString()),
                              isDark,
                              AppThemeData.danger300,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      controller.cabOrder.value.driver!.ownerId != null && controller.cabOrder.value.driver!.ownerId!.isNotEmpty ||
                              controller.cabOrder.value.status == Constant.orderPlaced
                          ? SizedBox()
                          : Container(
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? AppThemeData.danger50 : AppThemeData.danger50),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Note : Admin commission will be debited from your wallet balance. \n \nAdmin commission will apply on your booking Amount minus Discount(if applicable).",
                                      style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.danger300 : AppThemeData.danger300),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _iconTile(String value, title, icon, bool isDark) {
    return Column(
      children: [
        // Icon(icon, color: AppThemeData.primary300),
        SvgPicture.asset(icon, height: 28, width: 28, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
        const SizedBox(height: 6),
        Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
        const SizedBox(height: 6),
        Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }

  Widget _summaryTile(String title, String value, bool isDark, Color? colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
          Text(
            value,
            style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total" ? 18 : 16, color: colors ?? (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
          ),
        ],
      ),
    );
  }
}
