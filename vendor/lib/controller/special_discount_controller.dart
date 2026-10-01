import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class SpecialDiscountController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<SpecialDiscount> specialDiscount = <SpecialDiscount>[].obs;

  /// The two kinds of discount, as the *untranslated* keys they are stored
  /// against. They double as the dropdown's item values, so the value the
  /// field opens on is always one of its own items whatever the app language
  /// is: translated item values put the initial value out of range and the
  /// dropdown then asserts instead of rendering.
  static const String dineInDiscountOption = 'Dine-In Discount';
  static const String deliveryDiscountOption = 'Delivery Discount';
  static const List<String> discountTypeOptions = [dineInDiscountOption, deliveryDiscountOption];

  /// What `timeslot.discountType` is stored as for [option].
  static String storedDiscountType(String? option) => option == dineInDiscountOption ? 'dinein' : 'delivery';

  /// The option a stored `timeslot.discountType` maps onto. Always a member of
  /// [discountTypeOptions], including for a value the panel wrote that this
  /// app does not know.
  static String discountTypeOption(String? stored) => stored == 'dinein' ? dineInDiscountOption : deliveryDiscountOption;

  List<String> discountType = discountTypeOptions;

  /// The amount / percentage units. A getter, not a field: the field ran
  /// `Constant.currencyModel!` while the controller was being constructed, and
  /// the global currency arrives from a Firestore snapshot - so opening this
  /// screen before the first snapshot threw and the screen never built. It also
  /// keeps the list in step with a currency that changes later, which a cached
  /// list did not (the unit dropdown's selected value then fell outside its own
  /// items).
  String get currencySymbol => Constant.currencyModel?.symbol ?? '';

  List<String> get type => [currencySymbol, '%'];

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
