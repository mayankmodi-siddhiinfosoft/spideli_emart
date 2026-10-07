import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Owner's "Create / Update Driver" controller.
///
/// Mirrors the Individual signup flow: owner selects which of their own
/// sections the driver will serve (multi-select). Service types are derived
/// from the union of selected sections' `serviceTypeFlag`. Vehicle details
/// are captured per-section for cab-service / rental-service sections.
class DriverCreateController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  /// Every published zone, before the owner's region filter.
  RxList<ZoneModel> allZoneList = <ZoneModel>[].obs;

  /// Zones offered in the picker: the ones serving the company's management
  /// zone (client point 16). No region on the company = every zone.
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  /// All sections that the owner is registered in. Driver can only be
  /// assigned to a subset of these.
  RxList<SectionModel> ownerSections = <SectionModel>[].obs;

  /// Sections the owner has picked for this driver.
  RxList<SectionModel> selectedSections = <SectionModel>[].obs;

  /// Shared car makes list (loaded once).
  RxList<CarMakes> carMakesList = <CarMakes>[].obs;

  /// Per-section vehicle types.
  final Map<String, RxList<VehicleType>> vehicleTypesPerSection = {};

  /// Per-section selected vehicle.
  final Map<String, Rx<VehicleType>> selectedVehiclePerSection = {};

  /// Per-section ride type (cab-service only).
  final Map<String, RxString> selectedRideTypePerSection = {};

  /// Per-section car details (cab/rental only).
  final Map<String, Rx<CarMakes>> selectedCarMakesPerSection = {};
  final Map<String, RxList<CarModel>> carModelListPerSection = {};
  final Map<String, Rx<CarModel>> selectedCarModelPerSection = {};
  final Map<String, Rx<TextEditingController>> carPlatePerSection = {};

  Rx<UserModel> driverModel = UserModel().obs;

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool sectionNeedsVehicle(SectionModel s) => s.serviceTypeFlag == 'cab-service' || s.serviceTypeFlag == 'rental-service';

  bool get hasVehicleBasedSection => selectedSections.any(sectionNeedsVehicle);

  bool isSectionSelected(SectionModel section) => selectedSections.any((s) => s.id == section.id);

  String serviceFlagLabel(String? flag) {
    switch (flag) {
      case 'cab-service':
        return 'Cab';
      case 'parcel_delivery':
        return 'Parcel';
      case 'rental-service':
        return 'Rental';
      default:
        return 'Delivery';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    getArguments();
    super.onInit();
  }

  Future<void> getArguments() async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      // Load zones, car makes, and owner sections in parallel.
      await Future.wait([
        FireStoreUtils.getZone().then((v) {
          if (v != null) allZoneList.value = v;
        }),
        FireStoreUtils.getCarMakes().then((v) => carMakesList.value = v),
        FireStoreUtils.getAllActiveSections().then((v) {
          final ownerSectionIds = Constant.userModel?.sectionIds ?? [];
          ownerSections.value = v.where((s) => s.id != null && ownerSectionIds.contains(s.id)).toList();
        }),
      ]);

      _filterZones();

      // Edit mode: prefill from existing driver model.
      dynamic argumentData = Get.arguments;
      if (argumentData != null) {
        driverModel.value = argumentData['driverModel'] as UserModel;

        firstNameEditingController.value.text = driverModel.value.firstName ?? '';
        lastNameEditingController.value.text = driverModel.value.lastName ?? '';
        emailEditingController.value.text = driverModel.value.email ?? '';
        phoneNUmberEditingController.value.text = driverModel.value.phoneNumber ?? '';
        countryCodeEditingController.value.text = driverModel.value.countryCode ?? Constant.defaultCountryCode;
        countryISOCodeEditingController.value.text = driverModel.value.countryISOCode ?? Constant.defaultCountryCode;

        for (final z in allZoneList) {
          if (z.id == driverModel.value.zoneId) {
            selectedZone.value = z;
            // An existing driver keeps the zone it was saved with, even when
            // the company's region no longer covers it.
            if (!zoneList.any((e) => e.id == z.id)) zoneList.add(z);
            break;
          }
        }

        // Pre-select driver's existing sections (intersected with owner's).
        // Load vehicle data before adding so UI has data on first render.
        final driverSectionIds = driverModel.value.sectionIds ?? [];
        final sectionsToAdd = <SectionModel>[];
        for (final sec in ownerSections) {
          if (driverSectionIds.contains(sec.id)) {
            if (sectionNeedsVehicle(sec)) {
              await _loadVehicleDataForSection(sec, prefill: true);
            }
            sectionsToAdd.add(sec);
          }
        }
        selectedSections.addAll(sectionsToAdd);
      }
    } catch (e) {
      log("DriverCreateController.getArguments error: $e");
      ShowToastDialog.showToast("Could not load the registration data. Please try again.".tr);
    } finally {
      ShowToastDialog.closeLoader();
      isLoading.value = false;
      update();
    }
  }

  /// Client point 16: a fleet driver works in a zone of the company's own
  /// management zone. A zone with no region data serves every region.
  void _filterZones() {
    final String regionId = (Constant.userModel?.regionId ?? '').trim();
    if (regionId.isEmpty) {
      zoneList.value = allZoneList.toList();
    } else {
      zoneList.value = allZoneList.where((zone) => zone.belongsToRegion(regionId)).toList();
    }
    if (selectedZone.value.id != null && !zoneList.any((zone) => zone.id == selectedZone.value.id)) {
      selectedZone.value = ZoneModel();
    }
  }

  // ── Section toggle ─────────────────────────────────────────────────────────

  Future<void> toggleSection(SectionModel section) async {
    final sid = section.id;
    if (sid == null) return;

    if (isSectionSelected(section)) {
      selectedSections.removeWhere((s) => s.id == sid);
      vehicleTypesPerSection.remove(sid);
      selectedVehiclePerSection.remove(sid);
      selectedRideTypePerSection.remove(sid);
      selectedCarMakesPerSection.remove(sid);
      carModelListPerSection.remove(sid);
      selectedCarModelPerSection.remove(sid);
      carPlatePerSection.remove(sid);
    } else {
      // Load vehicle data BEFORE adding to selectedSections so that
      // when the RxList triggers a UI rebuild the data is already present.
      if (sectionNeedsVehicle(section)) {
        await _loadVehicleDataForSection(section);
      }
      selectedSections.add(section);
    }
    update();
  }

  Future<void> _loadVehicleDataForSection(
    SectionModel section, {
    bool prefill = false,
  }) async {
    final sid = section.id!;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      // Vehicle types.
      final types = section.serviceTypeFlag == 'rental-service' ? await FireStoreUtils.getRentalVehicleType(sid) : await FireStoreUtils.getCabVehicleType(sid);
      vehicleTypesPerSection[sid] = RxList<VehicleType>(types);

      final Map<String, dynamic>? sectionData = prefill && driverModel.value.vehicleDetails != null ? (driverModel.value.vehicleDetails![sid] as Map?)?.cast<String, dynamic>() : null;

      // Selected vehicle.
      final savedVehicleId = sectionData?['vehicleId']?.toString();
      VehicleType selectedVehicle = types.isNotEmpty ? types.first : VehicleType();
      if (savedVehicleId != null && savedVehicleId.isNotEmpty && types.isNotEmpty) {
        selectedVehicle = types.firstWhere(
          (e) => e.id == savedVehicleId,
          orElse: () => types.first,
        );
      }
      selectedVehiclePerSection[sid] = Rx<VehicleType>(selectedVehicle);

      // Ride type (cab only).
      final savedRideType = sectionData?['rideType']?.toString() ?? 'ride';
      selectedRideTypePerSection[sid] = RxString(savedRideType);

      // Car plate.
      final savedPlate = sectionData?['carPlateNumber']?.toString() ?? '';
      carPlatePerSection[sid] = Rx<TextEditingController>(TextEditingController(text: savedPlate));

      // Car brand / model.
      final savedBrand = sectionData?['carBrand']?.toString();
      if (savedBrand != null && savedBrand.isNotEmpty && carMakesList.isNotEmpty) {
        final brand = carMakesList.firstWhere(
          (e) => e.name == savedBrand,
          orElse: () => CarMakes(),
        );
        selectedCarMakesPerSection[sid] = Rx<CarMakes>(brand);
        final models = await FireStoreUtils.getCarModel(savedBrand);
        carModelListPerSection[sid] = RxList<CarModel>(models);

        final savedModel = sectionData?['carModel']?.toString();
        if (savedModel != null && savedModel.isNotEmpty && models.isNotEmpty) {
          selectedCarModelPerSection[sid] = Rx<CarModel>(
            models.firstWhere((e) => e.name == savedModel, orElse: () => models.first),
          );
        } else {
          selectedCarModelPerSection[sid] = Rx<CarModel>(CarModel());
        }
      } else {
        selectedCarMakesPerSection[sid] = Rx<CarMakes>(CarMakes());
        carModelListPerSection[sid] = <CarModel>[].obs;
        selectedCarModelPerSection[sid] = Rx<CarModel>(CarModel());
      }
    } finally {
      ShowToastDialog.closeLoader();
      update();
    }
  }

  Future<void> getCarModelForSection(String sectionId) async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final carMakes = selectedCarMakesPerSection[sectionId]?.value;
      carModelListPerSection[sectionId]?.clear();
      selectedCarModelPerSection[sectionId]?.value = CarModel();
      if (carMakes?.name != null && carMakes!.name!.isNotEmpty) {
        final models = await FireStoreUtils.getCarModel(carMakes.name!);
        carModelListPerSection[sectionId]?.value = models;
      }
    } finally {
      ShowToastDialog.closeLoader();
      update();
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// The owner app signs the new driver up on a SECOND Firebase app so the
  /// owner stays signed in. `initializeApp` with the same name throws
  /// `duplicate-app` on every create after the first one in a session, so the
  /// existing instance is reused.
  static Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app('SecondaryApp');
    } catch (_) {
      app = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<void> signUp() async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final FirebaseAuth secondaryAuth = await _secondaryAuth();

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: emailEditingController.value.text.trim(),
        password: passwordEditingController.value.text.trim(),
      );
      if (credential.user == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("The account could not be created. Please try again.".tr);
        return;
      }
      driverModel.value.id = credential.user!.uid;
      _applyCommonFields();
      driverModel.value.vehicleDetails = _buildVehicleDetails({});

      final bool saved = await FireStoreUtils.updateUser(driverModel.value, isNew: true);
      // The owner's own session must not be replaced by the new driver's.
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      ShowToastDialog.closeLoader();
      if (!saved) {
        ShowToastDialog.showToast("The driver account was created but its details could not be saved. Please open it and save again.".tr);
        return;
      }
      ShowToastDialog.showToast("Driver created successfully".tr);
      Get.back(result: true);
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(_authMessage(e));
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("DriverCreateController.signUp failed: $e");
      ShowToastDialog.showToast("The driver could not be created: ${e.toString()}");
    }
  }

  /// Every refusal says why — the three codes that were handled before left
  /// the rest of them silent, which is the "nothing happens on submit".
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
        return e.message ?? "The account could not be created (${e.code}).";
    }
  }

  Future<void> updateDriver() async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      _applyCommonFields(isNew: false);
      // Start fresh — drop any vehicleDetails entries for deselected sections.
      driverModel.value.vehicleDetails = _buildVehicleDetails({});
      final bool saved = await FireStoreUtils.updateUser(driverModel.value);
      ShowToastDialog.closeLoader();
      if (!saved) {
        ShowToastDialog.showToast("The driver could not be saved. Please try again.".tr);
        return;
      }
      ShowToastDialog.showToast("Driver updated successfully".tr);
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("DriverCreateController.updateDriver failed: $e");
      ShowToastDialog.showToast("The driver could not be saved: ${e.toString()}");
    }
  }

  /// [isNew]: a driver the owner is creating starts offline; editing an
  /// existing driver never changes their online status (it used to set
  /// `isActive` to false on every save, forcing the driver offline).
  void _applyCommonFields({bool isNew = true}) {
    driverModel.value.firstName = firstNameEditingController.value.text;
    driverModel.value.lastName = lastNameEditingController.value.text;
    driverModel.value.email = emailEditingController.value.text.trim().toLowerCase();
    driverModel.value.phoneNumber = phoneNUmberEditingController.value.text;
    driverModel.value.role = Constant.userRoleDriver;
    driverModel.value.active = true;
    if (isNew) driverModel.value.isActive = false;
    driverModel.value.isDocumentVerify = true;
    driverModel.value.countryCode = countryCodeEditingController.value.text;
    driverModel.value.countryISOCode = countryISOCodeEditingController.value.text;
    driverModel.value.createdAt ??= Timestamp.now();
    driverModel.value.zoneId = selectedZone.value.id;
    driverModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    driverModel.value.provider = 'email';
    driverModel.value.isOwner = false;
    driverModel.value.ownerId = FireStoreUtils.getCurrentUid();
    // The admin driver list filters on `driverType`; a fleet driver is an
    // individual driver that belongs to a company.
    driverModel.value.driverType = 'individual';
    // A company's fleet driver works in the company's management zone.
    if ((driverModel.value.regionId ?? '').isEmpty && (Constant.userModel?.regionId ?? '').isNotEmpty) {
      driverModel.value.regionId = Constant.userModel!.regionId;
    }

    // Derive fields from selected sections.
    driverModel.value.sectionIds = selectedSections.map((s) => s.id).whereType<String>().toList();
    driverModel.value.sectionNames = {
      for (final s in selectedSections)
        if (s.id != null) s.id!: s.name ?? s.id!
    };
    driverModel.value.serviceTypes = selectedSections.map((s) => Constant.driverServiceTypeFor(s.serviceTypeFlag)).toSet().toList();
  }

  Map<String, dynamic> _buildVehicleDetails(Map<String, dynamic> existing) {
    for (final section in selectedSections) {
      if (!sectionNeedsVehicle(section)) continue;
      final sid = section.id ?? '';
      final vehicle = selectedVehiclePerSection[sid]?.value;
      if (vehicle?.id != null) {
        existing[sid] = {
          'vehicleId': vehicle!.id ?? '',
          'vehicleType': vehicle.name ?? '',
          'carBrand': selectedCarMakesPerSection[sid]?.value.name ?? '',
          'carModel': selectedCarModelPerSection[sid]?.value.name ?? '',
          'carPlateNumber': carPlatePerSection[sid]?.value.text.trim() ?? '',
          if (section.serviceTypeFlag == 'cab-service') 'rideType': selectedRideTypePerSection[sid]?.value ?? 'ride',
        };
      }
    }
    return existing;
  }
}
