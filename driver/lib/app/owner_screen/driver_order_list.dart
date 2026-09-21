import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_order_controller.dart';
import '../../themes/theme_controller.dart';
import '../cab_screen/cab_order_list_screen.dart';
import '../parcel_screen/parcel_order_list_screen.dart';
import '../rental_service/rental_order_list_screen.dart';

class DriverOrderList extends StatelessWidget {
  const DriverOrderList({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<DriverOrderListController>(
      init: DriverOrderListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Driver Orders".tr,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor: isDark ? Colors.black : Colors.white,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          body: _buildBody(controller.serviceType.value),
        );
      },
    );
  }

  Widget _buildBody(String? serviceType) {
    switch (serviceType) {
      case "cab-service":
        return const CabOrderListScreen();
      case "parcel_delivery":
        return const ParcelOrderListScreen();
      case "rental-service":
        return const RentalOrderListScreen();
      default:
        return const Center(child: Text("Service type not supported"));
    }
  }
}
