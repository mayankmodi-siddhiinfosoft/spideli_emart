import 'package:get/get.dart';
import 'package:vendor/app/splash_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/store_service.dart';

class MyStoresController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<VendorModel> stores = <VendorModel>[].obs;

  String? get currentStoreId => Constant.userModel?.vendorID;

  @override
  void onInit() {
    getStores();
    super.onInit();
  }

  Future<void> getStores() async {
    isLoading.value = true;
    try {
      stores.value = await StoreService.getOwnerStores(FireStoreUtils.getCurrentUid());
    } catch (e) {
      ShowToastDialog.showToast("Could not load your stores".tr);
    }
    isLoading.value = false;
  }

  /// Switches to [store] and restarts from the splash screen, so every screen
  /// and cached value (store, currency, taxes, permissions) reloads for it.
  Future<void> switchTo(VendorModel store) async {
    if (store.id == null || store.id == currentStoreId) return;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      await StoreService.selectStore(store.id!);
      ShowToastDialog.closeLoader();
      Get.offAll(() => const SplashScreen());
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not switch store. Please try again.".tr);
    }
  }
}
