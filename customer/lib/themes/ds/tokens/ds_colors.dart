import 'package:flutter/material.dart';
import 'package:customer/themes/app_them_data.dart';

import '../foundation/ds_accent_scope.dart';
import 'ds_section.dart';

/// Semantic "tone" used by badges, chips, stat tiles, empty states, dialogs...
///
/// Pick the tone for *meaning*, never for looks:
/// * [brand]   – primary / neutral-positive highlight (new, placed, selected)
/// * [success] – completed, accepted, paid, online
/// * [warning] – pending, paused, needs attention
/// * [danger]  – rejected, cancelled, failed, destructive
/// * [info]    – in progress, shipped, informational
/// * [neutral] – inactive, draft, metadata
enum DsTone {
  neutral,
  brand,
  success,
  warning,
  danger,
  info;

  /// Best-effort mapping from any status string used in the customer app
  /// (food / e-commerce orders, cab & intercity rides, parcel, rental and
  /// on-demand bookings, dine-in, wallet / payment results, gift cards) to a
  /// tone. Matching is keyword based and case-insensitive, so it works for
  /// `Constant.orderCompleted`, `Constant.driverPending`, `'countered'`,
  /// `'SUCCESS'`, `"booking_placed"`, etc.
  static DsTone fromStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.isEmpty) return DsTone.neutral;
    bool has(List<String> keys) => keys.any(s.contains);
    if (has(['inactive', 'draft', 'disabled'])) return DsTone.neutral;
    if (has(['reject', 'cancel', 'fail', 'expire', 'declin', 'block', 'suspend', 'denied', 'unpaid', 'error'])) {
      return DsTone.danger;
    }
    if (has(['complete', 'accept', 'approv', 'running', 'success', 'paid', 'settled', 'deliver', 'active', 'verified', 'online', 'confirm', 'finish', 'redeem'])) {
      return DsTone.success;
    }
    if (has(['pending', 'pause', 'updated', 'schedul', 'waiting', 'review', 'hold', 'counter', 'request'])) {
      return DsTone.warning;
    }
    if (has(['ship', 'transit', 'driver', 'progress', 'prepar', 'pickup', 'picked', 'ongoing', 'assign', 'arriv', 'start', 'on the way', 'on_the_way'])) {
      return DsTone.info;
    }
    if (has(['placed', 'new'])) return DsTone.brand;
    return DsTone.neutral;
  }
}

/// The four colors every tone resolves to.
@immutable
class DsToneColors {
  /// Solid fill / icon / border color.
  final Color main;

  /// Readable foreground on [soft] and on the page surface (AA contrast).
  final Color strong;

  /// Soft tinted background (chips, tinted cards, icon containers).
  final Color soft;

  /// Foreground to use on top of [main] (solid buttons / solid badges).
  final Color onMain;

  const DsToneColors({required this.main, required this.strong, required this.soft, required this.onMain});
}

/// Semantic color roles resolved for the current brightness.
///
/// Always obtain through `DsColors.of(context)` or `context.dsColors` so the
/// palette follows light / dark mode and any [DsAccentScope] above you.
///
/// **Brand = active service section.** [brand] is read at call time from
/// `AppThemeData.primary300`, which the app sets from Firestore
/// (`globalSettings.app_customer_color` at start-up, then the tapped
/// section's `color` in `ServiceListController.onServiceTap`). So inside a
/// service (food, e-commerce, cab, parcel, rental, on-demand) `c.brand` is that
/// service's color, exactly like the legacy `AppThemeData.primary300` usages.
/// Use [sectionAccent] for an explicit section palette (e.g. service tiles).
///
/// ```dart
/// final c = context.dsColors;
/// Container(color: c.surface, child: Text('Hi', style: TextStyle(color: c.textPrimary)));
/// final cab = c.sectionAccent(DsSection.cab);   // main / strong / soft / onMain
/// ```
@immutable
class DsColors {
  final bool isDark;

  /// Brand override set by a [DsAccentScope] (or [DsColors.resolve]).
  final Color? _brandOverride;

  const DsColors._(this.isDark, [this._brandOverride]);

  static const DsColors light = DsColors._(false);
  static const DsColors dark = DsColors._(true);

  /// Resolve from an explicit flag (e.g. `themeController.isDark.value`).
  /// Pass [brand] to build a palette around a specific accent.
  factory DsColors.resolve(bool isDark, {Color? brand}) => brand == null ? (isDark ? dark : light) : DsColors._(isDark, brand);

