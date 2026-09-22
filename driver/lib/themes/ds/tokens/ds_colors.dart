import 'package:driver/themes/app_them_data.dart';
import 'package:flutter/material.dart';

/// Semantic "tone" used by badges, chips, stat tiles, empty states, dialogs...
///
/// Pick the tone for *meaning*, never for looks:
/// * [brand]   – primary / neutral-positive highlight (new request, selected)
/// * [success] – completed, accepted, paid, delivered, online
/// * [warning] – pending, waiting, needs attention (documents under review)
/// * [danger]  – rejected, cancelled, failed, destructive, SOS
/// * [info]    – in progress: on the way, picked up, in transit, trip started
/// * [neutral] – offline, inactive, draft, metadata
enum DsTone {
  neutral,
  brand,
  success,
  warning,
  danger,
  info;

  /// Best-effort mapping from any status string used in the driver app
  /// (orders, cab rides, parcels, rentals, payouts, documents) to a tone.
  /// Matching is keyword based and case-insensitive, so it works for
  /// `Constant.driverPending`, `Constant.orderInTransit`, `"parcel_completed"`,
  /// `"Offline"`, etc.
  static DsTone fromStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.isEmpty) return DsTone.neutral;
    bool has(List<String> keys) => keys.any(s.contains);
    if (has(['offline', 'inactive', 'draft', 'disabled'])) return DsTone.neutral;
    if (has(['unverified', 'not verified', 'incomplete'])) return DsTone.warning;
    if (has(['reject', 'cancel', 'fail', 'expire', 'declin', 'block', 'suspend', 'denied', 'unpaid', 'sos'])) {
      return DsTone.danger;
    }
    if (has(['complete', 'accept', 'approv', 'success', 'paid', 'deliver', 'active', 'verified', 'online', 'finish'])) {
      return DsTone.success;
    }
    if (has(['pending', 'pause', 'updated', 'schedul', 'waiting', 'review', 'hold', 'return'])) {
      return DsTone.warning;
    }
    if (has(['ship', 'transit', 'progress', 'prepar', 'pickup', 'picked', 'arriv', 'start', 'ongoing', 'on the way', 'on_the_way', 'running', 'driver'])) {
      return DsTone.info;
    }
    if (has(['placed', 'new', 'request'])) return DsTone.brand;
    return DsTone.neutral;
  }
}

/// Service sections a driver can work in. Each section has an accent color
/// (from the existing `AppThemeData` section palettes) used for section
/// badges, the service switcher and map/route accents. The **brand** color
/// stays the primary action color everywhere; section accents only tag.
enum DsSection {
  /// Taxi / cab rides (`cab-service`).
  cab,

  /// Parcel & mail (`parcel_delivery`).
  parcel,

  /// Vehicle rental (`rental-service`).
  rental,

  /// Multi-vendor order delivery (`delivery-service`, `ecommerce-service`).
  delivery,

  /// On-demand services.
  onDemand;

  /// Maps a driver service type / section `serviceTypeFlag` to a section.
  /// Unknown or empty values fall back to [delivery] (same as
  /// `Constant.driverServiceTypeFor`).
  static DsSection fromServiceType(String? serviceType) {
    final s = (serviceType ?? '').toLowerCase();
    if (s.contains('cab') || s.contains('taxi') || s.contains('ride')) return DsSection.cab;
    if (s.contains('parcel') || s.contains('mail')) return DsSection.parcel;
    if (s.contains('rental') || s.contains('rent')) return DsSection.rental;
    if (s.contains('ondemand') || s.contains('on-demand') || s.contains('provider')) return DsSection.onDemand;
    return DsSection.delivery;
  }

