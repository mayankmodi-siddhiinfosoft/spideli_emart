import 'dart:math' as math;

/// One `vendor_products/{id}.delivery_charges[]` tier (Doc 60, product-level
/// delivery charges). Values may be numbers or numeric strings.
class ProductDeliveryTier {
  /// `delivery_charges_per_km`: rate per km beyond [withinKm].
  final double perKm;

  /// `minimum_delivery_charges`: base fee covering up to [withinKm].
  final double minCharge;

  /// `minimum_delivery_charges_within_km`: distance the base fee covers.
  final double withinKm;

  const ProductDeliveryTier({required this.perKm, required this.minCharge, required this.withinKm});

  /// A tier from one array element, or null for anything that is not a map
  /// or carries none of the three fields. A missing / unreadable / negative
  /// field counts as 0.
  static ProductDeliveryTier? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? perKm = raw['delivery_charges_per_km'];
    final Object? minCharge = raw['minimum_delivery_charges'];
    final Object? withinKm = raw['minimum_delivery_charges_within_km'];
    if (_num(perKm) == null && _num(minCharge) == null && _num(withinKm) == null) return null;
    return ProductDeliveryTier(perKm: _nonNegative(perKm), minCharge: _nonNegative(minCharge), withinKm: _nonNegative(withinKm));
  }

  /// The tiers of a product document's `delivery_charges` value; empty for
  /// null / not a list / no usable tier.
  static List<ProductDeliveryTier> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(fromJson).whereType<ProductDeliveryTier>().toList(growable: false);
  }

  static double? _num(Object? v) {
    if (v == null) return null;
    final double? d = v is num ? v.toDouble() : double.tryParse(v.toString().trim());
    return d != null && d.isFinite ? d : null;
  }

  static double _nonNegative(Object? v) => math.max(0.0, _num(v) ?? 0.0);

  Map<String, dynamic> toJson() => {'delivery_charges_per_km': perKm, 'minimum_delivery_charges': minCharge, 'minimum_delivery_charges_within_km': withinKm};

  @override
  bool operator ==(Object other) => other is ProductDeliveryTier && other.perKm == perKm && other.minCharge == minCharge && other.withinKm == withinKm;

  @override
  int get hashCode => Object.hash(perKm, minCharge, withinKm);

  @override
  String toString() => 'ProductDeliveryTier(perKm: $perKm, min: $minCharge, withinKm: $withinKm)';
}

/// Product-level delivery charges (Doc 60, APP-SPEC-PRODUCT-DELIVERY-CHARGES
/// §4). Used only when the cart's section has
/// `sections/{id}.is_delivery_charge_customization == true`; then the Delivery
/// charge comes from these tiers ALONE - no `settings/DeliveryCharge`, no flat
/// e-commerce charge, no vendor-level charge.
///
/// **Tier choice (per item).** Tiers are sorted by `withinKm` ascending.
///  * The first tier whose `withinKm >= distance` applies: its
///    `minimum_delivery_charges` is the item's charge.
///  * Beyond every tier, the tier with the largest `withinKm` applies:
///    `min + (distance - withinKm) * perKm`.
///  * No tiers -> 0.
///
/// With a single tier this is exactly the spec formula
/// `distance <= withinKm ? min : min + (distance - withinKm) * perKm`.
///
/// **Order charge = the MAXIMUM item charge** across the cart, never the sum.
class ProductDeliveryCharge {
  ProductDeliveryCharge._();

  /// Whether a section document's `is_delivery_charge_customization` value
  /// turns the feature on (`true`, or the text "true"). Anything else - false,
  /// missing, malformed - keeps today's delivery charge.
  static bool isEnabled(Object? flag) => flag == true || (flag is String && flag.trim().toLowerCase() == 'true');

  /// Great-circle distance in km (Haversine, mean Earth radius 6371 km).
  /// Null when any coordinate is missing / not finite.
  static double? haversineKm(double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
    if (!lat1.isFinite || !lng1.isFinite || !lat2.isFinite || !lng2.isFinite) return null;
    const double earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180.0;
    final double dLat = rad(lat2 - lat1);
    final double dLng = rad(lng2 - lng1);
    final double a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1 - a)));
    return earthRadiusKm * c;
  }

  /// The charge for one item at [distanceKm] (see the class doc for the tier
  /// rule). A negative / non-finite distance counts as 0 km.
  static double itemCharge(double distanceKm, List<ProductDeliveryTier> tiers) {
    if (tiers.isEmpty) return 0.0;
    final double d = distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0.0;
    final List<ProductDeliveryTier> sorted = [...tiers]..sort((a, b) => a.withinKm.compareTo(b.withinKm));
    for (final ProductDeliveryTier t in sorted) {
      if (t.withinKm >= d) return _round(t.minCharge);
    }
    final ProductDeliveryTier last = sorted.last;
    return _round(last.minCharge + (d - last.withinKm) * last.perKm);
  }

  /// The order's delivery charge: the highest [itemCharge] over
  /// [itemTiers] (one tier list per cart line), 0 for an empty cart.
  static double orderCharge(double distanceKm, Iterable<List<ProductDeliveryTier>> itemTiers) {
    double max = 0.0;
    for (final List<ProductDeliveryTier> tiers in itemTiers) {
      final double c = itemCharge(distanceKm, tiers);
      if (c > max) max = c;
    }
    return max;
  }

  /// Two decimals, so the stored `deliveryCharge` has no floating-point tail.
  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
