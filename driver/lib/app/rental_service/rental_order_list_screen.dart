import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:flutter/material.dart';
import '../../constant/constant.dart';
import '../../controllers/rental_order_list_controller.dart';
import '../../models/rental_order_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/theme_controller.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RentalOrderListScreen extends StatelessWidget {
  const RentalOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<RentalOrderListController>(
      init: RentalOrderListController(),
      builder: (controller) {
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: Column(
            children: [
              // TabBar
              TabBar(
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
                indicatorColor: AppThemeData.parcelService500,
                labelColor: AppThemeData.parcelService500,
                dividerColor: isDark ? Colors.black : Colors.white,
                unselectedLabelColor: AppThemeData.grey500,
                labelStyle: AppThemeData.boldTextStyle(fontSize: 16),
                unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 16),
                tabs: controller.tabTitles.map((title) => Tab(child: Text(title))).toList(),
              ),

              // Body: loader or TabBarView
              Expanded(
                child: controller.isLoading.value
                    ? Constant.loader()
                    : TabBarView(
                        children: controller.tabTitles.map((title) {
                          // filter by tab using controller helper
                          final orders = controller.getOrdersForTab(title);

                          if (orders.isEmpty) {
                            return Center(
                              child: Text(
                                "No orders found".tr,
                                style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              RentalOrderModel order = orders[index]; //use this
                              return InkWell(
                                onTap: () {
                                  Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": order.id});
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(padding: const EdgeInsets.only(top: 5), child: Image.asset("assets/icons/pickup.png", height: 18, width: 18)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            //prevents overflow
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      //text wraps if too long
                                                      child: Text(
                                                        order.sourceLocationName ?? "-",
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                        overflow: TextOverflow.ellipsis, //safe cutoff
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                    if (order.status != null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                                        decoration: BoxDecoration(
                                                          color: AppThemeData.info50,
                                                          border: Border.all(color: AppThemeData.info300),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(order.status ?? '', style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.info500)),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (order.bookingDateTime != null)
                                                  Text(
                                                    Constant.timestampToDateTime(order.bookingDateTime!),
                                                    style: AppThemeData.mediumTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            "${'Section:'.tr} ",
                                            style: AppThemeData.regularTextStyle(fontSize: 13, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                          ),
                                          Text(
                                            Constant.sectionNameFromId(order.sectionId),
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 13, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text("Vehicle Type :".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl: order.rentalVehicleType?.rentalVehicleIcon ?? Constant.placeHolderImage,
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Center(
                                                  child: CircularProgressIndicator.adaptive(
                                                    valueColor: AlwaysStoppedAnimation(AppThemeData.primary300),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Image.network(
                                                  Constant.placeHolderImage,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${order.rentalVehicleType!.name}",
                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0),
                                                      child: Text(
                                                        "${order.rentalVehicleType!.shortDescription}",
                                                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text("Package info :".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    order.rentalPackageModel!.name.toString(),
                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    order.rentalPackageModel!.description.toString(),
                                                    style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              Constant.amountShow(amount: order.rentalPackageModel!.baseFare.toString()),
                                              style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (order.status == Constant.orderPlaced || order.status == Constant.driverAccepted) ...[
                                        SizedBox(height: 10),
                                        if (order.status == Constant.orderPlaced || order.status == Constant.driverAccepted)
                                          Expanded(
                                            child: RoundedButtonFill(
                                              title: "Cancel Booking".tr,
                                              onPress: () {
                                                // controller.cancelRentalRequest(order);
                                              },
                                              color: AppThemeData.danger300,
                                              textColor: AppThemeData.surface,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
