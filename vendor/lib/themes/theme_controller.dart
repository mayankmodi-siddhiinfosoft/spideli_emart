import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/preferences.dart';

class ThemeController extends GetxController {
  RxBool isDark = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTheme();
  }

  void loadTheme() {
    isDark.value = Preferences.getBoolean(Preferences.themKey);
  }

  void toggleTheme() {
    isDark.value = !isDark.value;
    Preferences.setBoolean(Preferences.themKey, isDark.value);
    update();
  }

  ThemeMode get themeMode => isDark.value ? ThemeMode.dark : ThemeMode.light;
}
