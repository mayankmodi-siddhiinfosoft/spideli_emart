import 'dart:developer';
import 'dart:io';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/company_profile.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<UserModel> userModel = UserModel().obs;

  Rx<TextEditingController> firstNameController = TextEditingController().obs;
  Rx<TextEditingController> lastNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  Rx<ZoneModel> selectedZone = ZoneModel().obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;

  // ── Company details (report Doc 38) ─────────────────────────────────────────

  /// One input per company text field: name, address and the three
  /// reference numbers, under the user-doc keys the panel reads.
  final Map<String, TextEditingController> companyFields = {
    for (final field in ['companyName', 'companyAddress', ...CompanyProfile.numberFields]) field: TextEditingController(),
  };

  /// Documents picked on this screen, not uploaded yet: field -> local path.
  final RxMap<String, String> pendingCompanyFiles = <String, String>{}.obs;

  /// Report Doc 43: the zones the company serves (`zoneIds`).
  final RxList<String> companyZoneIds = <String>[].obs;

  bool get isCompany => userModel.value.isCompany;

  /// The company inputs and zones as loaded ([getData]).
  Map<String, String> _loadedCompanyFields = const {};
  List<String> _loadedCompanyZoneIds = const [];

  /// The company part of the form was changed here: a field, the zones, or a
  /// document picked. Existing companies (and owner accounts) have no
  /// `companyAddress` yet, so an untouched company part must not stop them
  /// saving their name or photo.
  bool get companyEdited {
    if (pendingCompanyFiles.isNotEmpty) return true;
    if (companyFields.entries.any((e) => e.value.text.trim() != (_loadedCompanyFields[e.key] ?? '').trim())) return true;
    final Set<String> now = companyZoneIds.toSet();
    final Set<String> loaded = _loadedCompanyZoneIds.toSet();
    return now.length != loaded.length || !now.containsAll(loaded);
  }

  /// A reference number the admin already has is shown, not edited: only an
  /// empty one can be filled in from here.
  bool numberLocked(String field) => CompanyProfile.valueOf(userModel.value, field).trim().isNotEmpty;

  /// The zones a company may choose: those of its management zone, plus any
  /// it already serves.
  List<ZoneModel> get companyZoneChoices {
    final String regionId = (userModel.value.regionId ?? '').trim();
    return zoneList.where((zone) => regionId.isEmpty || zone.belongsToRegion(regionId) || companyZoneIds.contains(zone.id)).toList();
  }

  void toggleCompanyZone(String zoneId) {
    if (companyZoneIds.contains(zoneId)) {
      companyZoneIds.remove(zoneId);
    } else {
      companyZoneIds.add(zoneId);
    }
  }

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  @override
  void onClose() {
    for (final c in companyFields.values) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> getData() async {
    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });

    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        firstNameController.value.text = userModel.value.firstName.toString();
        lastNameController.value.text = userModel.value.lastName.toString();
        emailController.value.text = userModel.value.email.toString();
        phoneNumberController.value.text = userModel.value.phoneNumber.toString();
        countryCodeController.value.text = userModel.value.countryCode.toString();
        countryISOCodeController.value.text = userModel.value.countryISOCode.toString();
        profileImage.value = userModel.value.profilePictureURL ?? '';

        for (var element in zoneList) {
          if (element.id == userModel.value.zoneId) {
            selectedZone.value = element;
          }
        }

        if (value.isCompany) {
          for (final entry in companyFields.entries) {
            entry.value.text = CompanyProfile.valueOf(value, entry.key);
          }
          companyZoneIds.value = CompanyZones.of(value).where((id) => zoneList.any((z) => z.id == id)).toList();
          _loadedCompanyFields = {for (final entry in companyFields.entries) entry.key: entry.value.text};
          _loadedCompanyZoneIds = companyZoneIds.toList();
        }
      }
    });

    isLoading.value = false;
  }

  Future<void> pickCompanyFile(String field, ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      pendingCompanyFiles[field] = file.path;
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
    }
  }

  /// The first problem with the company part of the form, or null. Checked
  /// only when that part was edited ([companyEdited]).
  String? companyValidationError() {
    if (!isCompany || !companyEdited) return null;
    if (companyFields['companyName']!.text.trim().isEmpty) return "Please enter company name";
    if (companyFields['companyAddress']!.text.trim().isEmpty) return "Please enter the company address";
    if (companyZoneChoices.isNotEmpty && companyZoneIds.isEmpty) return "Please select at least one zone";
    return null;
  }

  Future<void> saveData() async {
    final String? error = companyValidationError();
    if (error != null) {
      ShowToastDialog.showToast(error.tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    if (Constant().hasValidUrl(profileImage.value) == false && profileImage.value.isNotEmpty) {
      profileImage.value = await Constant.uploadUserImageToFireStorage(
        File(profileImage.value),
        "profileImage/${FireStoreUtils.getCurrentUid()}",
        File(profileImage.value).path.split('/').last,
      );
    }

    userModel.value.firstName = firstNameController.value.text;
    userModel.value.lastName = lastNameController.value.text;
    userModel.value.profilePictureURL = profileImage.value;

    if (isCompany) {
      final bool uploaded = await _applyCompanyDetails();
      if (!uploaded) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("A company document could not be uploaded. Please try again.".tr);
        return;
      }
    } else {
      userModel.value.zoneId = selectedZone.value.id;
    }

    final bool saved = await FireStoreUtils.updateUser(userModel.value);
    ShowToastDialog.closeLoader();
    if (!saved) {
      ShowToastDialog.showToast("Your profile could not be saved. Please try again.".tr);
      return;
    }
    Get.back(result: true);
  }

  /// Copies the company inputs onto the model and uploads the documents
  /// picked here. False when an upload failed (nothing is saved then).
  Future<bool> _applyCompanyDetails() async {
    final UserModel user = userModel.value;
    CompanyProfile.setValue(user, 'companyName', companyFields['companyName']!.text);
    CompanyProfile.setValue(user, 'companyAddress', companyFields['companyAddress']!.text);
    for (final field in CompanyProfile.numberFields) {
      if (numberLocked(field)) continue;
      CompanyProfile.setValue(user, field, companyFields[field]!.text);
    }

    final List<String> zones = CompanyZones.normalize(companyZoneIds);
    if (zones.isNotEmpty) {
      user.zoneIds = zones;
      user.zoneId = CompanyZones.primary(zones);
    }

    final String uid = FireStoreUtils.getCurrentUid();
    for (final entry in pendingCompanyFiles.entries.toList()) {
      try {
        final File file = File(entry.value);
        final String url = await Constant.uploadUserImageToFireStorage(file, "driverDocument/$uid/company", "${entry.key}_${file.path.split('/').last}");
        CompanyProfile.setValue(user, entry.key, url);
        pendingCompanyFiles.remove(entry.key);
      } catch (e) {
        log("Company document upload failed (${entry.key}): $e");
        return false;
      }
    }
    return true;
  }

  final ImagePicker _imagePicker = ImagePicker();
  RxString profileImage = "".obs;

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      Get.back();
      profileImage.value = image.path;
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
    }
  }
}
