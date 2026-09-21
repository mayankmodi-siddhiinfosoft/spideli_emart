import 'package:spideliprovider/services/preferences.dart';
import 'package:get/get.dart';

class ThemChangeController extends GetxController {
  RxString lightDarkMode = "Light".obs;

  void handleGenderChange(String? value) {
    lightDarkMode.value = value!;
  }

  RxBool isLoading = true.obs;


  @override
  void onInit() {
    getLightDarkMode();
    super.onInit();
  }

  getLightDarkMode() async {
    if (Preferences.getString(Preferences.themeKey).toString().isNotEmpty) {
      lightDarkMode.value = Preferences.getString(Preferences.themeKey).toString();
    }
    isLoading.value = false;
    update();
  }

}
