import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/Home_screen/home_screen.dart';
import 'package:vendor/app/dine_in_order_screen/dine_in_order_screen.dart';
import 'package:vendor/app/product_screens/product_list_screen.dart';
import 'package:vendor/app/profile_screen/profile_screen.dart';
import 'package:vendor/app/wallet_screen/wallet_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class DashBoardController extends GetxController {
  RxBool isLoading = true.obs;
  RxInt selectedIndex = 0.obs;
  RxList<NavigationItem> navigationItems = <NavigationItem>[].obs;

  RxList pageList = [].obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<SectionModel> sectionModel = SectionModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getVendor();

    super.onInit();
  }

  void setPage() {
    final baseItems = <NavigationItem>[
      const NavigationItem(label: "Home", iconPath: "assets/icons/ic_home_cab.svg", page: HomeScreen()),
      if (sectionModel.value.dineInActive != null && sectionModel.value.dineInActive == true)
        NavigationItem(label: "Dine in", iconPath: "assets/icons/ic_dinein.svg", page: const DineInOrderScreen(), permissionModule: "Dine in Request"),
      NavigationItem(label: "Products", iconPath: "assets/icons/ic_menu.svg", page: const ProductListScreen(), permissionModule: "Manage Products"),
      NavigationItem(label: "Wallet", iconPath: "assets/icons/ic_wallet.svg", page: const WalletScreen(), permissionModule: "Wallet"),
      const NavigationItem(label: "Profile", iconPath: "assets/icons/ic_profile.svg", page: ProfileScreen()),
    ];
    // filter by permission
    navigationItems.value = baseItems.where((item) {
      log("SetPage :: ${item.label} :: ${item.permissionModule}");
      if (item.permissionModule == null) return true;
      return Constant.getEmployeeRolePermission(module: item.permissionModule!) == true;
    }).toList();
  }

  Future<void> getVendor() async {
    if (Constant.userModel?.vendorID != null) {
      await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) async {
        if (value != null) {
          vendorModel.value = value;
          Constant.vendorAdminCommission = value.adminCommission;
          await FireStoreUtils.getSectionById(vendorModel.value.sectionId.toString()).then((value) {
            if (value != null) {
              sectionModel.value = value;
              Constant.selectedSection = sectionModel.value;
            }
          });
        }
      });
      if (vendorModel.value.latitude != null && vendorModel.value.longitude != null) {
        await FireStoreUtils.getTaxList(double.parse("${vendorModel.value.latitude}"), double.parse("${vendorModel.value.longitude}"), vendorModel.value.sectionId.toString()).then((value) {
          Constant.taxProductList = value!.where((TaxModel taxModel) => taxModel.scope == "product").toList();
        });
      }
    }

    await FireStoreUtils.getSectionById(Constant.userModel!.sectionId.toString()).then((value) {
      if (value != null) {
        sectionModel.value = value;
        Constant.selectedSection = sectionModel.value;
      } else {
        sectionModel.value = SectionModel();
      }
    });
    setPage();

    isLoading.value = false;
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}

class NavigationItem {
  final String label;
  final String iconPath;
  final Widget page;
  final String? permissionModule;

  const NavigationItem({required this.label, required this.iconPath, required this.page, this.permissionModule});
}
