import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/themes/app_them_data.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          return PopScope(
            canPop: controller.canPopNow.value,
            onPopInvoked: (didPop) {
              final now = DateTime.now();
              if (controller.currentBackPressTime == null || now.difference(controller.currentBackPressTime!) > const Duration(seconds: 2)) {
                controller.currentBackPressTime = now;
                controller.canPopNow.value = false;
                ShowToastDialog.showToast("Double press to exit".tr);
                return;
              } else {
                controller.canPopNow.value = true;
              }
            },
            child: Scaffold(
              body: controller.isLoading.value ? Constant.loader() : controller.navigationItems[controller.selectedIndex.value].page,
              bottomNavigationBar: controller.isLoading.value
                  ? null
                  : BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      showUnselectedLabels: true,
                      showSelectedLabels: true,
                      selectedFontSize: 12,
                      selectedIconTheme: IconThemeData(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                      selectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
                      unselectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
                      currentIndex: controller.selectedIndex.value,
                      backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                      selectedItemColor: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                      unselectedItemColor: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                      onTap: (int index) {
                        controller.selectedIndex.value = index;
                      },
                      items: List.generate(controller.navigationItems.length, (index) => navigationBarItem(controller.navigationItems[index], index, controller, isDark)),
                    ),
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(NavigationItem item, int index, DashBoardController controller, bool isDark) {
    final isSelected = controller.selectedIndex.value == index;
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SvgPicture.asset(item.iconPath, height: 22, width: 22, color: isSelected ? AppThemeData.primary300 : (isDark ? AppThemeData.grey300 : AppThemeData.grey600)),
      ),
      label: item.label.tr,
    );
  }
}
