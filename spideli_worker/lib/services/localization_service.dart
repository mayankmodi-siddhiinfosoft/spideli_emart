import 'package:spideliworker/lang/app_en.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocalizationService extends Translations {
  // Default locale
  static const locale = Locale('en', 'US');

  static final locales = [
    const Locale('en'),
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'en': enUS,
      };

  void changeLocale(String lang) {
    Get.updateLocale(Locale(lang));
  }
}
