import 'package:driver/app/owner_screen/driver_create_screen.dart';
import 'package:driver/app/owner_screen/driver_order_list.dart';
import 'package:driver/controllers/owner_home_controller.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ViewAllDriverScreen extends StatelessWidget {
  const ViewAllDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<OwnerHomeController>(
      init: Get.find<OwnerHomeController>(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text("All Drivers".tr),
          ),
          body: controller.driverList.isEmpty
              ? Center(child: Text("No drivers found".tr))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: controller.driverList.length,
                  itemBuilder: (context, index) {
                    final driver = controller.driverList[index];
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                          ),
                        ),
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: NetworkImageWidget(
                                imageUrl: driver.profilePictureURL ?? '',
                                height: 42,
                                width: 42,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.fullName(),
                                    style: AppThemeData.semiBoldTextStyle(
                                      fontSize: 16,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                  ),
                                  Text(
                                    '${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}',
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RoundedButtonFill(
                              title: driver.isActive == false ? "Offline" : "Online".tr,
                              height: 3.5,
                              width: 18,
                              borderRadius: 10,
                              color: driver.isActive == false ? AppThemeData.danger300 : AppThemeData.success300,
                              textColor: AppThemeData.grey50,
                              onPress: () {},
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'Edit Driver') {
                                  Get.to(() => const DriverCreateScreen(), arguments: {"driverModel": driver})?.then((value0) {
                                    if (value0 == true) controller.getDriverList();
                                  });
                                } else if (value == 'Delete Driver') {
                                  controller.deleteDriver(driver.id.toString());
                                } else if (value == 'View All Order') {
                                  Get.to(() => const DriverOrderList(), arguments: {
                                    "driverId": driver.id,
                                    "serviceType": driver.serviceTypes?.first,
                                  });
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'Edit Driver',
                                  child: Text('Edit Driver'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                ),
                                PopupMenuItem<String>(
                                  value: 'Delete Driver',
                                  child: Text('Delete Driver'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                ),
                                PopupMenuItem<String>(
                                  value: 'View All Order',
                                  child: Text('View All Order'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                ),
                              ],
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              icon: Icon(Icons.more_vert, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
