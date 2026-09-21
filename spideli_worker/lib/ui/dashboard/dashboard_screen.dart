import 'package:spideliworker/controller/dashboard_controller.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<DashBoardController>(
        init: DashBoardController(),
        builder: (controller) {
          return Scaffold(
            body: PageView.builder(
              controller: controller.pageController,
              onPageChanged: (value) {
                controller.selectedIndex.value = value;
              },
              itemCount: controller.pageList.length,
              itemBuilder: (context, index) {
                return controller.pageList[controller.selectedIndex.value];
              },
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              showSelectedLabels: true,
              currentIndex: controller.selectedIndex.value,
              backgroundColor: themeChange.getTheme() ? AppColors.assetColorGrey1000 : AppColors.colorWhite,
              selectedItemColor: AppColors.colorPrimary,
              unselectedItemColor: AppColors.assetColorLightGrey1000,
              onTap: controller.onItemTapped,
              items: [
                navigationBarItem(
                  index: 0,
                  assetIcon: "assets/icons/ic_order.svg",
                  label: 'Booking'.tr,
                  controller: controller,
                ),
                navigationBarItem(
                  index: 1,
                  assetIcon: "assets/icons/ic_profile.svg",
                  label: 'Profile'.tr,
                  controller: controller,
                ),
              ],
            ),
          );
        });
  }

  BottomNavigationBarItem navigationBarItem({required int index, required String label, required String assetIcon, required DashBoardController controller}) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SvgPicture.asset(
          assetIcon,
          height: 22,
          width: 22,
          colorFilter: ColorFilter.mode(
            controller.selectedIndex.value == index ? AppColors.colorPrimary : AppColors.assetColorLightGrey1000,
            BlendMode.srcIn,
          ),
        ),
      ),
      label: label,
    );
  }
}
