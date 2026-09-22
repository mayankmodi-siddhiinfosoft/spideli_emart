import 'package:flutter/material.dart';
import 'package:customer/themes/app_them_data.dart';

import 'ds_colors.dart';

/// Raw type scale (no colors). All styles set `fontWeight` explicitly because
/// the EssentialSans family is selected by weight, and set `height` so lines
/// never clip at large accessibility text scales.
///
/// Prefer the colored variants from `context.dsText` in widgets.
abstract final class DsTypography {
  static const String family = AppThemeData.fontFamily;

  static const TextStyle displayLg = TextStyle(fontFamily: family, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w700, letterSpacing: -0.6);
  static const TextStyle display = TextStyle(fontFamily: family, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static const TextStyle headline = TextStyle(fontFamily: family, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  static const TextStyle title = TextStyle(fontFamily: family, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static const TextStyle titleSm = TextStyle(fontFamily: family, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);
  static const TextStyle bodyLg = TextStyle(fontFamily: family, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const TextStyle body = TextStyle(fontFamily: family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const TextStyle bodyStrong = TextStyle(fontFamily: family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const TextStyle bodySm = TextStyle(fontFamily: family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const TextStyle label = TextStyle(fontFamily: family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static const TextStyle labelSm = TextStyle(fontFamily: family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const TextStyle caption = TextStyle(fontFamily: family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);
  static const TextStyle overline = TextStyle(fontFamily: family, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.9);

  /// Large numbers (KPIs, balances). Tabular figures keep digits aligned
  /// while DsAnimatedCounter animates.
  static const TextStyle metric = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle metricLg = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 42 / 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Type scale colored for the current brightness.
///
/// ```dart
/// final t = context.dsText;
/// Text('Orders', style: t.headline);
/// Text('Last 7 days', style: t.caption);           // muted by default
/// Text('₹ 1,240', style: t.metric.withColor(c.success));
/// ```
@immutable
class DsTextTheme {
  final DsColors colors;
  const DsTextTheme(this.colors);

  static DsTextTheme of(BuildContext context) => DsTextTheme(DsColors.of(context));

  TextStyle get displayLg => DsTypography.displayLg.copyWith(color: colors.textPrimary);
  TextStyle get display => DsTypography.display.copyWith(color: colors.textPrimary);
  TextStyle get headline => DsTypography.headline.copyWith(color: colors.textPrimary);
  TextStyle get title => DsTypography.title.copyWith(color: colors.textPrimary);
  TextStyle get titleSm => DsTypography.titleSm.copyWith(color: colors.textPrimary);
  TextStyle get bodyLg => DsTypography.bodyLg.copyWith(color: colors.textPrimary);
  TextStyle get body => DsTypography.body.copyWith(color: colors.textPrimary);
  TextStyle get bodyStrong => DsTypography.bodyStrong.copyWith(color: colors.textPrimary);

  /// Secondary paragraph text.
  TextStyle get bodySecondary => DsTypography.body.copyWith(color: colors.textSecondary);
  TextStyle get bodySm => DsTypography.bodySm.copyWith(color: colors.textSecondary);
  TextStyle get label => DsTypography.label.copyWith(color: colors.textPrimary);
  TextStyle get labelSm => DsTypography.labelSm.copyWith(color: colors.textSecondary);
  TextStyle get caption => DsTypography.caption.copyWith(color: colors.textMuted);
  TextStyle get overline => DsTypography.overline.copyWith(color: colors.textMuted);
  TextStyle get metric => DsTypography.metric.copyWith(color: colors.textPrimary);
  TextStyle get metricLg => DsTypography.metricLg.copyWith(color: colors.textPrimary);

  /// Brand-colored link / inline action text.
  TextStyle get link => DsTypography.label.copyWith(color: colors.brandStrong);
}

/// Small fluent helpers for tweaking a DS text style.
extension DsTextStyleX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle get w400 => copyWith(fontWeight: FontWeight.w400);
  TextStyle get w500 => copyWith(fontWeight: FontWeight.w500);
  TextStyle get w600 => copyWith(fontWeight: FontWeight.w600);
  TextStyle get w700 => copyWith(fontWeight: FontWeight.w700);

  /// Monospaced digits (prices, counters, timers).
  TextStyle get tabular => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  TextStyle get strike => copyWith(decoration: TextDecoration.lineThrough, decorationColor: color);
}
