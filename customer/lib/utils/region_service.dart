import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

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
import 'package:geocoding/geocoding.dart';
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
///   [customerRegionIds] / [customerRegionId], on one ladder: an explicit
///   choice -> the published delivery zone(s) around them -> their country,
///   matched on `countryCode` (never `code`) -> `settings/RegionDefaults` ->
///   none. It decides DISCOVERY only (which sections and stores are offered,
///   and the currency shown before a store is chosen); every price, payment
///   method and delivery charge comes from the store's region.
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

  /// `settings/RegionDefaults.defaultRegionId` (admin spec §5): the LAST rung
  /// of the ladder - used only when location and country match no region, and
  /// never over a region already resolved. Empty = behaviour before it existed.
  static String? defaultRegionId;

  /// Country of the customer, ISO code, once known: the reverse-geocoded
  /// country of their location, else the device locale's country.
  static String? _customerCountryCode;
  static Future<void>? _countryLoading;

  /// Preferences key of an explicit region choice (rung 1). No picker ships
  /// today; [setSelectedRegion] is the single entry point when one does.
  static const String selectedRegionKey = 'selectedRegionId';

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
    // Last rung of the ladder; a missing document leaves it null (= today).
    try {
      final doc = await _db.collection(CollectionName.settings).doc('RegionDefaults').get();
      final String? value = doc.data()?['defaultRegionId']?.toString();
      defaultRegionId = _isEmpty(value) ? null : value;
    } catch (e) {
      log("RegionService RegionDefaults not loaded: $e");
    }
    // Rung 3 needs a country; resolving it is a best-effort background step so
    // nothing waits on it (the ladder simply skips the rung until it lands).
    unawaited(ensureCustomerCountry());
  }

  // ---------------------------------------------------------------------------
  // Regions
  // ---------------------------------------------------------------------------

  static bool get hasRegions => _regions.isNotEmpty;

  static RegionModel? regionById(String? regionId) => _isEmpty(regionId) ? null : _regions[regionId];

  /// Every region the admin publishes, sorted by name. Unpublished regions
  /// stay readable through [regionById] so an old record keeps its currency,
  /// but they are never offered or matched.
  static List<RegionModel> get publishedRegions {
    final list = _regions.values.where((r) => r.publish).toList();
    list.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    return list;
  }

  /// True when the region exists and is published.
  static bool isPublished(String? regionId) => regionById(regionId)?.publish == true;

  /// Published regions of [countryCode], matched on `countryCode` ONLY -
  /// `code` is a free-text label (Gabon reads "GB") and is never matched.
  static List<String> regionIdsForCountry(String? countryCode) {
    if (_isEmpty(countryCode)) return const [];
    return publishedRegions.where((r) => r.isInCountry(countryCode)).map((r) => r.id!).toList();
  }

  /// The country's region when exactly one published region claims it.
  static String? regionIdForCountry(String? countryCode) {
    final ids = regionIdsForCountry(countryCode);
    return ids.length == 1 ? ids.first : null;
  }

  /// The website's same-country bridge (WEB spec §1): the other published
  /// regions of [regionId]'s country. Discovery only - never pricing.
  static List<String> sameCountryRegionIds(String? regionId) {
    final region = regionById(regionId);
    if (region == null || _isEmpty(region.countryCode)) return const [];
    return regionIdsForCountry(region.countryCode);
  }

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

  /// An explicit region choice, if one was ever made (rung 1). Null when the
  /// stored id names no published region.
  static String? get selectedRegionId {
    try {
      final String value = Preferences.getString(selectedRegionKey);
      return isPublished(value) ? value : null;
    } catch (_) {
      // Preferences not initialised yet: no choice has been made.
      return null;
    }
  }

  /// Remembers (or clears, with null) an explicit region choice.
  static Future<void> setSelectedRegion(String? regionId) async {
    await Preferences.setString(selectedRegionKey, regionId ?? '');
  }

  /// Regions of the published delivery zone(s) containing the customer's
  /// current location (rung 2). Empty = no location, no zone, or zones
  /// without region data.
  static List<String> get zoneRegionIds {
    final point = customerLocation;
    if (point == null) return const [];
    return regionIdsAt(point.latitude, point.longitude);
  }

  /// The customer's DISCOVERY regions - which sections and stores are offered
  /// and which currency is shown before a store is chosen. It decides nothing
  /// about money: a price, a payment method or a delivery charge always comes
  /// from the STORE's region (admin spec §2/§3, WEB spec §1).
  ///
  /// **THE ANSWER to "service availability - the customer's location, or their
  /// account?" (ADMIN spec §18, WEB spec §10): the LOCATION.** Availability is
  /// the customer's CURRENT location resolved through the delivery zone to
  /// region(s); when it cannot be resolved this returns an empty list and
  /// EVERYTHING is shown (`isAvailableInAnyRegion`), never nothing.
  ///
  /// `users/{uid}.regionIds` is deliberately NOT read here. It is an
  /// append-only record of where the customer has already ordered
  /// (`FireStoreUtils.addCustomerRegion`), written for the admin panel - not
  /// an input to availability. A customer who travels sees the services of
  /// where they ARE, not of where they once ordered. Customers never carry a
  /// `regionId` string either; do not start writing one.
  ///
  /// This getter is the ONLY place availability regions are computed: home,
  /// the "More" panel and its search, and the per-service dashboards all read
  /// the one region-filtered section list built from it in
  /// `ServiceListController.loadData`. Filter here, nowhere else.
  ///
  /// The ladder, each rung used only when the ones above it found nothing:
  /// explicit choice -> the zone(s) around the customer (plus the other
  /// regions of that country, the website's same-country bridge) -> the
  /// customer's country matched on `countryCode` -> `RegionDefaults` ->
  /// empty, which filters nothing at all.
  static List<String> get customerRegionIds {
    final String? chosen = selectedRegionId;
    if (chosen != null) return [chosen];
    // A region the admin unpublished is dropped; one we know nothing about is
    // kept, so a missing / unread `regions` collection behaves as before.
    final List<String> fromZone = zoneRegionIds.where((id) => regionById(id)?.publish != false).toList();
    if (fromZone.isNotEmpty) {
      final Set<String> ids = {...fromZone};
      for (final id in fromZone) {
        ids.addAll(sameCountryRegionIds(id));
      }
      return ids.toList();
    }
    final List<String> fromCountry = regionIdsForCountry(_customerCountryCode);
    if (fromCountry.isNotEmpty) return fromCountry;
    if (isPublished(defaultRegionId)) return [defaultRegionId!];
    return const [];
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

  /// The customer's region when the ladder resolves to exactly one, else
  /// null. Same rungs as [customerRegionIds]: explicit choice -> a zone
  /// serving exactly one region -> the country (`countryCode`, never `code`)
  /// when exactly one published region claims it -> `RegionDefaults` -> none.
  static String? get customerRegionId {
    final String? chosen = selectedRegionId;
    if (chosen != null) return chosen;
    final List<String> fromZone = zoneRegionIds;
    if (fromZone.length == 1) return fromZone.first;
    if (fromZone.isEmpty) {
      final String? fromCountry = regionIdForCountry(_customerCountryCode);
      if (fromCountry != null) return fromCountry;
      if (isPublished(defaultRegionId)) return defaultRegionId;
    }
    return null;
  }

  /// The customer's country (ISO code), resolved once: the country of the
  /// location the app works with, else the device locale's country. Failures
  /// leave it null, which simply skips the country rung of the ladder.
  static Future<String?> ensureCustomerCountry({bool force = false}) async {
    if (_customerCountryCode != null && !force) return _customerCountryCode;
    if (force) _countryLoading = null;
    _countryLoading ??= _loadCustomerCountry();
    await _countryLoading;
    return _customerCountryCode;
  }

  /// The country code as last resolved (null until [ensureCustomerCountry]).
  static String? get customerCountryCode => _customerCountryCode;

  static Future<void> _loadCustomerCountry() async {
    final point = customerLocation;
    if (point != null) {
      try {
        final places = await Geocoding().placemarkFromCoordinates(point.latitude, point.longitude);
        final String? iso = places.isNotEmpty ? places.first.isoCountryCode : null;
        if (!_isEmpty(iso)) {
          _customerCountryCode = iso!.toUpperCase();
          return;
        }
      } catch (e) {
        log("RegionService country lookup failed: $e");
      }
    }
    final String? locale = ui.PlatformDispatcher.instance.locale.countryCode;
    if (!_isEmpty(locale)) _customerCountryCode = locale!.toUpperCase();
    _countryLoading = null; // an unresolved country may be retried later
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
