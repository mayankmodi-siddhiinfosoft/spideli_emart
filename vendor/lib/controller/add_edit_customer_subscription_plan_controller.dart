import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
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

  // Delivery schedule (spec 4.7): items, frequency, delivery days, time slot.
  RxList<PlanItemRow> itemRows = <PlanItemRow>[].obs;
  RxString frequency = VendorSubscriptionPlanModel.frequencyDaily.obs;
  RxList<String> deliveryDays = List<String>.from(VendorSubscriptionPlanModel.weekdays).obs;
  RxString slotFrom = "".obs;
  RxString slotTo = "".obs;

  Rx<VendorSubscriptionPlanModel> planModel = VendorSubscriptionPlanModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  String? vendorRegionId;

  bool get isEdit => planModel.value.id != null;

  /// A plan created before schedules existed, being edited without adding one:
  /// it keeps working as before (listed under "No delivery schedule"), so the
  /// owner can still change its price or text.
  bool get _keepsNoSchedule => isEdit && !_hadSchedule && _filledItemRows.isEmpty;
  bool _hadSchedule = true;

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
      final plan = planModel.value;
      itemRows.value = plan.items.map((e) => PlanItemRow(name: e.name ?? '', quantity: e.quantity ?? '')).toList();
      if (plan.frequency != null) frequency.value = plan.frequency!;
      _hadSchedule = plan.hasSchedule;
      if (plan.hasSchedule) deliveryDays.value = List<String>.from(plan.effectiveDeliveryDays);
      if (frequency.value == VendorSubscriptionPlanModel.frequencyWeekly && deliveryDays.length != 1) {
        deliveryDays.value = [deliveryDays.isEmpty ? VendorSubscriptionPlanModel.weekdays.first : deliveryDays.first];
      }
      slotFrom.value = plan.timeSlot?.from ?? '';
      slotTo.value = plan.timeSlot?.to ?? '';
    }
    if (itemRows.isEmpty) itemRows.add(PlanItemRow());
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
    final scheduleError = _keepsNoSchedule ? null : _validateSchedule();
    if (scheduleError != null) {
      ShowToastDialog.showToast(scheduleError);
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
      if (!_keepsNoSchedule) {
        plan.items = _filledItemRows.map((r) => VendorSubscriptionPlanItem(name: r.nameController.text.trim(), quantity: r.quantityController.text.trim())).toList();
        plan.frequency = frequency.value;
        plan.deliveryDays = VendorSubscriptionPlanModel.weekdays.where(deliveryDays.contains).toList();
        plan.timeSlot = VendorSubscriptionTimeSlot(from: slotFrom.value, to: slotTo.value);
      }

      await CustomerSubscriptionService.savePlan(plan);
      ShowToastDialog.closeLoader();
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
  }

  // ---------------------------------------------------------------- Schedule

  /// Rows where the user typed something (fully blank rows are ignored).
  List<PlanItemRow> get _filledItemRows => itemRows.where((r) => r.nameController.text.trim().isNotEmpty || r.quantityController.text.trim().isNotEmpty).toList();

  String? _validateSchedule() {
    final rows = _filledItemRows;
    if (rows.isEmpty) return "Please add at least one item".tr;
    for (final r in rows) {
      if (r.nameController.text.trim().isEmpty) return "Please enter a name for every item".tr;
      final qty = int.tryParse(r.quantityController.text.trim());
      if (qty == null || qty < 1) return "Item quantity must be at least 1".tr;
    }
    if (deliveryDays.isEmpty) return "Please select at least one delivery day".tr;
    if (frequency.value == VendorSubscriptionPlanModel.frequencyWeekly && deliveryDays.length != 1) return "A weekly plan delivers on exactly one day".tr;
    final from = VendorSubscriptionTimeSlot.minutesOf(slotFrom.value);
    final to = VendorSubscriptionTimeSlot.minutesOf(slotTo.value);
    if (from == null || to == null) return "Please select the delivery time slot".tr;
    if (from >= to) return "The time slot must end after it starts".tr;
    return null;
  }

  void addItemRow() => itemRows.add(PlanItemRow());

  void removeItemRow(PlanItemRow row) {
    itemRows.remove(row);
    // Dispose once the row's text fields have left the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    if (itemRows.isEmpty) itemRows.add(PlanItemRow());
  }

  void setFrequency(String value) {
    if (frequency.value == value) return;
    frequency.value = value;
    if (value == VendorSubscriptionPlanModel.frequencyDaily) {
      deliveryDays.value = List<String>.from(VendorSubscriptionPlanModel.weekdays);
    } else {
      deliveryDays.value = [deliveryDays.isEmpty ? VendorSubscriptionPlanModel.weekdays.first : VendorSubscriptionPlanModel.weekdays.firstWhere(deliveryDays.contains)];
    }
  }

  /// Daily: toggle the day. Weekly: the tapped day becomes the only day.
  void toggleDay(String day) {
    if (frequency.value == VendorSubscriptionPlanModel.frequencyWeekly) {
      deliveryDays.value = [day];
    } else if (deliveryDays.contains(day)) {
      deliveryDays.remove(day);
    } else {
      deliveryDays.add(day);
    }
  }

  static String formatTime(TimeOfDay time) => "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  static TimeOfDay? parseTime(String hhmm) {
    final minutes = VendorSubscriptionTimeSlot.minutesOf(hhmm);
    return minutes == null ? null : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  void onClose() {
    for (final r in itemRows) {
      r.dispose();
    }
    super.onClose();
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

/// One editable "item + quantity" row of the plan form.
class PlanItemRow {
  final TextEditingController nameController;
  final TextEditingController quantityController;

  PlanItemRow({String name = '', String quantity = ''})
      : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity);

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
