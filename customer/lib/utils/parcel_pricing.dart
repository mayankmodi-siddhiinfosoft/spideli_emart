// Parcel / mail pricing (spec Section 5, PARCEL-CONTRACT "Pricing").
//
// Pure Dart on purpose - no Flutter / Firestore imports - so the worked
// examples of spec 5.3 can be verified by a plain unit test
// (test/parcel_pricing_test.dart).

/// Shipment scope as stored on `parcel_orders.scope`.
class ParcelScope {
  ParcelScope._();

  static const String city = 'city';
  static const String intercity = 'intercity';
  static const String intercountry = 'intercountry';
}

/// Where a price comes from (`priceBreakdown.source`).
class ParcelPriceSource {
  ParcelPriceSource._();

  static const String rateTable = 'rate_table';
  static const String rateCard = 'rate_card';
  static const String defaultSetting = 'default';
  static const String manual = 'manual';
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final String s = value.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s.replaceAll(',', ''));
}

/// `settings/ParcelPricing` - every field optional, defaults per the contract.
class ParcelPricingSettings {
  final double intercityTax;
  final double intercountryTax;
  final double extraKgPrice;
  final double lastIntercityBandMaxKg;
  final double roundingStepKg;
  final String? currencyNote;

  /// Spec 5.1/5.2 "admin delivery commission (if configured as an extra)".
  /// false (default) = the commission is recorded on the order as the existing
  /// parcel checkout does, not added to the customer's price.
  final bool commissionAsExtra;

  const ParcelPricingSettings({
    this.intercityTax = 5000,
    this.intercountryTax = 5000,
    this.extraKgPrice = 1000,
    this.lastIntercityBandMaxKg = 10,
    this.roundingStepKg = 0.5,
    this.currencyNote,
    this.commissionAsExtra = false,
  });

  factory ParcelPricingSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ParcelPricingSettings();
    final double step = _num(json['roundingStepKg']) ?? 0.5;
    return ParcelPricingSettings(
      intercityTax: _num(json['intercityTax']) ?? 5000,
      intercountryTax: _num(json['intercountryTax']) ?? 5000,
      extraKgPrice: _num(json['extraKgPrice']) ?? 1000,
      lastIntercityBandMaxKg: _num(json['lastIntercityBandMaxKg']) ?? 10,
      roundingStepKg: step > 0 ? step : 0.5,
      currencyNote: json['currencyNote']?.toString(),
      commissionAsExtra: json['commissionAsExtra'] == true,
    );
  }

  double taxFor(String scope) {
    if (scope == ParcelScope.intercity) return intercityTax;
    if (scope == ParcelScope.intercountry) return intercountryTax;
    return 0;
  }
}

/// One intercity row: fixed price per directional route and weight band.
class IntercityRate {
  final String from;
  final String to;
  final double minKg;
  final double? maxKg; // null = open-ended
  final double price;

  const IntercityRate({required this.from, required this.to, required this.minKg, required this.maxKg, required this.price});

  static IntercityRate? fromJson(Map<String, dynamic> json) {
    final double? price = _num(json['price']);
    final String from = (json['from'] ?? '').toString().trim();
    final String to = (json['to'] ?? '').toString().trim();
    if (price == null || from.isEmpty || to.isEmpty) return null;
    return IntercityRate(from: from, to: to, minKg: _num(json['minKg']) ?? 0, maxKg: _num(json['maxKg']), price: price);
  }
}

/// One intercountry row: rate per kg per directional country route and band.
class IntercountryRate {
  final String fromCountry;
  final String toCountry;
  final double minKg;
  final double? maxKg; // null = open-ended
  final double ratePerKg;

  const IntercountryRate({required this.fromCountry, required this.toCountry, required this.minKg, required this.maxKg, required this.ratePerKg});

  static IntercountryRate? fromJson(Map<String, dynamic> json) {
    final double? rate = _num(json['ratePerKg']);
    final String from = (json['fromCountry'] ?? '').toString().trim();
    final String to = (json['toCountry'] ?? '').toString().trim();
    if (rate == null || from.isEmpty || to.isEmpty) return null;
    return IntercountryRate(fromCountry: from, toCountry: to, minKg: _num(json['minKg']) ?? 0, maxKg: _num(json['maxKg']), ratePerKg: rate);
  }
}

/// `delivery_carriers/{id}.rateTable`.
class ParcelRateTable {
  final List<IntercityRate> intercity;
  final List<IntercountryRate> intercountry;

  const ParcelRateTable({this.intercity = const [], this.intercountry = const []});

  bool get isEmpty => intercity.isEmpty && intercountry.isEmpty;

