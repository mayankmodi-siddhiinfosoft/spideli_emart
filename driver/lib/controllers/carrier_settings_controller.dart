import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Client point 18 — a driver registered as "Company" manages, from the app,
/// the carrier settings the admin panel holds in `delivery_carriers`.
///
/// The panel owns the link and the verification; this screen edits only the
/// commercial / operational fields of the panel's own shape (admin spec §11),
/// under the panel's own keys, and writes only what the company changed. When
/// nothing links this company to a carrier the screen says so and changes
/// nothing — it never creates a `delivery_carriers` document.
class CarrierSettingsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  /// Null once loading has finished = no carrier is linked to this company.
  final Rx<DeliveryCarrierModel?> carrier = Rx<DeliveryCarrierModel?>(null);

  /// `isVerified` is shown, never edited.
  final RxBool isVerified = false.obs;
  final RxString carrierId = ''.obs;

  /// Text inputs: `name`, `phone`, `conditions` and every number field.
  /// (`countryCode` and `deliveryTimeUnit` are pickers, below.)
  final Map<String, TextEditingController> fields = {
    for (final field in DeliveryCarrierModel.editableFields)
      if (field != 'countryCode' && field != DeliveryCarrierModel.unitField) field: TextEditingController(),
  };

  TextEditingController controllerFor(String field) => fields[field]!;

  /// Report Doc 43: a carrier serving named regions is priced per region.
  /// One input per region and charge, keyed [regionKey]; prefilled from
  /// `regionPricing`, the flat charge only as a fallback.
  final Map<String, TextEditingController> regionFields = {};
  final RxList<String> pricedRegionIds = <String>[].obs;
  final RxMap<String, String> regionLabels = <String, String>{}.obs;

  static String regionKey(String regionId, String field) => '$regionId|$field';

  TextEditingController regionControllerFor(String regionId, String field) =>
      regionFields.putIfAbsent(regionKey(regionId, field), () => TextEditingController());

  bool get pricedPerRegion => pricedRegionIds.isNotEmpty;

  /// Dial code, e.g. `+237`, as the panel stores it.
  final RxString countryCode = ''.obs;

  /// `hours` / `days`, or whatever the panel already stored; '' = not set.
  final RxString deliveryTimeUnit = ''.obs;
  final RxList<String> deliveryTimeUnitOptions = <String>[...DeliveryCarrierModel.deliveryTimeUnits].obs;

  /// Field -> validation message, shown under the field.
  final RxMap<String, String> errors = <String, String>{}.obs;

  /// Admin-owned values, read only.
  final RxString code = ''.obs;
  final RxList<String> regionNames = <String>[].obs;
  final RxMap<String, String> identification = <String, String>{}.obs;
  final RxMap<String, bool> identificationFiles = <String, bool>{}.obs;

  @override
  void onInit() {
    load();
    super.onInit();
  }

  @override
  void onClose() {
    for (final c in fields.values) {
      c.dispose();
    }
    for (final c in regionFields.values) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errors.clear();
    final DeliveryCarrierModel? found = await CarrierDispatchService.myCarrier();
    carrier.value = found;
    carrierId.value = found?.id ?? '';
    isVerified.value = found?.isVerified ?? false;
    if (found != null) {
      for (final entry in fields.entries) {
        entry.value.text = _initialText(found, entry.key);
      }
      countryCode.value = _initialText(found, 'countryCode');
      final String unit = _initialText(found, DeliveryCarrierModel.unitField);
      deliveryTimeUnit.value = unit;
      deliveryTimeUnitOptions.value = [
        ...DeliveryCarrierModel.deliveryTimeUnits,
        // A value the panel stored that is not one of ours is kept selectable.
        if (unit.isNotEmpty && !DeliveryCarrierModel.deliveryTimeUnits.contains(unit)) unit,
      ];

      code.value = found.text('code');
      await RegionService.ensureLoaded();
      regionNames.value = found.regionIds.map((id) => RegionService.regionById(id)?.name ?? id).toList();
      regionLabels.value = {for (final id in found.regionIds) id: RegionService.regionById(id)?.name ?? id};
      for (final regionId in found.regionIds) {
        for (final field in DeliveryCarrierModel.chargeFields) {
          regionControllerFor(regionId, field).text = DeliveryCarrierModel.formatNumber(found.chargeFor(regionId, field));
        }
      }
      pricedRegionIds.value = found.regionIds;
      identification.value = {
        for (final f in const ['operatingLicence', 'commercialRegister', 'uniqueIdNumber']) f: found.text(f),
      };
      identificationFiles.value = {
        for (final f in const ['operatingLicenceFile', 'commercialRegisterFile', 'uniqueIdNumberFile']) f: found.text(f).isNotEmpty,
      };
    }
    isLoading.value = false;
    update();
  }

  /// The stored value, or — only when the canonical field is empty — a value
  /// borrowed from a spelling an older build wrote.
  String _initialText(DeliveryCarrierModel carrier, String field) {
    final String stored = DeliveryCarrierModel.numberFields.contains(field)
        ? DeliveryCarrierModel.formatNumber(carrier.number(field))
        : carrier.text(field);
    return stored.isNotEmpty ? stored : carrier.legacyPrefill(field);
  }

  /// Sets the dial code from the picker. The picker's own start-up callback
  /// never calls this, so merely opening the screen writes nothing.
  void setCountryCode(String? dialCode) {
    countryCode.value = (dialCode ?? '').trim();
  }

  /// The dial code the picker displays (its start-up selection), recorded
  /// without counting as a change.
  String shownDialCode = '';

  void onPickerShown(String? dialCode) {
    shownDialCode = (dialCode ?? '').trim();
  }

  void setDeliveryTimeUnit(String? unit) {
    deliveryTimeUnit.value = (unit ?? '').trim();
  }

  /// Validates and returns the typed value of every editable field, or null
  /// when something is invalid ([errors] says what).
  Map<String, dynamic>? _validatedValues() {
    final Map<String, String> found = {};
    final Map<String, dynamic> values = {};

    final String name = fields['name']!.text.trim();
    if (name.isEmpty) found['name'] = "Please enter the carrier name".tr;
    values['name'] = name;
    values['phone'] = fields['phone']!.text.trim();
    values['conditions'] = fields['conditions']!.text.trim();
    values['countryCode'] = countryCode.value.trim();
    values[DeliveryCarrierModel.unitField] = deliveryTimeUnit.value.trim();

    for (final field in DeliveryCarrierModel.numberFields) {
      // Per-region carriers price in [regionFields]; their flat charges are
      // the panel's copy of the first region and are not edited directly.
      if (pricedPerRegion && DeliveryCarrierModel.chargeFields.contains(field)) continue;
      final String text = fields[field]!.text.trim();
      if (text.isEmpty) {
        values[field] = null; // "not set", never zero.
        continue;
      }
      final num? n = DeliveryCarrierModel.parseNumber(text);
      if (n == null) {
        found[field] = "Enter a valid number".tr;
      } else if (n < 0) {
        found[field] = "This value cannot be negative".tr;
      } else {
        values[field] = n;
      }
    }

    for (final regionId in pricedRegionIds) {
      for (final field in DeliveryCarrierModel.chargeFields) {
        final String text = regionControllerFor(regionId, field).text.trim();
        final String key = regionKey(regionId, field);
        if (text.isEmpty) {
          values[key] = null;
          continue;
        }
        final num? n = DeliveryCarrierModel.parseNumber(text);
        if (n == null) {
          found[key] = "Enter a valid number".tr;
        } else if (n < 0) {
          found[key] = "This value cannot be negative".tr;
        } else {
          values[key] = n;
        }
      }
    }

    final num? minTime = values['minDeliveryTime'] as num?;
    final num? maxTime = values['maxDeliveryTime'] as num?;
    if (minTime != null && maxTime != null && minTime > maxTime) {
      found['maxDeliveryTime'] = "The maximum delivery time must not be less than the minimum".tr;
    }

    errors.value = found;
    return found.isEmpty ? values : null;
  }

  /// Only the fields whose value differs from what the document stores under
  /// the panel's key. A value pre-filled from an old spelling differs from the
  /// (empty) canonical field, so saving moves it to the key the panel reads.
  Map<String, dynamic> _changes(DeliveryCarrierModel carrier, Map<String, dynamic> values) {
    final Map<String, dynamic> changes = {};
    for (final entry in values.entries) {
      final String field = entry.key;
      if (field.contains('|')) continue; // regional prices: [_regionChanges]
      if (DeliveryCarrierModel.numberFields.contains(field)) {
        final num? after = entry.value as num?;
        // Numerically equal = untouched, even when the panel stored the number
        // as a string: it is not rewritten.
        if (carrier.number(field) == after) continue;
        changes[field] = after;
      } else {
        final String after = entry.value as String;
        if (after == carrier.text(field)) continue;
        changes[field] = after;
      }
    }
    // A phone number is never written without its dial code: when the
    // document has none and the company did not pick one, the code the picker
    // is showing is the one they saw next to the number.
    if (changes.containsKey('phone') &&
        (values['countryCode'] as String).isEmpty &&
        carrier.text('countryCode').isEmpty &&
        shownDialCode.isNotEmpty) {
      changes['countryCode'] = shownDialCode;
    }
    return changes;
  }

  /// The regional prices that differ from what the company was shown
  /// (`regionPricing`, else the flat fallback): regionId -> {charge: value}.
  Map<String, Map<String, num?>> _regionChanges(DeliveryCarrierModel carrier, Map<String, dynamic> values) {
    final Map<String, Map<String, num?>> changes = {};
    for (final regionId in pricedRegionIds) {
      for (final field in DeliveryCarrierModel.chargeFields) {
        final String key = regionKey(regionId, field);
        if (!values.containsKey(key)) continue;
        final num? after = values[key] as num?;
        if (carrier.chargeFor(regionId, field) == after) continue;
        (changes[regionId] ??= {})[field] = after;
      }
    }
    return changes;
  }

  Future<void> save() async {
    final DeliveryCarrierModel? current = carrier.value;
    if (current == null) {
      ShowToastDialog.showToast("No carrier is linked to your company yet.".tr);
      return;
    }
    final Map<String, dynamic>? values = _validatedValues();
    if (values == null) {
      ShowToastDialog.showToast(errors.values.first);
      return;
    }
    final Map<String, dynamic> changes = _changes(current, values);
    final Map<String, Map<String, num?>> regionChanges = _regionChanges(current, values);
    if (changes.isEmpty && regionChanges.isEmpty) {
      ShowToastDialog.showToast("Nothing to save".tr);
      return;
    }
    isSaving.value = true;
    ShowToastDialog.showLoader("Please wait".tr);
    final bool ok = await CarrierDispatchService.saveCarrierSettings(current, changes, regionChanges: regionChanges);
    ShowToastDialog.closeLoader();
    isSaving.value = false;
    if (!ok) {
      ShowToastDialog.showToast("Your carrier settings could not be saved. Please try again.".tr);
      return;
    }
    ShowToastDialog.showToast("Carrier settings saved".tr);
    await load();
  }

  /// Initial selection for the dial-code picker.
  String get pickerInitialSelection {
    final String stored = countryCode.value.trim();
    if (stored.isNotEmpty) return stored;
    return Constant.defaultCountryCode;
  }
}
