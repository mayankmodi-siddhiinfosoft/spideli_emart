/// A row of `delivery_carriers` — admin spec §11 ("Carriers / delivery
/// companies"), client point 18.
///
/// The admin panel owns this document. Its shape (APP-SPEC-ADMIN §11):
///
/// ```
/// name, code, countryCode, phone, regionIds,
/// operatingLicence, commercialRegister, uniqueIdNumber,
/// operatingLicenceFile, commercialRegisterFile, uniqueIdNumberFile, isVerified,
/// baseCharge, perKmCharge, perKgCharge, minimumCharge, maxWeight,
/// minDeliveryTime, maxDeliveryTime, deliveryTimeUnit, conditions
/// ```
///
/// The company may maintain only the commercial / operational fields
/// ([editableFields]), always under those exact keys. Everything the admin
/// verifies ([readOnlyFields]) is shown, never written.
///
/// Report Doc 43: pricing is per region. `regionPricing` is the source of
/// truth:
///
/// ```
/// regionPricing: { "<regionId>": { baseCharge, perKmCharge, perKgCharge, minimumCharge } }
/// ```
///
/// The flat charges still exist but carry the FIRST region's price (or the
/// one "everywhere" price of a carrier with no `regionIds`). [chargeFor]
/// reads the region first and the flat field only as a fallback.
///
/// Older app builds wrote `rates`, `deliveryTimes`, `contactName` and `email`,
/// which the panel never reads. They are read **only** to pre-fill an empty
/// field ([legacyPrefill]) and are never written back.
class DeliveryCarrierModel {
  /// Document id in `delivery_carriers`.
  final String id;

  /// The document exactly as stored.
  final Map<String, dynamic> raw;

  DeliveryCarrierModel({required this.id, required this.raw});

  // ── Field lists ──────────────────────────────────────────────────────────

  static const List<String> textFields = ['name', 'countryCode', 'phone', 'conditions'];

  /// The four charges — non-negative.
  static const List<String> chargeFields = ['baseCharge', 'perKmCharge', 'perKgCharge', 'minimumCharge'];

  /// Every numeric field: written as a number, or null when emptied (the panel
  /// reads null as "not set", never as zero).
  static const List<String> numberFields = [...chargeFields, 'maxWeight', 'minDeliveryTime', 'maxDeliveryTime'];

  static const String unitField = 'deliveryTimeUnit';

  /// The units the panel offers. A different stored value is kept as is.
  static const List<String> deliveryTimeUnits = ['hours', 'days'];

  /// What the company may write — nothing else, ever.
  static const List<String> editableFields = [...textFields, ...numberFields, unitField];

  /// Owned and verified by the admin: displayed, never written.
  static const List<String> readOnlyFields = [
    'isVerified',
    'code',
    'regionIds',
    'operatingLicence',
    'commercialRegister',
    'uniqueIdNumber',
    'operatingLicenceFile',
    'commercialRegisterFile',
    'uniqueIdNumberFile',
  ];

  // ── Reading ──────────────────────────────────────────────────────────────

  /// A canonical text field as stored ('' when absent).
  String text(String field) {
    final dynamic v = raw[field];
    if (v == null) return '';
    final String s = v.toString().trim();
    return s == 'null' ? '' : s;
  }

  /// A canonical numeric field as stored (number or numeric string), else null.
  num? number(String field) => parseNumber(raw[field]);

  static num? parseNumber(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final String s = v.toString().trim().replaceAll(',', '.');
    if (s.isEmpty || s == 'null') return null;
    return num.tryParse(s);
  }

