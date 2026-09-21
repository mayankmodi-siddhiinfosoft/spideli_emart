import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class SpecialDiscountController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<SpecialDiscount> specialDiscount = <SpecialDiscount>[].obs;

  List<String> discountType = ['Dine-In Discount', 'Delivery Discount'].obs;
  List<String> type = [Constant.currencyModel!.symbol!, '%'];

  @override
  void onInit() {
    // TODO: implement onInit
    getVendor();
    super.onInit();
  }

  Rx<VendorModel> vendorModel = VendorModel().obs;
  RxBool isSpecialSwitched = false.obs;

  Future<void> getVendor() async {
    await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) {
      if (value != null) {
        vendorModel.value = value;

        if (vendorModel.value.specialDiscount == null || vendorModel.value.specialDiscount!.isEmpty) {
          specialDiscount.value = [
            SpecialDiscount(day: 'Monday', timeslot: []),
            SpecialDiscount(day: 'Tuesday', timeslot: []),
            SpecialDiscount(day: 'Wednesday', timeslot: []),
            SpecialDiscount(day: 'Thursday', timeslot: []),
            SpecialDiscount(day: 'Friday', timeslot: []),
            SpecialDiscount(day: 'Saturday', timeslot: []),
            SpecialDiscount(day: 'Sunday', timeslot: []),
          ];
        } else {
          specialDiscount.value = vendorModel.value.specialDiscount!;
        }
        isSpecialSwitched.value = vendorModel.value.specialDiscountEnable ?? false;
      }
    });

    isLoading.value = false;
  }

  Future<void> saveSpecialOffer() async {
    ShowToastDialog.showLoader("Please wait".tr);

    FocusScope.of(Get.context!).requestFocus(FocusNode()); //remove focus
    vendorModel.value.specialDiscount = specialDiscount;
    vendorModel.value.specialDiscountEnable = isSpecialSwitched.value;

    await FireStoreUtils.updateVendor(vendorModel.value).then((value) async {
      ShowToastDialog.showToast("Special discount update successfully".tr);
      ShowToastDialog.closeLoader();
    });
  }

  void addValue(int index) {
    SpecialDiscount specialDiscountModel = specialDiscount[index];
    specialDiscountModel.timeslot!.add(SpecialDiscountTimeslot(from: '', to: '', discount: '', type: 'percentage', discountType: 'delivery'));
    specialDiscount.removeAt(index);
    specialDiscount.insert(index, specialDiscountModel);
    update();
  }

  void changeValue(int index, int indexTimeSlot, String value) {
    SpecialDiscount specialDiscountModel = specialDiscount[index];

    List<SpecialDiscountTimeslot>? list = specialDiscountModel.timeslot!;

    SpecialDiscountTimeslot discountTimeslot = list[indexTimeSlot];
    discountTimeslot.type = value;
    list.removeAt(indexTimeSlot);
    list.insert(indexTimeSlot, discountTimeslot);

    specialDiscountModel.timeslot = list;
    specialDiscount.removeAt(index);
    specialDiscount.insert(index, specialDiscountModel);
    update();
  }

  void remove(int index, int timeSlotIndex) {
    SpecialDiscount specialDiscountModel = specialDiscount[index];
    specialDiscountModel.timeslot!.removeAt(timeSlotIndex);
    specialDiscount.removeAt(index);
    specialDiscount.insert(index, specialDiscountModel);
    update();
    update();
  }
}
