import 'dart:developer';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';

class ProfileController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<UserModel> userModel = UserModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    print("ProfileController onInit");
    print(Constant.selectedSection!.toJson());
    getUserProfile();
    getTheme();
    super.onInit();
  }

  Future<void> getUserProfile({Map<String, dynamic>? location}) async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        Constant.userModel = userModel.value;
      }
    });

    if (location != null) {
      await getProductTax(latitude: location['lat'], longitude: location['lng'], sectionId: Constant.selectedSection!.id.toString());
    }
    isLoading.value = false;
  }

  Future<void> getProductTax({required double latitude, required double longitude, required String sectionId}) async {
    await FireStoreUtils.getTaxList(latitude, longitude, sectionId).then((value) {
      if (value != null) {
        Constant.taxProductList = value.where((TaxModel taxModel) => taxModel.scope == "product" && taxModel.enable == true).toList();
        log("getProductTax :: ${Constant.taxProductList?.length}");
      }
    });
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
    isLoading.value = false;
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

  Future<bool> deleteUserFromServer() async {
    var url = '${Constant.storeUrl}/api/delete-user';
    try {
      var response = await http.post(Uri.parse(url), body: {'uuid': FireStoreUtils.getCurrentUid()});
      log("deleteUserFromServer :: ${response.body}");
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
