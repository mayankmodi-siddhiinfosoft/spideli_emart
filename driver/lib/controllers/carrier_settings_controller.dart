import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Client point 18 — a driver registered as "Company" manages, from the app,
/// the carrier settings the admin panel holds in `delivery_carriers`.
///
/// The panel owns the link and the verification; this screen only edits the
/// commercial fields a carrier maintains itself. When nothing links this
/// company to a carrier the screen says so and changes nothing — it never
/// creates a `delivery_carriers` document.
class CarrierSettingsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  /// Null once loading has finished = no carrier is linked to this company.
  final Rx<DeliveryCarrierModel?> carrier = Rx<DeliveryCarrierModel?>(null);

  /// `isVerified` is shown, never edited.
  final RxBool isVerified = false.obs;
  final RxString carrierId = ''.obs;

  final Map<String, TextEditingController> fields = {
    for (final field in DeliveryCarrierModel.editableFields) field: TextEditingController(),
  };

  TextEditingController controllerFor(String field) => fields[field]!;

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
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    final DeliveryCarrierModel? found = await CarrierDispatchService.myCarrier();
    carrier.value = found;
    carrierId.value = found?.id ?? '';
    isVerified.value = found?.isVerified ?? false;
    if (found != null) {
      for (final field in DeliveryCarrierModel.editableFields) {
        fields[field]!.text = found.value(field);
      }
    }
    isLoading.value = false;
    update();
  }

  Future<void> save() async {
    final DeliveryCarrierModel? current = carrier.value;
    if (current == null) {
      ShowToastDialog.showToast("No carrier is linked to your company yet.".tr);
      return;
    }
    if (fields['name']!.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter the carrier name".tr);
      return;
    }
    isSaving.value = true;
    ShowToastDialog.showLoader("Please wait".tr);
    final bool ok = await CarrierDispatchService.saveCarrierSettings(
      current,
      {for (final field in DeliveryCarrierModel.editableFields) field: fields[field]!.text},
    );
    ShowToastDialog.closeLoader();
    isSaving.value = false;
    if (!ok) {
      ShowToastDialog.showToast("Your carrier settings could not be saved. Please try again.".tr);
      return;
    }
    ShowToastDialog.showToast("Carrier settings saved".tr);
    await load();
  }
}
