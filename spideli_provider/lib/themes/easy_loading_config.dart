import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

bool? _appliedIsDark;

/// Styles the global EasyLoading HUD / toasts (used by ShowToastDialog) with
/// the design system: raised surface panel, soft shadow, brand loader and DS
/// typography. Called from `GetMaterialApp.builder` in `main.dart` with the
/// current DarkThemeProvider brightness; it only re-applies when that
/// changes, so it is cheap to call on every build.
void configEasyLoading(bool isDark) {
  if (_appliedIsDark == isDark) return;
  _appliedIsDark = isDark;
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
    ..animationDuration = DsMotion.base;
  // maskType / userInteractions / dismissOnTap are left at their defaults so
  // loader and toast interaction behaviour is unchanged.
}
