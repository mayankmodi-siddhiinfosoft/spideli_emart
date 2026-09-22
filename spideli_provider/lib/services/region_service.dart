import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/region_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';

/// Management zones (`regions`) and their currencies, matching the admin panel
/// (spec 3.1 / 18.4 / 18.5).
///
/// * Region of the provider: `users.regionId`, else the provider's `zoneId`
///   when that zone serves exactly one region (`zone.regionIds`, legacy
///   `zone.regionId`), else none (= global settings).
/// * Live amounts (services, catalogue, wallet balance, plans) use the
///   provider's region currency: `regions/{id}.currencyId` -> `currencies/{id}`,
///   falling back to the globally active currency. [apply] points the app-wide
///   [currencyData] at it, so every existing `amountShow` follows.
/// * History (bookings, receipts, wallet rows of a booking, payouts) uses the
///   record's own `regionId`, else the provider currency, else the global one.
///
/// `regions` and `currencies` are small; they are read once and cached. With
/// no `regions` at all everything behaves exactly as before regions existed.
class RegionService {
  RegionService._();

  // Always the app's own Firestore instance (named database, see main.dart).
  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static const String regionsCollection = 'regions';
  static const String zoneCollection = 'zone';

  static final Map<String, RegionModel> _regions = {};
  static final Map<String, CurrencyModel> _currencies = {};
  static final Map<String, String?> _zoneRegionIds = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  /// The globally active currency (`currencies.isActive == true`), fallback only.
  static CurrencyModel? globalCurrency;

