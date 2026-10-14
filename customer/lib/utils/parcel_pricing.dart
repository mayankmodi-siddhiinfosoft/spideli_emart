// Parcel / mail pricing — web team spec `app-spec-parcel-pricing.md` (12 Oct
// 2026, points 41 + 65; summary in .claude/PARCEL-PRICING.md).
//
// Pure Dart on purpose - no Flutter / Firestore imports - so the brief's
// check cases A-E can be verified by a plain unit test
// (test/parcel_pricing_test.dart).
//
// Nothing here is hard-coded: the divisor, the door / pickup-point charges and
// the fixed inter-city / inter-country charge are all read from
// `regions/{R}.parcelPricing` and `delivery_carriers/{id}.regionPricing.<R>`.
// Every amount is in region R's own currency and is never converted.

/// Shipment scope as stored on `parcel_orders.scope`.
class ParcelScope {
  ParcelScope._();

  static const String city = 'city';
  static const String intercity = 'intercity';
  static const String intercountry = 'intercountry';

  static const List<String> all = [city, intercity, intercountry];
}

/// Where a price comes from (`priceBreakdown.source`). `route_table` is
/// reserved by the web team for rate tables that are not built yet: never used.
class ParcelPriceSource {
  ParcelPriceSource._();

  /// A carrier's rate card (`regionPricing[R]`, else its flat fields).
  static const String rateCard = 'rate_card';

  /// No carrier: distance x the weight band's charge (Admin -> Parcel Weight).
  static const String defaultSetting = 'default';

  /// A quote the admin priced by hand.
  static const String manual = 'manual';
}

/// `pickupMethod` / `deliveryMethod` values on `parcel_orders`.
class ParcelMethod {
  ParcelMethod._();

  static const String home = 'home';
  static const String pickupPoint = 'pickup_point';
}

/// Defensive number: num, numeric text ("20", "1,500"), else null. `null`,
/// `""`, non-numeric text, NaN and infinity are all "not set".
double? parcelNumber(dynamic value) {
  if (value == null || value is bool) return null;
  double? d;
  if (value is num) {
    d = value.toDouble();
  } else {
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    d = double.tryParse(s.replaceAll(',', ''));
  }
  if (d == null || !d.isFinite) return null;
  return d;
}

double? _num(dynamic value) => parcelNumber(value);

/// `regions/{regionId}.parcelPricing` — the admin's per-region defaults.
/// A null value = not set; a missing map = everything unset (no divisor,
/// charges 0, fixed charges 0).
class RegionParcelPricing {
  final double? volumetricDivisor;
  final double? homePickupCharge;
  final double? pointDropoffCharge;
  final double? homeDeliveryCharge;
  final double? pointCollectionCharge;
  final double? intercityFixedTax;
  final double? intercountryFixedTax;

  const RegionParcelPricing({
    this.volumetricDivisor,
    this.homePickupCharge,
    this.pointDropoffCharge,
    this.homeDeliveryCharge,
    this.pointCollectionCharge,
    this.intercityFixedTax,
    this.intercountryFixedTax,
  });

  factory RegionParcelPricing.fromJson(dynamic json) {
    if (json is! Map) return const RegionParcelPricing();
    return RegionParcelPricing(
      volumetricDivisor: _num(json['volumetricDivisor']),
      homePickupCharge: _num(json['homePickupCharge']),
      pointDropoffCharge: _num(json['pointDropoffCharge']),
      homeDeliveryCharge: _num(json['homeDeliveryCharge']),
      pointCollectionCharge: _num(json['pointCollectionCharge']),
      intercityFixedTax: _num(json['intercityFixedTax']),
      intercountryFixedTax: _num(json['intercountryFixedTax']),
    );
  }

  /// Spec step 6: the fixed platform charge for [scope] — admin only, never
  /// the carrier's. Not set -> 0 (never an assumed 5,000).
  double fixedTaxFor(String scope) {
    final double? v = scope == ParcelScope.intercity
        ? intercityFixedTax
        : scope == ParcelScope.intercountry
        ? intercountryFixedTax
        : null;
    return v != null && v > 0 ? v : 0;
  }
}