  /// Default icon for the section.
  IconData get icon => switch (this) {
    DsSection.cab => Icons.local_taxi_rounded,
    DsSection.parcel => Icons.inventory_2_rounded,
    DsSection.rental => Icons.car_rental_rounded,
    DsSection.delivery => Icons.delivery_dining_rounded,
    DsSection.onDemand => Icons.handyman_rounded,
  };
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

/// Semantic color roles resolved for the current brightness (and the OS
/// "increase contrast" setting).
///
/// Always obtain through `DsColors.of(context)` or `context.dsColors` so the
/// palette follows light / dark mode and high contrast. Brand colors are read
/// from [AppThemeData.primary300] at call time because the driver brand color
/// (`app_driver_color`) is loaded from Firestore at runtime.
///
/// ```dart
/// final c = context.dsColors;
/// Container(color: c.surface, child: Text('Hi', style: TextStyle(color: c.textPrimary)));
/// ```
@immutable
class DsColors {
  final bool isDark;

  /// True when the OS asks for more contrast (iOS "Increase contrast",
  /// Android high-contrast text). Secondary text, borders and brand text get
  /// stronger. Drivers read the screen at a glance, often in sunlight.
  final bool highContrast;

  const DsColors._(this.isDark, [this.highContrast = false]);

  static const DsColors light = DsColors._(false);
  static const DsColors dark = DsColors._(true);
  static const DsColors lightHighContrast = DsColors._(false, true);
  static const DsColors darkHighContrast = DsColors._(true, true);

  /// Resolve from an explicit flag (e.g. `themeController.isDark.value`).
  factory DsColors.resolve(bool isDark, {bool highContrast = false}) =>
      highContrast ? (isDark ? darkHighContrast : lightHighContrast) : (isDark ? dark : light);

  /// Resolve from the ambient [Theme] brightness (kept in sync with
  /// ThemeController by GetMaterialApp.themeMode) and the OS contrast setting.
  static DsColors of(BuildContext context) =>
      DsColors.resolve(Theme.of(context).brightness == Brightness.dark, highContrast: MediaQuery.maybeHighContrastOf(context) ?? false);

  // ---------------------------------------------------------------- brand
  /// Driver brand color (runtime value of `AppThemeData.primary300`).
  Color get brand => AppThemeData.primary300;

  /// Darker (light mode) / lighter (dark mode) brand used for pressed states
  /// and for brand-colored text on surfaces (better contrast than [brand]).
  Color get brandStrong => isDark
      ? Color.lerp(brand, Colors.white, highContrast ? 0.40 : 0.22)!
      : Color.lerp(brand, Colors.black, highContrast ? 0.45 : 0.28)!;

