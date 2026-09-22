import 'dart:developer';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/service/fire_store_utils.dart';
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

  /// Pickup points of a region; when the region is unknown (e.g. abroad),
  /// those in [city]; failing that, every published point.
  static Future<List<PickupPointModel>> pickupPointsFor({String? regionId, String? city}) async {
    final all = await pickupPoints();
    if (regionId != null) {
      final inRegion = all.where((p) => p.regionIds.contains(regionId)).toList();
      if (inRegion.isNotEmpty) return inRegion;
    }
    final String c = (city ?? '').trim().toLowerCase();
    if (c.isNotEmpty) {
      final inCity = all.where((p) => p.town.toLowerCase() == c).toList();
      if (inCity.isNotEmpty) return inCity;
    }
    // Points without a region serve everywhere.
    final global = all.where((p) => p.regionIds.isEmpty).toList();
    return global.isNotEmpty ? global : all;
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

  static String qrValueFor(String orderId) => 'spideli:parcel:$orderId';

  /// Accepts a QR value (`spideli:parcel:<id>`), a tracking number or an order id.
  static Future<ParcelOrderModel?> findOrder(String input) async {
    final String value = input.trim();
    if (value.isEmpty) return null;
    const String prefix = 'spideli:parcel:';
    if (value.toLowerCase().startsWith(prefix)) {
      return _byId(value.substring(prefix.length).trim());
    }
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
  static Future<void> save(ParcelOrderModel order, List<ParcelTrackingEvent> events, {required bool isNew}) async {
    final ref = _orders.doc(order.id);
    final Map<String, dynamic> data = order.toJson();
    if (isNew) {
      if (events.isNotEmpty) {
        data['parcelStatus'] = events.last.status;
        data['trackingEvents'] = events.map((e) => e.toJson()).toList();
      }
      await ref.setKnownFields(data);
    } else {
      await ref.setKnownFields(data);
      if (events.isNotEmpty) {
        await ref.update({'parcelStatus': events.last.status, 'trackingEvents': FieldValue.arrayUnion(events.map((e) => e.toJson()).toList())});
      }
    }
    if (events.isNotEmpty) {
      order.parcelStatus = events.last.status;
      order.trackingEvents = [...order.trackingEvents, ...events];
    }
  }

  /// Appends one event (e.g. `Cancelled`) without touching other fields.
  static Future<void> append(String orderId, ParcelTrackingEvent e) async {
    await _orders.doc(orderId).update({'parcelStatus': e.status, 'trackingEvents': FieldValue.arrayUnion([e.toJson()])});
  }
}
