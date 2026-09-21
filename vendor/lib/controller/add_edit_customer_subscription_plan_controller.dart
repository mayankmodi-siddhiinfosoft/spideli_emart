import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/utils/customer_subscription_service.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Add / edit a plan the store sells to its own customers.
class AddEditCustomerSubscriptionPlanController extends GetxController {
  static const String periodMonthly = "monthly";
  static const String periodAnnual = "annual";
  static const String periodCustom = "custom";

  RxBool isLoading = true.obs;
  Rx<TextEditingController> titleController = TextEditingController().obs;
  Rx<TextEditingController> descriptionController = TextEditingController().obs;
  Rx<TextEditingController> priceController = TextEditingController().obs;
  Rx<TextEditingController> daysController = TextEditingController().obs;
  RxString selectedPeriod = periodMonthly.obs;
  RxBool isEnable = true.obs;
  RxList images = <dynamic>[].obs;

  Rx<VendorSubscriptionPlanModel> planModel = VendorSubscriptionPlanModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  String? vendorRegionId;

  bool get isEdit => planModel.value.id != null;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    final dynamic argumentData = Get.arguments;
    if (argumentData != null && argumentData['planModel'] != null) {
      planModel.value = argumentData['planModel'];
      titleController.value.text = planModel.value.title ?? '';
      descriptionController.value.text = planModel.value.description ?? '';
      priceController.value.text = planModel.value.price ?? '';
      isEnable.value = planModel.value.isEnable ?? true;
      final days = planModel.value.expiryDays;
      if (days == 30) {
        selectedPeriod.value = periodMonthly;
      } else if (days == 365) {
        selectedPeriod.value = periodAnnual;
      } else {
        selectedPeriod.value = periodCustom;
        daysController.value.text = days > 0 ? days.toString() : '';
      }
      if (planModel.value.photo != null && planModel.value.photo!.isNotEmpty) {
        images.add(planModel.value.photo);
      }
    }
    final vendorId = Constant.userModel?.vendorID;
    if (vendorId != null && vendorId.isNotEmpty) {
      final vendor = await FireStoreUtils.getVendorById(vendorId);
      if (vendor != null) vendorModel.value = vendor;
      vendorRegionId = await CustomerSubscriptionService.getVendorRegionId(vendorId);
    }
    isLoading.value = false;
  }

  String? _resolveDays() {
    switch (selectedPeriod.value) {
      case periodMonthly:
        return "30";
      case periodAnnual:
        return "365";
      default:
        final days = int.tryParse(daysController.value.text.trim());
        if (days == null || days <= 0) return null;
        return days.toString();
    }
  }

  Future<void> savePlan() async {
    final title = titleController.value.text.trim();
    final price = double.tryParse(priceController.value.text.trim());
    final days = _resolveDays();
    final vendorId = Constant.userModel?.vendorID;

    if (vendorId == null || vendorId.isEmpty) {
      ShowToastDialog.showToast("Store not found".tr);
      return;
    }
    if (title.isEmpty) {
      ShowToastDialog.showToast("Please enter title".tr);
      return;
    }
    if (price == null || price <= 0) {
      ShowToastDialog.showToast("Please enter a price greater than 0".tr);
      return;
    }
    if (days == null) {
      ShowToastDialog.showToast("Please enter a valid number of days".tr);
      return;
    }

    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      for (int i = 0; i < images.length; i++) {
        if (images[i] is XFile) {
          final file = File(images[i].path);
          final url = await Constant.uploadUserImageToFireStorage(file, "customerSubscriptionPlans/${DateTime.now().toIso8601String()}", file.path.split('/').last);
          images[i] = url;
        }
      }

      final plan = planModel.value;
      plan.id = plan.id ?? Constant.getUuid();
      plan.vendorID = vendorId;
      plan.sectionId = vendorModel.value.sectionId ?? plan.sectionId;
      plan.regionId = vendorRegionId ?? plan.regionId;
      plan.title = title;
      plan.description = descriptionController.value.text.trim();
      plan.photo = images.isEmpty ? "" : images.first.toString();
      plan.price = priceController.value.text.trim();
      plan.expiryDay = days;
      plan.isEnable = isEnable.value;
      plan.createdAt = plan.createdAt ?? Timestamp.now();

      await CustomerSubscriptionService.savePlan(plan);
      ShowToastDialog.closeLoader();
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future pickFile({required ImageSource source}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      images.clear();
      images.add(image);
      Get.back();
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"Failed to Pick :".tr} \n $e");
    }
  }
}
