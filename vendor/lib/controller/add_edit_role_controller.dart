import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/permission_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class AddEditRoleController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<TextEditingController> nameController = TextEditingController().obs;
  RxList<PermissionModel> permissionList = <PermissionModel>[].obs;
  RxBool isActive = true.obs;
  Rx<EmployeeRoleModel> employeeRoleModel = EmployeeRoleModel().obs;
  RxBool isAllPermission = false.obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  RxList images = <dynamic>[].obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      employeeRoleModel.value = argumentData['employeeRoleModel'];
      isActive.value = employeeRoleModel.value.isEnable ?? false;
      permissionList.value = employeeRoleModel.value.permissions ?? [];
      nameController.value.text = employeeRoleModel.value.title ?? '';
      isAllPermission.value = permissionList.every((item) => item.isActive == true);
    } else {
      setAllPermission(selectAll: false);
    }
    isLoading.value = false;
  }

  Future<void> saveEmployeeRole() async {
    if (nameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter role name".tr);
    } else if (permissionList.every((item) => item.isActive == false)) {
      ShowToastDialog.showToast("Please assign at least one permission.".tr);
    } else {
      ShowToastDialog.showLoader("Please wait".tr);
      if (employeeRoleModel.value.id == null) {
        employeeRoleModel.value.id = Constant.getUuid();
      }
      employeeRoleModel.value.title = nameController.value.text.trim();
      employeeRoleModel.value.isEnable = isActive.value;
      employeeRoleModel.value.permissions = permissionList;
      employeeRoleModel.value.vendorId = Constant.userModel?.vendorID;

      await FireStoreUtils.setEmployeeRole(employeeRoleModel.value).then((value) {
        ShowToastDialog.closeLoader();
        Get.back(result: true);
      });
    }
  }

  void setAllPermission({bool? selectAll}) {
    if (selectAll == true) {
      permissionList.value = [
        PermissionModel(title: 'Add Story', isActive: true),
        PermissionModel(title: 'Advertisement', isActive: true),
        PermissionModel(title: "Store Information's", isActive: true),
        PermissionModel(title: 'Manage Products', isActive: true),
        PermissionModel(title: 'Working Hours', isActive: true),
        PermissionModel(title: 'Withdraw Method', isActive: true),
        PermissionModel(title: 'Manage Delivery Man', isActive: true),
        PermissionModel(title: 'Employee Role', isActive: true),
        PermissionModel(title: 'All Employee', isActive: true),
        PermissionModel(title: 'Add Dine in', isActive: true),
        PermissionModel(title: 'Dine in Request', isActive: true),
        PermissionModel(title: 'Offers', isActive: true),
        PermissionModel(title: 'Special Discounts', isActive: true),
        PermissionModel(title: 'Manage Order', isActive: true),
      ];
      isAllPermission.value = true;
    } else {
      permissionList.value = [
        PermissionModel(title: 'Add Story', isActive: false),
        PermissionModel(title: 'Advertisement', isActive: false),
        PermissionModel(title: "Store Information's", isActive: false),
        PermissionModel(title: 'Manage Products', isActive: false),
        PermissionModel(title: 'Working Hours', isActive: false),
        PermissionModel(title: 'Withdraw Method', isActive: false),
        PermissionModel(title: 'Manage Delivery Man', isActive: false),
        PermissionModel(title: 'Employee Role', isActive: false),
        PermissionModel(title: 'All Employee', isActive: false),
        PermissionModel(title: 'Add Dine in', isActive: false),
        PermissionModel(title: 'Dine in Request', isActive: false),
        PermissionModel(title: 'Offers', isActive: false),
        PermissionModel(title: 'Special Discounts', isActive: false),
        PermissionModel(title: 'Manage Order', isActive: false),
      ];
      isAllPermission.value = false;
    }
  }
}
