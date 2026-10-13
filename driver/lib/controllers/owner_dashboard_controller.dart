import 'package:driver/app/owner_screen/carrier_setup_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/carrier_setup_form.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../themes/theme_controller.dart';
import 'package:driver/utils/background_delivery.dart';

class OwnerDashboardController extends GetxController{
  @override
  void onReady() {
    super.onReady();
    // Xiaomi & co.: explain Autostart once, or a closed app gets no push.
    BackgroundDelivery.maybePrompt();
  }

  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getUser();
    getTheme();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  Future<void> getUser() async {
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
          (event) {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
          RegionService.applyDriver(Constant.userModel);
          _openCarrierSetupIfNeeded(userModel.value);
        }
      },
    );
  }

  /// Opened once per app launch: closing it leaves the owner on the
  /// dashboard (the home reminder and Carrier settings still lead to it).
  static bool _carrierSetupShown = false;

  /// A company owner registered with the Parcel service and without a carrier
  /// lands on "Set up your carrier" ([CarrierSetupForm.needsSetup]).
  void _openCarrierSetupIfNeeded(UserModel user) {
    if (_carrierSetupShown) return;
    if (!CarrierSetupForm.needsSetup(isOwner: user.isOwner == true, serviceTypes: user.serviceTypes, carrierId: user.carrierId)) return;
    _carrierSetupShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.to(() => const CarrierSetupScreen()));
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
  }

  void toggleDarkMode(bool value) {
    isDarkModeSwitch.value = value;
    isDarkMode.value = value ? "Dark" : "Light";
    Preferences.setBoolean(Preferences.themKey, value);
    // Update ThemeController for instant app theme change
    if (Get.isRegistered<ThemeController>()) {
      final themeController = Get.find<ThemeController>();
      themeController.isDark.value = value;
    }
  }

}