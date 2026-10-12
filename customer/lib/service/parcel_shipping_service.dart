import 'dart:developer';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/carrier_owner_link.dart';
import 'package:customer/utils/parcel_pricing.dart';
import 'package:intl/intl.dart';

/// Firestore access for parcel / mail shipping and tracking (PARCEL-CONTRACT).
/// Kept out of FireStoreUtils so the shared file stays untouched.
class ParcelShippingService {
  ParcelShippingService._();

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static CollectionReference<Map<String, dynamic>> get _orders => _db.collection(CollectionName.parcelOrders);

  // ---------------- configuration ----------------

  static Future<ParcelPricingSettings> pricingSettings() async {
    try {
      final doc = await _db.collection(CollectionName.settings).doc('ParcelPricing').get();
      return ParcelPricingSettings.fromJson(doc.data());
    } catch (e) {
      log('ParcelPricing not loaded: $e');
      return const ParcelPricingSettings();
    }
  }

  static Future<RegionParcelPricing> regionParcelPricing(String? regionId) async {
    if (regionId == null || regionId.isEmpty) return const RegionParcelPricing();
    try {
      final doc = await _db.collection('regions').doc(regionId).get();
      // A region the admin has not saved yet has no map: everything unset.
      return RegionParcelPricing.fromJson(doc.data()?['parcelPricing']);
    } catch (e) {
      log('region parcel pricing not loaded: $e');
      return const RegionParcelPricing();
    }
  }

  static Future<List<DeliveryCarrierModel>> carriers() async {
    try {
      final snap = await _db.collection('delivery_carriers').get();
      final List<DeliveryCarrierModel> list = [];
      for (final doc in snap.docs) {
        try {
          final c = DeliveryCarrierModel.fromJson(doc.id, doc.data());
          if (c.name.isNotEmpty) list.add(c);
        } catch (e) {
          log('carrier ${doc.id} not parsed: $e');
        }
      }
      return list;
    } catch (e) {
      log('delivery_carriers not loaded: $e');
      return [];
    }
  }

  /// The company account that manages carrier [carrierId]
  /// (`users/{companyId}.carrierId`, `.claude/COMPANY-CARRIER-LINK.md`),
  /// else the owner the carrier document names ([carrierDocOwnerId]);
  /// '' when nothing links one. Never throws.
  static Future<String> carrierOwnerId(String? carrierId, {String? carrierDocOwnerId}) async {
    final String id = (carrierId ?? '').trim();
    if (id.isEmpty) return (carrierDocOwnerId ?? '').trim();
    final List<(String, Map<String, dynamic>)> users = [];
    for (final String field in const ['carrierId', 'deliveryCarrierId']) {
      try {
        final snap = await _db.collection(CollectionName.users).where(field, isEqualTo: id).limit(20).get();
        users.addAll(snap.docs.map((d) => (d.id, d.data())));
      } catch (e) {
        log('carrier owner lookup by $field failed: $e');
      }
      final String owner = CarrierOwnerLink.pickOwner(id, users);
      if (owner.isNotEmpty) return owner;
    }
    return CarrierOwnerLink.pickOwner(id, users, carrierDocOwnerId: carrierDocOwnerId);
  }

  static List<PickupPointModel>? _pickupPoints;