  static ParcelRateTable? fromJson(dynamic json) {
    if (json is! Map) return null;
    final List<IntercityRate> city = [];
    final List<IntercountryRate> country = [];
    if (json['intercity'] is List) {
      for (final row in json['intercity']) {
        if (row is Map) {
          final r = IntercityRate.fromJson(Map<String, dynamic>.from(row));
          if (r != null) city.add(r);
        }
      }
    }
    if (json['intercountry'] is List) {
      for (final row in json['intercountry']) {
        if (row is Map) {
          final r = IntercountryRate.fromJson(Map<String, dynamic>.from(row));
          if (r != null) country.add(r);
        }
      }
    }
    return ParcelRateTable(intercity: city, intercountry: country);
  }
}

/// The carrier's single rate card (spec 18.14). A null field = not set (not zero).
class ParcelRateCard {
  final double? baseCharge;
  final double? perKmCharge;
  final double? perKgCharge;
  final double? minimumCharge;

  const ParcelRateCard({this.baseCharge, this.perKmCharge, this.perKgCharge, this.minimumCharge});

  factory ParcelRateCard.fromJson(Map<String, dynamic> json) =>
      ParcelRateCard(baseCharge: _num(json['baseCharge']), perKmCharge: _num(json['perKmCharge']), perKgCharge: _num(json['perKgCharge']), minimumCharge: _num(json['minimumCharge']));

  bool get isSet => baseCharge != null || perKmCharge != null || perKgCharge != null || minimumCharge != null;
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

  /// Countries match by ISO code or by name, case-insensitively.
  bool countryMatches(String value) {
    final String v = _norm(value);
    if (v.isEmpty) return false;
    return v == _norm(countryCode) || v == _norm(country);
  }

  bool cityMatches(String value) {
    final String v = _norm(value);
    return v.isNotEmpty && v == _norm(city);
  }

  String get label {
    final List<String> parts = [if (city.trim().isNotEmpty) city.trim(), if (country.trim().isNotEmpty) country.trim() else if (countryCode.trim().isNotEmpty) countryCode.trim()];
    return parts.join(', ');
  }

  static String _norm(String s) => s.trim().toLowerCase();
}

/// Result of pricing one option. Amounts are in the ORIGIN region's currency.
class ParcelQuote {
  final double carrierPrice;
  final double extraKgCharge;
  final double fixedTax;
  final double commission;
  final double options;
  final String source;

  /// Chargeable weight used (intercountry rounding), for display.
  final double? chargeableKg;

  const ParcelQuote({required this.carrierPrice, this.extraKgCharge = 0, this.fixedTax = 0, this.commission = 0, this.options = 0, required this.source, this.chargeableKg});

  double get total => carrierPrice + extraKgCharge + fixedTax + commission + options;

  ParcelQuote copyWith({double? commission, double? options}) => ParcelQuote(
    carrierPrice: carrierPrice,
    extraKgCharge: extraKgCharge,
    fixedTax: fixedTax,
    commission: commission ?? this.commission,
    options: options ?? this.options,
    source: source,
    chargeableKg: chargeableKg,
  );
}

class ParcelPricing {
  ParcelPricing._();

  static const double _eps = 1e-9;

  /// Band whose [minKg, maxKg] holds [kg]: the band with the smallest maxKg
  /// >= kg (open-ended bands last). A weight falling in a gap between two
  /// bands (e.g. 2.05 kg between "501 g-2 kg" and "2.1-5 kg") is charged at
  /// the next band up.
  static T? _band<T>(List<T> bands, double kg, double? Function(T) maxOf) {
    T? best;
    double bestMax = double.infinity;
    bool bestOpen = true;
    for (final T b in bands) {
      final double? max = maxOf(b);
      if (max == null) {
        if (best == null) {
          best = b;
          bestOpen = true;
        }
        continue;
      }
      if (max + _eps < kg) continue;
      if (best == null || bestOpen || max < bestMax) {
        best = b;
        bestMax = max;
        bestOpen = false;
      }
    }
    return best;
  }

