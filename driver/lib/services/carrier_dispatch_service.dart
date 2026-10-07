import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Carrier-bound dispatch — admin spec §11 ("Carriers (delivery companies)").
///
/// An order that names a carrier (`carrierId`) is work of that delivery
/// company, so it must only be offered to the drivers registered under it.
/// The client's own way out of the "a carrier has no login and no device
/// token" blocker: *"companies deliver like individual deliver"* — a company
/// is an **owner of drivers**, and those drivers already have the app.
///
/// **Everything here is tolerant and additive.** An order without a
/// `carrierId` is never touched. A carrier order is hidden only when the data
/// actually says who the carrier's drivers are; when nothing links a carrier
/// to a driver the order stays visible to everyone exactly as today.
///
/// Links understood, in the order they are looked for:
///   1. the driver's own `users.carrierId` (an explicit membership),
///   2. `delivery_carriers/{id}.driverIds` (`userIds` / `driverIDs` / `drivers`
///      / `memberIds`) containing the driver **or its owner**,
///   3. `delivery_carriers/{id}.ownerId` (`userId` / `ownerUserId` /
///      `companyId` / `driverId`) equal to the driver, its owner, or the
///      signed-in owner account itself.
class CarrierDispatchService {
  CarrierDispatchService._();

  /// Admin spec §11. Not in [CollectionName] because nothing else reads it.
  static const String collectionName = 'delivery_carriers';

  static final Map<String, _CarrierLink> _cache = {};

  /// Forgets the cached carrier documents (sign-out / a pull to refresh).
  static void clearCache() => _cache.clear();

  /// True when [driver] may be offered an order carried by [carrierId].
  ///
  /// True for every order without a carrier, and true — by design — whenever
  /// the platform data carries no carrier→driver link at all.
  static Future<bool> driverServesCarrier(String? carrierId, UserModel? driver) async {
    final String id = (carrierId ?? '').trim();
    if (id.isEmpty) return true; // no carrier: today's behaviour, untouched.
    if (driver == null) return true;

    final String myCarrierId = (driver.carrierId ?? '').trim();
    if (myCarrierId.isNotEmpty && myCarrierId == id) return true;

    final _CarrierLink link = await _link(id);
    if (!link.isReadable) return true; // unknown carrier doc: never hide work.

    final Set<String> mine = _driverIdentities(driver);
    if (link.matches(mine)) return true;

    // No link anywhere in the data (neither on the carrier nor on the driver):
    // carriers are stored but unassigned, so behave exactly as before §11.
    if (!link.hasLink && myCarrierId.isEmpty) return true;

    return false;
  }

  /// Every id this driver can be named by on a carrier: itself, the uid it is
  /// signed in with, and the owner (company account) it drives for.
  static Set<String> _driverIdentities(UserModel driver) {
    final Set<String> ids = {};
    void add(String? value) {
      final String v = (value ?? '').trim();
      if (v.isNotEmpty) ids.add(v);
    }

    add(driver.id);
    add(driver.ownerId);
    final String uid = FireStoreUtils.getCurrentUid();
    if (driver.id == null || driver.id == uid) add(uid);
    return ids;
  }

  // ── The company's own carrier document (client point 18) ────────────────

  /// The `delivery_carriers` row this company account is linked to, or null
  /// when the panel has not linked one yet.
  ///
  /// Looked up exactly the way dispatch resolves membership:
  ///   1. `users/{uid}.carrierId` (the explicit link),
  ///   2. a carrier whose owner field names this account.
  static Future<DeliveryCarrierModel?> myCarrier({UserModel? user}) async {
    final UserModel? me = user ?? Constant.userModel;
    final String uid = FireStoreUtils.getCurrentUid();
    final String explicit = (me?.carrierId ?? '').trim();

    try {
      if (explicit.isNotEmpty) {
        final snap = await FireStoreUtils.fireStore.collection(collectionName).doc(explicit).get();
        if (snap.exists && snap.data() != null) {
          return DeliveryCarrierModel(id: snap.id, raw: Map<String, dynamic>.from(snap.data()!));
        }
      }
      final Set<String> identities = {uid, me?.id ?? '', me?.ownerId ?? ''}..removeWhere((e) => e.isEmpty);
      if (identities.isEmpty) return null;
      for (final field in const ['ownerId', 'userId', 'ownerUserId', 'companyId', 'driverId']) {
        for (final identity in identities) {
          final q = await FireStoreUtils.fireStore.collection(collectionName).where(field, isEqualTo: identity).limit(1).get();
          if (q.docs.isNotEmpty) {
            return DeliveryCarrierModel(id: q.docs.first.id, raw: Map<String, dynamic>.from(q.docs.first.data()));
          }
        }
      }
    } catch (e) {
      log("CarrierDispatchService.myCarrier failed: $e");
    }
    return null;
  }

