import 'package:flutter/material.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';

/// Raw color ramps the design system is built from.
///
/// Screens should NOT use these directly – use the semantic roles from
/// `context.dsColors` (they follow light / dark mode). This class exists
/// because the provider app's [AppThemeData] has no dark ramps and its
/// runtime brand color lives in [AppColors.colorPrimary].
abstract final class DsPalette {
  // ------------------------------------------------------------------ brand
  /// Provider brand color. Loaded at runtime from Firestore
  /// (`settings/globalSettings.provider_app_color`) into
  /// [AppColors.colorPrimary] – always read it at call time.
  static Color get brand => AppColors.colorPrimary;

  /// Font family used by the DS type scale (weights 400–800 are declared
  /// under this family in pubspec.yaml).
  static const String fontFamily = 'Metropolis';

  // -------------------------------------------------------------- surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = AppThemeData.surfaceDark;

  // ---------------------------------------------------------------- neutrals
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = AppThemeData.grey100;
  static const Color grey200 = AppThemeData.grey200;
  static const Color grey300 = AppThemeData.grey300;
  static const Color grey400 = AppThemeData.grey400;
  static const Color grey500 = AppThemeData.grey500;
  static const Color grey600 = AppThemeData.grey600;
  static const Color grey700 = AppThemeData.grey700;
  static const Color grey800 = AppThemeData.grey800;
  static const Color grey900 = AppThemeData.grey900;

  static const Color greyDark500 = Color(0xFF9CA3AF);
  static const Color greyDark600 = Color(0xFFD1D5DB);
  static const Color greyDark900 = Color(0xFFF9FAFB);

  // ---------------------------------------------------------------- semantic
  static const Color success50 = AppThemeData.success50;
  static const Color success400 = AppThemeData.success400;
  static const Color success500 = AppThemeData.success500;
  static const Color successDark200 = Color(0xFF26C281);
  static const Color successDark400 = Color(0xFF6EE7B7);

  static const Color warning50 = AppThemeData.warning50;
  static const Color warning300 = AppThemeData.warning300;
  static const Color warning500 = AppThemeData.warning500;
  static const Color warningDark300 = Color(0xFFFFCB39);
  static const Color warningDark400 = Color(0xFFFFDA72);

  static const Color danger50 = AppThemeData.danger50;
  static const Color danger300 = AppThemeData.danger300;
  static const Color danger400 = AppThemeData.danger400;
  static const Color dangerDark300 = Color(0xFFFF3840);
  static const Color dangerDark400 = Color(0xFFFF7277);

  static const Color info50 = AppThemeData.info50;
  static const Color info300 = AppThemeData.info300;
  static const Color info400 = AppThemeData.info400;
  static const Color info500 = AppThemeData.info500;
  static const Color infoDark300 = Color(0xFF38D0FF);
  static const Color infoDark400 = Color(0xFF72DEFF);
}
