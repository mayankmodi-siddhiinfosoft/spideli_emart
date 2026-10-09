import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vendor/models/product_model.dart';

/// Product-level custom delivery charges in the Add / Edit Product screen
/// (bug point 60, APP-SPEC-PRODUCT-DELIVERY-CHARGES §2-3). Pure rules, kept
/// out of the controller so they can be unit-tested.
abstract final class ProductDeliveryCharges {
  /// `sections/{sectionId}.is_delivery_charge_customization`.
  static const String sectionFlag = 'is_delivery_charge_customization';

  static const int maxTiers = DeliveryChargeTier.maxTiers;

  // Translation keys (every one is in all 9 vendor/lib/lang files).
  static const String title = 'Delivery Charges';
  static const String note = 'Configure up to 5 custom distance-based delivery charges for this product.';
  static const String perKmLabel = 'Delivery Charges Per Km';
  static const String minimumChargeLabel = 'Minimum Delivery Charges';
  static const String withinKmLabel = 'Minimum Delivery Charge Within Km';
  static const String addLabel = 'Add Delivery Charge';
  static const String removeLabel = 'Remove delivery charge';
  static const String limitReached = 'You have reached the maximum limit of 5 delivery charges. You cannot add more.';
  static const String incompleteRow = 'Please fill all 3 fields for each delivery charge tier or remove empty rows.';

  static const List<String> translationKeys = [title, note, perKmLabel, minimumChargeLabel, withinKmLabel, addLabel, removeLabel, limitReached, incompleteRow];

  /// True only when the section document says `true` (a bool; the string
  /// "true" is accepted too). Missing, false, anything else, or an unreadable
  /// document (null) hides the editor.
  static bool isEnabledForSection(Map<String, dynamic>? sectionData) {
    final dynamic value = sectionData?[sectionFlag];
    if (value is bool) return value;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return false;
  }

  /// Another row may be added while there are fewer than [maxTiers].
  static bool canAdd(int rowCount) => rowCount < maxTiers;

  /// The limit warning shows (and the add button is disabled) at [maxTiers].
  static bool isLimitReached(int rowCount) => rowCount >= maxTiers;

  /// "Minimum Delivery Charges (FCFA)": the translated label followed by the
  /// store's currency symbol, or its code when there is no symbol.
  static String minimumChargeLabelWithCurrency(String translatedLabel, {String? symbol, String? code}) {
    final String unit = (symbol ?? '').trim().isNotEmpty ? symbol!.trim() : (code ?? '').trim();
    return unit.isEmpty ? translatedLabel : '$translatedLabel ($unit)';
  }

  /// A field's value: a finite number >= 0, or null when blank or invalid.
  static num? parseField(String text) {
    final num? value = parseDeliveryChargeNumber(text);
    if (value == null || value < 0) return null;
    return value;
  }

  /// Text shown for a stored value: 150 -> "150", 1.5 -> "1.5".
  static String formatValue(num value) {
    if (value is int) return value.toString();
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  /// Validates the rows on save. Every row present must have all 3 fields
  /// filled with a number >= 0; otherwise [incompleteRow] is returned as the
  /// error and nothing may be saved. No rows -> an empty list (saved as []).
  static ({List<DeliveryChargeTier>? tiers, String? error}) validate(List<({String perKm, String minimumCharge, String withinKm})> rows) {
    if (rows.length > maxTiers) return (tiers: null, error: limitReached);
    final List<DeliveryChargeTier> tiers = [];
    for (final row in rows) {
      final num? perKm = parseField(row.perKm);
      final num? minimumCharge = parseField(row.minimumCharge);
      final num? withinKm = parseField(row.withinKm);
      if (perKm == null || minimumCharge == null || withinKm == null) {
        return (tiers: null, error: incompleteRow);
      }
      tiers.add(DeliveryChargeTier(deliveryChargesPerKm: perKm, minimumDeliveryCharges: minimumCharge, minimumDeliveryChargesWithinKm: withinKm));
    }
    return (tiers: tiers, error: null);
  }

  /// Digits with at most one decimal separator ("." or ",") and at most two
  /// decimals; any other edit is refused.
  static final TextInputFormatter inputFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    return RegExp(r'^\d*([.,]\d{0,2})?$').hasMatch(newValue.text) ? newValue : oldValue;
  });

  /// Decimal keyboard (no sign: values are >= 0).
  static const TextInputType keyboardType = TextInputType.numberWithOptions(decimal: true);
}

/// One editable delivery charge row (three text fields).
class DeliveryChargeTierInput {
  final TextEditingController perKmController;
  final TextEditingController minimumChargeController;
  final TextEditingController withinKmController;

  DeliveryChargeTierInput({String perKm = '', String minimumCharge = '', String withinKm = ''})
    : perKmController = TextEditingController(text: perKm),
      minimumChargeController = TextEditingController(text: minimumCharge),
      withinKmController = TextEditingController(text: withinKm);

  factory DeliveryChargeTierInput.fromTier(DeliveryChargeTier tier) => DeliveryChargeTierInput(
    perKm: ProductDeliveryCharges.formatValue(tier.deliveryChargesPerKm),
    minimumCharge: ProductDeliveryCharges.formatValue(tier.minimumDeliveryCharges),
    withinKm: ProductDeliveryCharges.formatValue(tier.minimumDeliveryChargesWithinKm),
  );

  ({String perKm, String minimumCharge, String withinKm}) get values =>
      (perKm: perKmController.text, minimumCharge: minimumChargeController.text, withinKm: withinKmController.text);

  void dispose() {
    perKmController.dispose();
    minimumChargeController.dispose();
    withinKmController.dispose();
  }
}
