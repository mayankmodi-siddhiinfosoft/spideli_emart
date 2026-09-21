import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_order_list_controller.dart';
import '../../models/cab_order_model.dart';
import '../../themes/app_them_data.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../themes/theme_controller.dart';
import 'cab_order_details.dart';

class CabOrderListScreen extends StatelessWidget {
  const CabOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: CabOrderListController(),
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
                    // isScrollable: true,
                    indicatorColor: AppThemeData.primary300,
                    labelColor: AppThemeData.primary300,
                    dividerColor: isDark ? Colors.black : Colors.white,
                    unselectedLabelColor: AppThemeData.primary300.withOpacity(0.60),
                    labelStyle: AppThemeData.boldTextStyle(fontSize: 14),
                    unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 14),
                    tabs: controller.tabTitles.map((title) => Tab(child: Center(child: Text(title)))).toList(),
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
                                    "No orders found",
                                    style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  CabOrderModel order = orders[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Get.to(() => CabOrderDetails(), arguments: {"cabOrderModel": order});
                                    },
                                    child: Container(
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
                                            "${'Booking Date:'.tr} ${controller.formatDate(order.scheduleDateTime!)}".tr,
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              fontFamily: AppThemeData.semiBold,
                                              fontSize: 18,
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                "${'Section:'.tr} ",
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.regular,
                                                  fontSize: 13,
                                                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                ),
                                              ),
                                              Text(
                                                Constant.sectionNameFromId(order.sectionId),
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontSize: 13,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                            ],
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
                                                            order.sourceLocationName.toString(),
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
                                                            order.status.toString(),
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
                                                      order.destinationLocationName.toString(),
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
}
