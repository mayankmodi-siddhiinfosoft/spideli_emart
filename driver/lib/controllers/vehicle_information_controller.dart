import 'dart:developer';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VehicleInformationController extends GetxController {
  /// The service type context this screen was opened from.
  /// e.g. 'cab-service', 'rental-service', 'delivery-service', 'parcel_delivery'
  final String initialServiceType;

  VehicleInformationController({required this.initialServiceType});

  Rx<TextEditingController> carPlatNumberEditingController = TextEditingController().obs;
  Rx<UserModel> userModel = UserModel().obs;

  RxString selectedService = ''.obs;
  /// Per-section ride type (cab only)
  final Map<String, RxString> selectedRideTypePerSection = {};

  /// All sections available for this service from Firestore
  RxList<SectionModel> allSectionsForService = <SectionModel>[].obs;

  /// Only the sections this driver is registered in (for current service)
  RxList<SectionModel> driverSections = <SectionModel>[].obs;

  /// Vehicle types per sectionId
  final Map<String, RxList<VehicleType>> vehicleTypesPerSection = {};

  /// Selected vehicle type per sectionId
  final Map<String, Rx<VehicleType>> selectedVehiclePerSection = {};

  /// Shared car makes list (loaded once)
  RxList<CarMakes> carMakesList = <CarMakes>[].obs;

  /// Per-section car details
  final Map<String, Rx<CarMakes>> selectedCarMakesPerSection = {};
  final Map<String, RxList<CarModel>> carModelListPerSection = {};
  final Map<String, Rx<CarModel>> selectedCarModelPerSection = {};
  final Map<String, Rx<TextEditingController>> carPlatePerSection = {};

  RxBool isLoading = false.obs;

  /// True if driver has cab-service or rental-service section
  bool get hasVehicleBasedSection =>
      initialServiceType == 'cab-service' || initialServiceType == 'rental-service';

  @override
  void onInit() {
    super.onInit();
    selectedService.value = getReadableServiceType(initialServiceType);
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      isLoading.value = true;

      UserModel? model = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (model == null) return;

      userModel.value = model;

      // Load all sections for this service from Firestore
      final sections = await FireStoreUtils.getSections(initialServiceType);
      allSectionsForService.value = sections;

      // Filter to only sections this driver is registered in
      final driverSectionIds = model.sectionIds ?? [];
      driverSections.value = sections.where((s) => driverSectionIds.contains(s.id)).toList();

      // If driver has no sections yet for this service, show all (edit mode)
      if (driverSections.isEmpty) driverSections.value = sections;

      // Load vehicle types for each driver section
      for (final section in driverSections) {
        final sid = section.id ?? '';
        final types = await _fetchVehicleTypes(sid);
        vehicleTypesPerSection[sid] = RxList<VehicleType>(types);

        // Pre-select saved vehicle for this section
        final savedId = model.vehicleDetails?[sid]?['vehicleId']?.toString();
        VehicleType selected = types.isNotEmpty ? types.first : VehicleType();
        if (savedId != null && savedId.isNotEmpty && types.isNotEmpty) {
          selected = types.firstWhere((e) => e.id == savedId, orElse: () => types.first);
        }
        selectedVehiclePerSection[sid] = Rx<VehicleType>(selected);

        // Per-section ride type (default from vehicleDetails, else 'ride')
        final savedRideType = model.vehicleDetails?[sid]?['rideType']?.toString() ?? 'ride';
        selectedRideTypePerSection[sid] = RxString(savedRideType);
      }

      // Load car makes list (shared)
      await getCarMakes();

      // Load per-section car details from vehicleDetails
      for (final section in driverSections) {
        final sid = section.id ?? '';
        final sectionData = model.vehicleDetails?[sid];

        // Car plate number
        final savedPlate = sectionData?['carPlateNumber']?.toString() ?? '';
        carPlatePerSection[sid] = Rx<TextEditingController>(TextEditingController(text: savedPlate));

        // Car brand
        final savedBrand = sectionData?['carBrand']?.toString();
        if (savedBrand != null && savedBrand.isNotEmpty && carMakesList.isNotEmpty) {
          selectedCarMakesPerSection[sid] = Rx<CarMakes>(
            carMakesList.firstWhere((e) => e.name == savedBrand, orElse: () => CarMakes()),
          );
          // Load car models for this section
          final models = await FireStoreUtils.getCarModel(savedBrand);
          carModelListPerSection[sid] = RxList<CarModel>(models);

          // Car model
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
      }
    } catch (e) {
      log("loadUserData error: $e");
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<List<VehicleType>> _fetchVehicleTypes(String sectionId) async {
    if (sectionId.isEmpty) return [];
    if (initialServiceType == 'rental-service') {
      return FireStoreUtils.getRentalVehicleType(sectionId);
    }
    return FireStoreUtils.getCabVehicleType(sectionId);
  }

  Future<void> saveVehicleInformation() async {
    if (userModel.value.isOwner == true) {
      ShowToastDialog.showToast("Update not allowed for Owner type users.");
      return;
    }
    // Validate at least one section has a vehicle selected
    for (final section in driverSections) {
      final sid = section.id ?? '';
      if (selectedVehiclePerSection[sid]?.value.id == null) {
        ShowToastDialog.showToast("Please select a vehicle type for ${section.name}");
        return;
      }
    }
    // Per-section car details validation
    for (final section in driverSections) {
      final sid = section.id ?? '';
      final plate = carPlatePerSection[sid]?.value.text.trim() ?? '';
      final carMakes = selectedCarMakesPerSection[sid]?.value;
      final carModel = selectedCarModelPerSection[sid]?.value;
      if (plate.isEmpty) {
        ShowToastDialog.showToast("Please enter car plate number for ${section.name}");
        return;
      }
      if (carMakes?.id == null) {
        ShowToastDialog.showToast("Please select a car brand for ${section.name}");
        return;
      }
      if (carModel?.id == null) {
        ShowToastDialog.showToast("Please select a car model for ${section.name}");
        return;
      }
    }

    ShowToastDialog.showLoader("Updating vehicle information...");
    try {
      // Merge vehicleDetails: only update sections for this service, keep others intact
      final existing = Map<String, dynamic>.from(userModel.value.vehicleDetails ?? {});
      for (final section in driverSections) {
        final sid = section.id ?? '';
        final vehicle = selectedVehiclePerSection[sid]?.value;
        final carMakes = selectedCarMakesPerSection[sid]?.value;
        final carModel = selectedCarModelPerSection[sid]?.value;
        final carPlate = carPlatePerSection[sid]?.value.text.trim() ?? '';
        if (vehicle?.id != null) {
          existing[sid] = {
            'vehicleId': vehicle!.id ?? '',
            'vehicleType': vehicle.name ?? '',
            'carBrand': carMakes?.name ?? '',
            'carModel': carModel?.name ?? '',
            'carPlateNumber': carPlate,
            if (initialServiceType == 'cab-service')
              'rideType': selectedRideTypePerSection[sid]?.value ?? 'ride',
          };
        }
      }
      userModel.value.vehicleDetails = existing;

      bool success = await FireStoreUtils.updateUser(userModel.value);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          success ? "Vehicle information updated successfully." : "Failed to update. Please try again.");
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error updating vehicle info: $e");
      log("Error: $e");
    }
  }

  Future<void> getCarMakes() async {
    try {
      carMakesList.value = await FireStoreUtils.getCarMakes();
    } catch (e) {
      log("Error loading car makes: $e");
    }
  }

  Future<void> getCarModelForSection(String sectionId) async {
    try {
      final carMakes = selectedCarMakesPerSection[sectionId]?.value;
      if (carMakes?.name == null || carMakes!.name!.isEmpty) {
        carModelListPerSection[sectionId]?.clear();
        selectedCarModelPerSection[sectionId]?.value = CarModel();
        return;
      }
      final models = await FireStoreUtils.getCarModel(carMakes.name!);
      carModelListPerSection[sectionId]?.value = models;
      if (models.isNotEmpty) {
        selectedCarModelPerSection[sectionId]?.value = models.first;
      } else {
        selectedCarModelPerSection[sectionId]?.value = CarModel();
      }
      update();
    } catch (e) {
      log("Error loading car models: $e");
    }
  }

  String getReadableServiceType(String key) {
    switch (key) {
      case 'cab-service':
        return 'Cab Service';
      case 'parcel_delivery':
        return 'Parcel Service';
      case 'rental-service':
        return 'Rental Service';
      default:
        return 'Delivery Service';
    }
  }

  String getServiceTypeKey(String name) {
    switch (name) {
      case 'Cab Service':
        return 'cab-service';
      case 'Parcel Service':
        return 'parcel_delivery';
      case 'Rental Service':
        return 'rental-service';
      default:
        return 'delivery-service';
    }
  }
}
