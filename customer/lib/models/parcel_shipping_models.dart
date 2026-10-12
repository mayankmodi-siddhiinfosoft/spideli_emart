import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/utils/address_format.dart';
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

  /// `publish == true` (app-spec-parcel-pricing 3.5): only these are offered.
  final bool published;

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
    this.published = true,
  });

  bool get hasLocation => latitude != null && longitude != null && !(latitude == 0 && longitude == 0);

  /// Quarter and town for display, through the shared address rule (02#18).
  String get subtitle => formatAddressLine([quarter, town]);

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
      published: json['publish'] == true || json['publish']?.toString() == 'true',
    );
  }

  bool inRegion(String? regionId) => regionIds.isEmpty || (regionId != null && regionIds.contains(regionId));

  /// Offered for an order of region [regionId]: published and in that region
  /// (`pickup_points.regionId`, app-spec-parcel-pricing 3.5 / section 4).
  bool offeredIn(String regionId) => active && published && name.isNotEmpty && regionIds.contains(regionId);
}

/// `delivery_carriers/{id}` (spec 18.14, app-spec-parcel-pricing.md 3.2 / 3.3).
class DeliveryCarrierModel {
  final String id;
  final String name;
  final String photo;
  final List<String> regionIds;
  /// `deliveryScopes` (point 65): missing / empty = all three scopes.
  final List<String> deliveryScopes;
  final bool publish;
  final bool? isVerified;
  final double? maxWeight;
  final double? minDeliveryTime;
  final double? maxDeliveryTime;
  final String deliveryTimeUnit;
  final String conditions;
  final double? rating;
  /// The flat `baseCharge` / `perKmCharge` / `perKgCharge` / `minimumCharge`.
  /// Since 6 October they hold the FIRST region's price: price through
  /// [rateCardFor], never this directly.
  final ParcelRateCard rateCard;

  /// The owner/company user ID who manages this carrier.
  final String? ownerId;

  /// `regionPricing`: the carrier's price per region (doc point 43).
  final Map<String, ParcelRateCard> regionPricing;

  DeliveryCarrierModel({
    required this.id,
    required this.name,
    this.photo = '',
    this.regionIds = const [],
    this.deliveryScopes = const [],
    this.publish = true,
    this.isVerified,
    this.ownerId,
    this.maxWeight,
    this.minDeliveryTime,
    this.maxDeliveryTime,
    this.deliveryTimeUnit = 'days',
    this.conditions = '',
    this.rating,
    this.rateCard = const ParcelRateCard(),
    this.regionPricing = const <String, ParcelRateCard>{},
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
      deliveryScopes: _ids(json['deliveryScopes']),
      publish: json['publish'] != false,
      isVerified: json['isVerified'] is bool ? json['isVerified'] : null,
      // `delivery_carriers/{id}.ownerId` (binding of 9 Oct; never `companyId`).
      ownerId: _s(json['ownerId']).isEmpty ? null : _s(json['ownerId']),
      maxWeight: _d(json['maxWeight']),
      minDeliveryTime: _d(json['minDeliveryTime']),
      maxDeliveryTime: _d(json['maxDeliveryTime']),
      deliveryTimeUnit: _s(json['deliveryTimeUnit']).isEmpty ? 'days' : _s(json['deliveryTimeUnit']),
      conditions: _s(json['conditions']),
      rating: rating,
      rateCard: ParcelRateCard.flatFromJson(json),
      regionPricing: ParcelRateCard.parseRegionPricing(json['regionPricing']),
    );
  }

  /// Spec step 3 - offered only when published (and not explicitly
  /// unverified, admin spec section 11), serving the origin region, handling
  /// the [scope] (`deliveryScopes`, missing / empty = all) and able to carry
  /// [chargeableKg] (`maxWeight` not set, or >= it).
  ///
  /// Every field is optional and a missing one is "not set", never zero:
  /// empty `regionIds` = served everywhere. A carrier that names its regions
  /// is offered ONLY in one of them: with the order's region R unresolved it
  /// is not offered at all (it used to be offered everywhere - three Yaounde
  /// carriers shown to an India customer, brief 12 Oct section 9).
  bool isEligible({required String? originRegionId, required double chargeableKg, required String scope}) {
    if (!publish || isVerified == false) return false;
    if (!ParcelPricing.handlesScope(deliveryScopes, scope)) return false;
    final String region = (originRegionId ?? '').trim();
    if (regionIds.isNotEmpty && !regionIds.contains(region)) return false;
    if (maxWeight != null && maxWeight! > 0 && maxWeight! + 1e-9 < chargeableKg) return false;
    return true;
  }

  /// The rate card for a shipment from [regionId] (the region of the
  /// sender's address): `regionPricing[regionId]`, else the flat fields.
  ParcelRateCard rateCardFor(String? regionId) => ParcelRateCard.forRegion(flat: rateCard, regionPricing: regionPricing, regionId: regionId);

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
