import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class ChangeSectionController extends GetxController {
  var isLoading = false.obs;

  RxList<SectionModel> allSections = <SectionModel>[].obs;
  RxList<SectionModel> selectedSections = <SectionModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;

    allSections.value = await FireStoreUtils.getAllActiveSections();

    final user = Constant.userModel;
    if (user != null && user.sectionIds != null) {
      for (final section in allSections) {
        if (user.sectionIds!.contains(section.id)) {
          selectedSections.add(section);
        }
      }
    }

    isLoading.value = false;
  }

  bool isSectionSelected(SectionModel section) =>
      selectedSections.any((s) => s.id == section.id);

  Future<void> toggleSection(SectionModel section) async {
    if (isSectionSelected(section)) {
      if (selectedSections.length == 1) {
        ShowToastDialog.showToast("At least one section must be selected.".tr);
        return;
      }
      selectedSections.removeWhere((s) => s.id == section.id);
    } else {
      selectedSections.add(section);
    }
    update();
  }

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

  Future<void> saveChanges() async {
    if (selectedSections.isEmpty) {
      ShowToastDialog.showToast("Please select at least one section.".tr);
      return;
    }

    ShowToastDialog.showLoader("Please wait".tr);

    final UserModel user = Constant.userModel!;
    final selectedIds = selectedSections.map((s) => s.id).toSet();

    // Update user fields
    user.sectionIds = selectedSections.map((s) => s.id!).toList();

    final uniqueFlags = selectedSections
        .map((s) => s.serviceTypeFlag ?? 'delivery-service')
        .toSet()
        .toList();
    user.serviceTypes = uniqueFlags;

    final newSectionNames = {
      for (final s in selectedSections) s.id!: s.name ?? s.id!,
    };
    user.sectionNames = newSectionNames;

    // Remove vehicle details for unselected sections
    Map<String, dynamic>? newVehicleDetails;
    if (user.vehicleDetails != null) {
      newVehicleDetails = Map<String, dynamic>.from(user.vehicleDetails!);
      newVehicleDetails.removeWhere((key, _) => !selectedIds.contains(key));
      if (newVehicleDetails.isEmpty) newVehicleDetails = null;
    }

    // Clear vehicle info if no cab/rental section is selected
    final hasVehicleSection = selectedSections.any((s) =>
        s.serviceTypeFlag == 'cab-service' || s.serviceTypeFlag == 'rental-service');
    if (!hasVehicleSection) {
      newVehicleDetails = null;
    }
    user.vehicleDetails = newVehicleDetails;

    // First save all user fields via normal updateUser
    await FireStoreUtils.updateUser(user);

    // Then overwrite sectionNames and vehicleDetails directly
    // updateUser uses set(merge:true) which merges nested map keys
    // so old keys in sectionNames/vehicleDetails persist.
    // This second write replaces those fields entirely.
    final docRef = FirebaseFirestore.instance
        .collection(CollectionName.users)
        .doc(user.id);

    await docRef.set({
      'sectionNames': newSectionNames,
      'vehicleDetails': newVehicleDetails ?? FieldValue.delete(),
    }, SetOptions(mergeFields: ['sectionNames', 'vehicleDetails']));

    // Update local cache
    Constant.userModel = user;
    for (final section in selectedSections) {
      Constant.sectionModels[section.id!] = section;
    }

    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Sections updated successfully".tr);

    SignupController.navigateByUserModel(user);
  }
}
