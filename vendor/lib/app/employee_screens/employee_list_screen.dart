import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/employee_screens/add_employee_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/employee_list_controller.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: EmployeeListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              "Manage Employees".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            actions: [
              InkWell(
                splashColor: Colors.transparent,
                onTap: () async {
                  if (Constant.userModel?.vendorID?.isEmpty == true || Constant.userModel?.vendorID == null) {
                    ShowToastDialog.showToast("Please add your restaurant details before creating a employee user.".tr);
                  } else {
                    ShowToastDialog.showLoader("Please wait".tr);
                    List<EmployeeRoleModel> employeeRolelList = await FireStoreUtils.getAllEmployeeRoles(isActive: true);
                    ShowToastDialog.closeLoader();
                    if (employeeRolelList.isEmpty == true) {
                      ShowToastDialog.showToast("Please add at least one active employee role before creating an employee user.".tr);
                    } else {
                      Get.to(const AddEmployeeScreen())?.then((value) {
                        if (value == true) {
                          Get.back();
                        }
                      });
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: AppThemeData.grey50),
                      const SizedBox(width: 5),
                      Text(
                        "Add".tr,
                        style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : (Constant.userModel?.vendorID?.isEmpty == true || Constant.userModel?.vendorID == null)
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
                        "Add Your First Restaurant".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Get started by adding your restaurant details to manage your employee men.".tr,
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
              : controller.employeeUserList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset("assets/icons/ic_employee.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey400 : AppThemeData.grey500, BlendMode.srcIn)),
                      const SizedBox(height: 12),
                      Text(
                        "No Employees Available".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "No Employees found! Add your first employee to start managing your team.".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "Add Employees".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          Get.to(const AddEmployeeScreen())?.then((value) {
                            if (value == true) {
                              Get.back();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: ListView.builder(
                    itemCount: controller.employeeUserList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      return InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          Get.to(const AddEmployeeScreen(), arguments: {"employeemodel": controller.employeeUserList[index]})?.then((value) {
                            if (value == true) {
                              controller.getAllEmployeeList();
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  controller.employeeUserList[index].profilePictureURL == null || controller.employeeUserList[index].profilePictureURL == ''
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(60),
                                          child: Image.asset(Constant.userPlaceHolder, height: Responsive.width(20, context), width: Responsive.width(20, context), fit: BoxFit.cover),
                                        )
                                      : ClipRRect(
                                          borderRadius: const BorderRadius.all(Radius.circular(60)),
                                          child: NetworkImageWidget(
                                            imageUrl: controller.employeeUserList[index].profilePictureURL.toString(),
                                            fit: BoxFit.cover,
                                            height: Responsive.width(20, context),
                                            width: Responsive.width(20, context),
                                          ),
                                        ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: Responsive.width(18, context),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "${controller.employeeUserList[index].firstName ?? ''} ${controller.employeeUserList[index].lastName ?? ''}",
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                    fontFamily: AppThemeData.semiBold,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              FutureBuilder<EmployeeRoleModel?>(
                                                future: FireStoreUtils.getEmployeeRoleById(controller.employeeUserList[index].employeePermissionId!),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
                                                    return const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
                                                  }
                                                  if (!snapshot.hasData) {
                                                    return Container(
                                                      margin: EdgeInsets.symmetric(horizontal: 4),
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                        borderRadius: BorderRadius.circular(4.0),
                                                        boxShadow: [BoxShadow(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, blurRadius: 1, spreadRadius: 0.5)],
                                                      ),
                                                      child: Text(
                                                        "Role not assigned.", // use actual field from EmployeeRoleModel
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  final role = snapshot.data;
                                                  return InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return showListOfRoleDialog(isDark, role!);
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      margin: EdgeInsets.symmetric(horizontal: 4),
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                        borderRadius: BorderRadius.circular(4.0),
                                                        boxShadow: [BoxShadow(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, blurRadius: 1, spreadRadius: 0.5)],
                                                      ),
                                                      child: Text(
                                                        role?.title ?? "Unknown Role", // use actual field from EmployeeRoleModel
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${controller.employeeUserList[index].countryCode} ${controller.employeeUserList[index].phoneNumber}",
                                                    maxLines: 1,
                                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular),
                                                  ),
                                                  Text(
                                                    controller.employeeUserList[index].email.toString(),
                                                    maxLines: 1,
                                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular),
                                                  ),
                                                ],
                                              ),
                                              GetBuilder<EmployeeListController>(
                                                builder: (controller) {
                                                  return Transform.scale(
                                                    scale: 0.8,
                                                    child: CupertinoSwitch(
                                                      activeTrackColor: AppThemeData.primary300,
                                                      value: controller.employeeUserList[index].active ?? false,
                                                      onChanged: (value) {
                                                        controller.employeeUserList[index].active = value;
                                                        controller.updateEmployee(controller.employeeUserList[index]);
                                                        controller.update();
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  Dialog showListOfRoleDialog(isDark, EmployeeRoleModel model) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.surface,
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "Permissions".tr,
                  textAlign: TextAlign.start,
                  style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16),
                ),
              ),
              SizedBox(height: 5),
              PreferredSize(
                preferredSize: const Size.fromHeight(4.0),
                child: Container(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, height: 3.0),
              ),
              SizedBox(height: 20),
              Text(
                model.permissions!.where((e) => e.title != null && e.title!.isNotEmpty && e.isActive == true).map((e) => e.title!).join(', '),
                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RoundedButtonFill(
                    width: 30,
                    title: "Close".tr,
                    color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                    textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                    onPress: () async {
                      Get.back();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