  /// Intercity (spec 5.1): band price for the directional route; above
  /// [ParcelPricingSettings.lastIntercityBandMaxKg] the price of the band
  /// holding that weight + extraKgPrice x ceil(weight - lastMax); + intercity tax.
  /// Null = the table has no price for this route / weight.
  static ParcelQuote? intercity({required ParcelRateTable table, required ParcelPlace origin, required ParcelPlace destination, required double weightKg, ParcelPricingSettings settings = const ParcelPricingSettings()}) {
    if (weightKg <= 0) return null;
    final List<IntercityRate> route = table.intercity.where((r) => origin.cityMatches(r.from) && destination.cityMatches(r.to)).toList();
    if (route.isEmpty) return null;
    final double lastMax = settings.lastIntercityBandMaxKg;
    if (weightKg > lastMax + _eps) {
      final IntercityRate? last = _band(route, lastMax, (r) => r.maxKg);
      if (last == null) return null;
      final int extraKg = (weightKg - lastMax - _eps).ceil();
      return ParcelQuote(carrierPrice: last.price, extraKgCharge: settings.extraKgPrice * extraKg, fixedTax: settings.intercityTax, source: ParcelPriceSource.rateTable, chargeableKg: weightKg);
    }
    final IntercityRate? band = _band(route, weightKg, (r) => r.maxKg);
    if (band == null) return null;
    return ParcelQuote(carrierPrice: band.price, fixedTax: settings.intercityTax, source: ParcelPriceSource.rateTable, chargeableKg: weightKg);
  }

  /// Weight rounded UP to the next [step] (0.5 kg by default).
  static double chargeableWeight(double weightKg, double step) {
    if (step <= 0) return weightKg;
    return (weightKg / step - _eps).ceil() * step;
  }

  /// Intercountry (spec 5.2): chargeable weight x ratePerKg of the band holding
  /// it + intercountry tax. Null = no rate for this route / weight.
  static ParcelQuote? intercountry({required ParcelRateTable table, required ParcelPlace origin, required ParcelPlace destination, required double weightKg, ParcelPricingSettings settings = const ParcelPricingSettings()}) {
    if (weightKg <= 0) return null;
    final List<IntercountryRate> route = table.intercountry.where((r) => origin.countryMatches(r.fromCountry) && destination.countryMatches(r.toCountry)).toList();
    if (route.isEmpty) return null;
    final double kg = chargeableWeight(weightKg, settings.roundingStepKg);
    final IntercountryRate? band = _band(route, kg, (r) => r.maxKg);
    if (band == null) return null;
    return ParcelQuote(carrierPrice: _round2(kg * band.ratePerKg), fixedTax: settings.intercountryTax, source: ParcelPriceSource.rateTable, chargeableKg: kg);
  }

  /// Rate-card fallback: max(minimumCharge, baseCharge + perKmCharge x km +
  /// perKgCharge x kg) with null fields ignored, + the scope tax.
  static ParcelQuote? rateCard({required ParcelRateCard card, required String scope, required double distanceKm, required double weightKg, ParcelPricingSettings settings = const ParcelPricingSettings()}) {
    if (!card.isSet) return null;
    double price = (card.baseCharge ?? 0) + (card.perKmCharge ?? 0) * distanceKm + (card.perKgCharge ?? 0) * weightKg;
    if (card.minimumCharge != null && card.minimumCharge! > price) price = card.minimumCharge!;
    if (price <= 0) return null;
    return ParcelQuote(carrierPrice: _round2(price), fixedTax: settings.taxFor(scope), source: ParcelPriceSource.rateCard, chargeableKg: weightKg);
  }

  /// A carrier's price for the shipment: its rate table first (intercity /
  /// intercountry), else its rate card. Null = the carrier does not serve it.
  static ParcelQuote? carrierQuote({
    required String scope,
    ParcelRateTable? table,
    ParcelRateCard? card,
    required ParcelPlace origin,
    required ParcelPlace destination,
    required double weightKg,
    required double distanceKm,
    ParcelPricingSettings settings = const ParcelPricingSettings(),
  }) {
    ParcelQuote? quote;
    if (table != null && !table.isEmpty) {
      if (scope == ParcelScope.intercity) {
        quote = intercity(table: table, origin: origin, destination: destination, weightKg: weightKg, settings: settings);
      } else if (scope == ParcelScope.intercountry) {
        quote = intercountry(table: table, origin: origin, destination: destination, weightKg: weightKg, settings: settings);
      }
    }
    if (quote == null && card != null) {
      quote = rateCard(card: card, scope: scope, distanceKm: distanceKm, weightKg: weightKg, settings: settings);
    }
    return quote;
  }

  /// The existing eMart same-city price (distance x weight-category charge).
  static ParcelQuote cityDefault({required double distance, required double weightCategoryCharge}) =>
      ParcelQuote(carrierPrice: distance * weightCategoryCharge, source: ParcelPriceSource.defaultSetting);

  /// Commission of the parcel section on [amount] ("Percent"/"Percentage" or fixed).
  static double commissionOn({required double amount, required String? type, required double? value}) {
    if (value == null || value <= 0) return 0;
    final String t = (type ?? '').toLowerCase();
    if (t == 'percent' || t == 'percentage') return _round2(amount * value / 100);
    return value;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
