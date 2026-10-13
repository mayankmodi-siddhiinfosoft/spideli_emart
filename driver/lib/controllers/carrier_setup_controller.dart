import 'dart:io';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/utils/carrier_setup_form.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// "Set up your carrier": a company owner with no carrier creates its own
/// (`CarrierSetupForm`, `CarrierDispatchService.createOwnCarrier`). The
/// carrier waits for the administrator's verification and publication;
/// prices per region are entered afterwards in Carrier settings.
class CarrierSetupController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  final Map<String, TextEditingController> fields = {};

  TextEditingController controllerFor(String field) => fields.putIfAbsent(field, () => TextEditingController());

  final RxString countryCode = ''.obs;
  final RxString deliveryTimeUnit = 'hours'.obs;
  final RxList<String> deliveryScopes = <String>[...DeliveryCarrierModel.allDeliveryScopes].obs;

  /// The regions offered, and the ones checked.
  final RxList<RegionModel> regions = <RegionModel>[].obs;
  final RxList<String> regionIds = <String>[].obs;

  /// Local image paths picked for the logo (`photo`) and the registration
  /// documents (`operatingLicenceFile`, ...), uploaded on submit.
  final RxMap<String, String> pickedFiles = <String, String>{}.obs;

  final RxMap<String, String> errors = <String, String>{}.obs;

  final ImagePicker _imagePicker = ImagePicker();

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
    final owner = Constant.userModel;
    // Pre-filled from the company profile; the owner may change them.
    controllerFor('name').text = (owner?.companyName ?? '').trim().isNotEmpty ? owner!.companyName!.trim() : (owner?.fullName() ?? '').trim();
    controllerFor('phone').text = (owner?.phoneNumber ?? '').trim();
    controllerFor('email').text = (owner?.email ?? '').trim();
    countryCode.value = (owner?.countryCode ?? '').trim();
    await RegionService.ensureLoaded();
    regions.value = RegionService.publishedRegions;
    final String? own = await RegionService.resolveUserRegionId(owner);
    if (own != null && regions.any((r) => r.id == own)) regionIds.value = [own];
    isLoading.value = false;
  }

  String get pickerInitialSelection => countryCode.value.trim().isNotEmpty ? countryCode.value.trim() : Constant.defaultCountryCode;

  void setCountryCode(String? dialCode) => countryCode.value = (dialCode ?? '').trim();

  void setDeliveryTimeUnit(String? unit) => deliveryTimeUnit.value = (unit ?? '').trim();

  void toggleRegion(String regionId) {
    regionIds.contains(regionId) ? regionIds.remove(regionId) : regionIds.add(regionId);
    errors.remove('regionIds');
  }

  void toggleDeliveryScope(String scope) {
    deliveryScopes.contains(scope) ? deliveryScopes.remove(scope) : deliveryScopes.add(scope);
    errors.remove(DeliveryCarrierModel.scopesField);
  }

  Future<void> pickImage(String field, ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 70);
      Get.back();
      if (image == null) return;
      pickedFiles[field] = image.path;
    } on PlatformException {
      ShowToastDialog.showToast("Could not pick the image.".tr);
    }
  }

  void removeImage(String field) => pickedFiles.remove(field);

  /// Validates, uploads the picked images, creates the carrier and binds it.
  /// True when the carrier exists and the owner is bound to it.
  Future<bool> submit() async {
    final owner = Constant.userModel;
    final String ownerId = (owner?.id ?? '').trim();
    if (ownerId.isEmpty || owner?.isOwner != true) return false;

    final Map<String, String> texts = {for (final e in fields.entries) e.key: e.value.text};
    final check = CarrierSetupForm.build(
      ownerId: ownerId,
      texts: texts,
      countryCode: countryCode.value.isNotEmpty ? countryCode.value : Constant.defaultCountryCode,
      regionIds: regionIds.toList(),
      deliveryScopes: deliveryScopes.toList(),
      deliveryTimeUnit: deliveryTimeUnit.value,
    );
    errors.value = {for (final e in check.errors.entries) e.key: e.value.tr};
    if (errors.isNotEmpty) {
      ShowToastDialog.showToast(errors.values.first);
      return false;
    }

    isSaving.value = true;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final Map<String, String> uploaded = {};
      for (final entry in pickedFiles.entries) {
        final String name = '${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploaded[entry.key] = await Constant.uploadUserImageToFireStorage(File(entry.value), 'carrierDocuments/$ownerId', name);
      }
      final built = CarrierSetupForm.build(
        ownerId: ownerId,
        texts: texts,
        countryCode: countryCode.value.isNotEmpty ? countryCode.value : Constant.defaultCountryCode,
        regionIds: regionIds.toList(),
        deliveryScopes: deliveryScopes.toList(),
        deliveryTimeUnit: deliveryTimeUnit.value,
        files: uploaded,
      );
      final String? id = await CarrierDispatchService.createOwnCarrier(ownerId: ownerId, data: built.data);
      if (id == null) {
        ShowToastDialog.showToast("Your carrier could not be created. Please try again.".tr);
        return false;
      }
      ShowToastDialog.showToast("Carrier created. Add your prices per region, then wait for the administrator's verification.".tr);
      return true;
    } catch (e) {
      ShowToastDialog.showToast("Your carrier could not be created. Please try again.".tr);
      return false;
    } finally {
      ShowToastDialog.closeLoader();
      isSaving.value = false;
    }
  }
}
