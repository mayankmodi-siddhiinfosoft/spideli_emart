/// A row of `delivery_carriers` — admin spec §11 ("Carriers / delivery
/// companies"), client point 18.
///
/// The admin panel owns this document. Its shape (APP-SPEC-ADMIN §11):
///
/// ```
/// name, code, countryCode, phone, email, logo, photo, regionIds,
/// operatingLicence, commercialRegister, uniqueIdNumber,
/// operatingLicenceFile, commercialRegisterFile, uniqueIdNumberFile, isVerified,
/// publish, baseCharge, perKmCharge, perKgCharge, minimumCharge, maxWeight,
/// minDeliveryTime, maxDeliveryTime, deliveryTimeUnit, conditions
/// ```
///
/// The company may maintain only the commercial / operational fields
/// ([editableFields]) and its `regionPricing` blocks, always under those exact
/// keys, through field-path `update()`s ([updatePaths]). Everything the admin
/// owns ([readOnlyFields]: verification, publish, owner, code, regions,
/// documents, the region fixed charges) is shown, never written. The admin
/// binds owners to carriers (`users/{ownerId}.carrierId` <->
/// `delivery_carriers/{id}.ownerId`); an owner with none creates its own
/// once (`CarrierSetupForm`, 13 Oct 2026), unverified and unpublished.
///
/// Report Doc 43: pricing is per region. `regionPricing` is the source of
/// truth:
///
/// ```
/// regionPricing: { "<regionId>": { baseCharge, perKmCharge, perKgCharge, minimumCharge,
///   volumetricDivisor, homePickupCharge, pointDropoffCharge, homeDeliveryCharge, pointCollectionCharge } }
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

  static const List<String> textFields = ['name', 'countryCode', 'phone', 'email', 'conditions'];

  /// The four prices (point 43). Inside `regionPricing.<R>`, and flat on the
  /// carrier (the FIRST region's mirror, or the one price of a carrier with no
  /// `regionIds`).
  static const List<String> standardChargeFields = ['baseCharge', 'perKmCharge', 'perKgCharge', 'minimumCharge'];

  /// The owner's five values (app-spec-parcel-pricing 3.2) — only ever inside
  /// `regionPricing.<R>`. Blank = null = "use the region default"; 0 = free.
  static const List<String> parcelPricingFields = [
    'volumetricDivisor',
    'homePickupCharge',
    'pointDropoffCharge',
    'homeDeliveryCharge',
    'pointCollectionCharge',
  ];

  /// Every key of a `regionPricing.<R>` block the owner edits.
  static const List<String> chargeFields = [...standardChargeFields, ...parcelPricingFields];

  /// Top-level numeric fields: written as a number, or null when emptied (the
  /// panel reads null as "not set", never as zero). The flat prices are edited
  /// only on a carrier with no `regionIds`.
  static const List<String> numberFields = [...standardChargeFields, 'maxWeight', 'minDeliveryTime', 'maxDeliveryTime'];

  static const String unitField = 'deliveryTimeUnit';
  static const String scopesField = 'deliveryScopes';

  /// The units the panel offers. A different stored value is kept as is.
  static const List<String> deliveryTimeUnits = ['hours', 'days'];

  /// `deliveryScopes` values (point 65). Missing / empty on the carrier = all.
  static const List<String> allDeliveryScopes = ['city', 'intercity', 'intercountry'];

  /// What the owner may write at the top level — nothing else, ever.
  static const List<String> editableFields = [...textFields, ...numberFields, unitField, scopesField];

  /// Owned by the admin: displayed, never written by the app (brief section 6).
  static const List<String> readOnlyFields = [
    'isVerified',
    'publish',
    'ownerId',
    'code',
    'regionIds',
    'operatingLicence',
    'commercialRegister',
    'uniqueIdNumber',
    'operatingLicenceFile',
    'commercialRegisterFile',
    'uniqueIdNumberFile',
    'intercityFixedTax',
    'intercountryFixedTax',
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
    final num? n = num.tryParse(s);
    return n == null || !n.isFinite ? null : n;
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

  /// The price of [field] for an order of [regionId]: `regionPricing` first,\
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

  /// The Firestore `update()` of the owner's changes, as field paths (each a
  /// list of segments) -> value. Nothing else of the document is touched.
  ///
  /// [changes]: top-level fields, already typed (a number, null for an
  /// emptied number, a list for `deliveryScopes`); anything outside
  /// [editableFields] is dropped. [regionChanges]: regionId -> {key -> value
  /// (null = blank = region default)}, written as
  /// `regionPricing.<regionId>.<key>`, only for regions in `regionIds` and
  /// keys in [chargeFields]. The first region's four PRICES are mirrored to
  /// the flat fields, as the panel does (never the five values).
  List<MapEntry<List<String>, dynamic>> updatePaths(Map<String, dynamic> changes, {Map<String, Map<String, num?>> regionChanges = const {}}) {
    final Map<String, MapEntry<List<String>, dynamic>> out = {};
    void put(List<String> path, dynamic value) => out[path.join('\u0000')] = MapEntry(path, value);
    for (final entry in changes.entries) {
      if (!editableFields.contains(entry.key) || readOnlyFields.contains(entry.key)) continue;
      put([entry.key], entry.value);
    }
    final List<String> served = regionIds;
    for (final region in regionChanges.entries) {
      if (!served.contains(region.key)) continue;
      for (final field in region.value.entries) {
        if (!chargeFields.contains(field.key)) continue;
        final num? value = field.value;
        if (value != null && value < 0) continue; // never negative
        put([regionPricingField, region.key, field.key], value);
        if (region.key == served.first && standardChargeFields.contains(field.key)) put([field.key], value);
      }
    }
    return out.values.toList();
  }

  List<String> get regionIds {
    final dynamic v = raw['regionIds'];
    if (v is Iterable) return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    return const [];
  }

  /// `deliveryScopes` as stored ('city', 'intercity', 'intercountry').
  /// Empty or missing = all three ([effectiveDeliveryScopes]).
  List<String> get deliveryScopes {
    final dynamic v = raw[scopesField];
    if (v is Iterable) return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }

  /// The scopes the carrier handles: missing / empty = all three.
  List<String> get effectiveDeliveryScopes => deliveryScopes.isEmpty ? allDeliveryScopes : deliveryScopes;

  /// True when the admin marked this carrier verified. Read only.
  bool get isVerified {
    final dynamic v = raw['isVerified'];
    if (v is bool) return v;
    return v != null && v.toString().toLowerCase() == 'true';
  }

  bool get publish {
    final dynamic v = raw['publish'];
    if (v is bool) return v;
    return v == null || v.toString().toLowerCase() != 'false';
  }

  String get code => text('code');
  String get email => text('email');
  /// `ownerId` (the binding of 9 Oct: never `companyId`).
  String get ownerId => text('ownerId');
  String get logo => text('logo').isNotEmpty ? text('logo') : text('photo');
  String get photo => text('photo').isNotEmpty ? text('photo') : text('logo');

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
      case 'email':
        return firstText(const ['contactEmail', 'carrierEmail']);
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