  static Future<List<PickupPointModel>> pickupPoints({bool force = false}) async {
    if (_pickupPoints != null && !force) return _pickupPoints!;
    try {
      final snap = await _db.collection('pickup_points').get();
      final List<PickupPointModel> list = [];
      for (final doc in snap.docs) {
        try {
          final p = PickupPointModel.fromJson(doc.id, doc.data());
          if (p.active && p.name.isNotEmpty) list.add(p);
        } catch (e) {
          log('pickup point ${doc.id} not parsed: $e');
        }
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _pickupPoints = list;
      return list;
    } catch (e) {
      log('pickup_points not loaded: $e');
      return [];
    }
  }

  static Future<PickupPointModel?> pickupPoint(String? id) async {
    if (id == null || id.isEmpty) return null;
    final cached = (await pickupPoints()).where((p) => p.id == id);
    if (cached.isNotEmpty) return cached.first;
    try {
      final doc = await _db.collection('pickup_points').doc(id).get();
      if (doc.data() != null) return PickupPointModel.fromJson(doc.id, doc.data()!);
    } catch (e) {
      log('pickup point $id not loaded: $e');
    }
    return null;
  }

  /// Pickup points offered for an order of region [regionId] (the sender's
  /// region for the drop-off point; the receiver's for the collection point):
  /// `publish == true` and `regionId` = that region, nothing else
  /// (app-spec-parcel-pricing 3.5). Only when the region is unknown, the
  /// published points in [city].
  static Future<List<PickupPointModel>> pickupPointsFor({String? regionId, String? city}) async {
    final all = await pickupPoints();
    final String region = (regionId ?? '').trim();
    if (region.isNotEmpty) return all.where((p) => p.offeredIn(region)).toList();
    final String c = ParcelPricing.normalize(city);
    if (c.isEmpty) return const [];
    return all.where((p) => p.published && ParcelPricing.normalize(p.town) == c).toList();
  }


  // ---------------- codes ----------------

  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();

  /// `SPD-yyMMdd-XXXXXX`, checked unique against `parcel_orders`.
  static Future<String> newTrackingNumber() async {
    String candidate = '';
    for (int attempt = 0; attempt < 4; attempt++) {
      final String suffix = List.generate(6, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
      candidate = 'SPD-${DateFormat('yyMMdd').format(DateTime.now())}-$suffix';
      try {
        final snap = await _orders.where('trackingNumber', isEqualTo: candidate).limit(1).get();
        if (snap.docs.isEmpty) return candidate;
      } catch (e) {
        // Rules may forbid the query; the 31^6 space makes a clash negligible.
        return candidate;
      }
    }
    return candidate;
  }

  static String newPickupCode() => (100000 + _random.nextInt(900000)).toString();

  static const String qrPrefix = 'spideli:parcel:';

  /// The website's public tracking page for a parcel, or null when no site URL
  /// is configured (`settings/Version.websiteUrl`).
  ///
  /// The receipt's QR must reach a page, not a bare code: the person scanning
  /// it is the RECEIVER, who has no account (WEB spec §15 - the website's own
  /// receipt encodes `track-parcel/{id}`).
  static String? trackingUrlFor(String orderId) {
    final String base = (Constant.websiteUrl ?? '').trim();
    if (base.isEmpty || orderId.isEmpty) return null;
    if (!base.startsWith('http://') && !base.startsWith('https://')) return null;
    final String root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$root/track-parcel/$orderId';
  }

  /// What the receipt's QR encodes: the public tracking URL when the site URL
  /// is configured, else the app-only `spideli:parcel:<id>` value. Both are
  /// resolved by this app's [findOrder] and by the Driver app's scanner, so a
  /// parcel created before the setting existed keeps working.
  static String qrValueFor(String orderId) => trackingUrlFor(orderId) ?? '$qrPrefix$orderId';

  /// Pulls the order id out of a `track-parcel/{id}` URL, whatever host it
  /// carries. Null when the value is not one.
  static String? orderIdFromTrackingUrl(String value) {
    final String v = value.trim();
    if (!v.toLowerCase().startsWith('http://') && !v.toLowerCase().startsWith('https://')) return null;
    final Uri? uri = Uri.tryParse(v);
    if (uri == null) return null;
    final List<String> parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final int i = parts.lastIndexWhere((s) => s.toLowerCase() == 'track-parcel');
    if (i < 0 || i + 1 >= parts.length) return null;
    return Uri.decodeComponent(parts[i + 1]).trim();
  }

  /// Accepts a QR value (a `track-parcel/{id}` URL or `spideli:parcel:<id>`),
  /// a tracking number or an order id.
  static Future<ParcelOrderModel?> findOrder(String input) async {
    final String value = input.trim();
    if (value.isEmpty) return null;
    const String prefix = qrPrefix;
    if (value.toLowerCase().startsWith(prefix)) {
      return _byId(value.substring(prefix.length).trim());
    }
    final String? fromUrl = orderIdFromTrackingUrl(value);
    if (fromUrl != null) return _byId(fromUrl);
    try {
      final snap = await _orders.where('trackingNumber', isEqualTo: value.toUpperCase()).limit(1).get();
      if (snap.docs.isNotEmpty) return ParcelOrderModel.fromJson(snap.docs.first.data());
    } catch (e) {
      log('tracking number lookup failed: $e');
    }
    return _byId(value);
  }

  static Future<ParcelOrderModel?> _byId(String id) async {
    if (id.isEmpty || id.contains('/')) return null;
    try {
      final doc = await _orders.doc(id).get();
      if (doc.data() != null) return ParcelOrderModel.fromJson(doc.data()!);
    } catch (e) {
      log('parcel order $id not loaded: $e');
    }
    return null;
  }

  static Stream<ParcelOrderModel?> watch(String orderId) =>
      _orders.doc(orderId).snapshots().map((doc) => doc.data() == null ? null : ParcelOrderModel.fromJson(doc.data()!));

  // ---------------- writes ----------------

  static ParcelTrackingEvent event(String status, {String? note, String? pickupPointId}) =>
      ParcelTrackingEvent(status: status, at: Timestamp.now(), by: FireStoreUtils.getCurrentUid(), role: 'customer', note: note, pickupPointId: pickupPointId);

  /// Creates the order (one write, first events included) or, for a priced
  /// quote being paid ([isNew] false), updates its known fields and appends
  /// [events] with arrayUnion. `parcelStatus` = the last event.
  ///
  /// The receiver SMS is not the app's job: the server-side trigger on
  /// `parcel_orders` reads `sendReceiverSms` / `receiverPhone` /
  /// `receiverCountryCode` and owns `smsSent`. A known-fields write never
  /// touches a field it does not carry, so `smsSent`, `smsOptOut` and the flat
  /// receiver fields the server or panel wrote survive a quote payment.
  static Future<void> save(ParcelOrderModel order, List<ParcelTrackingEvent> events, {required bool isNew}) async {
    final ref = _orders.doc(order.id);
    final _ParcelSave w = _saveData(order, events, isNew: isNew);
    await ref.setKnownFields(w.data);
    if (w.statusUpdate != null) await ref.update(w.statusUpdate!);
    applySaved(order, events, isNew: isNew);
  }

  /// [save]'s writes, for a wallet payment (`FireStoreUtils.payFromWallet`
  /// commits them with the debit, all or nothing). Call [applySaved] once
  /// the payment is committed.
  static List<WalletOrderWrite> saveWrites(ParcelOrderModel order, List<ParcelTrackingEvent> events, {required bool isNew}) {
    final ref = _orders.doc(order.id);
    final _ParcelSave w = _saveData(order, events, isNew: isNew);
    return [
      WalletOrderWrite.setKnownFields(ref, w.data),
      if (w.statusUpdate != null) WalletOrderWrite.update(ref, w.statusUpdate!),
    ];
  }

  /// The model after a [save] / [saveWrites] commit: `parcelStatus`, the
  /// appended events and, on creation, `smsOptOut`.
  static void applySaved(ParcelOrderModel order, List<ParcelTrackingEvent> events, {required bool isNew}) {
    if (events.isNotEmpty) {
      order.parcelStatus = events.last.status;
      order.trackingEvents = [...order.trackingEvents, ...events];
    }
    if (isNew) order.smsOptOut = false;
  }

  static _ParcelSave _saveData(ParcelOrderModel order, List<ParcelTrackingEvent> events, {required bool isNew}) {
    final Map<String, dynamic> data = order.toJson();
    // A carrier parcel names no driver and never goes to the dispatch: its
    // company owner assigns one (CarrierOwnerLink).
    if (CarrierOwnerLink.isCarrierOrder(carrierId: order.carrierId, carrierOwnerId: order.carrierOwnerId)) {
      data.addAll(CarrierOwnerLink.unassignedFields());
      data.remove('driver');
    }
    if (isNew && events.isNotEmpty) {
      data['parcelStatus'] = events.last.status;
      data['trackingEvents'] = events.map((e) => e.toJson()).toList();
    }
    // Creation only: the receiver has not opted out. Never written again by
    // the app (it is not in toJson), so a later opt-out recorded by the server
    // is never reset.
    if (isNew) data['smsOptOut'] = false;
    final Map<String, dynamic>? statusUpdate = isNew || events.isEmpty
        ? null
        : {'parcelStatus': events.last.status, 'trackingEvents': FieldValue.arrayUnion(events.map((e) => e.toJson()).toList())};
    return _ParcelSave(data, statusUpdate);
  }

  /// Appends one event (e.g. `Cancelled`) without touching other fields.
  static Future<void> append(String orderId, ParcelTrackingEvent e) async {
    await _orders.doc(orderId).update(appendFields(e));
  }

  /// The fields [append] writes, for a caller that writes them inside its own
  /// transaction (the customer's cancel).
  static Map<String, dynamic> appendFields(ParcelTrackingEvent e) => {'parcelStatus': e.status, 'trackingEvents': FieldValue.arrayUnion([e.toJson()])};
}

/// The two parts of a parcel save: the known fields, and (paying a priced
/// quote) the status / events appended to the existing order.
class _ParcelSave {
  const _ParcelSave(this.data, this.statusUpdate);
  final Map<String, dynamic> data;
  final Map<String, dynamic>? statusUpdate;
}