/// `settings/ParcelPricing` - only `commissionAsExtra` is still read. The
/// fixed charges and the divisor it used to carry are superseded by
/// `regions/{R}.parcelPricing` and `delivery_carriers/{id}.regionPricing.<R>`.
class ParcelPricingSettings {
  /// "admin delivery commission (if configured as an extra)". false (default)
  /// = the commission is recorded on the order as the existing parcel
  /// checkout does, not added to the customer's price.
  final bool commissionAsExtra;

  const ParcelPricingSettings({this.commissionAsExtra = false});

  factory ParcelPricingSettings.fromJson(Map<String, dynamic>? json) => ParcelPricingSettings(commissionAsExtra: json?['commissionAsExtra'] == true);
}

/// A carrier's price block. A null field = not set (never zero).
///
/// The four prices (`baseCharge`, `perKmCharge`, `perKgCharge`,
/// `minimumCharge`) and - only inside `regionPricing.<R>` - the owner's five
/// values (`volumetricDivisor` and the four door / pickup-point charges).
class ParcelRateCard {
  final double? baseCharge;
  final double? perKmCharge;
  final double? perKgCharge;
  final double? minimumCharge;
  final double? volumetricDivisor;
  final double? homePickupCharge;
  final double? pointDropoffCharge;
  final double? homeDeliveryCharge;
  final double? pointCollectionCharge;

  const ParcelRateCard({
    this.baseCharge,
    this.perKmCharge,
    this.perKgCharge,
    this.minimumCharge,
    this.volumetricDivisor,
    this.homePickupCharge,
    this.pointDropoffCharge,
    this.homeDeliveryCharge,
    this.pointCollectionCharge,
  });

  /// One `regionPricing.<R>` block: the four prices and the five values.
  factory ParcelRateCard.fromJson(Map<String, dynamic> json) => ParcelRateCard(
    baseCharge: _num(json['baseCharge']),
    perKmCharge: _num(json['perKmCharge']),
    perKgCharge: _num(json['perKgCharge']),
    minimumCharge: _num(json['minimumCharge']),
    volumetricDivisor: _num(json['volumetricDivisor']),
    homePickupCharge: _num(json['homePickupCharge']),
    pointDropoffCharge: _num(json['pointDropoffCharge']),
    homeDeliveryCharge: _num(json['homeDeliveryCharge']),
    pointCollectionCharge: _num(json['pointCollectionCharge']),
  );

  /// The carrier's FLAT fields: the four prices only. A carrier with no region
  /// block has none of the five values, so it always uses the region defaults.
  factory ParcelRateCard.flatFromJson(Map<String, dynamic> json) => ParcelRateCard(
    baseCharge: _num(json['baseCharge']),
    perKmCharge: _num(json['perKmCharge']),
    perKgCharge: _num(json['perKgCharge']),
    minimumCharge: _num(json['minimumCharge']),
  );

  /// At least one of the four prices is set.
  bool get hasPrice => baseCharge != null || perKmCharge != null || perKgCharge != null || minimumCharge != null;

  bool get isSet =>
      hasPrice || volumetricDivisor != null || homePickupCharge != null || pointDropoffCharge != null || homeDeliveryCharge != null || pointCollectionCharge != null;

  /// `delivery_carriers.regionPricing`: `{ "<regionId>": { ... } }`. Entries
  /// that are not maps, or that set nothing, are left out.
  static Map<String, ParcelRateCard> parseRegionPricing(dynamic raw) {
    if (raw is! Map) return const <String, ParcelRateCard>{};
    final Map<String, ParcelRateCard> out = <String, ParcelRateCard>{};
    raw.forEach((key, value) {
      final String id = key.toString().trim();
      if (id.isEmpty || value is! Map) return;
      final ParcelRateCard card = ParcelRateCard.fromJson(Map<String, dynamic>.from(value));
      if (card.isSet) out[id] = card;
    });
    return out;
  }

