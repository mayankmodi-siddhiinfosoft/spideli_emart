import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/add_edit_customer_subscription_plan_controller.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// Create / edit a Customer Subscription plan (sold by this store to its own customers).
class AddEditCustomerSubscriptionPlanScreen extends StatelessWidget {
  const AddEditCustomerSubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddEditCustomerSubscriptionPlanController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              controller.isEdit ? "Edit Customer Subscription Plan".tr : "Create Customer Subscription Plan".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DottedBorder(
                          options: RoundedRectDottedBorderOptions(radius: const Radius.circular(12), dashPattern: const [6, 6, 6, 6], color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                          child: Container(
                            decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.all(Radius.circular(12))),
                            child: SizedBox(
                              height: Responsive.height(20, context),
                              width: Responsive.width(90, context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset('assets/icons/ic_folder.svg'),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Choose a image and upload here".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium, fontSize: 16),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "JPEG, PNG".tr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                                  ),
                                  const SizedBox(height: 10),
                                  RoundedButtonFill(
                                    title: "Brows Image".tr,
                                    color: AppThemeData.secondary50,
                                    width: 30,
                                    height: 5,
                                    textColor: AppThemeData.primary300,
                                    onPress: () async {
                                      buildBottomSheet(context, controller);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        controller.images.isEmpty
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: controller.images.first is XFile
                                          ? Image.file(File(controller.images.first.path), fit: BoxFit.cover, width: 80, height: 80)
                                          : NetworkImageWidget(imageUrl: controller.images.first.toString(), fit: BoxFit.cover, width: 80, height: 80),
                                    ),
                                    Positioned.fill(
                                      child: InkWell(
                                        onTap: () {
                                          controller.images.clear();
                                        },
                                        child: const Icon(Icons.remove_circle, size: 28, color: AppThemeData.danger300),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 10),
                        TextFieldWidget(title: 'Title'.tr, controller: controller.titleController.value, hintText: 'e.g. Daily Bread — Monthly'.tr, maxLength: 60),
                        TextFieldWidget(title: 'Description'.tr, controller: controller.descriptionController.value, hintText: 'Description'.tr, maxLine: 4),
                        TextFieldWidget(
                          title: 'Price'.tr,
                          controller: controller.priceController.value,
                          hintText: 'Enter price'.tr,
                          textInputType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          prefix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Text(
                              Constant.currencyModel?.symbol ?? '',
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                            ),
                          ),
                        ),
                        Text(
                          'Billing period'.tr,
                          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                        Row(
                          children: [
                            _periodOption(controller, AddEditCustomerSubscriptionPlanController.periodMonthly, "Monthly".tr, isDark),
                            _periodOption(controller, AddEditCustomerSubscriptionPlanController.periodAnnual, "Annual".tr, isDark),
                            _periodOption(controller, AddEditCustomerSubscriptionPlanController.periodCustom, "Custom".tr, isDark),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (controller.selectedPeriod.value == AddEditCustomerSubscriptionPlanController.periodCustom)
                          TextFieldWidget(
                            title: 'Number of days'.tr,
                            controller: controller.daysController.value,
                            hintText: 'e.g. 7'.tr,
                            textInputType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        _scheduleSection(context, controller, isDark),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Enabled".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: CupertinoSwitch(
                                value: controller.isEnable.value,
                                activeTrackColor: AppThemeData.primary300,
                                onChanged: (value) {
                                  controller.isEnable.value = value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Save Plan".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  controller.savePlan();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ Delivery schedule

  Widget _sectionTitle(String text, bool isDark, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleSection(BuildContext context, AddEditCustomerSubscriptionPlanController controller, bool isDark) {
    final isWeekly = controller.frequency.value == VendorSubscriptionPlanModel.frequencyWeekly;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
    );
    InputDecoration fieldDecoration(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: AppThemeData.primary300)),
          hintStyle: TextStyle(fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, fontSize: 14, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
        );
    final inputStyle = TextStyle(fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _sectionTitle("Items per delivery".tr, isDark, subtitle: "What one delivery contains, e.g. Baguette × 2".tr),
        ...controller.itemRows.map(
          (row) => Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: row.nameController,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: AppThemeData.primary300,
                    style: inputStyle,
                    decoration: fieldDecoration("Item name".tr),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    cursorColor: AppThemeData.primary300,
                    textAlign: TextAlign.center,
                    style: inputStyle,
                    decoration: fieldDecoration("Qty".tr),
                  ),
                ),
                IconButton(
                  tooltip: "Remove item".tr,
                  onPressed: () => controller.removeItemRow(row),
                  icon: const Icon(Icons.remove_circle_outline, color: AppThemeData.danger300, size: 22),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: controller.addItemRow,
          icon: Icon(Icons.add, color: AppThemeData.primary300, size: 20),
          label: Text(
            "Add item".tr,
            style: TextStyle(fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, fontSize: 14, color: AppThemeData.primary300),
          ),
        ),
        const SizedBox(height: 8),
        _sectionTitle("Frequency".tr, isDark),
        Row(
          children: [
            _radioOption("Daily".tr, !isWeekly, isDark, () => controller.setFrequency(VendorSubscriptionPlanModel.frequencyDaily)),
            _radioOption("Weekly".tr, isWeekly, isDark, () => controller.setFrequency(VendorSubscriptionPlanModel.frequencyWeekly)),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle("Delivery days".tr, isDark, subtitle: isWeekly ? "Pick the one day of the week to deliver".tr : "Untick the days without delivery".tr),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VendorSubscriptionPlanModel.weekdays.map((day) {
            final selected = controller.deliveryDays.contains(day);
            return ChoiceChip(
              label: Text(CustomerSubscriptionController.shortDay(day)),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => controller.toggleDay(day),
              selectedColor: AppThemeData.primary300,
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              side: BorderSide(color: selected ? AppThemeData.primary300 : (isDark ? AppThemeData.grey700 : AppThemeData.grey200)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              labelStyle: TextStyle(
                fontFamily: AppThemeData.medium,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: selected ? AppThemeData.grey50 : (isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _sectionTitle("Delivery time slot".tr, isDark),
        Row(
          children: [
            Expanded(child: _timeField(context, "From".tr, controller.slotFrom, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _timeField(context, "To".tr, controller.slotTo, isDark)),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _radioOption(String label, bool selected, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppThemeData.primary300 : (isDark ? AppThemeData.grey500 : AppThemeData.grey400), size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, fontSize: 15, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(BuildContext context, String label, RxString value, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: AddEditCustomerSubscriptionPlanController.parseTime(value.value) ?? const TimeOfDay(hour: 7, minute: 0),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
        if (picked != null) value.value = AddEditCustomerSubscriptionPlanController.formatTime(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
            const SizedBox(width: 8),
            Text(
              "$label ",
              style: TextStyle(fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, fontSize: 13, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
            ),
            Expanded(
              child: Text(
                value.value.isEmpty ? "--:--" : value.value,
                textAlign: TextAlign.end,
                style: TextStyle(fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodOption(AddEditCustomerSubscriptionPlanController controller, String value, String label, bool isDark) {
    final selected = controller.selectedPeriod.value == value;
    return Expanded(
      child: InkWell(
        onTap: () => controller.selectedPeriod.value = value,
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppThemeData.primary300 : (isDark ? AppThemeData.grey500 : AppThemeData.grey400), size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 15, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future buildBottomSheet(BuildContext context, AddEditCustomerSubscriptionPlanController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;
        return SizedBox(
          height: Responsive.height(22, context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  "Please Select".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.bold, fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: () => controller.pickFile(source: ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 32),
                        ),
                        Padding(padding: const EdgeInsets.only(top: 3), child: Text("Camera".tr)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: () => controller.pickFile(source: ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_sharp, size: 32),
                        ),
                        Padding(padding: const EdgeInsets.only(top: 3), child: Text("Gallery".tr)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
