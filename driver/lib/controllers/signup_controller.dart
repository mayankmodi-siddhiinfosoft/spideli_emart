import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/multi_service/multi_service_dashboard_screen.dart';
import 'package:driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
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
  Rx<TextEditingController> operatingLicenceController = TextEditingController().obs;
  Rx<TextEditingController> commercialRegisterController = TextEditingController().obs;
  Rx<TextEditingController> uniqueIdNumberController = TextEditingController().obs;

  /// Local paths of the picked company documents, keyed by the user-doc field
  /// the uploaded URL is written to.
  RxMap<String, String> companyFiles = <String, String>{}.obs;

  static const Map<String, String> companyFileFields = {
    'operatingLicenceFile': 'Operating licence',
    'commercialRegisterFile': 'Commercial register',
    'uniqueIdNumberFile': 'Unique identification number',
  };

  bool get isCompany => selectedValue.value == 'Company';

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
  /// writes their URLs on the user model.
  Future<void> _uploadCompanyFiles(String uid) async {
    for (final entry in companyFiles.entries) {
      try {
        final file = File(entry.value);
        final url = await Constant.uploadUserImageToFireStorage(file, "driverDocument/$uid/company", "${entry.key}_${file.path.split('/').last}");
        switch (entry.key) {
          case 'operatingLicenceFile':
            userModel.value.operatingLicenceFile = url;
            break;
          case 'commercialRegisterFile':
            userModel.value.commercialRegisterFile = url;
            break;
          case 'uniqueIdNumberFile':
            userModel.value.uniqueIdNumberFile = url;
            break;
        }
      } catch (e) {
        log("Company document upload failed (${entry.key}): $e");
      }
    }
  }

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
        if (v != null) zoneList.value = v;
      }),
      FireStoreUtils.getCarMakes().then((v) => carMakesList.value = v),
      FireStoreUtils.getAllActiveSections().then((v) => allSections.value = v),
      RegionService.ensureLoaded().then((_) => regionList.value = RegionService.regions),
    ]);
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

    if (type.value == "google" || type.value == "apple" || type.value == "mobileNumber") {
      _populateUserModel();
      final uid = userModel.value.id ?? FirebaseAuth.instance.currentUser?.uid;
      if (isCompany && uid != null) await _uploadCompanyFiles(uid);
      await FireStoreUtils.updateUser(userModel.value);
      _navigateAfterSignup(userModel.value);
    } else {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailEditingController.value.text.trim(),
          password: passwordEditingController.value.text.trim(),
        );
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          _populateUserModel();
          if (isCompany) await _uploadCompanyFiles(credential.user!.uid);
          await FireStoreUtils.updateUser(userModel.value);
          _navigateAfterSignup(userModel.value);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast("The account already exists for that email.".tr);
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr);
        }
        print(e);
      } catch (e) {
        print(e);
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }

  void _populateUserModel() {
    userModel.value.firstName = firstNameEditingController.value.text;
    userModel.value.lastName = lastNameEditingController.value.text;
    userModel.value.email = emailEditingController.value.text.toLowerCase();
    userModel.value.phoneNumber = phoneNUmberEditingController.value.text;
    userModel.value.role = Constant.userRoleDriver;
    userModel.value.isActive = false;
    userModel.value.active = Constant.autoApproveDriver == true ? true : false;
    userModel.value.isDocumentVerify = selectedValue.value == "Company"
        ? Constant.isOwnerVerification == true
            ? false
            : true
        : Constant.isDriverVerification == true
            ? false
            : true;
    userModel.value.countryCode = countryCodeEditingController.value.text;
    userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
    userModel.value.createdAt = Timestamp.now();
    userModel.value.zoneId = selectedZone.value.id;
    userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    userModel.value.provider = type.value.isEmpty ? 'email' : type.value;
    userModel.value.isOwner = selectedValue.value == "Company" ? true : false;
    userModel.value.isAutoVerify = selectedValue.value == "Company"
        ? Constant.isOwnerVerification == false
            ? true
            : false
        : Constant.isDriverVerification == false
            ? true
            : false;

    // ── Section IDs ──────────────────────────────────────────────────────────
    userModel.value.sectionIds = selectedSections.map((s) => s.id!).toList();

    // ── Region + Individual / Company (spec 4.11) ─────────────────────────────
    if (selectedRegion.value?.id != null) userModel.value.regionId = selectedRegion.value!.id;
    userModel.value.driverType = isCompany ? 'company' : 'individual';
    if (isCompany) {
      String? text(Rx<TextEditingController> c) => c.value.text.trim().isEmpty ? null : c.value.text.trim();
      userModel.value.companyName = text(companyNameController);
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
      for (final s in selectedSections) s.id!: s.name ?? s.id!,
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

  static void navigateByUserModel(UserModel user) {
    if (user.isOwner == true) {
      Get.offAll(OwnerDashboardScreen());
    } else if ((user.serviceTypes?.length ?? 0) > 1) {
      Get.offAll(const MultiServiceDashboardScreen());
    } else {
      _navigateByServiceType(user.serviceTypes?.first ?? 'delivery-service');
    }
  }

  static void _navigateByServiceType(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        Get.offAll(const CabDashboardScreen());
        break;
      case 'parcel_delivery':
        Get.offAll(const ParcelDashboardScreen());
        break;
      case 'rental-service':
        Get.offAll(const RentalDashboardScreen());
        break;
      default:
        Get.offAll(const DashBoardScreen());
    }
  }
}