  /// The card a carrier charges in [regionId]: `regionPricing[regionId]`; the
  /// flat fields ([flat]) only when there is no entry for that region (or the
  /// region is unknown).
  static ParcelRateCard forRegion({required ParcelRateCard flat, required Map<String, ParcelRateCard> regionPricing, String? regionId}) {
    final String id = (regionId ?? '').trim();
    if (id.isEmpty || regionPricing.isEmpty) return flat;
    return regionPricing[id] ?? flat;
  }
}

/// A place on a route (`origin` / `destination` on the order).
class ParcelPlace {
  final String city;
  final String country;
  final String countryCode;

  const ParcelPlace({this.city = '', this.country = '', this.countryCode = ''});

  factory ParcelPlace.fromJson(dynamic json) {
    if (json is! Map) return const ParcelPlace();
    return ParcelPlace(city: (json['city'] ?? '').toString(), country: (json['country'] ?? '').toString(), countryCode: (json['countryCode'] ?? '').toString());
  }

  Map<String, dynamic> toJson() => {'city': city, 'country': country, 'countryCode': countryCode};

  /// Countries match by ISO code or by name (trimmed, lower-case, no accents).
  bool countryMatches(String value) {
    final String v = ParcelPricing.normalize(value);
    if (v.isEmpty) return false;
    return v == ParcelPricing.normalize(countryCode) || v == ParcelPricing.normalize(country);
  }

  /// Spec section 5: "Yaoundé" == "yaounde".
  bool cityMatches(String value) {
    final String v = ParcelPricing.normalize(value);
    return v.isNotEmpty && v == ParcelPricing.normalize(city);
  }

  String get label {
    final List<String> parts = [if (city.trim().isNotEmpty) city.trim(), if (country.trim().isNotEmpty) country.trim() else if (countryCode.trim().isNotEmpty) countryCode.trim()];
    return parts.join(', ');
  }
}

/// A weight band (`parcel_weight/{id}`), as the pricing sees it.
class ParcelBand<T> {
  /// The model the band came from (returned to the caller).
  final T source;
  final String? title;
  final double? minKg;
  final double? maxKg;

  /// `delivery_charge` (a string on existing bands), per distance unit.
  final double charge;

  const ParcelBand({required this.source, this.title, this.minKg, this.maxKg, required this.charge});
}

/// Chargeable weight of one shipment (spec step 2).
class ParcelWeight {
  /// The real weight, kg.
  final double actualKg;

  /// The divisor used; null = none (size not used).
  final double? divisor;

  /// L x W x H / divisor, 2 decimals; 0 without a divisor or all three sides.
  final double volumetricKg;

  /// max(actualKg, volumetricKg), 2 decimals.
  final double chargeableKg;

  const ParcelWeight({required this.actualKg, required this.divisor, required this.volumetricKg, required this.chargeableKg});
}

/// The price of one option (a carrier, or the default setting). Amounts are in
/// the order region's currency.
class ParcelQuote {
  /// The base price (spec step 4), whichever source it came from.
  final double carrierPrice;

  /// Reserved for the web team's rate tables: always 0.
  final double extraKgCharge;
  final double fixedTax;
  final double commission;
  final double pickupCharge;
  final double deliveryCharge;
  final String source;

  final double? actualKg;
  final double? volumetricKg;
  final double? chargeableKg;

  /// The divisor used; null = none.
  final double? volumetricDivisor;

  const ParcelQuote({
    required this.carrierPrice,
    this.extraKgCharge = 0,
    this.fixedTax = 0,
    this.commission = 0,
    this.pickupCharge = 0,
    this.deliveryCharge = 0,
    required this.source,
    this.actualKg,
    this.volumetricKg,
    this.chargeableKg,
    this.volumetricDivisor,
  });

  /// Door / pickup-point charges (spec step 5).
  double get options => pickupCharge + deliveryCharge;

  /// The shipping price before the receiver SMS, platform fee and taxes:
  /// carrierPrice + extraKgCharge + options + fixedTax (+ commission when the
  /// admin charges it as an extra).
  double get total => carrierPrice + extraKgCharge + options + fixedTax + commission;

  /// The order's `subTotal`: the base price (plus the commission when it is
  /// charged as an extra, as before). Options, fixedTax, extraKgCharge and the
  /// SMS fee are never folded in: they are added on top at checkout.
  double get subTotal => carrierPrice + commission;

