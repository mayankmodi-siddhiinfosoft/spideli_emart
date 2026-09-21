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
    try{
      isDark.value = Preferences.getBoolean(Preferences.themKey);
    }catch(e){
      Preferences.setBoolean(Preferences.themKey, false);
    }
  }

  void toggleTheme() {
    isDark.value = !isDark.value;
    Preferences.setBoolean(Preferences.themKey, isDark.value);
  }

  ThemeMode get themeMode => isDark.value ? ThemeMode.dark : ThemeMode.light;
}
