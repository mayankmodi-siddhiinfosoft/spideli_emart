import 'package:customer/constant/constant.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';

/// The customer app's service sections. Each one keeps its own accent
/// palette from [AppThemeData] so a service always looks like itself.
///
/// | Section | `serviceTypeFlag` | Palette |
/// |---|---|---|
/// | [food] (multi-vendor / restaurants) | `delivery-service` | `multiVendor*` (red) |
/// | [ecommerce] | `ecommerce-service` | `ecommerce*` (blue) |
/// | [cab] (taxi / intercity) | `cab-service` | `taxiBooking*` (amber) |
/// | [parcel] | `parcel_delivery` | `parcelService*` (green) |
/// | [rental] (car rent) | `rental-service` | `carRent*` (green) |
/// | [onDemand] (services / providers) | `ondemand-service` | `onDemand*` (cyan) |
/// | [none] | no section selected | the app brand (`AppThemeData.primary300`) |
///
/// ```dart
/// final s = DsSection.current;                        // active section
/// final a = context.dsColors.sectionAccent(DsSection.cab);  // explicit accent
/// DsSection.fromServiceFlag(section.serviceTypeFlag)
/// ```
enum DsSection {
  none,
  food,
  ecommerce,
  cab,
  parcel,
  rental,
  onDemand;

  /// Map a `SectionModel.serviceTypeFlag` to a section.
  static DsSection fromServiceFlag(String? flag) {
    switch ((flag ?? '').trim().toLowerCase()) {
      case 'delivery-service':
        return DsSection.food;
      case 'ecommerce-service':
        return DsSection.ecommerce;
      case 'cab-service':
        return DsSection.cab;
      case 'parcel_delivery':
        return DsSection.parcel;
      case 'rental-service':
        return DsSection.rental;
      case 'ondemand-service':
        return DsSection.onDemand;
      default:
        return DsSection.none;
    }
  }

  /// The section the user is currently in (`Constant.sectionConstantModel`).
  static DsSection get current => fromServiceFlag(Constant.sectionConstantModel?.serviceTypeFlag);

  /// Palette base color (the `…300` step) for this section.
  ///
  /// This is the *design* palette. The live brand color of the active section
  /// (`context.dsColors.brand`) comes from the section's `color` in Firestore
  /// and is normally the same hue.
  Color base(bool isDark) {
    switch (this) {
      case DsSection.food:
        return isDark ? AppThemeData.multiVendorDark300 : AppThemeData.multiVendor300;
      case DsSection.ecommerce:
        return isDark ? AppThemeData.ecommerceDark300 : AppThemeData.ecommerce300;
      case DsSection.cab:
        return isDark ? AppThemeData.taxiBookingDark300 : AppThemeData.taxiBooking300;
      case DsSection.parcel:
        return isDark ? AppThemeData.parcelServiceDark300 : AppThemeData.parcelService300;
      case DsSection.rental:
        return isDark ? AppThemeData.carRentDark300 : AppThemeData.carRent300;
      case DsSection.onDemand:
        return isDark ? AppThemeData.onDemandDark300 : AppThemeData.onDemand300;
      case DsSection.none:
        return AppThemeData.primary300;
    }
  }

  /// Readable accent text on surfaces (`…400` light / `…400|500` dark).
  Color strong(bool isDark) {
    switch (this) {
      case DsSection.food:
        return isDark ? AppThemeData.multiVendorDark400 : AppThemeData.multiVendor400;
      case DsSection.ecommerce:
        return isDark ? AppThemeData.ecommerceDark400 : AppThemeData.ecommerce400;
      case DsSection.cab:
        return isDark ? AppThemeData.taxiBookingDark400 : AppThemeData.taxiBooking400;
      case DsSection.parcel:
        return isDark ? AppThemeData.parcelServiceDark400 : AppThemeData.parcelService400;
      case DsSection.rental:
        return isDark ? AppThemeData.carRentDark400 : AppThemeData.carRent400;
      case DsSection.onDemand:
        return isDark ? AppThemeData.onDemandDark300 : AppThemeData.onDemand400;
      case DsSection.none:
        final b = AppThemeData.primary300;
        return isDark ? Color.lerp(b, Colors.white, 0.22)! : Color.lerp(b, Colors.black, 0.28)!;
    }
  }

  /// Light-mode soft tint (`…50`). Dark mode blends [base] onto the surface.
  Color get lightSoft {
    switch (this) {
      case DsSection.food:
        return AppThemeData.multiVendor50;
      case DsSection.ecommerce:
        return AppThemeData.ecommerce50;
      case DsSection.cab:
        return AppThemeData.taxiBooking50;
      case DsSection.parcel:
        return AppThemeData.parcelService50;
      case DsSection.rental:
        return AppThemeData.carRent50;
      case DsSection.onDemand:
        return AppThemeData.onDemand50;
      case DsSection.none:
        return AppThemeData.primary50;
    }
  }

  /// Default icon for section tiles, chips and empty states.
  IconData get icon {
    switch (this) {
      case DsSection.food:
        return Icons.restaurant_rounded;
      case DsSection.ecommerce:
        return Icons.shopping_bag_rounded;
      case DsSection.cab:
        return Icons.local_taxi_rounded;
      case DsSection.parcel:
        return Icons.inventory_2_rounded;
      case DsSection.rental:
        return Icons.car_rental_rounded;
      case DsSection.onDemand:
        return Icons.home_repair_service_rounded;
      case DsSection.none:
        return Icons.apps_rounded;
    }
  }
}
