import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/models/region_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/zone_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Everything region-related for the Customer app, in one place (spec 18.4 -
/// 18.8 and the shared app contract).
///
/// * `regionOf(record)`: the record's own `regionId`, else its zone's region
///   when that zone serves exactly ONE region (`zone.regionIds`, falling back
///   to the deprecated `zone.regionId` only when `regionIds` is absent), else
///   null = global settings.
/// * Live amounts (a store's products, cart, checkout, delivery charge, fares
///   being quoted) use the currency of the region of the store / provider /
///   driver whose price it is: [currencyForVendor], [currencyForRegion].
/// * History amounts (orders, rides, bookings, receipts, order wallet rows)
///   use the record's OWN `regionId`: [currencyForRecord].
/// * Fallback everywhere: the globally active currency
///   (`Constant.currencyModel`), i.e. exactly what the app showed before
///   regions existed.
/// * The customer's current region(s) are computed ONLY in
///   [customerRegionIds] (current location -> published delivery zone
///   containing it -> that zone's `regionIds`).
///
/// `regions`, `currencies` and `zone` are small collections; they are read
/// once and kept in memory. With no region data everything behaves exactly as
/// before.
class RegionService {
  RegionService._();

  // The app may run on a named Firestore database (see main.dart), so always
  // go through FireStoreUtils.fireStore.
  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static final Map<String, RegionModel> _regions = {};
  static final Map<String, CurrencyModel> _currencies = {};
  static final Map<String, ZoneModel> _zones = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Loads `regions`, `currencies` and `zone` once. Safe to call
  /// concurrently; a failed load is retried on the next call.
  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (force) _loading = null;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    try {
      final results = await Future.wait([
        _db.collection(CollectionName.regions).get(),
        _db.collection(CollectionName.currencies).get(),
        _db.collection(CollectionName.zone).get(),
      ]);
      _regions.clear();
      for (final doc in results[0].docs) {
        final region = RegionModel.fromJson(doc.data(), docId: doc.id);
        if (region.id != null) _regions[region.id!] = region;
      }
      _currencies.clear();
      for (final doc in results[1].docs) {
        final currency = CurrencyModel.fromJson(doc.data());
        _currencies[doc.id] = currency;
        if (currency.id.isNotEmpty && currency.id != doc.id) _currencies[currency.id] = currency;
      }
      _zones.clear();
      for (final doc in results[2].docs) {
        final zone = ZoneModel.fromJson(doc.data());
        zone.id ??= doc.id;
        _zones[doc.id] = zone;
      }
      _loaded = true;
    } catch (e, s) {
      log("RegionService load failed: $e", stackTrace: s);
      _loading = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Regions
  // ---------------------------------------------------------------------------

  static bool get hasRegions => _regions.isNotEmpty;

  static RegionModel? regionById(String? regionId) => _isEmpty(regionId) ? null : _regions[regionId];

  static ZoneModel? zoneById(String? zoneId) {
    if (_isEmpty(zoneId)) return null;
    final cached = _zones[zoneId];
    if (cached != null) return cached;
    for (final zone in Constant.zoneList) {
      if (zone.id == zoneId) return zone;
    }
    return null;
  }

  /// The regions a zone serves: `regionIds`, else the legacy `regionId`.
  static List<String> regionIdsOfZone(ZoneModel? zone) {
    if (zone == null) return const [];
    if (zone.regionIds != null) return zone.regionIds!;
    if (!_isEmpty(zone.regionId)) return [zone.regionId!];
    return const [];
  }

  /// The zone's region, only when it serves exactly one region.
  static String? regionOfZone(String? zoneId) {
    final ids = regionIdsOfZone(zoneById(zoneId));
    return ids.length == 1 ? ids.first : null;
  }

  /// `regionOf(record)` from the contract: own `regionId`, else the zone's
  /// single region, else null (= global settings).
  static String? regionOf({String? regionId, String? zoneId}) {
    if (!_isEmpty(regionId)) return regionId;
    return regionOfZone(zoneId);
  }

  // ---------------------------------------------------------------------------
  // Stores (vendors)
  // ---------------------------------------------------------------------------

  /// vendorId -> (regionId, zoneId) as last parsed. Filled by
  /// `VendorModel.fromJson`, so products listed next to their stores can find
  /// the store currency without another read.
  static final Map<String, List<String?>> _vendors = {};

  static void rememberVendor(String? vendorId, String? regionId, String? zoneId) {
    if (_isEmpty(vendorId)) return;
    _vendors[vendorId!] = [regionId, zoneId];
  }

  /// Region of a store (`regionOf(vendor)`).
  static String? regionOfVendor(VendorModel? vendor) {
    if (vendor == null) return null;
    return regionOf(regionId: vendor.regionId, zoneId: vendor.zoneId);
  }

  /// Region of a store known only by id (from the parsed-vendor cache).
  static String? regionOfVendorId(String? vendorId) {
    if (_isEmpty(vendorId)) return null;
    final entry = _vendors[vendorId];
    if (entry == null) return null;
    return regionOf(regionId: entry[0], zoneId: entry[1]);
  }

  /// Store region, reading the store when it is not cached yet.
  static Future<String?> resolveVendorRegion(String? vendorId) async {
    await ensureLoaded();
    if (_isEmpty(vendorId)) return null;
    if (!_vendors.containsKey(vendorId)) await FireStoreUtils.getVendorById(vendorId!);
    return regionOfVendorId(vendorId);
  }

  // ---------------------------------------------------------------------------
  // Users (drivers, providers)
  // ---------------------------------------------------------------------------

  static final Map<String, String?> _userRegions = {};

  /// `users/{userId}.regionId` (driver / provider / worker), cached. Null when
  /// the user has no region.
  static Future<String?> userRegionId(String? userId) async {
    if (_isEmpty(userId)) return null;
    if (_userRegions.containsKey(userId)) return _userRegions[userId];
    try {
      final doc = await _db.collection(CollectionName.users).doc(userId).get();
      final data = doc.data();
      final String? value = data?['regionId']?.toString();
      _userRegions[userId!] = _isEmpty(value) ? regionOfZone(data?['zoneId']?.toString()) : value;
    } catch (e) {
      log("RegionService user region failed: $e");
      return null;
    }
    return _userRegions[userId];
  }

  /// Region of an on-demand service provider: the provider's user document
  /// (`provider.author`), else `providers_services.regionId`.
  static Future<String?> providerRegionId(ProviderServiceModel? provider) async {
    if (provider == null) return null;
    return await userRegionId(provider.author) ?? regionOf(regionId: provider.regionId);
  }

  // ---------------------------------------------------------------------------
  // Customer's current region(s) - the single place this is computed
  // ---------------------------------------------------------------------------

  /// The location the app works with: the chosen delivery location (initially
  /// the device position), else the device position.
  static LatLng? get customerLocation {
    final selected = Constant.selectedLocation.location;
    if (selected?.latitude != null && selected?.longitude != null) {
      return LatLng(selected!.latitude!, selected.longitude!);
    }
    final current = Constant.currentLocation;
    if (current != null) return LatLng(current.latitude, current.longitude);
    return null;
  }

  /// Regions of the published delivery zone(s) containing the customer's
  /// current location. Empty = unresolved (no location, no zone, or zones
  /// without region data): callers then show everything, as today.
  static List<String> get customerRegionIds {
    final point = customerLocation;
    if (point == null) return const [];
    return regionIdsAt(point.latitude, point.longitude);
  }

  /// Regions of the published delivery zone(s) containing a point.
  static List<String> regionIdsAt(double? latitude, double? longitude) {
    if (latitude == null || longitude == null || (latitude == 0 && longitude == 0)) return const [];
    final point = LatLng(latitude, longitude);
    final zones = _zones.isNotEmpty ? _zones.values : Constant.zoneList;
    final Set<String> ids = {};
    for (final zone in zones) {
      if (zone.publish == false || zone.area == null || zone.area!.isEmpty) continue;
      if (Constant.isPointInPolygon(point, zone.area!)) ids.addAll(regionIdsOfZone(zone));
    }
    return ids.toList();
  }

  /// The single region a point (e.g. a ride's pickup) resolves to, else null.
  static String? regionAt(double? latitude, double? longitude) {
    final ids = regionIdsAt(latitude, longitude);
    return ids.length == 1 ? ids.first : null;
  }

  /// The customer's region when it resolves to exactly one, else null.
  static String? get customerRegionId {
    final ids = customerRegionIds;
    return ids.length == 1 ? ids.first : null;
  }

  // ---------------------------------------------------------------------------
  // Currency
  // ---------------------------------------------------------------------------

  /// The globally active currency (fallback only).
  static CurrencyModel? get globalCurrency => Constant.currencyModel;

  /// Currency configured for [regionId]; null when the region is unknown or
  /// has no currency (normal for old records).
  static CurrencyModel? currencyForRegion(String? regionId) {
    final region = regionById(regionId);
    if (region == null || _isEmpty(region.currencyId)) return null;
    return _currencies[region.currencyId!];
  }

  /// History: the currency a record (order, ride, booking, payment, receipt)
  /// was charged in = its own `regionId`, else the global currency.
  static CurrencyModel? currencyForRecord(String? regionId) => currencyForRegion(regionId) ?? globalCurrency;

  /// Live: a store's current region currency, else global.
  static CurrencyModel? currencyForVendor(VendorModel? vendor) => currencyForRegion(regionOfVendor(vendor)) ?? globalCurrency;

  /// Live: currency of the store with [vendorId] (cached vendors only).
  static CurrencyModel? currencyForVendorId(String? vendorId) => currencyForRegion(regionOfVendorId(vendorId)) ?? globalCurrency;

  /// Live: on-demand service price = the service's region (`regionId`, else
  /// its zone), else global.
  static CurrencyModel? currencyForService({String? regionId, String? zoneId}) => currencyForRegion(regionOf(regionId: regionId, zoneId: zoneId)) ?? globalCurrency;

  /// Account-level amounts not tied to one store (wallet balance, top-up,
  /// gift cards, referral rewards): the customer's current region when it
  /// resolves to exactly one, else global.
  static CurrencyModel? get customerCurrency => currencyForRegion(customerRegionId) ?? globalCurrency;

  // ---------------------------------------------------------------------------
  // `regionIds` availability (payment gateways, sections)
  // ---------------------------------------------------------------------------

  /// Empty/absent [regionIds] = available everywhere; otherwise only in the
  /// listed regions. An unknown region hides nothing (today's behaviour).
  static bool isAvailableInRegion(dynamic regionIds, String? regionId) {
    final ids = toIdList(regionIds);
    if (ids.isEmpty || _isEmpty(regionId)) return true;
    return ids.contains(regionId);
  }

  /// Same rule against several regions: available when [regionIds] is empty,
  /// the customer's regions are unresolved, or the two intersect.
  static bool isAvailableInAnyRegion(dynamic regionIds, List<String> customerRegions) {
    final ids = toIdList(regionIds);
    if (ids.isEmpty || customerRegions.isEmpty) return true;
    return ids.any(customerRegions.contains);
  }

  static List<String> toIdList(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  /// Preferences key of a gateway -> its `regionIds`, as last loaded by
  /// `FireStoreUtils.getPaymentSettingsData`.
  static final Map<String, List<String>> _gatewayRegionIds = {};

  static void rememberGatewayRegions(String prefsKey, dynamic regionIds) {
    _gatewayRegionIds[prefsKey] = toIdList(regionIds);
  }

  /// The stored settings of the gateway saved under [prefsKey], with every
  /// "enabled" flag switched off when the gateway is not offered in
  /// [regionId] (spec 18.7). The models use `isEnabled`, `isEnable` or
  /// `enable`; only keys already present are touched. [regionId] null = no
  /// filtering (today's behaviour).
  static Map<String, dynamic> gatewaySettings(String prefsKey, String? regionId) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(Preferences.getString(prefsKey)) as Map);
    if (isAvailableInRegion(_gatewayRegionIds[prefsKey], regionId)) return data;
    for (final key in const ['isEnabled', 'isEnable', 'enable']) {
      if (data.containsKey(key)) data[key] = false;
    }
    return data;
  }

  static const Map<String, String> _gatewayPrefsKey = {
    'stripe': Preferences.stripeSettings,
    'paypal': Preferences.paypalSettings,
    'payStack': Preferences.payStack,
    'mercadoPago': Preferences.mercadoPago,
    'flutterWave': Preferences.flutterWave,
    'payFast': Preferences.payFastSettings,
    'razorpay': Preferences.razorpaySettings,
    'midTrans': Preferences.midTransSettings,
    'orangeMoney': Preferences.orangeMoneySettings,
    'xendit': Preferences.xenditSettings,
    'wallet': Preferences.walletSettings,
    'cod': Preferences.codSettings,
    'paytm': Preferences.paytmSettings,
  };

  /// Whether the payment method [name] (a PaymentGateway name) can be used in
  /// [regionId]: enabled in its settings and not excluded by its regionIds.
  /// Used to drop a remembered choice after the region's methods reload.
  static bool isGatewayUsable(String name, String? regionId) {
    if (name.isEmpty) return false;
    final String? key = _gatewayPrefsKey[name];
    if (key == null) return true;
    try {
      final data = gatewaySettings(key, regionId);
      for (final field in const ['isEnabled', 'isEnable', 'enable']) {
        if (data.containsKey(field)) return data[field] == true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Delivery charge (settings/DeliveryCharge, optional per-region overrides)
  // ---------------------------------------------------------------------------

  /// `regions[regionId]` of settings/DeliveryCharge when present, else the
  /// top-level (global) figures.
  static DeliveryCharge? deliveryChargeFrom(Map<String, dynamic>? data, String? regionId) {
    if (data == null) return null;
    final Map<String, dynamic> global = Map<String, dynamic>.from(data)..remove('regions');
    final regional = data['regions'];
    if (!_isEmpty(regionId) && regional is Map && regional[regionId] is Map) {
      return DeliveryCharge.fromJson({...global, ...Map<String, dynamic>.from(regional[regionId] as Map)});
    }
    return DeliveryCharge.fromJson(global);
  }

  // ---------------------------------------------------------------------------
  // Region of order-based wallet rows
  // ---------------------------------------------------------------------------

  static const List<String> _orderCollections = [
    CollectionName.vendorOrders,
    CollectionName.rides,
    CollectionName.rentalOrders,
    CollectionName.providerOrders,
    CollectionName.parcelOrders,
  ];

  /// `regionId` of the orders/rides/bookings with [orderIds]. Skipped (no
  /// reads) when no regions exist. Failures fall back to "unknown".
  static Future<Map<String, String>> orderRegionIds(Iterable<String?> orderIds) async {
    final Map<String, String> result = {};
    await ensureLoaded();
    if (!hasRegions) return result;
    final ids = orderIds.whereType<String>().where((e) => e.isNotEmpty && e != 'null').toSet().toList();
    if (ids.isEmpty) return result;
    for (final collection in _orderCollections) {
      final pending = ids.where((e) => !result.containsKey(e)).toList();
      for (var i = 0; i < pending.length; i += 30) {
        final chunk = pending.sublist(i, i + 30 > pending.length ? pending.length : i + 30);
        try {
          final snap = await _db.collection(collection).where(FieldPath.documentId, whereIn: chunk).get();
          for (final doc in snap.docs) {
            final regionId = doc.data()['regionId']?.toString();
            if (!_isEmpty(regionId)) result[doc.id] = regionId!;
          }
        } catch (e) {
          log("RegionService order regions ($collection) failed: $e");
        }
      }
    }
    return result;
  }

  static bool _isEmpty(String? value) => value == null || value.isEmpty;
}
