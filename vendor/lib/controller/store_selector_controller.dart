import 'dart:developer';

import 'package:get/get.dart';
import 'package:vendor/app/splash_screen.dart';
import 'package:vendor/app/store_screens/store_selector_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/store_service.dart';

/// Store selector shown right after an owner logs in (spec 2.2:
/// Login > Store selector (my stores) > Dashboard).
class StoreSelectorController extends GetxController {
  RxList<VendorModel> stores = <VendorModel>[].obs;

  /// The store selected last time (`users.vendorID`), marked in the list.
  RxnString lastStoreId = RxnString();

  @override
  void onInit() {
    final dynamic args = Get.arguments;
    if (args is Map) {
      stores.value = List<VendorModel>.from(args['stores'] ?? const <VendorModel>[]);
      lastStoreId.value = args['lastStoreId']?.toString();
    }
    super.onInit();
  }

  /// Called by every owner login path once the user is signed in. When the
  /// owner has two or more stores it opens the selector and returns true (the
  /// caller then stops its own routing); otherwise returns false and login
  /// continues exactly as before. Employees never see it.
  static Future<bool> openIfNeeded(UserModel user) async {
    if (user.role == Constant.userRoleEmployee || (user.id ?? '').isEmpty) return false;
    try {
      final List<VendorModel> stores = await StoreService.getOwnerStores(user.id!);
      if (stores.length < 2) return false;
      Constant.userModel = user;
      Get.offAll(() => const StoreSelectorScreen(), arguments: {'stores': stores, 'lastStoreId': user.vendorID});
      return true;
    } catch (e) {
      log("Store selector skipped: $e");
      return false;
    }
  }

  /// Makes [store] the working store, then continues through the splash
  /// screen, which runs the usual plan / access checks for it.
  Future<void> choose(VendorModel store) async {
    if (store.id == null) return;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      if (store.id != lastStoreId.value) await StoreService.selectStore(store.id!);
      ShowToastDialog.closeLoader();
      Get.offAll(() => const SplashScreen());
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not select store. Please try again.".tr);
    }
  }
}