  /// Region of the signed-in provider, once known.
  static String? providerRegionId;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (force) _loading = null;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    try {
      final results = await Future.wait([_db.collection(regionsCollection).get(), _db.collection(Currency).get()]);
      _regions.clear();
      for (final doc in results[0].docs) {
        final region = RegionModel.fromJson(doc.data(), docId: doc.id);
        if (region.id != null) _regions[region.id!] = region;
      }
      _currencies.clear();
      CurrencyModel? active;
      for (final doc in results[1].docs) {
        final data = doc.data();
        final currency = parseCurrency(data, docId: doc.id);
        _currencies[doc.id] = currency;
        if (currency.id != null && currency.id!.isNotEmpty && currency.id != doc.id) _currencies[currency.id!] = currency;
        if (data['isActive'] == true) active ??= currency;
      }
      globalCurrency ??= active;
      _loaded = true;
    } catch (e, s) {
      log("RegionService load failed: $e", stackTrace: s);
      _loading = null; // allow a retry later
    }
  }

  /// Parses a `currencies` row tolerantly (`decimal_degits` or `decimalDigits`,
  /// numbers stored as strings, missing booleans).
  static CurrencyModel parseCurrency(Map<String, dynamic> data, {String? docId}) {
    final dynamic digits = data['decimal_degits'] ?? data['decimalDigits'];
    final String id = (data['id']?.toString().isNotEmpty == true) ? data['id'].toString() : (docId ?? '');
    return CurrencyModel(
      id: id,
      code: data['code']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      symbol: data['symbol']?.toString() ?? '',
      symbolatright: data['symbolAtRight'] == true,
      isactive: data['isActive'] == true,
      decimal: digits is num ? digits.toInt() : int.tryParse(digits?.toString() ?? '') ?? 2,
      rounding: data['rounding'] is num ? data['rounding'] : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Regions
  // ---------------------------------------------------------------------------

  static bool get hasRegions => _regions.isNotEmpty;

  /// All regions, sorted by name.
  static List<RegionModel> get regions {
    final list = _regions.values.toList();
    list.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    return list;
  }

  static RegionModel? regionById(String? regionId) => (regionId == null || regionId.isEmpty) ? null : _regions[regionId];

  /// Region a zone resolves to: its `regionIds` when it holds exactly one entry
  /// (legacy `regionId` when `regionIds` is absent), else null. Cached.
  static Future<String?> regionIdForZone(String? zoneId) async {
    if (zoneId == null || zoneId.isEmpty) return null;
    if (_zoneRegionIds.containsKey(zoneId)) return _zoneRegionIds[zoneId];
    try {
      final doc = await _db.collection(zoneCollection).doc(zoneId).get();
      final data = doc.data();
      String? value;
      if (data != null) {
        if (data['regionIds'] is Iterable) {
          final ids = toIdList(data['regionIds']);
          value = ids.length == 1 ? ids.first : null;
        } else {
          final legacy = data['regionId']?.toString();
          value = (legacy == null || legacy.isEmpty) ? null : legacy;
        }
      }
      _zoneRegionIds[zoneId] = value;
    } catch (e) {
      log("RegionService zone lookup failed: $e");
      return null;
    }
    return _zoneRegionIds[zoneId];
  }

  /// regionOf(provider): own `regionId`, else its zone (single region), else null.
  static Future<String?> resolveUserRegionId(User? user) async {
    if (user == null) return null;
    if (user.regionId != null && user.regionId!.isNotEmpty) return user.regionId;
    return regionIdForZone(user.zoneId);
  }

  // ---------------------------------------------------------------------------
  // Currency
  // ---------------------------------------------------------------------------

  /// Currency configured for [regionId]; null when unknown / not configured.
  static CurrencyModel? currencyForRegion(String? regionId) {
    final region = regionById(regionId);
    if (region == null || region.currencyId == null || region.currencyId!.isEmpty) return null;
    return _currencies[region.currencyId!];
  }

  /// The provider's region currency, or null when the provider has none.
  static CurrencyModel? get providerCurrency => currencyForRegion(providerRegionId);

  /// Currency of live amounts: the provider's region, else the global one.
  static CurrencyModel? get liveCurrency => providerCurrency ?? globalCurrency ?? currencyData;

  /// Currency a booking (or its receipt / wallet rows) was charged in: the
  /// booking's own region, else the provider's, else global.
  static CurrencyModel? currencyForBooking(String? bookingRegionId) => currencyForRegion(bookingRegionId) ?? liveCurrency;

  /// Resolves the provider's region and points [currencyData] (used by every
  /// live amount) at that region's currency. Safe to call repeatedly.
  static Future<void> apply(User? user) async {
    await ensureLoaded();
    providerRegionId = await resolveUserRegionId(user);
    _applyToGlobal();
  }

  /// Called when the globally active currency has been read at start-up.
  static void onGlobalCurrency(CurrencyModel currency) {
    globalCurrency = currency;
    _applyToGlobal();
  }

  static void _applyToGlobal() {
    final currency = providerCurrency ?? globalCurrency;
    if (currency != null) currencyData = currency;
  }

  /// Forget the provider region (sign-out).
  static void clearProvider() {
    providerRegionId = null;
    if (globalCurrency != null) currencyData = globalCurrency;
  }

  // ---------------------------------------------------------------------------
  // "regionIds" availability (payment gateways)
  // ---------------------------------------------------------------------------

  /// Empty or absent [regionIds] = available everywhere; otherwise only in the
  /// listed regions. When the region is unknown nothing is hidden.
  static bool isAvailableInRegion(dynamic regionIds, String? regionId) {
    final ids = toIdList(regionIds);
    if (ids.isEmpty) return true;
    if (regionId == null || regionId.isEmpty) return true;
    return ids.contains(regionId);
  }

  static List<String> toIdList(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static final Map<String, List<String>> _gatewayRegionIds = {};

  /// Gateway settings documents that may carry `regionIds` (spec 18.7).
  static const List<String> gatewayDocs = [
    "stripeSettings",
    "CODSettings",
    "razorpaySettings",
    "paypalSettings",
    "walletSettings",
    "payFastSettings",
    "payStack",
    "flutterWave",
    "MercadoPago",
    "orange_money_settings",
    "xendit_settings",
    "midtrans_settings",
    "PaytmSettings",
  ];

  /// Reads `regionIds` of every gateway settings doc (the gateway models do
  /// not keep unknown fields).
  static Future<void> loadGatewayRegionIds() async {
    try {
      final docs = await Future.wait(gatewayDocs.map((name) => _db.collection(Setting).doc(name).get()));
      for (final doc in docs) {
        _gatewayRegionIds[doc.id] = toIdList(doc.data()?['regionIds']);
      }
    } catch (e) {
      log("RegionService gateway regions failed: $e");
    }
  }

  /// Whether the gateway stored in settings/[docName] is offered in [regionId].
  static bool isGatewayAvailable(String docName, String? regionId) => isAvailableInRegion(_gatewayRegionIds[docName], regionId);

  // ---------------------------------------------------------------------------
  // Booking regions for booking-based wallet rows
  // ---------------------------------------------------------------------------

  /// `provider_orders/{id}.regionId` for [orderIds]. No reads when no region
  /// exists.
  static Future<Map<String, String>> bookingRegionIds(Iterable<String> orderIds) async {
    final Map<String, String> result = {};
    if (!hasRegions) return result;
    final ids = orderIds.where((e) => e.isNotEmpty && e != 'null').toSet().toList();
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snap = await _db.collection(PROVIDER_ORDER).where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          final regionId = doc.data()['regionId']?.toString();
          if (regionId != null && regionId.isNotEmpty) result[doc.id] = regionId;
        }
      } catch (e) {
        log("RegionService booking regions failed: $e");
      }
    }
    return result;
  }
}
