import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';

/// Shipment scope as stored on `parcel_orders.scope` (parcel contract §5).
class ParcelScope {
  ParcelScope._();

  static const String city = 'city';
  static const String intercity = 'intercity';
  static const String intercountry = 'intercountry';

  /// A parcel that ENDS somewhere other than where it starts.
  static bool isCrossRegion(String? scope) => scope == intercity || scope == intercountry;
}

/// Who a parcel job may be offered to — the two rules the panels cannot apply
/// themselves (admin spec §11 carriers, §12 pickup points).
///
/// 1. **Region.** A same-city parcel keeps today's rule exactly: a driver only
///    sees requests of its own region. An intercity / intercountry parcel
///    starts in one region and ends in another, so it is offered to drivers of
///    the **origin region and the destination region**. The destination region
///    is resolved tolerantly — by the destination pickup point (§12) first,
///    then by the destination city / country matched through [RegionService] —
///    and when it cannot be resolved the parcel falls back to today's rule.
/// 2. **Carrier.** See [CarrierDispatchService].
class ParcelDispatchService {
  ParcelDispatchService._();

  /// `pickup_points/{id}` -> the region ids that point belongs to. Cached for
  /// the session; a point that cannot be read caches an empty set so a broken
  /// id is never re-fetched per list item.
  static final Map<String, Set<String>> _pickupPointRegions = {};

  static void clearCache() {
    _pickupPointRegions.clear();
    CarrierDispatchService.clearCache();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Region
  // ───────────────────────────────────────────────────────────────────────

  /// Scope-aware replacement for `RegionService.isOutOfDriverRegion` on a
  /// parcel order. `data` is the raw `parcel_orders` document.
  ///
  /// Returns false (= keep the job) whenever today's rule already kept it, so
  /// this can only ever widen what a driver sees.
  static Future<bool> isOutOfDriverRegion(Map<String, dynamic> data, {required UserModel? driver}) async {
    final String? orderRegionId = data['regionId']?.toString();
    if (!RegionService.isOutOfDriverRegion(orderRegionId, driver: driver)) return false;

    // Out of the driver's region by the origin. Only a parcel that ends in
    // another region can still be theirs.
    if (!ParcelScope.isCrossRegion(data['scope']?.toString())) return true;

    final String? mine = driver?.regionId;
    if (mine == null || mine.isEmpty) return true; // unreachable: guarded above.

    final Set<String> destination = await destinationRegionIds(data);
    if (destination.isEmpty) return true; // unresolved -> today's behaviour.
    return !destination.contains(mine);
  }

  /// Convenience overload for a parsed order.
  static Future<bool> isOrderOutOfDriverRegion(ParcelOrderModel order, {required UserModel? driver}) {
    return isOutOfDriverRegion({
      'regionId': order.regionId,
      'scope': order.scope,
      'destinationPickupPointId': order.destinationPickupPointId,
      'destination': order.destination,
      'receiverZoneId': order.receiverZoneId,
    }, driver: driver);
  }

  /// The region(s) an intercity / intercountry parcel ends in. Empty when the
  /// data does not say — the caller then keeps today's behaviour.
  static Future<Set<String>> destinationRegionIds(Map<String, dynamic> data) async {
    // 1. The destination pickup point carries the region outright (§12).
    final String pointId = (data['destinationPickupPointId'] ?? '').toString().trim();
    if (pointId.isNotEmpty) {
      final Set<String> fromPoint = await _regionIdsOfPickupPoint(pointId);
      if (fromPoint.isNotEmpty) return fromPoint;
    }

    await RegionService.ensureLoaded();
    final List<RegionModel> regions = RegionService.regions;
    if (regions.isEmpty) return const {};

    final dynamic destination = data['destination'];
    if (destination is! Map) return const {};
    final String city = (destination['city'] ?? '').toString().trim();
    final String country = (destination['country'] ?? '').toString().trim();
    final String countryCode = (destination['countryCode'] ?? '').toString().trim();

    // 2. A region named after the destination city (city-scoped regions).
    final Set<String> byCity = _idsWhere(regions, (r) => _eq(r.name, city));
    if (byCity.isNotEmpty) return byCity;

    // 3. The destination country. `countryCode` only — a region's `code` is a
    //    free-text label and must never be matched on (admin spec §1).
    final Set<String> byCountryCode = _idsWhere(regions, (r) => r.isInCountry(countryCode));
    if (byCountryCode.isNotEmpty) return byCountryCode;

    return _idsWhere(regions, (r) => _eq(r.name, country));
  }

  /// `pickup_points/{id}` read tolerantly: the admin writes `regionId`
  /// (string), older / other writers may use `regionIds` (array).
  static Future<Set<String>> _regionIdsOfPickupPoint(String pointId) async {
    final cached = _pickupPointRegions[pointId];
    if (cached != null) return cached;
    Set<String> result = {};
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(CollectionName.pickupPoints).doc(pointId).get();
      final Map<String, dynamic>? point = snap.data();
      if (point != null) {
        result = {...RegionService.toIdList(point['regionIds']), ...RegionService.toIdList([point['regionId']])};
      }
    } catch (e) {
      log("ParcelDispatchService: pickup point $pointId unreadable ($e)");
    }
    _pickupPointRegions[pointId] = result;
    return result;
  }

  static Set<String> _idsWhere(List<RegionModel> regions, bool Function(RegionModel) test) {
    return regions.where(test).map((r) => r.id ?? '').where((id) => id.isNotEmpty).toSet();
  }

  static bool _eq(String? a, String b) {
    final String left = (a ?? '').trim().toLowerCase();
    final String right = b.trim().toLowerCase();
    return left.isNotEmpty && left == right;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Carrier + region together
  // ───────────────────────────────────────────────────────────────────────

  /// The two new gates in one call, for a raw `parcel_orders` document.
  /// True = this driver may be offered the job.
  static Future<bool> isOfferable(Map<String, dynamic> data, {required UserModel? driver}) async {
    if (await isOutOfDriverRegion(data, driver: driver)) return false;
    return CarrierDispatchService.driverServesCarrier(data['carrierId']?.toString(), driver);
  }
}
