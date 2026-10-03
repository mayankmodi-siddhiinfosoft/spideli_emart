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
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/utils/background_delivery.dart';

class DashBoardController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    // Xiaomi & co.: explain Autostart once, or a closed app gets no push.
    BackgroundDelivery.maybePrompt();
  }

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
      const NavigationItem(label: homeTab, iconPath: "assets/icons/ic_home_cab.svg", page: HomeScreen()),
      if (sectionModel.value.dineInActive != null && sectionModel.value.dineInActive == true)
        NavigationItem(label: dineInTab, iconPath: "assets/icons/ic_dinein.svg", page: const DineInOrderScreen(), permissionModule: "Dine in Request"),
      NavigationItem(label: productsTab, iconPath: "assets/icons/ic_menu.svg", page: const ProductListScreen(), permissionModule: "Manage Products"),
      NavigationItem(label: walletTab, iconPath: "assets/icons/ic_wallet.svg", page: const WalletScreen(), permissionModule: "Wallet"),
      const NavigationItem(label: profileTab, iconPath: "assets/icons/ic_profile.svg", page: ProfileScreen()),
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
          // Live amounts use the store's region currency from here on.
          await RegionService.applyStore(value);
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
      // Never left null. Every `Constant.selectedSection!` across the app threw
      // when the section could not be read - including the first line of the
      // order card's Accept handler, which then did nothing at all when tapped
      // (the fault behind report #5). The store's own section, read a few lines
      // above, still wins; an empty section is only the last resort and reads as
      // "no special behaviour", which is what the old code fell through to.
      Constant.selectedSection ??= sectionModel.value;
    });
    setPage();

    isLoading.value = false;
  }

  /// Labels of the bottom tabs, used to open one by what it is rather than by
  /// where it happens to sit. Kept equal to the `label` given in [setPage].
  static const String homeTab = "Home";
  static const String dineInTab = "Dine in";
  static const String productsTab = "Products";
  static const String walletTab = "Wallet";
  static const String profileTab = "Profile";

  /// Position of the tab labelled [label] in the bar the signed-in user
  /// actually has, or -1 when that tab is not there for them.
  int indexOfTab(String label) => tabIndexIn(navigationItems, label);

  /// Opens the tab labelled [label]. Does nothing when the user does not have
  /// that tab, which an employee whose role leaves it out does not.
  ///
  /// Report 02#7: the photo in the home header (and the "Manage Products" /
  /// "Dine in Requests" rows in the profile) used to set a fixed position such
  /// as 3 or 4. Those positions only exist for an owner; an employee's bar is
  /// filtered by role and is shorter, so the dashboard then read past the end
  /// of its own tab list while building and the whole screen came up blank.
  void openTab(String label) {
    final int index = indexOfTab(label);
    if (index >= 0) selectedIndex.value = index;
  }

  /// [indexOfTab] over any list, so it can be tested without Firebase.
  static int tabIndexIn(List<NavigationItem> items, String label) => items.indexWhere((item) => item.label == label);

  /// The tab position that is safe to show for [selected] among [count] tabs:
  /// [selected] itself when it exists, otherwise the first tab.
  static int safeTabIndex(int selected, int count) => (selected >= 0 && selected < count) ? selected : 0;

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
