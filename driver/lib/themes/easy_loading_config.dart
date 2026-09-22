import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

bool _themeListenerAttached = false;

/// Styles the global EasyLoading HUD / toasts (used by ShowToastDialog) with
/// the design system: raised surface panel, soft shadow, brand loader,
/// DS typography. Re-applies automatically when the theme is toggled.
Future<void> configEasyLoading() async {
  final themeController = Get.find<ThemeController>();
  _applyEasyLoadingStyle(themeController.isDark.value);
  if (!_themeListenerAttached) {
    _themeListenerAttached = true;
    ever<bool>(themeController.isDark, _applyEasyLoadingStyle);
  }
}

void _applyEasyLoadingStyle(bool isDark) {
  final c = DsColors.resolve(isDark);
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorWidget = const DsBrandLoader(size: 44)
    ..indicatorSize = 44
    ..backgroundColor = c.surfaceRaised
    ..indicatorColor = c.brand
    ..progressColor = c.brand
    ..textColor = c.textPrimary
    ..textStyle = DsTypography.bodyStrong.copyWith(color: c.textPrimary)
    ..radius = DsRadius.lg
    ..contentPadding = const EdgeInsets.symmetric(vertical: DsSpace.lg, horizontal: DsSpace.xl)
    ..textPadding = const EdgeInsets.only(top: DsSpace.xs, bottom: DsSpace.xs)
    ..boxShadow = [
      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10), blurRadius: 32, offset: const Offset(0, 12)),
      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05), blurRadius: 6, offset: const Offset(0, 2)),
    ]
    ..animationStyle = EasyLoadingAnimationStyle.scale
    ..animationDuration = DsMotion.base
    ..maskColor = Colors.black.withValues(alpha: 0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}