  ParcelQuote copyWith({double? commission}) => ParcelQuote(
    carrierPrice: carrierPrice,
    extraKgCharge: extraKgCharge,
    fixedTax: fixedTax,
    commission: commission ?? this.commission,
    pickupCharge: pickupCharge,
    deliveryCharge: deliveryCharge,
    source: source,
    actualKg: actualKg,
    volumetricKg: volumetricKg,
    chargeableKg: chargeableKg,
    volumetricDivisor: volumetricDivisor,
  );

  /// `parcel_orders.priceBreakdown` (spec section 7). [total] defaults to
  /// [ParcelQuote.total] + [smsCharge]; checkout overwrites it with what the
  /// customer actually pays (after coupon, platform fee and taxes).
  Map<String, dynamic> breakdown({required String currency, double smsCharge = 0, double? total}) => {
    'source': source,
    'currency': currency,
    'actualKg': actualKg ?? 0,
    'volumetricKg': volumetricKg ?? 0,
    'chargeableKg': chargeableKg ?? actualKg ?? 0,
    'volumetricDivisor': volumetricDivisor,
    'carrierPrice': carrierPrice,
    'extraKgCharge': extraKgCharge,
    'options': options,
    'pickupCharge': pickupCharge,
    'deliveryCharge': deliveryCharge,
    'fixedTax': fixedTax,
    'smsCharge': smsCharge,
    'commission': commission,
    'total': total ?? (this.total + smsCharge),
  };
}

class ParcelPricing {
  ParcelPricing._();

  static const double _eps = 1e-9;

  // ---- Step 1: scope -------------------------------------------------------