  /// Very soft brand tint (opaque) for selected rows, tonal buttons, chips.
  Color get brandSoft => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.18 : 0.10), surface);

  /// Slightly stronger tint, for borders of tinted elements.
  Color get brandMuted => Color.alphaBlend(brand.withValues(alpha: isDark ? 0.34 : 0.24), surface);

  /// Text / icon color placed on a solid [brand] fill.
  Color get onBrand => brand.computeLuminance() > 0.5 ? AppThemeData.grey900 : Colors.white;

  // -------------------------------------------------------------- surfaces
  /// Page background (scaffold). Slightly tinted so white cards float.
  Color get background => isDark ? AppThemeData.surfaceDark : const Color(0xFFF6F7F9);

  /// Cards, sheets, app bars, map panels.
  Color get surface => isDark ? const Color(0xFF0E131D) : AppThemeData.surface;

  /// Subtle fill: inputs, segmented control track, skeleton base, icon wells.
  Color get surfaceAlt => isDark ? const Color(0xFF171E2B) : AppThemeData.grey100;

  /// Elevated surface for dialogs / bottom sheets / menus / request cards.
  Color get surfaceRaised => isDark ? const Color(0xFF141B27) : AppThemeData.surface;

  /// Inverse surface (snackbars, tooltips).
  Color get surfaceInverse => isDark ? AppThemeData.grey100 : AppThemeData.grey800;

  /// Text on [surfaceInverse].
  Color get onSurfaceInverse => isDark ? AppThemeData.grey900 : AppThemeData.grey50;

  // --------------------------------------------------------------- borders
  Color get border => highContrast ? (isDark ? AppThemeData.grey600 : AppThemeData.grey400) : (isDark ? const Color(0xFF232C3B) : AppThemeData.grey200);
  Color get borderStrong => highContrast ? (isDark ? AppThemeData.greyDark500 : AppThemeData.grey600) : (isDark ? AppThemeData.grey700 : AppThemeData.grey300);
  Color get divider => highContrast ? border : (isDark ? const Color(0xFF1C2431) : const Color(0xFFEDEFF3));

  // ------------------------------------------------------------------ text
  Color get textPrimary => isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
  Color get textSecondary => highContrast ? (isDark ? AppThemeData.greyDark800 : AppThemeData.grey700) : (isDark ? AppThemeData.greyDark600 : AppThemeData.grey600);

  /// Hints, captions, metadata. Still >= 4.5:1 on [surface].
  Color get textMuted => highContrast ? (isDark ? AppThemeData.greyDark700 : AppThemeData.grey600) : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500);
  Color get textDisabled => isDark ? AppThemeData.grey600 : AppThemeData.grey400;
  Color get iconDefault => highContrast ? textPrimary : (isDark ? AppThemeData.greyDark600 : AppThemeData.grey600);

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

  // ------------------------------------------------------- driver states
  /// "Online / available" state color (solid fills, toggle track, map dot).
  Color get online => success;

  /// Text / icon color for the online state on surfaces.
  Color get onlineStrong => successStrong;

  /// "Offline" state color – a clear neutral slate, never red (offline is a
  /// choice, not an error).
  Color get offline => isDark ? AppThemeData.grey500 : AppThemeData.grey600;

  /// Soft background for the offline state.
  Color get offlineSoft => surfaceAlt;

  /// "Busy / on a trip" state color.
  Color get busy => info;

  // ----------------------------------------------------------------- misc
  /// Modal barrier / scrim.
  Color get scrim => Colors.black.withValues(alpha: isDark ? 0.64 : 0.45);
  Color get shimmerBase => isDark ? const Color(0xFF1A2230) : const Color(0xFFE9ECF1);
  Color get shimmerHighlight => isDark ? const Color(0xFF263042) : const Color(0xFFF7F8FA);
  Color get focusRing => brand.withValues(alpha: 0.35);

  /// Shadow color base (used by DsShadows).
  Color get shadow => isDark ? Colors.black : const Color(0xFF0F172A);

  /// Route polyline / pickup marker accent on maps (brand) and drop (danger).
  Color get routePickup => brand;
  Color get routeDrop => isDark ? danger : dangerStrong;

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

  /// Resolve the accent colors of a service [DsSection] (from the existing
  /// `AppThemeData` section palettes).
  DsToneColors section(DsSection section) {
    final (Color main, Color strongLight, Color strongDark) = switch (section) {
      DsSection.cab => (AppThemeData.taxiBooking300, AppThemeData.taxiBooking500, AppThemeData.taxiBookingDark500),
      DsSection.parcel => (AppThemeData.parcelService300, AppThemeData.parcelService500, AppThemeData.parcelServiceDark400),
      DsSection.rental => (AppThemeData.carRent300, AppThemeData.carRent500, AppThemeData.carRentDark400),
      DsSection.delivery => (AppThemeData.multiVendor300, AppThemeData.multiVendor500, AppThemeData.multiVendorDark400),
      DsSection.onDemand => (AppThemeData.onDemand300, AppThemeData.onDemand500, AppThemeData.onDemandDark300),
    };
    return DsToneColors(
      main: main,
      strong: isDark ? strongDark : strongLight,
      soft: Color.alphaBlend(main.withValues(alpha: isDark ? 0.18 : 0.14), surface),
      onMain: main.computeLuminance() > 0.45 ? AppThemeData.grey900 : Colors.white,
    );
  }
}
