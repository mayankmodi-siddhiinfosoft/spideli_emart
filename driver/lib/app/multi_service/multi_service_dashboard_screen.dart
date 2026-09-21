import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Controller that tracks which service tab is active.
class MultiServiceDashboardController extends GetxController {
  RxInt currentIndex = 0.obs;
}

/// Unified dashboard for drivers registered to multiple services.
/// Shows a BottomNavigationBar with one tab per registered service.
/// Each tab renders the full existing service dashboard.
class MultiServiceDashboardScreen extends StatelessWidget {
  const MultiServiceDashboardScreen({super.key});

  /// Returns the ordered list of service type keys for this driver.
  List<String> _serviceTypes() {
    final user = Constant.userModel;
    if (user == null) return ['delivery-service'];
    if (user.serviceTypes != null && user.serviceTypes!.isNotEmpty) {
      return user.serviceTypes!;
    }
    return [user.serviceTypes?.first ?? 'delivery-service'];
  }

  Widget _dashboardForService(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        return const CabDashboardScreen();
      case 'parcel_delivery':
        return const ParcelDashboardScreen();
      case 'rental-service':
        return const RentalDashboardScreen();
      default:
        return const DashBoardScreen();
    }
  }

  BottomNavigationBarItem _navItemForService(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.local_taxi_outlined),
          activeIcon: Icon(Icons.local_taxi),
          label: 'Cab',
        );
      case 'parcel_delivery':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Parcel',
        );
      case 'rental-service':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.car_rental_outlined),
          activeIcon: Icon(Icons.car_rental),
          label: 'Rental',
        );
      default:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.delivery_dining_outlined),
          activeIcon: Icon(Icons.delivery_dining),
          label: 'Delivery',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceTypes = _serviceTypes();

    // Single service: skip wrapper, go directly to the appropriate dashboard.
    if (serviceTypes.length == 1) {
      return _dashboardForService(serviceTypes.first);
    }

    final themeController = Get.find<ThemeController>();

    return GetBuilder<MultiServiceDashboardController>(
      init: MultiServiceDashboardController(),
      builder: (controller) {
        return Obx(() {
          final isDark = themeController.isDark.value;
          return Scaffold(
            body: IndexedStack(
              index: controller.currentIndex.value,
              children: serviceTypes.map(_dashboardForService).toList(),
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: controller.currentIndex.value,
              onTap: (index) {
                controller.currentIndex.value = index;
                // Reset each dashboard to home screen when switching tabs
                if (Get.isRegistered<DashBoardController>()) {
                  Get.find<DashBoardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<CabDashBoardController>()) {
                  Get.find<CabDashBoardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<ParcelDashboardController>()) {
                  Get.find<ParcelDashboardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<RentalDashboardController>()) {
                  Get.find<RentalDashboardController>().drawerIndex.value = 0;
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppThemeData.primary300,
              unselectedItemColor: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              items: serviceTypes.map(_navItemForService).toList(),
            ),
          );
        });
      },
    );
  }
}
