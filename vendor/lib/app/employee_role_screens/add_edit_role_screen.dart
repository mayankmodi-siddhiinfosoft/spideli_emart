import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/add_edit_role_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';

import '../../constant/constant.dart' show Constant;

class AddEditRoleScreen extends StatelessWidget {
  const AddEditRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddEditRoleController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              Get.arguments == null ? "Create Role".tr : "Edit Role".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Active".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 16),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: CupertinoSwitch(
                                activeTrackColor: AppThemeData.primary300,
                                value: controller.isActive.value,
                                onChanged: (value) {
                                  controller.isActive.value = value;
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        TextFieldWidget(title: 'Role Name'.tr, controller: controller.nameController.value, hintText: 'Role Name'.tr),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Permissions".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 16),
                            ),
                            Row(
                              children: [
                                Text(
                                  'All'.tr,
                                  style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Checkbox(
                                    value: controller.isAllPermission.value,
                                    activeColor: AppThemeData.primary300, // Color when checked
                                    checkColor: Colors.white, // Tick color
                                    onChanged: (bool? value) {
                                      controller.isAllPermission.value = value!;
                                      controller.setAllPermission(selectAll: value);
                                      controller.permissionList.refresh();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ListView.builder(
                          padding: EdgeInsets.all(0),
                          primary: false,
                          itemCount: controller.permissionList.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            bool selectAll = false;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08), // subtle shadow
                                      blurRadius: 12, // soft edges
                                      offset: const Offset(0, 4), // shadow position
                                      spreadRadius: 1, // light spread
                                    ),
                                  ],
                                ),
                                child: Obx(
                                  () => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              controller.permissionList[index].title?.tr ?? '',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: controller.permissionList[index].isActive,
                                                  activeColor: AppThemeData.primary300, // Color when checked
                                                  checkColor: Colors.white, // Tick color
                                                  onChanged: (bool? value) {
                                                    selectAll = value ?? false;
                                                    controller.permissionList[index].isActive = selectAll;
                                                    controller.permissionList.refresh();
                                                    controller.isAllPermission.value = controller.permissionList.every((item) => item.isActive == true);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Save Role".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  controller.saveEmployeeRole();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
