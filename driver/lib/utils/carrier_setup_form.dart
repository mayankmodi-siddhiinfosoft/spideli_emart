import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/utils/carrier_settings_form.dart';

/// The owner's "Set up your carrier" form: a company owner with no carrier
/// creates its own `delivery_carriers` document (decision of 13 Oct 2026,
/// replacing "the app never creates a carrier").
///
/// Pure (no Flutter / Firestore), unit tested in
/// `test/carrier_setup_form_test.dart`. The new carrier is always
/// `isVerified: false`, `publish: false`, `ownerId` = the owner: customers
/// are offered it only once the administrator verifies and publishes it.
/// No documents are submitted from the app. Every selected region gets its
/// prices (`regionPricing.<regionId>`): the four prices are required, the
/// five door / pickup-point values are optional (blank = region default).
///
/// Error values are untranslated message keys (the caller calls `.tr`).
class CarrierSetupForm {
  CarrierSetupForm._();

  static const String errPhone = 'Please enter the phone number';
  static const String errEmail = 'Please enter a valid email address';
  static const String errRegions = 'Select at least one region';
  static const String errPrice = 'Please enter this price';

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// [texts]: name, phone, email, conditions, maxWeight, minDeliveryTime,
  /// maxDeliveryTime. [regionTexts]: regionId -> charge field -> text (the
  /// error key of a price is [CarrierSettingsForm.regionKey]). [logoUrl]: the
  /// uploaded logo (`photo`). Returns the document to create, or the errors
  /// (field -> message key).
  static ({Map<String, dynamic> data, Map<String, String> errors}) build({
    required String ownerId,
    required Map<String, String> texts,
    required String countryCode,
    required List<String> regionIds,
    required List<String> deliveryScopes,
    required String deliveryTimeUnit,
    Map<String, Map<String, String>> regionTexts = const {},
    String logoUrl = '',
  }) {
    final Map<String, String> errors = {};
    String text(String field) => (texts[field] ?? '').trim();

    if (text('name').isEmpty) errors['name'] = CarrierSettingsForm.errRequiredName;
    if (text('phone').isEmpty) errors['phone'] = errPhone;
    if (text('email').isNotEmpty && !_email.hasMatch(text('email'))) errors['email'] = errEmail;

    final List<String> regions = regionIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (regions.isEmpty) errors['regionIds'] = errRegions;

    final List<String> scopes = DeliveryCarrierModel.allDeliveryScopes.where(deliveryScopes.contains).toList();
    if (scopes.isEmpty) errors[DeliveryCarrierModel.scopesField] = CarrierSettingsForm.errScopes;

    final Map<String, num?> numbers = {};
    for (final field in const ['maxWeight', 'minDeliveryTime', 'maxDeliveryTime']) {
      final (num? value, String? error) = CarrierSettingsForm.parse(text(field));
      if (error != null) {
        errors[field] = error;
      } else {
        numbers[field] = value;
      }
    }
    final num? minTime = numbers['minDeliveryTime'], maxTime = numbers['maxDeliveryTime'];
    if (minTime != null && maxTime != null && minTime > maxTime) errors['maxDeliveryTime'] = CarrierSettingsForm.errTimes;

    // Prices per selected region.
    final Map<String, Map<String, num>> regionPricing = {};
    for (final regionId in regions) {
      final Map<String, num> block = {};
      for (final field in DeliveryCarrierModel.chargeFields) {
        final String key = CarrierSettingsForm.regionKey(regionId, field);
        final (num? value, String? error) = CarrierSettingsForm.parse(regionTexts[regionId]?[field] ?? '');
        if (error != null) {
          errors[key] = error;
        } else if (value != null) {
          block[field] = value;
        } else if (DeliveryCarrierModel.standardChargeFields.contains(field)) {
          errors[key] = errPrice;
        }
      }
      regionPricing[regionId] = block;
    }

    if (errors.isNotEmpty) return (data: const <String, dynamic>{}, errors: errors);

    final String unit = deliveryTimeUnit.trim();
    final Map<String, dynamic> data = {
      'name': text('name'),
      'countryCode': countryCode.trim(),
      'phone': text('phone'),
      'email': text('email'),
      'conditions': text('conditions'),
      'regionIds': regions,
      DeliveryCarrierModel.scopesField: scopes,
      for (final entry in numbers.entries)
        if (entry.value != null) entry.key: entry.value,
      if (unit.isNotEmpty) DeliveryCarrierModel.unitField: unit,
      DeliveryCarrierModel.regionPricingField: regionPricing,
      // The flat prices carry the FIRST region's, as the panel writes them.
      for (final field in DeliveryCarrierModel.standardChargeFields) field: regionPricing[regions.first]![field],
      if (logoUrl.trim().isNotEmpty) 'photo': logoUrl.trim(),
      // Admin-owned from here on: the owner never changes these again.
      'ownerId': ownerId,
      'isVerified': false,
      'publish': false,
      'createdFrom': 'driver_app',
    };
    return (data: data, errors: errors);
  }
}
