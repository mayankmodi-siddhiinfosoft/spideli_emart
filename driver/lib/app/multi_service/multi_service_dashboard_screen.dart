import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/themes/ds/ds.dart';
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
///
/// Archetype A/K shell: the service switcher is a raised, hairline-topped bar
/// whose active tab is tinted with that service's section accent.
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

  ({IconData icon, IconData activeIcon, String label}) _tabSpec(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        return (icon: Icons.local_taxi_outlined, activeIcon: Icons.local_taxi, label: 'Cab');
      case 'parcel_delivery':
        return (icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Parcel');
      case 'rental-service':
        return (icon: Icons.car_rental_outlined, activeIcon: Icons.car_rental, label: 'Rental');
      default:
        return (icon: Icons.delivery_dining_outlined, activeIcon: Icons.delivery_dining, label: 'Delivery');
    }
  }

  BottomNavigationBarItem _navItemForService(BuildContext context, String serviceType, bool selected) {
    final c = context.dsColors;
    final spec = _tabSpec(serviceType);
    final accent = c.section(DsSection.fromServiceType(serviceType));
    Widget pill(IconData icon, bool active) => AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.emphasized,
          margin: const EdgeInsets.only(bottom: DsSpace.xxs),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
          decoration: BoxDecoration(
            color: active ? accent.soft : Colors.transparent,
            borderRadius: DsRadius.brPill,
          ),
          child: Icon(icon, size: 22, color: active ? accent.strong : c.textMuted),
        );
    return BottomNavigationBarItem(
      icon: pill(spec.icon, false),
      activeIcon: pill(spec.activeIcon, true),
      label: spec.label,
      tooltip: spec.label,
    );
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
          themeController.isDark.value;
          final index = controller.currentIndex.value;
          final c = context.dsColors;
          return Scaffold(
            backgroundColor: c.background,
            body: IndexedStack(
              index: index,
              children: serviceTypes.map(_dashboardForService).toList(),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: DsShadows.sm(context),
              ),
              child: BottomNavigationBar(
                currentIndex: index,
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
                selectedItemColor: c.textPrimary,
                unselectedItemColor: c.textMuted,
                selectedLabelStyle: DsTypography.labelSm,
                unselectedLabelStyle: DsTypography.labelSm,
                backgroundColor: Colors.transparent,
                elevation: 0,
                items: [
                  for (var i = 0; i < serviceTypes.length; i++) _navItemForService(context, serviceTypes[i], i == index),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