  /// Display form of a number: `500`, not `500.0`.
  static String formatNumber(num? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static const String regionPricingField = 'regionPricing';

  /// `regionPricing` as stored: regionId -> {charge field: value}. Entries
  /// that are not maps are ignored.
  Map<String, Map<String, dynamic>> get regionPricing {
    final dynamic v = raw[regionPricingField];
    if (v is! Map) return const {};
    return {
      for (final entry in v.entries)
        if (entry.value is Map && entry.key.toString().isNotEmpty) entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
    };
  }

  /// The price of [field] in [regionId] from `regionPricing`, or null.
  num? regionCharge(String regionId, String field) => parseNumber(regionPricing[regionId]?[field]);

  /// The price of [field] for an order of [regionId]: `regionPricing` first,
  /// the flat field as the fallback (no region, or no entry for it).
  num? chargeFor(String? regionId, String field) {
    final String region = (regionId ?? '').trim();
    if (region.isNotEmpty) {
      final num? regional = regionCharge(region, field);
      if (regional != null) return regional;
    }
    return number(field);
  }

  /// True when the carrier is priced per region (it serves named regions).
  /// A carrier with no `regionIds` serves everywhere at the flat price.
  bool get pricedPerRegion => regionIds.isNotEmpty;

  /// The write for changed regional prices: [changes] is regionId ->
  /// {charge field -> new value (null = not set)}. Regions the carrier does
  /// not serve and non-charge fields are dropped. The FIRST region's values
  /// are mirrored to the flat fields, as the panel does. `paths` are the
  /// exact field paths to merge, so no other price is touched.
  ({Map<String, dynamic> data, List<List<String>> paths}) regionPricingUpdate(Map<String, Map<String, num?>> changes) {
    final List<String> served = regionIds;
    final Map<String, dynamic> nested = {};
    final Map<String, dynamic> data = {};
    final List<List<String>> paths = [];
    for (final region in changes.entries) {
      if (!served.contains(region.key)) continue;
      for (final field in region.value.entries) {
        if (!chargeFields.contains(field.key)) continue;
        (nested[region.key] ??= <String, dynamic>{})[field.key] = field.value;
        paths.add([regionPricingField, region.key, field.key]);
        if (region.key == served.first) {
          data[field.key] = field.value;
          paths.add([field.key]);
        }
      }
    }
    if (nested.isNotEmpty) data[regionPricingField] = nested;
    return (data: data, paths: paths);
  }

  List<String> get regionIds {
    final dynamic v = raw['regionIds'];
    if (v is Iterable) return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    return const [];
  }

  /// True when the admin marked this carrier verified. Read only.
  bool get isVerified {
    final dynamic v = raw['isVerified'];
    if (v is bool) return v;
    return v != null && v.toString().toLowerCase() == 'true';
  }

  // ── Legacy pre-fill (read only, never written) ───────────────────────────

  /// The value an EMPTY editable field is pre-filled with, from spellings
  /// older builds wrote. '' when there is nothing to borrow. Never used when
  /// the canonical field holds a value.
  String legacyPrefill(String field) {
    String firstText(List<String> keys) {
      for (final key in keys) {
        final dynamic v = raw[key];
        if (v == null) continue;
        final String s = v.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
      return '';
    }

    final String rates = firstText(const ['rates', 'rate', 'deliveryRate', 'pricePerKg', 'price']);
    final String times = firstText(const ['deliveryTimes', 'deliveryTime', 'delivery_times', 'deliveryDuration']);
    final List<num> timeNumbers = _numbersIn(times);

    switch (field) {
      case 'name':
        return firstText(const ['title', 'carrierName', 'companyName']);
      case 'phone':
        return firstText(const ['phoneNumber', 'contactPhone', 'mobile']);
      case 'conditions':
        return firstText(const ['terms', 'conditionsOfCarriage', 'notes']);
      case 'maxWeight':
        return formatNumber(_numbersIn(firstText(const ['maximumWeight', 'max_weight', 'weightLimit'])).firstOrNull);
      // The old free-text "Rates" field was hinted "e.g. 1500 per kg".
      case 'perKgCharge':
        return formatNumber(_numbersIn(rates).firstOrNull);
      // The old free-text "Delivery Times" field was hinted "e.g. 24 - 48 hours".
      case 'minDeliveryTime':
        return formatNumber(timeNumbers.firstOrNull);
      case 'maxDeliveryTime':
        return timeNumbers.length > 1 ? formatNumber(timeNumbers[1]) : '';
      case unitField:
        final String lower = times.toLowerCase();
        if (lower.contains('day') || lower.contains('jour')) return 'days';
        if (lower.contains('hour') || lower.contains('heure') || RegExp(r'\d\s*h\b').hasMatch(lower)) return 'hours';
        return '';
    }
    return '';
  }

  static List<num> _numbersIn(String s) =>
      RegExp(r'\d+(?:[.,]\d+)?').allMatches(s).map((m) => num.tryParse(m.group(0)!.replaceAll(',', '.'))).whereType<num>().toList();
}