  static const Map<String, String> _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'œ': 'oe',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss',
  };

  /// Trimmed, lower-case, accents removed, inner spaces collapsed.
  static String normalize(String? value) {
    final String lower = (value ?? '').trim().toLowerCase();
    final StringBuffer out = StringBuffer();
    for (final int rune in lower.runes) {
      final String ch = String.fromCharCode(rune);
      out.write(_accents[ch] ?? ch);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Spec section 5: different country codes -> intercountry; same country,
  /// different city (accent-insensitive) -> intercity; otherwise city. A city
  /// missing on either side: same zone -> city, else intercity.
  static String scopeFor({required ParcelPlace origin, required ParcelPlace destination, String? senderZoneId, String? receiverZoneId}) {
    final String a = normalize(origin.countryCode), b = normalize(destination.countryCode);
    if (a.isNotEmpty && b.isNotEmpty && a != b) return ParcelScope.intercountry;
    final String ca = normalize(origin.city), cb = normalize(destination.city);
    if (ca.isEmpty || cb.isEmpty) {
      final String za = (senderZoneId ?? '').trim(), zb = (receiverZoneId ?? '').trim();
      return za.isNotEmpty && za == zb ? ParcelScope.city : ParcelScope.intercity;
    }
    return ca == cb ? ParcelScope.city : ParcelScope.intercity;
  }

  // ---- Step 2: chargeable weight -------------------------------------------

  /// carrier.regionPricing[R].volumetricDivisor if > 0, else
  /// regions[R].parcelPricing.volumetricDivisor if > 0, else none (null).
  static double? resolveVolumetricDivisor({ParcelRateCard? carrierCard, RegionParcelPricing? regionPricing}) {
    final double? carrierDiv = carrierCard?.volumetricDivisor;
    if (carrierDiv != null && carrierDiv > 0) return carrierDiv;
    final double? regionDiv = regionPricing?.volumetricDivisor;
    if (regionDiv != null && regionDiv > 0) return regionDiv;
    return null;
  }

  /// L x W x H (cm) / [divisor], 2 decimals. Null when there is no divisor or
  /// a side is missing / not positive.
  static double? volumetricKg({num? lengthCm, num? widthCm, num? heightCm, double? divisor}) {
    if (divisor == null || divisor <= 0) return null;
    final List<num?> sides = [lengthCm, widthCm, heightCm];
    if (sides.any((v) => v == null || v <= 0 || !v.isFinite)) return null;
    return round2(lengthCm! * widthCm! * heightCm! / divisor);
  }

  /// The greater of [actualKg] and [volumetricKg] (either may be unknown),
  /// 2 decimals. 0 when neither is known.
  static double chargeableKg({double? actualKg, double? volumetricKg}) {
    final double a = (actualKg != null && actualKg > 0) ? actualKg : 0;
    final double v = (volumetricKg != null && volumetricKg > 0) ? volumetricKg : 0;
    return round2(a > v ? a : v);
  }

  /// Step 2 for one option: [carrierCard] null = no carrier (region divisor).
  static ParcelWeight weightFor({required double actualKg, num? lengthCm, num? widthCm, num? heightCm, ParcelRateCard? carrierCard, RegionParcelPricing region = const RegionParcelPricing()}) {
    final double? divisor = resolveVolumetricDivisor(carrierCard: carrierCard, regionPricing: region);
    final double? vol = volumetricKg(lengthCm: lengthCm, widthCm: widthCm, heightCm: heightCm, divisor: divisor);
    final double actual = actualKg > 0 ? round2(actualKg) : 0;
    return ParcelWeight(actualKg: actual, divisor: divisor, volumetricKg: vol ?? 0, chargeableKg: chargeableKg(actualKg: actual, volumetricKg: vol));
  }

  // ---- Step 3: which carriers ----------------------------------------------

  /// `scope` in `deliveryScopes`; missing or empty = all three.
  static bool handlesScope(List<String> deliveryScopes, String scope) => deliveryScopes.isEmpty || deliveryScopes.contains(scope);

  // ---- Step 4: base price ----------------------------------------------------

  /// rate_card: baseCharge + perKmCharge x km + perKgCharge x chargeableKg, at
  /// least minimumCharge, 2 decimals. Null = the card sets no price (or a
  /// price of 0): the carrier is not offered.
  static double? rateCardPrice({required ParcelRateCard card, required double distanceKm, required double chargeableKg}) {
    if (!card.hasPrice) return null;
    double price = (card.baseCharge ?? 0) + (card.perKmCharge ?? 0) * distanceKm + (card.perKgCharge ?? 0) * chargeableKg;
    if (card.minimumCharge != null && card.minimumCharge! > price) price = card.minimumCharge!;
    if (price <= 0) return null;
    return round2(price);
  }

  /// The bands carry `minKg` / `maxKg` (the admin has saved Parcel Weight).
  static bool hasKgBands<T>(List<ParcelBand<T>> bands) => bands.any((b) => b.minKg != null || b.maxKg != null);

  /// default: the band with minKg <= [kg] <= maxKg (inclusive; maxKg null = no
  /// upper limit). A weight in a gap between two bands takes the next band up;
  /// above every band, the heaviest. Only when the bands carry no
  /// minKg / maxKg at all: today's title matching ([categoryFor] from
  /// [selected]).
  static ParcelBand<T>? bandFor<T>(List<ParcelBand<T>> bands, double kg, {ParcelBand<T>? selected}) {
    if (bands.isEmpty) return selected;
    if (!hasKgBands(bands)) {
      if (selected == null) return null;
      return categoryFor<ParcelBand<T>>(categories: bands, selected: selected, kg: kg, titleOf: (b) => b.title);
    }
    final List<ParcelBand<T>> withKg = bands.where((b) => b.minKg != null || b.maxKg != null).toList()..sort((a, b) => (a.minKg ?? 0).compareTo(b.minKg ?? 0));
    ParcelBand<T>? containing;
    for (final b in withKg) {
      if (kg + _eps >= (b.minKg ?? 0) && (b.maxKg == null || kg <= b.maxKg! + _eps)) {
        containing = b;
        break;
      }
    }
    if (containing == null) {
      for (final b in withKg) {
        if ((b.minKg ?? 0) > kg) {
          containing = b;
          break;
        }
      }
    }
    if (containing == null) {
      ParcelBand<T> heaviest = withKg.first;
      for (final b in withKg) {
        if (b.maxKg == null || (heaviest.maxKg != null && b.maxKg! > heaviest.maxKg!)) heaviest = b;
      }
      containing = heaviest;
    }
    // Moves up, never down (the website's `effectiveBand()`, BUG-REPORT-01-WEB
    // section 41): the heavier of the band the customer chose and the band of
    // the chargeable weight.
    if (selected != null && (selected.minKg != null || selected.maxKg != null) && isHeavierBand(selected, containing)) return selected;
    return containing;
  }

  /// [a] is a heavier band than [b]: a higher lower limit, else a higher upper
  /// limit (no upper limit = the heaviest).
  static bool isHeavierBand<T>(ParcelBand<T> a, ParcelBand<T> b) {
    final double aMin = a.minKg ?? 0, bMin = b.minKg ?? 0;
    if ((aMin - bMin).abs() > _eps) return aMin > bMin;
    if (a.maxKg == null) return b.maxKg != null;
    if (b.maxKg == null) return false;
    return a.maxKg! > b.maxKg! + _eps;
  }

  /// The candidate regions of the order, in order of preference (the SENDER's
  /// region: carriers, prices, currency, pickup points and payment methods all
  /// follow it). The first one is the primary region R (the platform option,
  /// pickup points); a carrier that names its regions is priced with the first
  /// candidate it serves (`DeliveryCarrierModel.servedRegion`).
  ///
  ///  1. every region of the zones around the sender ([senderZones], one list
  ///     per zone containing the sender) - a zone often serves a country
  ///     region AND a city region ("Yaounde": Cameroun + Yaounde-Cameroun);
  ///  2. else the published regions of the sender's country ([countryRegions],
  ///     on `countryCode`);
  ///  3. else the customer's region ([customerRegion]).
  ///
  /// Only regions that exist ([exists]; null = no region data, keep all) are
  /// kept: a zone still listing a deleted region ("Worldwide") must not make
  /// the order ambiguous. Order: the customer's own region first when it is a
  /// candidate, then the most specific - the region served by the fewest
  /// published zones ([allZones]; Yaounde-Cameroun before the country-level
  /// Cameroun) - ties in their original order.
  ///
  /// It used to return a single region and nothing at all when the sender's
  /// zone served several regions and the customer's own was not one of them;
  /// every carrier with `regionIds` was then dropped and the carrier choice
  /// disappeared from the parcel flow.
  static List<String> orderRegionCandidates({
    List<List<String>> senderZones = const [],
    List<List<String>> allZones = const [],
    bool Function(String regionId)? exists,
    List<String> countryRegions = const [],
    String? customerRegion,
  }) {
    final String mine = (customerRegion ?? '').trim();
    List<String> clean(Iterable<String> ids) => ids.map((e) => e.trim()).where((e) => e.isNotEmpty && (exists == null || exists(e))).toSet().toList();
    final List<List<String>> counted = allZones.isNotEmpty ? allZones : senderZones;
    int zonesServing(String id) => counted.where((z) => z.contains(id)).length;
    List<String> ordered(List<String> ids) {
      final List<({String id, int index, int zones})> rows = [for (int i = 0; i < ids.length; i++) (id: ids[i], index: i, zones: zonesServing(ids[i]))];
      rows.sort((a, b) {
        final int am = a.id == mine ? 0 : 1, bm = b.id == mine ? 0 : 1;
        if (am != bm) return am.compareTo(bm);
        if (a.zones != b.zones) return a.zones.compareTo(b.zones);
        return a.index.compareTo(b.index);
      });
      return rows.map((r) => r.id).toList();
    }

    final List<String> atSender = clean(senderZones.expand((z) => z));
    if (atSender.isNotEmpty) return ordered(atSender);
    final List<String> inCountry = clean(countryRegions);
    if (inCountry.isNotEmpty) return ordered(inCountry);
    return clean([mine]);
  }

  // ---- Step 5: options ---------------------------------------------------------

  /// Each charge from the carrier's `regionPricing[R]` if set (0 included),
  /// else `regions[R].parcelPricing`, else 0. No carrier: the region directly.
  static ({double pickupCharge, double deliveryCharge}) resolveOptionCharges({
    required String pickupMethod,
    required String deliveryMethod,
    ParcelRateCard? carrierCard,
    RegionParcelPricing? regionPricing,
  }) {
    double pick(double? carrier, double? region) {
      final double v = carrier ?? region ?? 0;
      return v > 0 ? v : 0;
    }

    final double pickup = pickupMethod == ParcelMethod.pickupPoint
        ? pick(carrierCard?.pointDropoffCharge, regionPricing?.pointDropoffCharge)
        : pickupMethod == ParcelMethod.home
        ? pick(carrierCard?.homePickupCharge, regionPricing?.homePickupCharge)
        : 0;
    final double delivery = deliveryMethod == ParcelMethod.pickupPoint
        ? pick(carrierCard?.pointCollectionCharge, regionPricing?.pointCollectionCharge)
        : deliveryMethod == ParcelMethod.home
        ? pick(carrierCard?.homeDeliveryCharge, regionPricing?.homeDeliveryCharge)
        : 0;
    return (pickupCharge: pickup, deliveryCharge: delivery);
  }

  // ---- Steps 2-6 for one option ----------------------------------------------

  /// A carrier's quote (`source: rate_card`), or null when it is not offered
  /// (step 3) or its card sets no price. [card] is the carrier's card for R
  /// ([ParcelRateCard.forRegion]).
  static ParcelQuote? carrierQuote({
    required String scope,
    required ParcelRateCard card,
    required double distanceKm,
    required double actualKg,
    num? lengthCm,
    num? widthCm,
    num? heightCm,
    required String pickupMethod,
    required String deliveryMethod,
    RegionParcelPricing region = const RegionParcelPricing(),
    List<String> deliveryScopes = const [],
    double? maxWeight,
  }) {
    final ParcelWeight w = weightFor(actualKg: actualKg, lengthCm: lengthCm, widthCm: widthCm, heightCm: heightCm, carrierCard: card, region: region);
    if (!handlesScope(deliveryScopes, scope)) return null;
    if (maxWeight != null && maxWeight > 0 && maxWeight + _eps < w.chargeableKg) return null;
    final double? price = rateCardPrice(card: card, distanceKm: distanceKm, chargeableKg: w.chargeableKg);
    if (price == null) return null;
    final opt = resolveOptionCharges(pickupMethod: pickupMethod, deliveryMethod: deliveryMethod, carrierCard: card, regionPricing: region);
    return ParcelQuote(
      carrierPrice: price,
      fixedTax: region.fixedTaxFor(scope),
      pickupCharge: opt.pickupCharge,
      deliveryCharge: opt.deliveryCharge,
      source: ParcelPriceSource.rateCard,
      actualKg: w.actualKg,
      volumetricKg: w.volumetricKg,
      chargeableKg: w.chargeableKg,
      volumetricDivisor: w.divisor,
    );
  }

  /// No carrier (`source: default`): [distance] x the band's charge. [bandOf]
  /// picks the band for the chargeable weight ([bandFor]); null = no band.
  static ParcelQuote? defaultQuote<T>({
    required String scope,
    required double distance,
    required double actualKg,
    num? lengthCm,
    num? widthCm,
    num? heightCm,
    required String pickupMethod,
    required String deliveryMethod,
    required List<ParcelBand<T>> bands,
    ParcelBand<T>? selected,
    RegionParcelPricing region = const RegionParcelPricing(),
  }) {
    final ParcelWeight w = weightFor(actualKg: actualKg, lengthCm: lengthCm, widthCm: widthCm, heightCm: heightCm, region: region);
    final ParcelBand<T>? band = bandFor<T>(bands, w.chargeableKg, selected: selected);
    if (band == null) return null;
    final opt = resolveOptionCharges(pickupMethod: pickupMethod, deliveryMethod: deliveryMethod, regionPricing: region);
    return ParcelQuote(
      carrierPrice: distance * band.charge,
      fixedTax: region.fixedTaxFor(scope),
      pickupCharge: opt.pickupCharge,
      deliveryCharge: opt.deliveryCharge,
      source: ParcelPriceSource.defaultSetting,
      actualKg: w.actualKg,
      volumetricKg: w.volumetricKg,
      chargeableKg: w.chargeableKg,
      volumetricDivisor: w.divisor,
    );
  }

  // ---- Title matching (bands without minKg / maxKg) --------------------------

  /// Same-city weight category for a parcel charged on [kg]: [selected] while
  /// it covers [kg] (its title's upper limit, [categoryMaxKg]), else the
  /// LIGHTEST category whose upper limit does, else the heaviest one. Never
  /// lighter than what the customer picked; categories whose title holds no
  /// number are only ever kept when selected.
  static T categoryFor<T>({required List<T> categories, required T selected, required double kg, required String? Function(T) titleOf}) {
    final double? selectedMax = categoryMaxKg(titleOf(selected));
    if (kg <= 0 || selectedMax == null || selectedMax + _eps >= kg) return selected;
    T? best;
    double bestMax = double.infinity;
    T heaviest = selected;
    double heaviestMax = selectedMax;
    for (final T c in categories) {
      final double? max = categoryMaxKg(titleOf(c));
      if (max == null) continue;
      if (max > heaviestMax) {
        heaviest = c;
        heaviestMax = max;
      }
      if (max + _eps >= kg && max < bestMax) {
        best = c;
        bestMax = max;
      }
    }
    return best ?? heaviest;
  }

  /// Upper limit in kg of a weight category title ("Upto 5 kg", "1-5 kg",
  /// "500 g - 1 kg", "Above 20kg", "2 lbs"): the largest number in it, a
  /// number without a unit taking the unit of the next one (kg when none).
  /// Null when the title holds no number.
  static double? categoryMaxKg(String? title) {
    if (title == null) return null;
    final RegExp re = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kgs?|kilo\w*|grams?|gms?|g|lbs?|pounds?)?(?![a-z])', caseSensitive: false);
    final List<RegExpMatch> matches = re.allMatches(title).toList();
    if (matches.isEmpty) return null;
    double factor(String? unit) {
      final String u = (unit ?? '').toLowerCase();
      if (u.startsWith('g')) return 0.001;
      if (u.startsWith('lb') || u.startsWith('pound')) return 0.45359237;
      return 1;
    }

    double? best;
    for (int i = 0; i < matches.length; i++) {
      final double? value = double.tryParse(matches[i].group(1)!.replaceAll(',', '.'));
      if (value == null) continue;
      String? unit = matches[i].group(2);
      for (int j = i + 1; unit == null && j < matches.length; j++) {
        unit = matches[j].group(2);
      }
      final double kg = value * factor(unit);
      if (best == null || kg > best) best = kg;
    }
    return best;
  }

  /// Commission of the parcel section on [amount] ("Percent"/"Percentage" or fixed).
  static double commissionOn({required double amount, required String? type, required double? value}) {
    if (value == null || value <= 0) return 0;
    final String t = (type ?? '').toLowerCase();
    if (t == 'percent' || t == 'percentage') return round2(amount * value / 100);
    return value;
  }

  /// [quote] with the parcel section's commission (`sections/{id}.adminCommision`,
  /// its [type] and [value]) added as an extra (`settings/ParcelPricing.commissionAsExtra`):
  /// a percentage is taken on the delivery company's base price
  /// ([ParcelQuote.carrierPrice]) only - never on the options, the fixed tax,
  /// the SMS fee or a tax.
  static ParcelQuote withExtraCommission(ParcelQuote quote, {required String? type, required double? value}) =>
      quote.copyWith(commission: commissionOn(amount: quote.carrierPrice, type: type, value: value));

  /// The amount the order taxes (`taxSetting`) apply to: subTotal - coupon,
  /// less the commission added as an extra ([commission],
  /// `priceBreakdown.commission`) - no tax is charged on that commission.
  /// Never below 0.
  static double taxableAmount({required double subTotal, required double discount, double commission = 0}) {
    final double base = subTotal - discount - (commission.isFinite && commission > 0 ? commission : 0);
    return base.isFinite && base > 0 ? base : 0;
  }

  static double round2(double v) => (v * 100).roundToDouble() / 100;
}
