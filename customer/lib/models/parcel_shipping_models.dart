import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/utils/parcel_pricing.dart';

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

String _s(dynamic v) => v == null ? '' : v.toString().trim();

List<String> _ids(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

/// `pickup_points/{id}` (admin module, spec 6.8) - read tolerantly.
class PickupPointModel {
  final String id;
  final String name;
  final String quarter;
  final String phone;
  final String town;
  final double? latitude;
  final double? longitude;
  final String openingHours;
  final String capacity;
  final List<String> regionIds;
  final bool active;

  PickupPointModel({
    required this.id,
    required this.name,
    this.quarter = '',
    this.phone = '',
    this.town = '',
    this.latitude,
    this.longitude,
    this.openingHours = '',
    this.capacity = '',
    this.regionIds = const [],
    this.active = true,
  });

  bool get hasLocation => latitude != null && longitude != null && !(latitude == 0 && longitude == 0);

  String get subtitle => [quarter, town].where((e) => e.isNotEmpty).join(', ');

  factory PickupPointModel.fromJson(String id, Map<String, dynamic> json) {
    double? lat;
    double? lng;
    final dynamic loc = json['location'] ?? json['geoPoint'] ?? json['coordinates'];
    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
    } else if (loc is Map) {
      if (loc['geopoint'] is GeoPoint) {
        lat = (loc['geopoint'] as GeoPoint).latitude;
        lng = (loc['geopoint'] as GeoPoint).longitude;
      } else {
        lat = _d(loc['latitude'] ?? loc['lat']);
        lng = _d(loc['longitude'] ?? loc['lng']);
      }
    }
    lat ??= _d(json['latitude'] ?? json['lat']);
    lng ??= _d(json['longitude'] ?? json['lng']);

    String hours;
    final dynamic oh = json['openingHours'];
    if (oh is Map) {
      hours = oh.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } else if (oh is List) {
      hours = oh.map((e) => e is Map ? e.values.join(' ') : e.toString()).join(', ');
    } else {
      hours = _s(oh);
    }

    final List<String> regions = {..._ids(json['regionIds']), ..._ids(json['regionId'])}.toList();
    final bool active = json['publish'] != false && json['isActive'] != false && json['active'] != false;
    return PickupPointModel(
      id: _s(json['id']).isNotEmpty ? _s(json['id']) : id,
      name: _s(json['name']).isNotEmpty ? _s(json['name']) : _s(json['title']),
      quarter: _s(json['quarter']),
      phone: [_s(json['countryCode']), _s(json['phone'])].where((e) => e.isNotEmpty).join(' '),
      town: _s(json['town']).isNotEmpty ? _s(json['town']) : _s(json['city']),
      latitude: lat,
      longitude: lng,
      openingHours: hours,
      capacity: _s(json['capacity']),
      regionIds: regions,
      active: active,
    );
  }

  bool inRegion(String? regionId) => regionIds.isEmpty || (regionId != null && regionIds.contains(regionId));
}

/// `delivery_carriers/{id}` (spec 18.14 + the optional contract rateTable).
class DeliveryCarrierModel {
  final String id;
  final String name;
  final String photo;
  final List<String> regionIds;
  final bool publish;
  final bool? isVerified;
  final double? maxWeight;
  final double? minDeliveryTime;
  final double? maxDeliveryTime;
  final String deliveryTimeUnit;
  final String conditions;
  final double? rating;
  final ParcelRateCard rateCard;
  final ParcelRateTable? rateTable;

  DeliveryCarrierModel({
    required this.id,
    required this.name,
    this.photo = '',
    this.regionIds = const [],
    this.publish = true,
    this.isVerified,
    this.maxWeight,
    this.minDeliveryTime,
    this.maxDeliveryTime,
    this.deliveryTimeUnit = 'days',
    this.conditions = '',
    this.rating,
    this.rateCard = const ParcelRateCard(),
    this.rateTable,
  });

  factory DeliveryCarrierModel.fromJson(String id, Map<String, dynamic> json) {
    double? rating = _d(json['rating']);
    final double? sum = _d(json['reviewsSum']);
    final double? count = _d(json['reviewsCount']);
    if (rating == null && sum != null && count != null && count > 0) rating = sum / count;
    return DeliveryCarrierModel(
      id: _s(json['id']).isNotEmpty ? _s(json['id']) : id,
      name: _s(json['name']),
      photo: _s(json['photo']),
      regionIds: _ids(json['regionIds']),
      publish: json['publish'] != false,
      isVerified: json['isVerified'] is bool ? json['isVerified'] : null,
      maxWeight: _d(json['maxWeight']),
      minDeliveryTime: _d(json['minDeliveryTime']),
      maxDeliveryTime: _d(json['maxDeliveryTime']),
      deliveryTimeUnit: _s(json['deliveryTimeUnit']).isEmpty ? 'days' : _s(json['deliveryTimeUnit']),
      conditions: _s(json['conditions']),
      rating: rating,
      rateCard: ParcelRateCard.fromJson(json),
      rateTable: ParcelRateTable.fromJson(json['rateTable']),
    );
  }

  /// Contract "Carriers": published, not explicitly unverified, serving the
  /// origin region, able to carry the weight.
  bool isEligible({required String? originRegionId, required double weightKg}) {
    if (!publish || isVerified == false) return false;
    if (regionIds.isNotEmpty && (originRegionId == null || !regionIds.contains(originRegionId))) return false;
    if (maxWeight != null && maxWeight! > 0 && maxWeight! < weightKg) return false;
    return true;
  }

  String get estimatedTime {
    String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    if (minDeliveryTime == null && maxDeliveryTime == null) return '';
    final String range = minDeliveryTime != null && maxDeliveryTime != null && minDeliveryTime != maxDeliveryTime ? '${n(minDeliveryTime!)}-${n(maxDeliveryTime!)}' : n((minDeliveryTime ?? maxDeliveryTime)!);
    return '$range $deliveryTimeUnit';
  }
}

/// One option on the carrier-selection screen.
class ParcelCarrierOption {
  /// Null = the platform's own drivers (today's flow and price).
  final DeliveryCarrierModel? carrier;
  final ParcelQuote quote;

  ParcelCarrierOption({required this.carrier, required this.quote});
}
