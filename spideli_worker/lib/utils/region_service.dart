import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/currency_model.dart';
import 'package:spideliworker/model/region_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';

/// Regions (management zones) and their currencies for the Worker app.
/// Ported from the Store app's RegionService (spec 18.4 / 18.5).
///
/// * The worker's region: `providers_workers/{uid}.regionId`, else
///   `users/{uid}.regionId`, else none.
/// * Bookings are history: their amounts use the booking's OWN `regionId`
///   currency (`regions/{id}.currencyId` -> `currencies/{id}`), falling back
///   to the global active currency (`currencyData`, today's behaviour).
///
/// When the `regions` collection is empty, or a record has no region,
/// everything behaves exactly as before regions existed.
class RegionService {
  RegionService._();

  // The app may run on a named Firestore database (see main.dart), so always
  // go through FireStoreUtils.firestore -- never FirebaseFirestore.instance.
  static FirebaseFirestore get _db => FireStoreUtils.firestore;

  static final Map<String, RegionModel> _regions = {};
  static final Map<String, CurrencyModel> _currencies = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  /// Region of the signed-in worker, once known. Null = no region (every job
  /// is shown, today's behaviour).
  static String? workerRegionId;

  /// Loads `regions` and `currencies` once. Safe to call concurrently.
  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (force) _loading = null;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    try {
      final results = await Future.wait([_db.collection(REGIONS).get(), _db.collection(Currency).get()]);
      _regions.clear();
      for (final doc in results[0].docs) {
        final region = RegionModel.fromJson(doc.data(), docId: doc.id);
        if (region.id != null) _regions[region.id!] = region;
      }
      _currencies.clear();
      for (final doc in results[1].docs) {
        final currency = parseCurrency(doc.data(), docId: doc.id);
        _currencies[doc.id] = currency;
        if (currency.id != null && currency.id!.isNotEmpty && currency.id != doc.id) _currencies[currency.id!] = currency;
      }
      _loaded = true;
    } catch (e, s) {
      log("RegionService load failed: $e", stackTrace: s);
      _loading = null; // allow a retry later
    }
  }

  /// Parses a `currencies` row, tolerating both `decimal_degits` (panel) and
  /// `decimalDigits`, and numbers stored as strings.
  static CurrencyModel parseCurrency(Map<String, dynamic> data, {String? docId}) {
    final dynamic digits = data['decimal_degits'] ?? data['decimalDigits'];
    return CurrencyModel(
      code: data['code']?.toString() ?? '',
      decimal: digits is int ? digits : int.tryParse(digits?.toString() ?? '') ?? 2,
      isactive: data['isActive'] == true,
      id: (data['id']?.toString().isNotEmpty == true) ? data['id'].toString() : (docId ?? ''),
      name: data['name']?.toString() ?? '',
      rounding: data['rounding'] is num ? data['rounding'] : 0,
      symbol: data['symbol']?.toString() ?? '',
      symbolatright: data['symbolAtRight'] == true,
    );
  }

  static bool get hasRegions => _regions.isNotEmpty;

  static RegionModel? regionById(String? regionId) => (regionId == null || regionId.isEmpty) ? null : _regions[regionId];

  /// Resolves and remembers the worker's region: the `providers_workers` doc
  /// first ([workerDocRegionId]), then `users/{uid}.regionId`.
  static Future<String?> resolveWorkerRegion(String workerId, {String? workerDocRegionId}) async {
    String? regionId = (workerDocRegionId == null || workerDocRegionId.isEmpty) ? null : workerDocRegionId;
    if (regionId == null && workerId.isNotEmpty) {
      try {
        final value = (await _db.collection(USERS).doc(workerId).get()).data()?['regionId']?.toString();
        if (value != null && value.isNotEmpty) regionId = value;
      } catch (e) {
        log("RegionService worker region lookup failed: $e");
      }
    }
    workerRegionId = regionId;
    return regionId;
  }

  /// Zone-bound job reception (spec 11): a job carrying a `regionId` that
  /// differs from the worker's region is not shown. Either side absent =
  /// shown (today's behaviour).
  static bool isJobInWorkerRegion(String? jobRegionId) {
    if (jobRegionId == null || jobRegionId.isEmpty) return true;
    final worker = workerRegionId;
    if (worker == null || worker.isEmpty) return true;
    return jobRegionId == worker;
  }

  /// Currency configured for [regionId]. Null when the region is unknown or
  /// has no currency (normal for old records) -- `amountShow` then falls back
  /// to the global active currency.
  static CurrencyModel? currencyForRegion(String? regionId) {
    final region = regionById(regionId);
    if (region == null || region.currencyId == null || region.currencyId!.isEmpty) return null;
    return _currencies[region.currencyId!];
  }
}