  /// Resolve from the ambient [Theme] brightness (kept in sync with
  /// ThemeController by GetMaterialApp.themeMode) and the nearest
  /// [DsAccentScope].
  static DsColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scope = context.dependOnInheritedWidgetOfExactType<DsAccentInherited>();
    return DsColors.resolve(isDark, brand: scope?.resolve(isDark));
  }

  // ---------------------------------------------------------------- brand
  /// Brand color: the active service section's color (runtime value of
  /// `AppThemeData.primary300`), or the [DsAccentScope] override.
  Color get brand => _brandOverride ?? AppThemeData.primary300;

  /// Darker (light mode) / lighter (dark mode) brand used for pressed states
  /// and for brand-colored text on surfaces. Guaranteed >= 4.5:1 on [surface].
  Color get brandStrong => readableOn(isDark ? Color.lerp(brand, Colors.white, 0.22)! : Color.lerp(brand, Colors.black, 0.28)!, surface);

  /// Very soft brand tint (opaque) for selected rows, tonal buttons, chips.
  Color get brandSoft => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.18 : 0.10), surface);

  /// Slightly stronger tint, for borders of tinted elements.
  Color get brandMuted => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.34 : 0.24), surface);

  /// Text / icon color placed on a solid [brand] fill. Light accents (amber
  /// cab, green parcel / rental, cyan on-demand) get dark text; red, blue and
  /// orange keep white.
  Color get onBrand => onColor(brand);

  // --------------------------------------------------------------- sections
  /// The active service section (`Constant.sectionConstantModel`).
  DsSection get section => DsSection.current;

  /// Accent colors of a service section from its design palette. Defaults
  /// to the active section. For [DsSection.none] this is the brand.
  ///
  /// `main` fill / icon, `strong` readable text, `soft` tinted background,
  /// `onMain` foreground on `main`.
  DsToneColors sectionAccent([DsSection? section]) {
    final s = section ?? DsSection.current;
    if (s == DsSection.none) return tone(DsTone.brand);
    final main = s.base(isDark);
    return DsToneColors(
      main: main,
      strong: readableOn(s.strong(isDark), surface),
      soft: isDark ? Color.alphaBlend(main.withValues(alpha: 0.18), surface) : s.lightSoft,
      onMain: onColor(main),
    );
  }

  /// Accent colors derived from any color, e.g. a section tile's Firestore
  /// `SectionModel.color`: `c.accentFrom(Color(int.parse(hex)))`.
  DsToneColors accentFrom(Color color) {
    return DsToneColors(
      main: color,
      strong: readableOn(isDark ? Color.lerp(color, Colors.white, 0.22)! : Color.lerp(color, Colors.black, 0.28)!, surface),
      soft: Color.alphaBlend(color.withValues(alpha: isDark ? 0.18 : 0.10), surface),
      onMain: onColor(color),
    );
  }

  /// Parse a Firestore hex color (`'#FF6839'`, `'FF6839'`, `'#80FF6839'`),
  /// e.g. `SectionModel.color`. Returns null when empty or invalid.
  static Color? fromHex(String? hex) {
    var h = (hex ?? '').trim().replaceFirst('#', '').replaceFirst(RegExp('^0x', caseSensitive: false), '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  /// Dark ink or white, whichever reads better on [fill].
  static Color onColor(Color fill) => fill.computeLuminance() > 0.40 ? AppThemeData.grey900 : Colors.white;

  /// WCAG contrast ratio between two opaque colors.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Darkens (light bg) or lightens (dark bg) [color] until it reaches
  /// [minRatio] contrast on [background].
  static Color readableOn(Color color, Color background, {double minRatio = 4.5}) {
    final towards = background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    var c = color;
    for (var i = 0; i < 12 && contrast(c, background) < minRatio; i++) {
      c = Color.lerp(c, towards, 0.08)!;
    }
    return c;
  }

  // -------------------------------------------------------------- surfaces
  /// Page background (scaffold). Slightly tinted so white cards float.
  Color get background => isDark ? AppThemeData.surfaceDark : const Color(0xFFF6F7F9);

  /// Cards, sheets, app bars.
  Color get surface => isDark ? const Color(0xFF0E131D) : AppThemeData.surface;

  /// Subtle fill: inputs, segmented control track, skeleton base, icon wells.
  Color get surfaceAlt => isDark ? const Color(0xFF171E2B) : AppThemeData.grey100;

  /// Elevated surface for dialogs / bottom sheets / menus.
  Color get surfaceRaised => isDark ? const Color(0xFF141B27) : AppThemeData.surface;

  /// Inverse surface (snackbars, tooltips).
  Color get surfaceInverse => isDark ? AppThemeData.grey100 : AppThemeData.grey800;

  /// Text on [surfaceInverse].
  Color get onSurfaceInverse => isDark ? AppThemeData.grey900 : AppThemeData.grey50;

  // --------------------------------------------------------------- borders
  Color get border => isDark ? const Color(0xFF232C3B) : AppThemeData.grey200;
  Color get borderStrong => isDark ? AppThemeData.grey700 : AppThemeData.grey300;
  Color get divider => isDark ? const Color(0xFF1C2431) : const Color(0xFFEDEFF3);

  // ------------------------------------------------------------------ text
  Color get textPrimary => isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
  Color get textSecondary => isDark ? AppThemeData.greyDark600 : AppThemeData.grey600;

  /// Hints, captions, metadata. Still >= 4.5:1 on [surface].
  Color get textMuted => isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
  Color get textDisabled => isDark ? AppThemeData.grey600 : AppThemeData.grey400;
  Color get iconDefault => isDark ? AppThemeData.greyDark600 : AppThemeData.grey600;

  // ------------------------------------------------------------- semantic
  Color get success => isDark ? AppThemeData.successDark200 : AppThemeData.success400;
  Color get successStrong => isDark ? AppThemeData.successDark400 : AppThemeData.success500;
  Color get successSoft => _soft(AppThemeData.success400, AppThemeData.success50);

  Color get warning => isDark ? AppThemeData.warningDark300 : AppThemeData.warning300;
  Color get warningStrong => isDark ? AppThemeData.warningDark400 : AppThemeData.warning500;
  Color get warningSoft => _soft(AppThemeData.warning300, AppThemeData.warning50);

  Color get danger => isDark ? AppThemeData.dangerDark300 : AppThemeData.danger300;
  Color get dangerStrong => isDark ? AppThemeData.dangerDark400 : AppThemeData.danger400;
  Color get dangerSoft => _soft(AppThemeData.danger300, AppThemeData.danger50);

  Color get info => isDark ? AppThemeData.infoDark300 : AppThemeData.info400;
  Color get infoStrong => isDark ? AppThemeData.infoDark400 : AppThemeData.info500;
  Color get infoSoft => _soft(AppThemeData.info300, AppThemeData.info50);

  // ----------------------------------------------------------------- misc
  /// Modal barrier / scrim.
  Color get scrim => Colors.black.withValues(alpha: isDark ? 0.64 : 0.45);
  Color get shimmerBase => isDark ? const Color(0xFF1A2230) : const Color(0xFFE9ECF1);
  Color get shimmerHighlight => isDark ? const Color(0xFF263042) : const Color(0xFFF7F8FA);
  Color get focusRing => brand.withValues(alpha: 0.35);

  /// Shadow color base (used by DsShadows).
  Color get shadow => isDark ? Colors.black : const Color(0xFF0F172A);

  Color _soft(Color base, Color lightSoft) => isDark ? Color.alphaBlend(base.withValues(alpha: 0.16), surface) : lightSoft;

  /// Resolve the 4 colors of a [DsTone].
  DsToneColors tone(DsTone tone) {
    switch (tone) {
      case DsTone.brand:
        return DsToneColors(main: brand, strong: brandStrong, soft: brandSoft, onMain: onBrand);
      case DsTone.success:
        return DsToneColors(main: success, strong: successStrong, soft: successSoft, onMain: isDark ? AppThemeData.grey900 : Colors.white);
      case DsTone.warning:
        return DsToneColors(main: warning, strong: warningStrong, soft: warningSoft, onMain: AppThemeData.grey900);
      case DsTone.danger:
        return DsToneColors(main: isDark ? danger : dangerStrong, strong: dangerStrong, soft: dangerSoft, onMain: Colors.white);
      case DsTone.info:
        return DsToneColors(main: info, strong: infoStrong, soft: infoSoft, onMain: isDark ? AppThemeData.grey900 : Colors.white);
      case DsTone.neutral:
        return DsToneColors(main: textSecondary, strong: textPrimary, soft: surfaceAlt, onMain: surface);
    }
  }
}
