import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/employee_role_screens/add_edit_role_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/role_controller.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RoleController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              "Employee Role".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: controller.isLoading.value
                ? Constant.loader()
                : Constant.userModel?.vendorID == null || Constant.userModel?.vendorID?.isEmpty == true
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                              ),
                              child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_building_two.svg")),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Add Your First Store".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Get started by adding your store details to manage your menu, orders.".tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                            ),
                            const SizedBox(height: 20),
                            RoundedButtonFill(
                              title: "Add Store".tr,
                              width: 55,
                              height: 5.5,
                              color: AppThemeData.primary300,
                              textColor: AppThemeData.grey50,
                              onPress: () async {
                                Get.to(const AddRestaurantScreen())?.then((value) {
                                  controller.update();
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    : controller.employeeRolelList.isEmpty
                        ? Constant.showEmptyView(message: "No employee role found".tr, isDark: isDark)
                        : ListView.builder(
                            itemCount: controller.employeeRolelList.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              EmployeeRoleModel model = controller.employeeRolelList[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  onTap: () {
                                    Get.to(const AddEditRoleScreen(), arguments: {"employeeRoleModel": model})!.then((value) {
                                      if (value == true) {
                                        controller.getAllEmployeeRoles();
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08), // subtle shadow
                                          blurRadius: 12, // soft edges
                                          offset: const Offset(0, 4), // shadow position
                                          spreadRadius: 1, // light spread
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          model.title ?? '',
                                          style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                        ),
                                        Row(
                                          children: [
                                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg", width: 22, height: 22)),
                                            IconButton(
                                              onPressed: () {
                                                FireStoreUtils.deleteEmployeeRole(model.id!);
                                                controller.employeeRolelList.remove(model);
                                              },
                                              icon: SvgPicture.asset("assets/icons/ic_delete.svg", width: 22, height: 22),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          floatingActionButton: FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: AppThemeData.primary300,
            onPressed: () {
              if (Constant.userModel?.vendorID == null || Constant.userModel?.vendorID == '') {
                ShowToastDialog.showToast("Please add your restaurant details before creating a employee role.".tr);
              } else {
                Get.to(const AddEditRoleScreen())!.then((value) {
                  if (value == true) {
                    controller.getAllEmployeeRoles();
                  }
                });
              }
            },
            child: const Icon(Icons.add, color: AppThemeData.grey50),
          ),
        );
      },
    );
  }
}
