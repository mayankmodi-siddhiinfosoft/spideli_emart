import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/utils/carrier_settings_form.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The owner's "Carrier settings" (APP-DEV-BRIEF 12 Oct 2026 section 6).
///
/// Only for an owner account (`isOwner == true`). The carrier is the one the
/// admin bound to it (`users/{uid}.carrierId`); without one the screen only
/// says "Your carrier has not been set up yet — please contact Spideli." The
/// app never creates or links a carrier.
///
/// Editable: per region in `regionIds`, `regionPricing.<R>` (the four prices
/// and the five values), `deliveryScopes`, `minDeliveryTime`,
/// `maxDeliveryTime`, `deliveryTimeUnit`, `maxWeight`, `conditions` (and the
/// contact fields). Never: `isVerified`, `publish`, `ownerId`, `code`,
/// `regionIds`, the documents, the region's fixed charges. Saved with a
/// field-path `update()` of the changed keys only.
class CarrierSettingsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  /// The logged-in account is an owner (the screen is for owners only).
  final RxBool isOwner = false.obs;

  /// Null once loading has finished = no carrier bound to this owner yet.
  final Rx<DeliveryCarrierModel?> carrier = Rx<DeliveryCarrierModel?>(null);

  /// `isVerified` is shown, never edited (admin only).
  final RxBool isVerified = false.obs;
  final RxBool published = false.obs;
  final RxString carrierId = ''.obs;

  static const String scopeCity = 'city';
  static const String scopeIntercity = 'intercity';
  static const String scopeIntercountry = 'intercountry';
  static const List<String> allScopes = DeliveryCarrierModel.allDeliveryScopes;

  /// The checked scopes (a carrier without `deliveryScopes` handles all three).
  final RxList<String> deliveryScopes = <String>[].obs;

  /// Text inputs: contact fields, conditions and the top-level numbers.
  final Map<String, TextEditingController> fields = {};

  TextEditingController controllerFor(String field) => fields.putIfAbsent(field, () => TextEditingController());

  /// `regionPricing` inputs: "regionId|field" -> controller.
  final Map<String, TextEditingController> regionFields = {};
  final RxList<String> pricedRegionIds = <String>[].obs;
  final RxMap<String, String> regionLabels = <String, String>{}.obs;

  static String regionKey(String regionId, String field) => CarrierSettingsForm.regionKey(regionId, field);

  TextEditingController regionControllerFor(String regionId, String field) => regionFields.putIfAbsent(regionKey(regionId, field), () => TextEditingController());

  /// Dial code, e.g. `+237`, as stored.
  final RxString countryCode = ''.obs;

  /// `hours` / `days`.
  final RxString deliveryTimeUnit = 'hours'.obs;
  final RxList<String> deliveryTimeUnitOptions = <String>[...DeliveryCarrierModel.deliveryTimeUnits].obs;

  /// Field -> validation message.
  final RxMap<String, String> errors = <String, String>{}.obs;

  /// Admin-owned values, read only.
  final RxString code = ''.obs;
  final RxList<String> regionNames = <String>[].obs;

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

  /// The empty field's hint: the region default of one of the five values
  /// (`regions/{regionId}.parcelPricing`), as the admin form shows it.
  String regionHint(String regionId, String field, {String fallback = ''}) {
    if (!DeliveryCarrierModel.parcelPricingFields.contains(field)) return fallback;
    final num? def = RegionService.parcelPricingDefault(regionId, field);
    if (field == 'volumetricDivisor') {
      return def != null && def > 0 ? 'Region default: @value'.trParams({'value': DeliveryCarrierModel.formatNumber(def)}) : 'Region default: size not used'.tr;
    }
    return 'Region default: @value'.trParams({'value': DeliveryCarrierModel.formatNumber(def ?? 0)});
  }

  /// "Littoral (FCFA)": every block's amounts are in that region's currency.
  String _regionLabel(String regionId) {
    final String name = RegionService.regionById(regionId)?.name ?? regionId;
    final currency = RegionService.currencyForRegion(regionId);
    final String unit = (currency?.symbol ?? '').trim().isNotEmpty ? currency!.symbol!.trim() : (currency?.code ?? '').trim();
    return unit.isEmpty ? name : '$name ($unit)';
  }

  Future<void> load() async {
    isLoading.value = true;
    errors.clear();
    isOwner.value = Constant.userModel?.isOwner == true;
    final DeliveryCarrierModel? found = isOwner.value ? await CarrierDispatchService.myCarrier() : null;
    carrier.value = found;
    carrierId.value = found?.id ?? '';
    isVerified.value = found?.isVerified ?? false;
    published.value = found?.publish ?? false;

    if (found != null) {
      // Fresh region defaults for the hints.
      await RegionService.ensureLoaded(force: true);
      for (final field in ['name', 'phone', 'email', 'conditions', ...CarrierSettingsForm.numberFieldsFor(found)]) {
        controllerFor(field).text = _initialText(found, field);
      }
      countryCode.value = found.text('countryCode');
      final String unit = _initialText(found, DeliveryCarrierModel.unitField);
      deliveryTimeUnit.value = unit.isNotEmpty ? unit : 'hours';
      deliveryTimeUnitOptions.value = [
        ...DeliveryCarrierModel.deliveryTimeUnits,
        if (unit.isNotEmpty && !DeliveryCarrierModel.deliveryTimeUnits.contains(unit)) unit,
      ];
      code.value = found.code;
      deliveryScopes.value = List<String>.from(found.effectiveDeliveryScopes);
      regionNames.value = found.regionIds.map((id) => RegionService.regionById(id)?.name ?? id).toList();
      regionLabels.value = {for (final id in found.regionIds) id: _regionLabel(id)};
      for (final regionId in found.regionIds) {
        for (final field in DeliveryCarrierModel.chargeFields) {
          // The block as stored: an empty value stays empty (= region default).
          regionControllerFor(regionId, field).text = DeliveryCarrierModel.formatNumber(found.regionCharge(regionId, field));
        }
      }
      pricedRegionIds.value = found.regionIds;
    }
    isLoading.value = false;
    update();
  }

  String _initialText(DeliveryCarrierModel carrier, String field) {
    final String stored = DeliveryCarrierModel.numberFields.contains(field) ? DeliveryCarrierModel.formatNumber(carrier.number(field)) : carrier.text(field);
    return stored.isNotEmpty ? stored : carrier.legacyPrefill(field);
  }

  /// Toggles a delivery scope; at least one stays checked.
  void toggleDeliveryScope(String scope) {
    if (deliveryScopes.contains(scope)) {
      if (deliveryScopes.length <= 1) {
        ShowToastDialog.showToast(CarrierSettingsForm.errScopes.tr);
        return;
      }
      deliveryScopes.remove(scope);
    } else {
      deliveryScopes.add(scope);
    }
    errors.remove(DeliveryCarrierModel.scopesField);
    update();
  }

  void setCountryCode(String? dialCode) {
    countryCode.value = (dialCode ?? '').trim();
  }

  String shownDialCode = '';

  void onPickerShown(String? dialCode) {
    shownDialCode = (dialCode ?? '').trim();
  }

  void setDeliveryTimeUnit(String? unit) {
    deliveryTimeUnit.value = (unit ?? '').trim();
  }

  Future<void> save() async {
    final DeliveryCarrierModel? current = carrier.value;
    if (current == null || !isOwner.value) return;
    final result = CarrierSettingsForm.diff(
      carrier: current,
      texts: {for (final e in fields.entries) e.key: e.value.text},
      regionTexts: {
        for (final regionId in current.regionIds) regionId: {for (final f in DeliveryCarrierModel.chargeFields) f: regionControllerFor(regionId, f).text},
      },
      deliveryScopes: deliveryScopes.toList(),
      deliveryTimeUnit: deliveryTimeUnit.value,
      // A phone saved without a dial code takes the one the picker shows.
      countryCode: countryCode.value.isNotEmpty ? countryCode.value : ((fields['phone']?.text.trim() ?? '') != current.text('phone') ? shownDialCode : ''),
    );
    errors.value = {for (final e in result.errors.entries) e.key: e.value.tr};
    if (errors.isNotEmpty) {
      ShowToastDialog.showToast(errors.values.first);
      return;
    }
    if (result.changes.isEmpty && result.regionChanges.isEmpty) {
      ShowToastDialog.showToast("Nothing to save".tr);
      return;
    }
    isSaving.value = true;
    ShowToastDialog.showLoader("Please wait".tr);
    final bool ok = await CarrierDispatchService.saveCarrierSettings(current, result.changes, regionChanges: result.regionChanges);
    ShowToastDialog.closeLoader();
    isSaving.value = false;
    if (!ok) {
      ShowToastDialog.showToast("Your carrier settings could not be saved. Please try again.".tr);
      return;
    }
    ShowToastDialog.showToast("Carrier settings saved".tr);
    await load();
  }

  String get pickerInitialSelection {
    final String stored = countryCode.value.trim();
    if (stored.isNotEmpty) return stored;
    return Constant.defaultCountryCode;
  }
}
