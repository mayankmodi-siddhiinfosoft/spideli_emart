import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/currency_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Regions (management zones) and currency, per the Spideli app contract.
///
/// * Region of the driver: `users.regionId`, else the region of the driver's
///   zone when that zone serves exactly ONE region (`zone.regionIds`, legacy
///   `zone.regionId` when `regionIds` is absent), else none (= global).
/// * Live amounts (fares being quoted, wallet balance, minimum deposit) use the
///   driver's region currency: `regions/{id}.currencyId` -> `currencies/{id}`,
///   falling back to the globally active currency.
/// * History amounts (rides, rentals, parcels, orders) use the record's OWN
///   `regionId`, falling back to the live currency.
///
/// `regions` and `currencies` are small collections, read once and cached.
/// With an empty `regions` collection everything behaves as before regions.
class RegionService {
  RegionService._();

  // Always the app's own Firestore instance (see FireStoreUtils.init).
  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static final Map<String, RegionModel> _regions = {};
  static final Map<String, CurrencyModel> _currencies = {};
  static final Map<String, String?> _zoneRegionIds = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  /// Globally active currency (`currencies.isActive == true`) - fallback only.
  static CurrencyModel? globalCurrency;

  /// Resolved region of the signed-in driver (explicit or via its zone).
  static String? driverRegionId;

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
      final results = await Future.wait([_db.collection(CollectionName.regions).get(), _db.collection(CollectionName.currencies).get()]);
      _regions.clear();
      for (final doc in results[0].docs) {
        final region = RegionModel.fromJson(doc.data(), docId: doc.id);
        if (region.id != null) _regions[region.id!] = region;
      }
      _currencies.clear();
      for (final doc in results[1].docs) {
        final currency = parseCurrency(doc.data(), docId: doc.id);
        _currencies[doc.id] = currency;
        if (currency.id != null && currency.id != doc.id) _currencies[currency.id!] = currency;
      }
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

  static List<String> toIdList(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  /// Region of a zone: its `regionIds` when it has exactly one entry (legacy
  /// `regionId` when `regionIds` is absent). Null for a shared zone or none.
  static Future<String?> regionIdForZone(String? zoneId) async {
    if (zoneId == null || zoneId.isEmpty) return null;
    if (_zoneRegionIds.containsKey(zoneId)) return _zoneRegionIds[zoneId];
    try {
      final doc = await _db.collection(CollectionName.zone).doc(zoneId).get();
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

  /// regionOf(user): `users.regionId`, else its zone (single-region only).
  static Future<String?> resolveUserRegionId(UserModel? user) async {
    if (user == null) return null;
    if (user.regionId != null && user.regionId!.isNotEmpty) return user.regionId;
    return regionIdForZone(user.zoneId);
  }

  /// Zone-bound dispatch (spec 9.1): true only when BOTH the record and the
  /// driver carry an explicit region and they differ. Records without a
  /// `regionId`, and drivers without one, behave exactly as before.
  static bool isOutOfDriverRegion(String? recordRegionId, {UserModel? driver}) {
    final String? mine = (driver ?? Constant.userModel)?.regionId;
    if (mine == null || mine.isEmpty) return false;
    if (recordRegionId == null || recordRegionId.isEmpty) return false;
    return recordRegionId != mine;
  }

  /// Region to stamp on a ride / rental the driver accepts (spec 18.12).
  static Future<String?> regionIdToStamp(UserModel? driver) async {
    final explicit = driver?.regionId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (driverRegionId != null && driverRegionId!.isNotEmpty && driver?.id == Constant.userModel?.id) return driverRegionId;
    return resolveUserRegionId(driver);
  }

  // ---------------------------------------------------------------------------
  // Currency
  // ---------------------------------------------------------------------------

  /// Currency configured for [regionId]. Null when unknown (normal for records
  /// created before regions existed).
  static CurrencyModel? currencyForRegion(String? regionId) {
    final region = regionById(regionId);
    if (region == null || region.currencyId == null || region.currencyId!.isEmpty) return null;
    return _currencies[region.currencyId!];
  }

  /// Currency for live amounts: the driver's region, else the global one.
  static CurrencyModel? get liveCurrency => currencyForRegion(driverRegionId) ?? globalCurrency ?? Constant.currencyModel;

  /// Currency a record (ride, rental, parcel, order) was charged in: its own
  /// region, else the live currency.
  static CurrencyModel? currencyForRecord(String? recordRegionId) => currencyForRegion(recordRegionId) ?? liveCurrency;

  /// Resolves the driver's region and points `Constant.currencyModel` (used by
  /// every live amount) at that region's currency.
  static Future<void> applyDriver(UserModel? driver) async {
    await ensureLoaded();
    driverRegionId = await resolveUserRegionId(driver);
    _applyToConstant();
  }

  /// Called whenever the globally active currency is (re)read.
  static void onGlobalCurrency(CurrencyModel currency) {
    globalCurrency = currency;
    _applyToConstant();
  }

  static void _applyToConstant() {
    final currency = currencyForRegion(driverRegionId) ?? globalCurrency;
    if (currency != null) Constant.currencyModel = currency;
  }
}
