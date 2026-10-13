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
/// Prices per region are filled afterwards in Carrier settings.
///
/// Error values are untranslated message keys (the caller calls `.tr`).
class CarrierSetupForm {
  CarrierSetupForm._();

  static const String errPhone = 'Please enter the phone number';
  static const String errEmail = 'Please enter a valid email address';
  static const String errRegions = 'Select at least one region';

  /// The registration numbers and their document photo fields.
  static const List<String> registrationFields = ['operatingLicence', 'commercialRegister', 'uniqueIdNumber'];

  static String fileField(String field) => '${field}File';

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// [texts]: name, phone, email, conditions, maxWeight, minDeliveryTime,
  /// maxDeliveryTime and the [registrationFields]. [files]: uploaded URLs by
  /// file field (`operatingLicenceFile`, ...) and `photo` (the logo).
  /// Returns the document to create, or the errors (field -> message key).
  static ({Map<String, dynamic> data, Map<String, String> errors}) build({
    required String ownerId,
    required Map<String, String> texts,
    required String countryCode,
    required List<String> regionIds,
    required List<String> deliveryScopes,
    required String deliveryTimeUnit,
    Map<String, String> files = const {},
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
      for (final field in registrationFields) field: text(field),
      for (final field in registrationFields)
        if ((files[fileField(field)] ?? '').trim().isNotEmpty) fileField(field): files[fileField(field)]!.trim(),
      if ((files['photo'] ?? '').trim().isNotEmpty) 'photo': files['photo']!.trim(),
      // Admin-owned from here on: the owner never changes these again.
      'ownerId': ownerId,
      'isVerified': false,
      'publish': false,
      'createdFrom': 'driver_app',
    };
    return (data: data, errors: errors);
  }
}
