import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_list_controller.dart';
import '../../themes/app_them_data.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../themes/theme_controller.dart';

class ParcelOrderListScreen extends StatelessWidget {
  const ParcelOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX<ParcelOrderListController>(
        init: ParcelOrderListController(),
        builder: (controller) {
          return DefaultTabController(
            length: controller.tabTitles.length,
            initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
            child: Scaffold(
              body: Column(
                children: [
                  // TabBar
                  TabBar(
                    onTap: (index) {
                      controller.selectTab(controller.tabTitles[index]);
                    },
                    indicatorColor: AppThemeData.parcelService500,
                    labelColor: AppThemeData.parcelService500,
                    dividerColor: Colors.transparent,
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
                                  final order = orders[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Get.to(() => const ParcelOrderDetails(), arguments: order);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Text(
                                              "Order Date:${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                                              style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.info400),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Row(
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
                                          ),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Column(
                                                children: [
                                                  Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
                                                  DottedBorder(
                                                    options: CustomPathDottedBorderOptions(
                                                      color: Colors.grey.shade400,
                                                      strokeWidth: 2,
                                                      dashPattern: [4, 4],
                                                      customPath: (size) => Path()
                                                        ..moveTo(size.width / 2, 0)
                                                        ..lineTo(size.width / 2, size.height),
                                                    ),
                                                    child: const SizedBox(width: 20, height: 95),
                                                  ),
                                                  Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _infoSection(
                                                      "Pickup Address (Sender):".tr,
                                                      order.sender?.name ?? '',
                                                      order.sender?.address ?? '',
                                                      order.sender?.phone ?? '',
                                                      // order.senderPickupDateTime != null
                                                      //     ? "Pickup Time: ${controller.formatDate(order.senderPickupDateTime!)}"
                                                      //     : '',
                                                      order.status,
                                                      isDark,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    _infoSection(
                                                      "Delivery Address (Receiver):".tr,
                                                      order.receiver?.name ?? '',
                                                      order.receiver?.address ?? '',
                                                      order.receiver?.phone ?? '',
                                                      // order.receiverPickupDateTime != null
                                                      //     ? "Delivery Time: ${controller.formatDate(order.receiverPickupDateTime!)}"
                                                      //     : '',
                                                      null,
                                                      isDark,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
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
            ),
          );
        },
      );
    });
  }

  Widget _infoSection(String title, String name, String address, String phone, String? status, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppThemeData.info50,
                  border: Border.all(color: AppThemeData.info300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.info500)),
              ),
            ],
          ],
        ),
        Text(name, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(address, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(phone, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        //Text(time, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }
}
