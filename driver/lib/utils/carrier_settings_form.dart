import 'package:driver/models/delivery_carrier_model.dart';

/// The owner's "Carrier settings" form (APP-DEV-BRIEF 12 Oct 2026 section 6,
/// app-spec-parcel-pricing 3.2 / 3.4) turned into the keys to update.
///
/// Pure (no Flutter / Firestore), unit tested in
/// `test/carrier_settings_form_test.dart`. Only what changed is returned;
/// [DeliveryCarrierModel.updatePaths] turns it into field paths.
///
/// * A blank number is `null` ("not set": the region default applies), never
///   0 — 0 is the owner's "free". Numbers are saved as numbers, never negative.
/// * `deliveryScopes`: at least one of city / intercity / intercountry.
/// * Error values are untranslated message keys (the caller calls `.tr`).
class CarrierSettingsForm {
  CarrierSettingsForm._();

  static const String errRequiredName = 'Please enter the carrier name';
  static const String errNumber = 'Enter a valid number';
  static const String errNegative = 'This value cannot be negative';
  static const String errTimes = 'The maximum delivery time must not be less than the minimum';
  static const String errScopes = 'At least one delivery scope must be selected';

  /// Error key of a region field.
  static String regionKey(String regionId, String field) => '$regionId|$field';

  /// The top-level number fields the form edits: the flat prices only for a
  /// carrier with no `regionIds` (one "everywhere" price).
  static List<String> numberFieldsFor(DeliveryCarrierModel carrier) => [
    if (carrier.regionIds.isEmpty) ...DeliveryCarrierModel.standardChargeFields,
    'maxWeight',
    'minDeliveryTime',
    'maxDeliveryTime',
  ];

  /// Parses one number input: (value, error key). Blank = (null, null).
  static (num?, String?) parse(String text) {
    final String t = text.trim();
    if (t.isEmpty) return (null, null);
    final num? n = DeliveryCarrierModel.parseNumber(t);
    if (n == null) return (null, errNumber);
    if (n < 0) return (null, errNegative);
    return (n, null);
  }

  /// [texts]: field -> text (name, phone, email, conditions and the number
  /// fields of [numberFieldsFor]). [regionTexts]: regionId -> field -> text
  /// for the carrier's `regionIds` and [DeliveryCarrierModel.chargeFields].
  static ({Map<String, dynamic> changes, Map<String, Map<String, num?>> regionChanges, Map<String, String> errors}) diff({
    required DeliveryCarrierModel carrier,
    required Map<String, String> texts,
    required Map<String, Map<String, String>> regionTexts,
    required List<String> deliveryScopes,
    required String deliveryTimeUnit,
    required String countryCode,
  }) {
    final Map<String, String> errors = {};
    final Map<String, dynamic> changes = {};

    for (final field in const ['name', 'phone', 'email', 'conditions']) {
      final String after = (texts[field] ?? '').trim();
      if (field == 'name' && after.isEmpty) errors['name'] = errRequiredName;
      if (after != carrier.text(field)) changes[field] = after;
    }
    final String code = countryCode.trim();
    if (code.isNotEmpty && code != carrier.text('countryCode')) changes['countryCode'] = code;

    final Map<String, num?> numbers = {};
    for (final field in numberFieldsFor(carrier)) {
      final (num? value, String? error) = parse(texts[field] ?? '');
      if (error != null) {
        errors[field] = error;
        continue;
      }
      numbers[field] = value;
      if (carrier.number(field) != value) changes[field] = value;
    }
    final num? minTime = numbers['minDeliveryTime'], maxTime = numbers['maxDeliveryTime'];
    if (minTime != null && maxTime != null && minTime > maxTime) errors['maxDeliveryTime'] = errTimes;

    final String unit = deliveryTimeUnit.trim();
    if (unit.isNotEmpty && unit != carrier.text(DeliveryCarrierModel.unitField)) changes[DeliveryCarrierModel.unitField] = unit;

    final List<String> scopes = DeliveryCarrierModel.allDeliveryScopes.where(deliveryScopes.contains).toList();
    if (scopes.isEmpty) {
      errors[DeliveryCarrierModel.scopesField] = errScopes;
    } else {
      final Set<String> before = carrier.effectiveDeliveryScopes.toSet();
      if (before.length != scopes.length || !scopes.every(before.contains)) changes[DeliveryCarrierModel.scopesField] = scopes;
    }

    final Map<String, Map<String, num?>> regionChanges = {};
    for (final regionId in carrier.regionIds) {
      for (final field in DeliveryCarrierModel.chargeFields) {
        final (num? value, String? error) = parse(regionTexts[regionId]?[field] ?? '');
        if (error != null) {
          errors[regionKey(regionId, field)] = error;
          continue;
        }
        if (carrier.regionCharge(regionId, field) == value) continue;
        (regionChanges[regionId] ??= {})[field] = value;
      }
    }
    return (changes: changes, regionChanges: regionChanges, errors: errors);
  }
}
