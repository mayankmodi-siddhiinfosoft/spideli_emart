import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/region_model.dart';
import 'package:vendor/models/vendor_model.dart';

/// Everything region-related, in one place, matching the store panel.
///
/// * Region of a store: `vendors.regionId`, else the region of its zone
///   (`zone/{zoneId}.regionId`), else none.
/// * Live amounts (products, the store's prices, wallet, payouts, plans) use
///   the current store's region currency: `regions/{id}.currencyId` ->
///   `currencies/{id}`, falling back to the globally active currency.
/// * Order amounts use the order's own `regionId` (the currency it was charged
///   in), falling back to the store currency, then the global one.
///
/// `regions` and `currencies` are small collections; they are read once and
/// kept in memory. When the `regions` collection is empty everything behaves
/// exactly as before regions existed.
class RegionService {
  RegionService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static final Map<String, RegionModel> _regions = {};
  static final Map<String, CurrencyModel> _currencies = {};
  static final Map<String, String?> _zoneRegionIds = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  /// The globally active currency (`currencies.isActive == true`). Only a
  /// fallback now.
  static CurrencyModel? globalCurrency;

  /// Region of the store this session is working on, once known.
  static String? storeRegionId;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Loads `regions` and `currencies` once. Safe to call concurrently.
  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (force) _loading = null;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    try {
      final results = await Future.wait([_db.collection(CollectionName.regions).get(), _db.collection(CollectionName.currencies).get()]);
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
        if (currency.id != null && currency.id != doc.id) _currencies[currency.id!] = currency;
        // Parsed exactly like GlobalSettingController does, so a store without
        // a region shows precisely what it showed before regions existed.
        if (data['isActive'] == true) active ??= CurrencyModel.fromJson(data);
      }
      globalCurrency ??= active;
      _loaded = true;
    } catch (e, s) {
      log("RegionService load failed: $e", stackTrace: s);
      _loading = null; // allow a retry later
    }
  }

  /// Parses a `currencies` row, tolerating both `decimalDigits` and the
  /// panel's `decimal_degits` spelling.
  static CurrencyModel parseCurrency(Map<String, dynamic> data, {String? docId}) {
    final currency = CurrencyModel.fromJson(data);
    if (data['decimalDigits'] == null && data['decimal_degits'] != null) {
      currency.decimalDigits = int.tryParse(data['decimal_degits'].toString()) ?? 2;
    }
    if (currency.id == null || currency.id!.isEmpty) currency.id = docId;
    return currency;
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

  /// `zone/{zoneId}.regionId`, cached. Null when the zone has no region.
  static Future<String?> regionIdForZone(String? zoneId) async {
    if (zoneId == null || zoneId.isEmpty) return null;
    if (_zoneRegionIds.containsKey(zoneId)) return _zoneRegionIds[zoneId];
    try {
      final doc = await _db.collection(CollectionName.zone).doc(zoneId).get();
      final value = doc.data()?['regionId']?.toString();
      _zoneRegionIds[zoneId] = (value == null || value.isEmpty) ? null : value;
    } catch (e) {
      log("RegionService zone lookup failed: $e");
      return null;
    }
    return _zoneRegionIds[zoneId];
  }

  /// The admin-panel resolution order: (1) store.regionId, (2) store.zoneId ->
  /// zone.regionId, (3) none.
  static Future<String?> resolveStoreRegionId(VendorModel? vendor) async {
    if (vendor == null) return null;
    if (vendor.regionId != null && vendor.regionId!.isNotEmpty) return vendor.regionId;
    return regionIdForZone(vendor.zoneId);
  }

  // ---------------------------------------------------------------------------
  // Currency
  // ---------------------------------------------------------------------------

  /// Currency configured for [regionId], from the preloaded cache. Null when
  /// the region is unknown or has no currency (normal for old records).
  static CurrencyModel? currencyForRegion(String? regionId) {
    final region = regionById(regionId);
    if (region == null || region.currencyId == null || region.currencyId!.isEmpty) return null;
    return _currencies[region.currencyId!];
  }

  /// Current store's currency, or null when the store has no regional one.
  static CurrencyModel? get storeCurrency => currencyForRegion(storeRegionId);

  /// Currency for live amounts: store currency, else the global one.
  static CurrencyModel? get liveCurrency => storeCurrency ?? globalCurrency ?? Constant.currencyModel;

  /// Currency an order (or payment / receipt / order-based wallet row) was
  /// charged in: the order's own region, else the store, else global.
  static CurrencyModel? currencyForOrder(String? orderRegionId) => currencyForRegion(orderRegionId) ?? liveCurrency;

  /// Resolves the store's region and points `Constant.currencyModel` (used by
  /// every live amount) at the store's currency.
  static Future<void> applyStore(VendorModel? vendor) async {
    await ensureLoaded();
    storeRegionId = await resolveStoreRegionId(vendor);
    _applyToConstant();
  }

  /// Called when the globally active currency changes.
  static void onGlobalCurrency(CurrencyModel currency) {
    globalCurrency = currency;
    _applyToConstant();
  }

  static void _applyToConstant() {
    final currency = storeCurrency ?? globalCurrency;
    if (currency != null) Constant.currencyModel = currency;
  }

  // ---------------------------------------------------------------------------
  // "regionIds" availability (payment gateways, sections)
  // ---------------------------------------------------------------------------

  /// Empty or absent [regionIds] = available everywhere; otherwise only in the
  /// listed regions. When the region is not known (no store yet / store
  /// without region) nothing is hidden, so behaviour matches pre-region.
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

  /// Settings documents of the payment gateways that may carry `regionIds`.
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

  /// Reads `regionIds` of every gateway settings doc (alongside the app's
  /// existing settings parsing, which does not keep unknown fields).
  static Future<void> loadGatewayRegionIds() async {
    try {
      final docs = await Future.wait(gatewayDocs.map((name) => _db.collection(CollectionName.settings).doc(name).get()));
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
  // Delivery charge (settings/DeliveryCharge, optional per-region overrides)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _deliveryChargeDoc;

  /// Reads settings/DeliveryCharge (one read) and returns the figures for
  /// [regionId]. Later region changes can use [deliveryChargeForRegion].
  static Future<DeliveryCharge?> getDeliveryCharge(String? regionId) async {
    try {
      final doc = await _db.collection(CollectionName.settings).doc("DeliveryCharge").get();
      _deliveryChargeDoc = doc.data();
    } catch (e) {
      log("RegionService delivery charge failed: $e");
    }
    return deliveryChargeForRegion(regionId);
  }

  /// `regions[regionId]` when present, else the top-level (global) figures.
  static DeliveryCharge? deliveryChargeForRegion(String? regionId) {
    final data = _deliveryChargeDoc;
    if (data == null) return null;
    final Map<String, dynamic> global = Map<String, dynamic>.from(data)..remove('regions');
    final regional = data['regions'];
    if (regionId != null && regionId.isNotEmpty && regional is Map && regional[regionId] is Map) {
      return DeliveryCharge.fromJson({...global, ...Map<String, dynamic>.from(regional[regionId] as Map)});
    }
    return DeliveryCharge.fromJson(global);
  }

  // ---------------------------------------------------------------------------
  // Order regions for order-based wallet rows
  // ---------------------------------------------------------------------------

  /// `vendor_orders/{id}.regionId` for [orderIds]. Skipped entirely (no reads)
  /// when no regions exist.
  static Future<Map<String, String>> orderRegionIds(Iterable<String> orderIds) async {
    final Map<String, String> result = {};
    if (!hasRegions) return result;
    final ids = orderIds.where((e) => e.isNotEmpty && e != 'null').toSet().toList();
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snap = await _db.collection(CollectionName.vendorOrders).where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          final regionId = doc.data()['regionId']?.toString();
          if (regionId != null && regionId.isNotEmpty) result[doc.id] = regionId;
        }
      } catch (e) {
        log("RegionService order regions failed: $e");
      }
    }
    return result;
  }
}
