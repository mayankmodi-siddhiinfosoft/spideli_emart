import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import 'package:customer/utils/address_format.dart';

class EnterManuallyLocationController extends GetxController {
  Rx<UserModel> userModel = UserModel().obs;

  RxList<ShippingAddress> shippingAddressList = <ShippingAddress>[].obs;

  List saveAsList = ['Home', 'Work', 'Hotel', 'other'].obs;
  RxString selectedSaveAs = "Home".obs;

  Rx<TextEditingController> houseBuildingTextEditingController = TextEditingController().obs;
  Rx<TextEditingController> localityEditingController = TextEditingController().obs;
  Rx<TextEditingController> landmarkEditingController = TextEditingController().obs;
  Rx<UserLocation> location = UserLocation().obs;
  Rx<ShippingAddress> shippingModel = ShippingAddress().obs;
  RxBool isLoading = false.obs;
  RxBool isDefault = false.obs;

  RxString mode = "Add".obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      //check mode
      mode.value = argumentData['mode'] ?? "Add";

      //check address
      if (argumentData['address'] != null && argumentData['address'] is ShippingAddress) {
        shippingModel.value = argumentData['address'];
        setData(shippingModel.value);
      }
    }

    await getUser();
    isLoading.value = false;
    update();
  }

  void setData(ShippingAddress shippingAddress) {
    shippingModel.value = shippingAddress;
    // `null.toString()` is the four characters "null": editing an address that
    // was saved without a landmark (or house number) put "null" in the field,
    // and saving it wrote that text back into the address (report #17). The
    // same formatter also cleans a legacy "18, null, Yaoundé" locality before
    // the customer sees it, so re-saving the address repairs it.
    houseBuildingTextEditingController.value.text = formatAddressLine([shippingAddress.address]);
    localityEditingController.value.text = formatAddressLine([shippingAddress.locality]);
    landmarkEditingController.value.text = formatAddressLine([shippingAddress.landmark]);
    selectedSaveAs.value = shippingAddress.addressAs ?? selectedSaveAs.value;
    location.value = shippingAddress.location!;
  }

  Future<void> getUser() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        if (userModel.value.shippingAddress != null) {
          shippingAddressList.value = userModel.value.shippingAddress!;
        }
      }
    });
  }

  String getLocalizedSaveAs(String key) {
    switch (key) {
      case 'Home':
        return 'Home'.tr;
      case 'Work':
        return 'Work'.tr;
      case 'Hotel':
        return 'Hotel'.tr;
      case 'Other':
        return 'Other'.tr;
      default:
        return key;
    }
  }
}
