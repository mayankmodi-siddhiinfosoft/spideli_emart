import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/add_or_update_service_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/category_model.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/geoflutterfire.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/models/point.dart';
import 'package:spideliprovider/widgets/osm_map/map_picker_page.dart';
import 'package:spideliprovider/widgets/place_picker/location_picker_screen.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_helper.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AddOrUpdateServiceScreen extends StatelessWidget {
  const AddOrUpdateServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateServiceController>(
        init: AddOrUpdateServiceController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
              title: Text(
                controller.serviceModel.value.title.toString() != '' ? "Edit Service".tr : "Add Service".tr,
                style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
              ),
              leading: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: const Icon(
                    Icons.arrow_back,
                  )),
            ),
            body: controller.isLoading.value
                ? loader()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Form(
                          key: controller.formKey.value,
                          autovalidateMode: controller.validate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Service Name".tr,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                              ),
                              TextFormField(
                                  controller: controller.serviceName.value,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.next,
                                  validator: validateEmptyField,
                                  keyboardType: TextInputType.text,
                                  cursorColor: AppColors.colorPrimary,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    hintText: "Service Name".tr,
                                    hintStyle: TextStyle(
                                      color: themeChange.getTheme() ? Colors.white : const Color(0Xff333333),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  )),
                              Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    "Select Section".tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  )),
                              ((controller.serviceModel.value.subscriptionPlan == null) || (isSubscriptionModelApplied == false && controller.selectedSection.value.adminCommision?.enable == false))
                                  ? DropdownButtonFormField<SectionModel>(
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                          borderRadius: BorderRadius.circular(7.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                          borderRadius: BorderRadius.circular(7.0),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey.shade400),
                                          borderRadius: BorderRadius.circular(7.0),
                                        ),
                                      ),
                                      validator: (value) => value == null ? 'field required' : null,
                                      value: controller.selectedSection.value.id == null ? null : controller.selectedSection.value,
                                      onChanged: (value) async {
                                        controller.selectedSection.value = value!;

                                        await FireStoreUtils.getCategory(controller.selectedSection.value.id.toString()).then((value) {
                                          controller.categoryVal.value = value;
                                        });

                                        if (controller.categoryVal.isNotEmpty) {
                                          controller.selectedCategory.value = controller.categoryVal.first;
                                          await FireStoreUtils.getSubCategory(controller.selectedCategory.value.id!).then((value) {
                                            controller.subCategoryList.value = value;
                                          });
                                          if (controller.subCategoryList.isNotEmpty) {
                                            controller.selectedSubCategory.value = controller.subCategoryList.first;
                                          }
                                        } else {
                                          Get.showSnackbar(
                                            GetSnackBar(
                                              message: 'No category for this section'.tr,
                                              duration: 5.seconds,
                                            ),
                                          );
                                        }
                                      },
                                      hint: Text("Select OnDemand section".tr),
                                      items: controller.sectionList.map((item) {
                                        return DropdownMenuItem(
                                          value: item,
                                          child: Text(item.name.toString()),
                                        );
                                      }).toList())
                                  : Container(
                                      padding: const EdgeInsetsDirectional.only(bottom: 5),
                                      child: InkWell(
                                        onTap: () {
                                          ShowToastDialog.showToast("You are not able to change section. because of your plan is purchased on ${selectedSectionModel!.name} section");
                                        },
                                        child: TextFormField(
                                            initialValue: controller.selectedSection.value.name.toString() + " (${controller.selectedSection.value.serviceType})",
                                            textAlignVertical: TextAlignVertical.center,
                                            textInputAction: TextInputAction.next,
                                            keyboardType: TextInputType.streetAddress,
                                            enabled: false,
                                            cursorColor: AppThemeData.primary600,
                                            // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                                            decoration: InputDecoration(
                                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                                hintText: 'Section'.tr,
                                                hintStyle: TextStyle(
                                                  color: themeChange.getTheme() ? Colors.white : Color(0Xff333333),
                                                  fontSize: 14,
                                                  fontFamily: AppThemeData.medium,
                                                ),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppThemeData.primary600, width: 2.0)),
                                                errorBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                                  borderRadius: BorderRadius.circular(7.0),
                                                ),
                                                focusedErrorBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                                  borderRadius: BorderRadius.circular(7.0),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                                  borderRadius: BorderRadius.circular(7.0),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                                  borderRadius: BorderRadius.circular(7.0),
                                                ))),
                                      ),
                                    ),
                              Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    "Select Category".tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  )),
                              DropdownButtonFormField<CategoryModel>(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  ),
                                  validator: (value) => value == null ? 'field required'.tr : null,
                                  value: controller.selectedCategory.value.id == null ? null : controller.selectedCategory.value,
                                  onChanged: (value) async {
                                    controller.selectedCategory.value = value!;
                                    print(controller.selectedCategory.value.title);
                                    await FireStoreUtils.getSubCategory(controller.selectedCategory.value.id.toString()).then((value) {
                                      controller.subCategoryList.value = value;
                                    });
                                    if (controller.subCategoryList.isNotEmpty) {
                                      controller.selectedSubCategory.value = controller.subCategoryList.first;
                                    } else {
                                      Get.showSnackbar(
                                        GetSnackBar(
                                          message: 'No Sub category for this category'.tr,
                                          duration: 5.seconds,
                                        ),
                                      );
                                    }
                                  },
                                  hint: Text('Select Category'.tr),
                                  items: controller.categoryVal.map((CategoryModel item) {
                                    return DropdownMenuItem<CategoryModel>(
                                      value: item,
                                      child: Text(item.title.toString()),
                                    );
                                  }).toList()),
                              Container(
                                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                                  child: Text(
                                    "Select Sub Category".tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  )),
                              DropdownButtonFormField<CategoryModel>(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  ),
                                  value: controller.selectedSubCategory.value,
                                  validator: (value) => value == null ? 'field required'.tr : null,
                                  disabledHint: Text("Select Sub Category".tr),
                                  onChanged: (value) {
                                    controller.selectedSubCategory.value = value!;
                                    controller.update();
                                  },
                                  hint: Text('Select Sub Category'.tr),
                                  items: controller.subCategoryList.map((CategoryModel item) {
                                    return DropdownMenuItem<CategoryModel>(
                                      value: item,
                                      child: Text(item.title.toString()),
                                    );
                                  }).toList()),
                              Container(
                                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                                  child: Text(
                                    "Description".tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  )),
                              TextFormField(
                                  controller: controller.description.value,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.next,
                                  validator: validateEmptyField,
                                  style: const TextStyle(fontSize: 18.0),
                                  keyboardType: TextInputType.streetAddress,
                                  cursorColor: AppColors.colorPrimary,
                                  decoration: InputDecoration(
                                    hintText: 'Description'.tr,
                                    hintStyle: TextStyle(
                                      color: themeChange.getTheme() ? Colors.white : const Color(0Xff333333),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  )),
                              Container(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Address".tr,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          checkPermission(() async {
                                            ShowToastDialog.showLoader("Please wait");
                                            try {
                                              await Geolocator.requestPermission();
                                              await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                              ShowToastDialog.closeLoader();
                                              if (selectedMapType == 'osm') {
                                                final result = await Get.to(() => MapPickerPage());
                                                final firstPlace = result;
                                                if (result != null) {
                                                  controller.latValue.value = firstPlace.coordinates.latitude;
                                                  controller.longValue.value = firstPlace.coordinates.longitude;

                                                  controller.address.value.text = firstPlace.address;
                                                }
                                              } else {
                                                Get.to(LocationPickerScreen())!.then((value) async {
                                                  if (value != null) {
                                                    SelectedLocationModel selectedLocationModel = value;
                                                    controller.latValue.value = selectedLocationModel.latLng!.latitude;
                                                    controller.longValue.value = selectedLocationModel.latLng!.longitude;

                                                    controller.address.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                                    controller.update();
                                                  }
                                                });
                                              }
                                            } catch (e) {
                                              print(e.toString());
                                            }
                                          }, context);
                                        },
                                        child: Text(
                                          "Change".tr,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: AppColors.colorPrimary),
                                        ),
                                      ),
                                    ],
                                  )),
                              InkWell(
                                onTap: () {},
                                child: TextFormField(
                                  controller: controller.address.value,
                                  readOnly: true,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.next,
                                  validator: validateEmptyField,
                                  style: const TextStyle(fontSize: 18.0),
                                  keyboardType: TextInputType.streetAddress,
                                  cursorColor: AppColors.colorPrimary,
                                  decoration: InputDecoration(
                                    hintText: 'Address'.tr,
                                    hintStyle: TextStyle(
                                      color: themeChange.getTheme() ? Colors.white : const Color(0Xff333333),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  ),
                                  onTap: () {
                                    checkPermission(() async {
                                      try {
                                        await Geolocator.requestPermission();
                                        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

                                        if (selectedMapType == 'osm') {
                                          final result = await Get.to(() => MapPickerPage());
                                          final firstPlace = result;
                                          if (result != null) {
                                            controller.latValue.value = firstPlace.coordinates.latitude;
                                            controller.longValue.value = firstPlace.coordinates.longitude;

                                            controller.address.value.text = firstPlace.address;
                                          }
                                        } else {
                                          Get.to(LocationPickerScreen())!.then((value) async {
                                            if (value != null) {
                                              SelectedLocationModel selectedLocationModel = value;
                                              controller.latValue.value = selectedLocationModel.latLng!.latitude;
                                              controller.longValue.value = selectedLocationModel.latLng!.longitude;

                                              controller.address.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                              controller.update();
                                            }
                                          });
                                        }
                                      } catch (e) {
                                        await Geocoding().placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) async {
                                          List<Placemark> placeMarks = await Geocoding().placemarkFromCoordinates(19.228825, 72.854118);

                                          controller.address.value.text =
                                              "${placeMarks.first.name.toString()},${placeMarks.first.subLocality.toString()},${placeMarks.first.locality.toString()},${placeMarks.first.administrativeArea.toString()},${placeMarks.first.country.toString()}";
                                        });
                                        controller.update();
                                      }
                                    }, context);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Time'.tr,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          initializeDateFormatting();
                                          TimeOfDay? from = await _selectTime(context);
                                          print('=====${controller.endTime!}');
                                          print('=====${controller.endTime!}');
                                          if (controller.endTime!.isNotEmpty) {
                                            if (DateTime(
                                              DateTime.now().year,
                                              DateTime.now().month,
                                              DateTime.now().day,
                                              from!.hour,
                                              from.minute,
                                            ).isAfter(DateTime(
                                              DateTime.now().year,
                                              DateTime.now().month,
                                              DateTime.now().day,
                                              int.parse(controller.endTime!.toString().split(":").first.toString()),
                                              int.parse(controller.endTime!.toString().split(":").last.toString()),
                                            ))) {
                                              controller.startTime!.value = "";
                                              ShowToastDialog.showToast("Please enter valid time");
                                            } else {
                                              controller.startTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, from.hour, from.minute));
                                            }
                                          } else {
                                            controller.startTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, from!.hour, from.minute));
                                          }

                                          controller.update();
                                        },
                                        child: Container(
                                          width: MediaQuery.of(context).size.width / 2.38,
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                                            border: Border.all(color: const Color(0XFFB1BCCA)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                controller.startTime!.isEmpty ? 'HH:mm'.tr : controller.startTime!.value,
                                                style: TextStyle(color: themeChange.getTheme() ? const Color(0xFFFFFFFF) : Colors.black, fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Time'.tr,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          TimeOfDay? to = await _selectTime(context);
                                          if (controller.startTime!.isNotEmpty) {
                                            if (DateTime(
                                              DateTime.now().year,
                                              DateTime.now().month,
                                              DateTime.now().day,
                                              to!.hour,
                                              to.minute,
                                            ).isBefore(DateTime(
                                              DateTime.now().year,
                                              DateTime.now().month,
                                              DateTime.now().day,
                                              int.parse(controller.startTime!.toString().split(":").first.toString()),
                                              int.parse(controller.startTime!.toString().split(":").last.toString()),
                                            ))) {
                                              controller.endTime!.value = "";
                                              ShowToastDialog.showToast("Please enter valid time");
                                            } else {
                                              if (to.format(context).toString() == "12:00 AM") {
                                                controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                                              } else {
                                                controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, to.hour, to.minute));
                                                controller.update();
                                              }
                                            }
                                          } else {
                                            if (to!.format(context).toString() == "12:00 AM") {
                                              controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                                            } else {
                                              controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, to.hour, to.minute));
                                              controller.update();
                                            }
                                          }
                                        },
                                        child: Container(
                                          width: MediaQuery.of(context).size.width / 2.38,
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                                            border: Border.all(color: const Color(0XFFB1BCCA)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                controller.endTime!.isEmpty ? 'HH:mm'.tr : controller.endTime!.value,
                                                style: TextStyle(color: themeChange.getTheme() ? const Color(0xFFFFFFFF) : Colors.black, fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                ]),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      'Price'.tr,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width / 2.3,
                                      child: TextFormField(
                                        maxLength: 5,
                                        textInputAction: TextInputAction.done,
                                        controller: controller.rprice.value,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                        ],
                                        style: const TextStyle(fontSize: 18.0),
                                        cursorColor: AppColors.colorPrimary,
                                        validator: validateEmptyField,
                                        decoration: InputDecoration(
                                          hintText: "0",
                                          contentPadding: const EdgeInsets.only(left: 8, right: 8),
                                          counterText: '',
                                          errorStyle: const TextStyle(),
                                          prefix: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(currencyData!.symbol.toString()),
                                          ),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      'Discount Price'.tr,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.only(right: 5),
                                      width: MediaQuery.of(context).size.width / 2.25,
                                      child: TextFormField(
                                        maxLength: 5,
                                        textInputAction: TextInputAction.done,
                                        controller: controller.disprice.value,
                                        onChanged: (val) {
                                          var regularPrice = double.parse(controller.rprice.value.text.toString());
                                          var discountedPrice = double.parse(controller.disprice.value.text.toString());

                                          if (discountedPrice > regularPrice) {
                                            controller.isDiscountedPriceOk.value = true;
                                            ShowToastDialog.showToast('Please enter valid discount price'.tr);
                                          } else {
                                            controller.isDiscountedPriceOk.value = false;
                                          }
                                          controller.update();
                                        },
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                        ],
                                        style: const TextStyle(fontSize: 18.0),
                                        cursorColor: AppColors.colorPrimary,
                                        //validator: validateEmptyField,
                                        decoration: InputDecoration(
                                          hintText: "0",
                                          contentPadding: const EdgeInsets.only(left: 8, right: 8),
                                          counterText: '',
                                          prefix: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(currencyData!.symbol.toString()),
                                          ),
                                          errorStyle: const TextStyle(),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(7.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ])
                                ],
                              ),
                              Container(
                                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                                  child: Text(
                                    "Price Unit".tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  )),
                              DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(7.0),
                                    ),
                                  ),
                                  validator: (value) => value == null ? 'field required' : null,
                                  value: controller.priceUnit!.isEmpty ? null : controller.priceUnit!.value,
                                  onChanged: (value) {
                                    controller.priceUnit!.value = value!;
                                  },
                                  hint: Text("Select Price Unit".tr),
                                  items: controller.priceUnitList.map((item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text(item.toString()),
                                    );
                                  }).toList()),
                              SizedBox(
                                height: 10,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Days'.tr,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  ),
                                  Wrap(
                                    children: controller.selectedDaysList!
                                        .map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: InputChip(
                                              selectedColor: controller.selectedDays!.contains(item..toString()) ? AppColors.colorPrimary : AppColors.colorWhite,
                                              showCheckmark: false,
                                              label: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(
                                                  item.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontFamily: AppColors.medium,
                                                    color: controller.selectedDays!.contains(item.toString()) ? AppColors.colorWhite : AppColors.assetColorLightGrey1000,
                                                  ),
                                                ),
                                              ),
                                              selected: controller.selectedDays!.contains(item.toString()),
                                              onSelected: (bool selected) {
                                                if (selected) {
                                                  controller.selectedDays!.add(item.toString());
                                                } else {
                                                  controller.selectedDays!.remove(item.toString());
                                                }
                                              },
                                            ),
                                          );
                                        })
                                        .toList()
                                        .cast<Widget>(),
                                  ),
                                ],
                              ),
                              SwitchListTile.adaptive(
                                  activeColor: AppColors.colorPrimary,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Publish'.tr,
                                    style: TextStyle(fontSize: 16, color: themeChange.getTheme() ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  value: controller.publish.value,
                                  onChanged: (bool newValue) {
                                    controller.publish.value = newValue;
                                    controller.update();
                                  }),
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Add Photos'.tr,
                                  style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    height: 100,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            pickImage(controller);
                                          },
                                          child: SizedBox(
                                            width: 100,
                                            height: 100,
                                            child: Card(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide.none,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              color: AppColors.colorPrimary,
                                              child: Icon(
                                                CupertinoIcons.camera,
                                                size: 40,
                                                color: themeChange.getTheme() ? Colors.black : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: controller.mediaFiles.length,
                                            itemBuilder: (context, index) {
                                              return imageBuilder(controller.mediaFiles[index], controller, context, themeChange);
                                            },
                                            shrinkWrap: true,
                                            scrollDirection: Axis.horizontal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
                    ),
                  ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side: BorderSide(color: AppColors.colorPrimary),
                        ),
                        backgroundColor: AppColors.colorPrimary),
                    onPressed: () {
                      _validate(controller, context);
                    },
                    child: Text(
                      'Save'.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeChange.getTheme() ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  _validate(AddOrUpdateServiceController controller, BuildContext context) async {
    if (controller.selectedSection.value.id == null) {
      ShowToastDialog.showToast('Please Select OnDemand section.'.tr);
    } else if (controller.selectedCategory.value.id == null) {
      ShowToastDialog.showToast('Please Select Category.'.tr);
    } else if (controller.selectedSubCategory.value.id == null) {
      ShowToastDialog.showToast('Please Select Sub Category.'.tr);
    } else if (controller.startTime!.value.isEmpty || controller.endTime!.value.isEmpty) {
      ShowToastDialog.showToast('Please Select start and end time.'.tr);
    } else if (controller.selectedDays!.isEmpty) {
      ShowToastDialog.showToast('Please Select Days.'.tr);
    } else {
      if (controller.formKey.value.currentState?.validate() ?? false) {
        if (controller.mediaFiles.isEmpty) {
          showimgAlertDialog(context, 'Please add Image'.tr, 'Add Image to continue'.tr, true);
        } else {
          controller.formKey.value.currentState!.save();
          ShowToastDialog.showLoader('Adding service...'.tr);

          ProviderServiceModel? providerModel = controller.serviceModel.value;

          List<String> mediaFilesURLs = controller.mediaFiles.whereType<String>().toList().cast<String>();
          List<File> imagesToUpload = controller.mediaFiles.whereType<File>().toList().cast<File>();
          if (imagesToUpload.isNotEmpty) {
            for (int i = 0; i < imagesToUpload.length; i++) {
              String url = await FireStoreUtils.uploadServiceImage(
                imagesToUpload[i],
                'Uploading Product Images {} of {}'.tr,
              );
              mediaFilesURLs.add(url);
            }
          }

          if ((providerModel.id!).isEmpty) {
            providerModel.subscriptionTotalOrders = MyAppState.currentUser!.subscriptionTotalOrders;
            providerModel.subscriptionPlanId = MyAppState.currentUser!.subscriptionPlanId;
            providerModel.subscriptionPlan = MyAppState.currentUser!.subscriptionPlan;
            providerModel.subscriptionPlan?.createdAt = MyAppState.currentUser!.subscriptionPlan!.createdAt;
            providerModel.subscriptionExpiryDate = MyAppState.currentUser!.subscriptionExpiryDate;
          }

          GeoFirePoint myLocation = Geoflutterfire().point(latitude: controller.latValue.value, longitude: controller.longValue.value);

          providerModel.phoneNumber = MyAppState.currentUser!.phoneNumber;
          providerModel.author = MyAppState.currentUser!.id;
          providerModel.sectionId = controller.selectedSection.value.id;
          providerModel.authorName = MyAppState.currentUser!.firstName + " " + MyAppState.currentUser!.lastName;
          providerModel.authorProfilePic = MyAppState.currentUser!.photos.isEmpty ? '' : MyAppState.currentUser!.photos.first;
          if (providerModel.id?.isEmpty == true) {
            providerModel.createdAt = Timestamp.now();
          }
          providerModel.geoFireData = GeoFireData(geohash: myLocation.hash, geoPoint: GeoPoint(controller.latValue.value, controller.longValue.value));
          providerModel.description = controller.description.value.text.toString();
          providerModel.latitude = controller.latValue.value;
          providerModel.longitude = controller.longValue.value;
          providerModel.address = controller.address.value.text;
          providerModel.title = controller.serviceName.value.text.toString();
          providerModel.categoryId = controller.selectedCategory.value.id.toString();
          providerModel.subCategoryId = controller.selectedSubCategory.value.id.toString();
          providerModel.price = controller.rprice.value.text.toString();
          providerModel.disPrice = controller.disprice.value.text.toString().isEmpty ? "0" : controller.disprice.value.text.toString();
          providerModel.publish = controller.publish.value;
          providerModel.photos = mediaFilesURLs;
          providerModel.startTime = controller.startTime.toString();
          providerModel.endTime = controller.endTime.toString();
          providerModel.priceUnit = controller.priceUnit.toString();
          providerModel.days = controller.selectedDays!.toList();

          await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id).then((userdata) {
            MyAppState.currentUser = userdata;
            MyAppState.currentUser?.sectionId = controller.selectedSection.value.id!;
          });
          if (MyAppState.currentUser?.adminCommission == null) {
            MyAppState.currentUser?.adminCommission = controller.selectedSection.value.adminCommision;
          }
          await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
          await FireStoreUtils.firebaseAddOrUpdateProvider(providerModel);
          await ShowToastDialog.closeLoader();
          ShowToastDialog.showToast(controller.serviceModel.value.title.toString() != '' ? "Service successfully updated" : "Service successfully added");
          if ((MyAppState.currentUser?.adminCommission?.enable == true || isSubscriptionModelApplied == true) &&
              (MyAppState.currentUser?.subscriptionPlanId == null || MyAppState.currentUser?.subscriptionPlanId == '')) {
            Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": true});
          } else {
            Future.delayed(Duration(seconds: 2), () {
              Get.back(result: true);
              Get.back(result: true);
            });
          }
        }
      } else {
        controller.validate = AutovalidateMode.onUserInteraction;
      }
    }
  }

  showAlertDialogNew(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("OK".tr),
      onPressed: () async {
        Get.back(result: true);
        Get.back(result: true);
      },
    );

    AlertDialog alert = AlertDialog(
      title: Text("Adding Service".tr),
      content: Text("Data is saved to database.".tr),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  pickImage(controller) {
    final action = CupertinoActionSheet(
      message: Text(
        'Add Picture'.tr,
        style: const TextStyle(fontSize: 15.0),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
            }
            controller.update();
          },
          child: Text('Choose image from gallery'.tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
              controller.update();
            }
          },
          child: Text('Take a picture'.tr),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: MyAppState.navigatorKey.currentContext!, builder: (context) => action);
  }

  Widget imageBuilder(dynamic image, AddOrUpdateServiceController controller, context, themeChange) {
    return SizedBox(
      width: 100,
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        color: themeChange.getTheme() ? Colors.black : Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image is File
              ? Stack(
                  children: [
                    Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    ),
                    Positioned(
                        top: 5,
                        right: 5,
                        child: InkWell(
                          onTap: () {
                            controller.mediaFiles.removeWhere((value) => value is File && value.path == image.path);
                          },
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                          ),
                        ))
                  ],
                )
              : Stack(
                  children: [
                    displayImage(image),
                    Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            controller.mediaFiles.removeWhere((value) => value is String && value == image);
                          },
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                          ),
                        ))
                  ],
                ),
        ),
      ),
    );
  }

  Future<TimeOfDay?> _selectTime(context) async {
    FocusScope.of(
      context,
    ).requestFocus(FocusNode()); //remove focus
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (newTime != null) {
      return newTime;
    }
    return null;
  }
}
