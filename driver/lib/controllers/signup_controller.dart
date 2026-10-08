import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/services/dashboard_navigation.dart';
import 'package:driver/utils/company_profile.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/region_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class SignupController extends GetxController {
  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;
  Rx<TextEditingController> carPlatNumberEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;
  Rx<UserModel> userModel = UserModel().obs;

  /// Every published zone, before the region filter.
  RxList<ZoneModel> allZoneList = <ZoneModel>[].obs;

  /// The zones offered in the picker: only those serving the selected region
  /// (client point 16). No region selected, or no regions at all = every zone.
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  /// All active sections loaded from Firestore (no service filter)
  RxList<SectionModel> allSections = <SectionModel>[].obs;

  /// Sections the driver has selected during registration
  RxList<SectionModel> selectedSections = <SectionModel>[].obs;

  /// Vehicle types per section (loaded only for cab-service / rental-service sections)
  RxMap<String, List<VehicleType>> vehicleTypesPerSection = <String, List<VehicleType>>{}.obs;
  RxMap<String, VehicleType> selectedVehiclePerSection = <String, VehicleType>{}.obs;

  /// Shared car makes list (loaded once from Firestore)
  RxList<CarMakes> carMakesList = <CarMakes>[].obs;

  /// Per-section car details
  final Map<String, Rx<CarMakes>> selectedCarMakesPerSection = {};
  final Map<String, RxList<CarModel>> carModelListPerSection = {};
  final Map<String, Rx<CarModel>> selectedCarModelPerSection = {};
  final Map<String, Rx<TextEditingController>> carPlatePerSection = {};

  RxString selectedValue = "Individual".obs;

  // ── Management zone (region, spec 3.1 / 4.11) ──────────────────────────────
  RxList<RegionModel> regionList = <RegionModel>[].obs;
  Rx<RegionModel?> selectedRegion = Rx<RegionModel?>(null);

  /// A region must be picked whenever the admin has created regions.
  bool get regionRequired => regionList.isNotEmpty;

  // ── Company identification (spec 4.11) ──────────────────────────────────────
  Rx<TextEditingController> companyNameController = TextEditingController().obs;

  /// Report Doc 38: asked for and saved as `companyAddress` (it never was).
  Rx<TextEditingController> companyAddressController = TextEditingController().obs;
  Rx<TextEditingController> operatingLicenceController = TextEditingController().obs;
  Rx<TextEditingController> commercialRegisterController = TextEditingController().obs;
  Rx<TextEditingController> uniqueIdNumberController = TextEditingController().obs;

  /// Local paths of the picked company documents, keyed by the user-doc field
  /// the uploaded URL is written to.
  RxMap<String, String> companyFiles = <String, String>{}.obs;

  static final Map<String, String> companyFileFields = {
    for (final field in CompanyProfile.fileFields) field: CompanyProfile.labels[field]!,
  };

  bool get isCompany => selectedValue.value == 'Company';

  /// Report Doc 43: the zones a company serves (several), saved as `zoneIds`
  /// with `zoneId` = the first one.
  RxList<String> selectedZoneIds = <String>[].obs;

  bool isCompanyZoneSelected(String? zoneId) => zoneId != null && selectedZoneIds.contains(zoneId);

  void toggleCompanyZone(String? zoneId) {
    if (zoneId == null || zoneId.isEmpty) return;
    if (selectedZoneIds.contains(zoneId)) {
      selectedZoneIds.remove(zoneId);
    } else {
      selectedZoneIds.add(zoneId);
    }
    update();
  }

  /// The first company-registration problem, or null when the company part
  /// of the form is complete. The three documents are required: four of six
  /// companies were saved without them because nothing asked (report Doc 38).
  String? companyValidationError() {
    if (!isCompany) return null;
    if (companyNameController.value.text.trim().isEmpty) return "Please enter company name";
    if (companyAddressController.value.text.trim().isEmpty) return "Please enter the company address";
    if (operatingLicenceController.value.text.trim().isEmpty ||
        commercialRegisterController.value.text.trim().isEmpty ||
        uniqueIdNumberController.value.text.trim().isEmpty) {
      return "Please enter the operating licence, commercial register and unique identification number";
    }
    if (CompanyProfile.missingFiles(companyFiles).isNotEmpty) return "Please add the three company documents";
    if (zoneList.isNotEmpty && selectedZoneIds.isEmpty) return "Please select at least one zone";
    return null;
  }

  Future<void> pickCompanyFile(String field, ImageSource source) async {
    try {
      final XFile? file = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      companyFiles[field] = file.path;
    } catch (e) {
      ShowToastDialog.showToast("Could not open the camera / gallery".tr);
    }
  }

  /// Uploads the picked company documents (after the account exists) and
  /// writes their URLs on the user model. Returns the fields that could not
  /// be uploaded: a failure used to be logged and forgotten, and the company
  /// was saved without its documents with nobody told (report Doc 38).
  Future<List<String>> _uploadCompanyFiles(String uid) async {
    final List<String> failed = [];
    for (final entry in companyFiles.entries) {
      try {
        final file = File(entry.value);
        final url = await Constant.uploadUserImageToFireStorage(file, "driverDocument/$uid/company", "${entry.key}_${file.path.split('/').last}");
        CompanyProfile.setValue(userModel.value, entry.key, url);
      } catch (e) {
        log("Company document upload failed (${entry.key}): $e");
        failed.add(entry.key);
      }
    }
    return failed;
  }

  static const String _companyUploadFailed =
      "Your account was created, but some company documents could not be uploaded. Please add them from your profile.";

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool sectionNeedsVehicle(SectionModel section) => section.serviceTypeFlag == 'cab-service' || section.serviceTypeFlag == 'rental-service';

  bool get hasVehicleBasedSection => selectedSections.any(sectionNeedsVehicle);

  bool isSectionSelected(SectionModel section) => selectedSections.any((s) => s.id == section.id);

  /// Sections offered at registration. Spec 4.11: a Company can select the
  /// delivery sections (any multivendor / e-commerce section) in addition to
  /// Cab, Parcel and Rental, exactly like an Individual.
  List<SectionModel> get visibleSections => allSections;

  /// Called when switching between Individual / Company.
  void onRoleChanged(String role) {
    selectedValue.value = role;
    update();
  }

  /// Returns a human-readable label for a section's serviceTypeFlag.
  String serviceFlagLabel(String? flag) {
    switch (flag) {
      case 'cab-service':
        return 'Cab';
      case 'parcel_delivery':
        return 'Parcel';
      case 'rental-service':
        return 'Rental';
      case 'ecommerce-service':
        return 'Delivery (e-commerce)';
      default:
        return 'Delivery';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber ?? "";
        countryCodeEditingController.value.text = userModel.value.countryCode ?? Constant.defaultCountryCode;
        countryISOCodeEditingController.value.text = userModel.value.countryISOCode ?? Constant.defaultCountryCode;
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
      }
    }

    await Future.wait([
      FireStoreUtils.getZone().then((v) {
        if (v != null) allZoneList.value = v;
      }),
      FireStoreUtils.getCarMakes().then((v) => carMakesList.value = v),
      FireStoreUtils.getAllActiveSections().then((v) => allSections.value = v),
      RegionService.ensureLoaded().then((_) => regionList.value = RegionService.regions),
    ]);
    filterZones();
  }

  /// Keeps the zone picker in step with the chosen region (client point 16,
  /// the Store app's rule): a zone with no region data serves every region.
  void filterZones() {
    final String? regionId = selectedRegion.value?.id;
    if (regionId == null || regionId.isEmpty) {
      zoneList.value = allZoneList.toList();
    } else {
      zoneList.value = allZoneList.where((zone) => zone.belongsToRegion(regionId)).toList();
    }
    // A zone that does not serve the chosen region must not stay selected.
    if (selectedZone.value.id != null && !zoneList.any((zone) => zone.id == selectedZone.value.id)) {
      selectedZone.value = ZoneModel();
    }
    selectedZoneIds.removeWhere((id) => !zoneList.any((zone) => zone.id == id));
  }

  /// Save-time guard: the chosen zone must serve the chosen region. The picker
  /// already enforces this; this stops a stale selection slipping through.
  bool get zoneServesSelectedRegion {
    final String? regionId = selectedRegion.value?.id;
    final String? zoneId = selectedZone.value.id;
    if (regionId == null || regionId.isEmpty || zoneId == null) return true;
    final ZoneModel? zone = allZoneList.where((z) => z.id == zoneId).firstOrNull;
    return zone == null || zone.belongsToRegion(regionId);
  }

  /// Called by the management-zone dropdown.
  void onRegionChanged(RegionModel? region) {
    selectedRegion.value = region;
    filterZones();
    update();
  }

  // ── Section toggle ─────────────────────────────────────────────────────────

  Future<void> toggleSection(SectionModel section) async {
    if (isSectionSelected(section)) {
      if (selectedSections.length == 1) {
        ShowToastDialog.showToast("At least one section must be selected.".tr);
        return;
      }
      selectedSections.removeWhere((s) => s.id == section.id);
      vehicleTypesPerSection.remove(section.id);
      selectedVehiclePerSection.remove(section.id);
      selectedCarMakesPerSection.remove(section.id);
      carModelListPerSection.remove(section.id);
      selectedCarModelPerSection.remove(section.id);
      carPlatePerSection.remove(section.id);
    } else {
      selectedSections.add(section);
      if (sectionNeedsVehicle(section)) {
        await _loadVehicleTypesForSection(section);
        // Init per-section car details
        selectedCarMakesPerSection[section.id!] = Rx<CarMakes>(CarMakes());
        carModelListPerSection[section.id!] = <CarModel>[].obs;
        selectedCarModelPerSection[section.id!] = Rx<CarModel>(CarModel());
        carPlatePerSection[section.id!] = Rx<TextEditingController>(TextEditingController());
      }
    }
    update();
  }

  Future<void> _loadVehicleTypesForSection(SectionModel section) async {
    ShowToastDialog.showLoader("Please wait".tr);
    List<VehicleType> types;
    if (section.serviceTypeFlag == 'cab-service') {
      types = await FireStoreUtils.getCabVehicleType(section.id.toString());
    } else {
      types = await FireStoreUtils.getRentalVehicleType(section.id.toString());
    }
    vehicleTypesPerSection[section.id!] = types;
    if (types.isNotEmpty) selectedVehiclePerSection[section.id!] = types.first;
    ShowToastDialog.closeLoader();
    update();
  }

  Future<void> getCarModelForSection(String sectionId) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final carMakes = selectedCarMakesPerSection[sectionId]?.value;
    carModelListPerSection[sectionId]?.clear();
    selectedCarModelPerSection[sectionId]?.value = CarModel();
    if (carMakes?.name != null) {
      await FireStoreUtils.getCarModel(carMakes!.name.toString()).then((v) {
        carModelListPerSection[sectionId]?.value = v;
      });
    }
    ShowToastDialog.closeLoader();
  }

  // ── Sign up ────────────────────────────────────────────────────────────────

  Future<void> signUpWithEmailAndPassword() async {
    await signUp();
  }

  Future<void> signUp() async {
    if (selectedSections.isEmpty) {
      ShowToastDialog.showToast("Please select at least one section.".tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    await _resolveRegionId();
    // The admin's verification setting decides `isAutoVerify` for good: read
    // it now rather than rely on the background settings load.
    await FireStoreUtils.loadDocumentVerificationSettings();

    try {
      if (type.value == "google" || type.value == "apple" || type.value == "mobileNumber") {
        _populateUserModel();
        final uid = userModel.value.id ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Your session expired before the account was created. Please sign in again.".tr);
          return;
        }
        userModel.value.id = uid;
        final List<String> failedFiles = isCompany ? await _uploadCompanyFiles(uid) : const [];
        final bool saved = await FireStoreUtils.updateUser(userModel.value, isNew: true);
        ShowToastDialog.closeLoader();
        if (!saved) {
          ShowToastDialog.showToast("Your account could not be saved. Please check your connection and try again.".tr);
          return;
        }
        if (failedFiles.isNotEmpty) ShowToastDialog.showToast(_companyUploadFailed.tr);
        // The device token (field-level) and, once active, the topics: a new
        // driver used to get no push until the app was restarted.
        unawaited(NotificationService.syncSignedInDevice(userModel.value));
        _navigateAfterSignup(userModel.value);
        return;
      }

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailEditingController.value.text.trim(),
        password: passwordEditingController.value.text.trim(),
      );
      if (credential.user == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("The account could not be created. Please try again.".tr);
        return;
      }
      userModel.value.id = credential.user!.uid;
      _populateUserModel();
      final List<String> failedFiles = isCompany ? await _uploadCompanyFiles(credential.user!.uid) : const [];
      final bool saved = await FireStoreUtils.updateUser(userModel.value, isNew: true);
      ShowToastDialog.closeLoader();
      if (!saved) {
        ShowToastDialog.showToast("Your account was created but its details could not be saved. Please sign in and complete your profile.".tr);
        return;
      }
      if (failedFiles.isNotEmpty) ShowToastDialog.showToast(_companyUploadFailed.tr);
      unawaited(NotificationService.syncSignedInDevice(userModel.value));
      _navigateAfterSignup(userModel.value);
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      // Every refusal says why: only three codes were handled before, so any
      // other failure (network, App Check, sign-up disabled) looked like
      // "nothing happens on submit".
      ShowToastDialog.showToast(_authMessage(e));
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("SignupController.signUp failed: $e");
      ShowToastDialog.showToast("Sign up failed: ${e.toString()}");
    }
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return "The password provided is too weak.".tr;
      case 'email-already-in-use':
        return "The account already exists for that email.".tr;
      case 'invalid-email':
        return "Enter email is Invalid".tr;
      case 'operation-not-allowed':
        return "Email sign-up is disabled for this project. Please contact support.".tr;
      case 'network-request-failed':
        return "No connection. Please check your internet and try again.".tr;
      case 'too-many-requests':
        return "Too many attempts. Please try again in a few minutes.".tr;
      default:
        return e.message ?? "Sign up failed (${e.code}).";
    }
  }

  /// The admin driver list filters on `users.regionId`. When the admin has no
  /// regions the field stays absent (global); when it does, the chosen zone's
  /// own region is used as the fallback so a record is never filed nowhere.
  Future<void> _resolveRegionId() async {
    if (selectedRegion.value?.id != null) return;
    final String? zoneId = isCompany ? CompanyZones.primary(selectedZoneIds) : selectedZone.value.id;
    if (zoneId == null || zoneId.isEmpty) return;
    final ZoneModel? zone = allZoneList.where((z) => z.id == zoneId).firstOrNull;
    final List<String> ids = zone?.regionIds ?? const <String>[];
    String? regionId = ids.length == 1 ? ids.first : zone?.regionId;
    regionId ??= await RegionService.regionIdForZone(zoneId);
    if (regionId == null || regionId.isEmpty) return;
    selectedRegion.value = regionList.where((r) => r.id == regionId).firstOrNull ?? selectedRegion.value;
    if (selectedRegion.value?.id == null) userModel.value.regionId = regionId;
  }

  void _populateUserModel() {
    userModel.value.firstName = firstNameEditingController.value.text;
    userModel.value.lastName = lastNameEditingController.value.text;
    userModel.value.email = emailEditingController.value.text.toLowerCase();
    userModel.value.phoneNumber = phoneNUmberEditingController.value.text;
    userModel.value.role = Constant.userRoleDriver;
    userModel.value.isActive = false;
    userModel.value.active = Constant.autoApproveDriver == true ? true : false;
    userModel.value.countryCode = countryCodeEditingController.value.text;
    userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
    userModel.value.createdAt = Timestamp.now();
    if (isCompany) {
      // Report Doc 43: every zone the company serves, and the first one in
      // `zoneId` for the readers of the single field.
      final List<String> zones = CompanyZones.normalize(selectedZoneIds);
      userModel.value.zoneIds = zones;
      userModel.value.zoneId = CompanyZones.primary(zones);
    } else {
      userModel.value.zoneId = selectedZone.value.id;
    }
    userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    userModel.value.provider = type.value.isEmpty ? 'email' : type.value;
    userModel.value.isOwner = selectedValue.value == "Company" ? true : false;
    // Report Doc 37: a new account is never verified by the app itself — only
    // the administrator sets `isDocumentVerify` true, once every required
    // document is approved. With verification switched off in the panel the
    // account is auto-verified instead, which is what every gate reads.
    final flags = DocumentVerification.initialFlags(isCompany: isCompany);
    userModel.value.isDocumentVerify = flags.isDocumentVerify;
    userModel.value.isAutoVerify = flags.isAutoVerify;

    // ── Section IDs ──────────────────────────────────────────────────────────
    userModel.value.sectionIds = selectedSections.map((s) => s.id).whereType<String>().toList();

    // ── Region + Individual / Company (spec 4.11) ─────────────────────────────
    if (selectedRegion.value?.id != null) userModel.value.regionId = selectedRegion.value!.id;
    userModel.value.driverType = isCompany ? 'company' : 'individual';
    if (isCompany) {
      String? text(Rx<TextEditingController> c) => c.value.text.trim().isEmpty ? null : c.value.text.trim();
      userModel.value.companyName = text(companyNameController);
      userModel.value.companyAddress = text(companyAddressController);
      userModel.value.operatingLicence = text(operatingLicenceController);
      userModel.value.commercialRegister = text(commercialRegisterController);
      userModel.value.uniqueIdNumber = text(uniqueIdNumberController);
    }

    // ── Derive serviceTypes from unique serviceTypeFlags of selected sections ─
    // (e-commerce sections are served by the delivery flow)
    final uniqueFlags = selectedSections.map((s) => Constant.driverServiceTypeFor(s.serviceTypeFlag)).toSet().toList();
    userModel.value.serviceTypes = uniqueFlags;

    // ── sectionNames: simple {sectionId → sectionName} lookup ────────────────
    userModel.value.sectionNames = {
      for (final s in selectedSections)
        if (s.id != null) s.id!: s.name ?? s.id!,
    };

    // ── vehicleDetails: {sectionId → {vehicleId, vehicleType, carBrand, carModel, carPlateNumber}} ─
    // Skip for Company users — they register their own drivers separately.
    final Map<String, dynamic> vDetails = {};
    final bool companyAccount = isCompany;
    for (final section in selectedSections) {
      if (!companyAccount && sectionNeedsVehicle(section)) {
        final vehicle = selectedVehiclePerSection[section.id];
        final carMakes = selectedCarMakesPerSection[section.id]?.value;
        final carModel = selectedCarModelPerSection[section.id]?.value;
        final carPlate = carPlatePerSection[section.id]?.value.text ?? '';
        vDetails[section.id!] = {
          'vehicleId': vehicle?.id ?? '',
          'vehicleType': vehicle?.name ?? '',
          'carBrand': carMakes?.name ?? '',
          'carModel': carModel?.name ?? '',
          'carPlateNumber': carPlate,
          if (section.serviceTypeFlag == 'cab-service') 'rideType': section.rideType ?? 'ride',
        };
      }
    }
    if (vDetails.isNotEmpty) userModel.value.vehicleDetails = vDetails;

    log(userModel.value.toJson().toString());
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigateAfterSignup(UserModel user) {
    if (!(Constant.autoApproveDriver ?? false)) {
      ShowToastDialog.showToast("Thank you for sign up, your application is under approval so please wait till that approve.".tr);
      Get.offAll(const LoginScreen());
      return;
    }
    navigateByUserModel(user);
  }

  /// Opens [user]'s dashboards ([DashboardNavigation.open]): never a second
  /// copy of dashboards that are already running.
  static void navigateByUserModel(UserModel user) {
    unawaited(DashboardNavigation.open(user));
  }
}
