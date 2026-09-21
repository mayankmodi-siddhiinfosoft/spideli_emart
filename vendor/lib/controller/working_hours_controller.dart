import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class WorkingHoursController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<WorkingHours> workingHours = <WorkingHours>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getVendor();
    super.onInit();
  }

  Rx<VendorModel> vendorModel = VendorModel().obs;

  Future<void> getVendor() async {
    await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) {
      if (value != null) {
        vendorModel.value = value;
        if (vendorModel.value.workingHours == null || vendorModel.value.workingHours!.isEmpty) {
          workingHours.value = [
            WorkingHours(day: 'Monday', timeslot: []),
            WorkingHours(day: 'Tuesday', timeslot: []),
            WorkingHours(day: 'Wednesday', timeslot: []),
            WorkingHours(day: 'Thursday', timeslot: []),
            WorkingHours(day: 'Friday', timeslot: []),
            WorkingHours(day: 'Saturday', timeslot: []),
            WorkingHours(day: 'Sunday', timeslot: []),
          ];
        } else {
          workingHours.value = vendorModel.value.workingHours!;
        }
      }
    });
    isLoading.value = false;
  }

  Future<void> saveWorkingHours() async {
    ShowToastDialog.showLoader("Please wait".tr);

    FocusScope.of(Get.context!).requestFocus(FocusNode()); //remove focus
    vendorModel.value.workingHours = workingHours;

    await FireStoreUtils.updateVendor(vendorModel.value).then((value) async {
      ShowToastDialog.showToast("Working hours update successfully".tr);
      ShowToastDialog.closeLoader();
    });
  }

  void addValue(int index) {
    WorkingHours specialDiscountModel = workingHours[index];
    specialDiscountModel.timeslot!.add(Timeslot(from: '', to: ''));
    workingHours.removeAt(index);
    workingHours.insert(index, specialDiscountModel);
    update();
  }

  void remove(int index, int timeSlotIndex) {
    WorkingHours specialDiscountModel = workingHours[index];
    specialDiscountModel.timeslot!.removeAt(timeSlotIndex);
    workingHours.removeAt(index);
    workingHours.insert(index, specialDiscountModel);
    update();
    update();
  }
}