  /// Saves the commercial settings a carrier maintains itself.
  ///
  /// [changes] holds only the fields the company actually changed, already
  /// typed (numbers as `num`, an emptied number as `null`). Anything outside
  /// [DeliveryCarrierModel.editableFields] is dropped, so the verification
  /// flag, the code, the regions and the identification documents — all the
  /// admin's — can never be written from here. Known-fields merge: every other
  /// field of the document is left exactly as the panel stored it.
  ///
  /// [regionChanges] (report Doc 43): regionId -> {charge -> value} for a
  /// carrier priced per region, merged into `regionPricing` field by field
  /// ([DeliveryCarrierModel.regionPricingUpdate]); the first region is
  /// mirrored to the flat charges, as the panel does.
  static Future<bool> saveCarrierSettings(DeliveryCarrierModel carrier, Map<String, dynamic> changes, {Map<String, Map<String, num?>> regionChanges = const {}}) async {
    final Map<String, dynamic> data = {
      for (final entry in changes.entries)
        if (DeliveryCarrierModel.editableFields.contains(entry.key)) entry.key: entry.value,
    };
    final List<List<String>> paths = [for (final key in data.keys) [key]];
    final regional = carrier.regionPricingUpdate(regionChanges);
    data.addAll(regional.data);
    for (final path in regional.paths) {
      if (!paths.any((p) => p.join('\u0000') == path.join('\u0000'))) paths.add(path);
    }
    if (data.isEmpty) return true;
    try {
      await FireStoreUtils.fireStore
          .collection(collectionName)
          .doc(carrier.id)
          .set(data, SetOptions(mergeFields: paths.map((p) => FieldPath(p)).toList()));
      _cache.remove(carrier.id);
      return true;
    } catch (e) {
      log("CarrierDispatchService.saveCarrierSettings failed: $e");
      return false;
    }
  }

  static Future<_CarrierLink> _link(String carrierId) async {
    final cached = _cache[carrierId];
    if (cached != null) return cached;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(collectionName).doc(carrierId).get();
      final _CarrierLink link = snap.exists && snap.data() != null ? _CarrierLink.fromJson(snap.data()!) : const _CarrierLink.unreadable();
      _cache[carrierId] = link;
      return link;
    } catch (e) {
      log("CarrierDispatchService: carrier $carrierId unreadable ($e)");
      return const _CarrierLink.unreadable();
    }
  }
}

/// The owner / driver ids a `delivery_carriers` document names, read
/// tolerantly: the panel does not write any of them yet (§11), so every
/// spelling is accepted and an empty result means "no link".
class _CarrierLink {
  final Set<String> ownerIds;
  final Set<String> driverIds;
  final bool isReadable;

  const _CarrierLink({this.ownerIds = const {}, this.driverIds = const {}}) : isReadable = true;

  const _CarrierLink.unreadable() : ownerIds = const {}, driverIds = const {}, isReadable = false;

  bool get hasLink => ownerIds.isNotEmpty || driverIds.isNotEmpty;

  bool matches(Set<String> candidates) {
    if (candidates.isEmpty) return false;
    return candidates.any((id) => ownerIds.contains(id) || driverIds.contains(id));
  }

  factory _CarrierLink.fromJson(Map<String, dynamic> json) {
    final Set<String> owners = {};
    final Set<String> drivers = {};
    for (final key in const ['ownerId', 'userId', 'ownerUserId', 'companyId', 'authorId', 'author']) {
      owners.addAll(_ids(json[key]));
    }
    for (final key in const ['ownerIds', 'userIds', 'owners']) {
      owners.addAll(_ids(json[key]));
    }
    for (final key in const ['driverId', 'driverIds', 'driverIDs', 'drivers', 'memberIds', 'members']) {
      drivers.addAll(_ids(json[key]));
    }
    return _CarrierLink(ownerIds: owners, driverIds: drivers);
  }

  static Iterable<String> _ids(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      final String v = value.trim();
      return v.isEmpty ? const [] : [v];
    }
    if (value is Iterable) {
      return value.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty);
    }
    if (value is Map) {
      // `{uid: true}` style membership maps.
      return value.entries.where((e) => e.value != false).map((e) => e.key.toString().trim()).where((e) => e.isNotEmpty);
    }
    return const [];
  }
}
