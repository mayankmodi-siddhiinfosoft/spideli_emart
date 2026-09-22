import 'package:flutter/material.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/app_them_data.dart';

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

  /// Best-effort mapping from any status string used in the app (booking /
  /// job status, document verification, payment...) to a tone. Matching is
  /// keyword based and case-insensitive, so it works for `ORDER_STATUS_*`
  /// constants, `"Order Completed"`, `"approved"`, `"rejected"`, etc.
  static DsTone fromStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.isEmpty) return DsTone.neutral;
    bool has(List<String> keys) => keys.any(s.contains);
    if (has(['reject', 'cancel', 'fail', 'expire', 'declin', 'block', 'suspend', 'denied', 'unpaid'])) {
      return DsTone.danger;
    }
    if (has(['inactive', 'draft', 'offline'])) return DsTone.neutral;
    if (has(['complete', 'accept', 'approv', 'running', 'success', 'paid', 'deliver', 'active', 'verified', 'online'])) {
      return DsTone.success;
    }
    if (has(['pending', 'pause', 'updated', 'schedul', 'waiting', 'review', 'hold'])) {
      return DsTone.warning;
    }
    if (has(['ship', 'transit', 'driver', 'progress', 'prepar', 'pickup', 'picked', 'ongoing', 'start', 'assign'])) {
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
/// palette follows light / dark mode. The brand color is read from
/// [AppColors.colorPrimary] at call time because the worker brand color
/// (`globalSettings.worker_app_color`) is loaded from Firestore at runtime.
///
/// ```dart
/// final c = context.dsColors;
/// Container(color: c.surface, child: Text('Hi', style: TextStyle(color: c.textPrimary)));
/// ```
@immutable
class DsColors {
  final bool isDark;

  const DsColors._(this.isDark);

  static const DsColors light = DsColors._(false);
  static const DsColors dark = DsColors._(true);

  /// Resolve from an explicit flag (e.g. `themeChange.getTheme()` from the
  /// `DarkThemeProvider`).
  factory DsColors.resolve(bool isDark) => isDark ? dark : light;

  /// Resolve from the ambient [Theme] brightness (kept in sync with
  /// `DarkThemeProvider` by `main.dart`, which rebuilds the app theme).
  static DsColors of(BuildContext context) => DsColors.resolve(Theme.of(context).brightness == Brightness.dark);

  // ---------------------------------------------------------------- brand
  /// Worker brand color (runtime value of `AppColors.colorPrimary`).
  Color get brand => AppColors.colorPrimary;

  /// Darker (light mode) / lighter (dark mode) brand used for pressed states
  /// and for brand-colored text on surfaces (better contrast than [brand]).
  Color get brandStrong => isDark ? Color.lerp(brand, Colors.white, 0.22)! : Color.lerp(brand, Colors.black, 0.28)!;

  /// Very soft brand tint (opaque) for selected rows, tonal buttons, chips.
  Color get brandSoft => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.18 : 0.10), surface);

  /// Slightly stronger tint, for borders of tinted elements.
  Color get brandMuted => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.34 : 0.24), surface);

  /// Text / icon color placed on a solid [brand] fill.
  Color get onBrand => brand.computeLuminance() > 0.62 ? AppThemeData.grey900 : Colors.white;

  // -------------------------------------------------------------- surfaces
  /// Page background (scaffold). Slightly tinted so white cards float.
  Color get background => isDark ? AppThemeData.surfaceDark : const Color(0xFFF6F7F9);

  /// Cards, sheets, app bars.
  Color get surface => isDark ? const Color(0xFF0E131D) : AppThemeData.grey50;

  /// Subtle fill: inputs, segmented control track, skeleton base, icon wells.
  Color get surfaceAlt => isDark ? const Color(0xFF171E2B) : AppThemeData.grey100;

  /// Elevated surface for dialogs / bottom sheets / menus.
  Color get surfaceRaised => isDark ? const Color(0xFF141B27) : AppThemeData.grey50;

  /// Inverse surface (snackbars, tooltips).
  Color get surfaceInverse => isDark ? AppThemeData.grey100 : AppThemeData.grey800;

  /// Text on [surfaceInverse].
  Color get onSurfaceInverse => isDark ? AppThemeData.grey900 : AppThemeData.grey50;

  // --------------------------------------------------------------- borders
  Color get border => isDark ? const Color(0xFF232C3B) : AppThemeData.grey200;
  Color get borderStrong => isDark ? AppThemeData.grey700 : AppThemeData.grey300;
  Color get divider => isDark ? const Color(0xFF1C2431) : const Color(0xFFEDEFF3);

  // ------------------------------------------------------------------ text
  Color get textPrimary => isDark ? _greyDark900 : AppThemeData.grey900;
  Color get textSecondary => isDark ? _greyDark600 : AppThemeData.grey600;

  /// Hints, captions, metadata. Still >= 4.5:1 on [surface].
  Color get textMuted => isDark ? _greyDark500 : AppThemeData.grey500;
  Color get textDisabled => isDark ? AppThemeData.grey600 : AppThemeData.grey400;
  Color get iconDefault => isDark ? _greyDark600 : AppThemeData.grey600;

  // ------------------------------------------------------------- semantic
  Color get success => AppThemeData.success400;
  Color get successStrong => isDark ? AppThemeData.success200 : AppThemeData.success500;
  Color get successSoft => _soft(AppThemeData.success400, AppThemeData.success50);

  Color get warning => AppThemeData.warning300;
  Color get warningStrong => isDark ? AppThemeData.warning200 : AppThemeData.warning500;
  Color get warningSoft => _soft(AppThemeData.warning300, AppThemeData.warning50);

  Color get danger => AppThemeData.danger300;
  Color get dangerStrong => isDark ? AppThemeData.danger200 : AppThemeData.danger400;
  Color get dangerSoft => _soft(AppThemeData.danger300, AppThemeData.danger50);

  Color get info => isDark ? AppThemeData.info300 : AppThemeData.info400;
  Color get infoStrong => isDark ? AppThemeData.info200 : AppThemeData.info500;
  Color get infoSoft => _soft(AppThemeData.info300, AppThemeData.info50);

  // ----------------------------------------------------------------- misc
  /// Modal barrier / scrim.
  Color get scrim => Colors.black.withValues(alpha: isDark ? 0.64 : 0.45);
  Color get shimmerBase => isDark ? const Color(0xFF1A2230) : const Color(0xFFE9ECF1);
  Color get shimmerHighlight => isDark ? const Color(0xFF263042) : const Color(0xFFF7F8FA);
  Color get focusRing => brand.withValues(alpha: 0.35);

  /// Shadow color base (used by DsShadows).
  Color get shadow => isDark ? Colors.black : const Color(0xFF0F172A);

  // Dark-mode text greys (the worker AppThemeData has no dark grey scale).
  static const Color _greyDark900 = Color(0xFFF9FAFB);
  static const Color _greyDark600 = Color(0xFFD1D5DB);
  static const Color _greyDark500 = Color(0xFF9CA3AF);

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
