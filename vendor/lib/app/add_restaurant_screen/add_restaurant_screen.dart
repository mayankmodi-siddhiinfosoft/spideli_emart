import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker_mb/google_maps_place_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:vendor/app/add_restaurant_screen/qr_code_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_restaurant_controller.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/osm_map/map_picker_page.dart';

class AddRestaurantScreen extends StatelessWidget {
  const AddRestaurantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddRestaurantController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, size: 20),
            title: Text(
              "Store Details".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            actions: [
              Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                  ? SizedBox()
                  : Obx(
                      () => controller.canShowQRCodeButton.value
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: RoundedButtonFill(
                                title: "Generate QR Code".tr,
                                width: 38,
                                height: 5,
                                color: AppThemeData.grey50,
                                textColor: AppThemeData.primary300,
                                onPress: () async {
                                  if (controller.vendorModel.value.id == null) {
                                    ShowToastDialog.showToast("First save a store details".tr);
                                  } else {
                                    Get.to(const QrCodeScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                                  }
                                },
                              ),
                            )
                          : const SizedBox(),
                    ),
            ],
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
                            : SizedBox(
                                height: 90,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: controller.images.length,
                                        shrinkWrap: true,
                                        scrollDirection: Axis.horizontal,
                                        // physics: const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 5),
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                  child: controller.images[index].runtimeType == XFile
                                                      ? Image.file(File(controller.images[index].path), fit: BoxFit.cover, width: 80, height: 80)
                                                      : NetworkImageWidget(imageUrl: controller.images[index], fit: BoxFit.cover, width: 80, height: 80),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  top: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: InkWell(
                                                    onTap: () {
                                                      controller.images.removeAt(index);
                                                    },
                                                    child: const Icon(Icons.remove_circle, size: 28, color: AppThemeData.danger300),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                        InkWell(
                          onTap: () {
                            ShowToastDialog.showToast("${'You are not able to change section. because of your plan is purchased on'.tr} ${controller.selectedSectionModel.value.name} ${'section'.tr}");
                          },
                          child: TextFieldWidget(
                            readOnly: true,
                            title: 'Section'.tr,
                            controller: null,
                            hintText: 'Section Name'.tr,
                            initialValue: controller.selectedSectionModel.value.name,
                            enable: false,
                          ),
                        ),
                        TextFieldWidget(title: 'Store Name'.tr, controller: controller.restaurantNameController.value, hintText: 'Enter Store name'.tr),
                        TextFieldWidget(
                          title: 'Store Description'.tr,
                          controller: controller.restaurantDescriptionController.value,
                          maxLine: 5,
                          hintText: 'Enter short description here....'.tr,
                          textInputAction: TextInputAction.done,
                        ),
                        Text(
                          "Mobile number and Address".tr,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        TextFieldWidget(
                          title: 'Phone Number'.tr,
                          controller: controller.mobileNumberController.value,
                          hintText: 'Phone Number'.tr,
                          textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                        ),
                        InkWell(
                          onTap: () {
                            if (controller.addressController.value.text.isEmpty) {
                              Constant.checkPermission(
                                onTap: () async {
                                  ShowToastDialog.showLoader("Please wait".tr);
                                  try {
                                    await Geolocator.requestPermission();
                                    await Geolocator.getCurrentPosition();
                                    ShowToastDialog.closeLoader();
                                    if (Constant.selectedMapType == 'osm') {
                                      final result = await Get.to(() => MapPickerPage());
                                      if (result != null) {
                                        final firstPlace = result;
                                        final lat = firstPlace.coordinates.latitude;
                                        final lng = firstPlace.coordinates.longitude;
                                        final address = firstPlace.address;

                                        controller.selectedLocation = LatLng(lat, lng);
                                        controller.addressController.value.text = address.toString();
                                        controller.isAddressEnable.value = true;
                                      }
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PlacePicker(
                                            apiKey: Constant.mapAPIKey,
                                            onPlacePicked: (result) async {
                                              controller.selectedLocation = LatLng(result.geometry!.location.lat, result.geometry!.location.lng);
                                              controller.addressController.value.text = result.formattedAddress.toString();
                                              controller.isAddressEnable.value = true;
                                              Get.back();
                                            },
                                            initialPosition: const LatLng(-33.8567844, 151.213108),
                                            useCurrentLocation: true,
                                            selectInitialPosition: true,
                                            usePinPointingSearch: true,
                                            usePlaceDetailSearch: true,
                                            zoomGesturesEnabled: true,
                                            zoomControlsEnabled: true,
                                            resizeToAvoidBottomInset: false, // only works in page mode, less flickery, remove if wrong offsets
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ShowToastDialog.closeLoader();
                                  }
                                },
                                context: context,
                              );
                            }
                          },
                          child: TextFieldWidget(
                            title: 'Address'.tr,
                            controller: controller.addressController.value,
                            hintText: 'Enter address'.tr,
                            enable: controller.isAddressEnable.value,
                            suffix: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                              child: InkWell(
                                onTap: () {
                                  Constant.checkPermission(
                                    context: context,
                                    onTap: () async {
                                      ShowToastDialog.showToast("Please wait...".tr);
                                      try {
                                        await Geolocator.requestPermission();
                                        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                        if (Constant.selectedMapType == 'osm') {
                                          final result = await Get.to(() => MapPickerPage());
                                          if (result != null) {
                                            final firstPlace = result;
                                            final lat = firstPlace.coordinates.latitude;
                                            final lng = firstPlace.coordinates.longitude;
                                            final address = firstPlace.address;

                                            controller.selectedLocation = LatLng(lat, lng);
                                            controller.addressController.value.text = address.toString();
                                            controller.isAddressEnable.value = true;
                                          }
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlacePicker(
                                                apiKey: Constant.mapAPIKey,
                                                onPlacePicked: (result) async {
                                                  controller.selectedLocation = LatLng(result.geometry!.location.lat, result.geometry!.location.lng);
                                                  controller.addressController.value.text = result.formattedAddress.toString();
                                                  controller.isAddressEnable.value = true;
                                                  Get.back();
                                                },
                                                initialPosition: const LatLng(-33.8567844, 151.213108),
                                                useCurrentLocation: true,
                                                selectInitialPosition: true,
                                                usePinPointingSearch: true,
                                                usePlaceDetailSearch: true,
                                                zoomGesturesEnabled: true,
                                                zoomControlsEnabled: true,
                                                resizeToAvoidBottomInset: false, // only works in page mode, less flickery, remove if wrong offsets
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print(e.toString());
                                      }
                                    },
                                  );
                                },
                                child: Text(
                                  "change".tr,
                                  style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Zone".tr,
                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                            ),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<ZoneModel>(
                              hint: Text(
                                'Select zone'.tr,
                                style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey700 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                              ),
                              dropdownColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              decoration: InputDecoration(
                                errorStyle: const TextStyle(color: Colors.red),
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                disabledBorder: UnderlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                ),
                              ),
                              initialValue: controller.selectedZone.value.id == null ? null : controller.selectedZone.value,
                              onChanged: (value) {
                                controller.selectedZone.value = value!;
                                controller.update();
                              },
                              style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                              items: controller.zoneList.map((item) {
                                return DropdownMenuItem<ZoneModel>(
                                  value: item,
                                  child: Text(
                                    item.name.toString(),
                                    style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 18),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Service and Categories".tr,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Categories".tr,
                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                            ),
                            const SizedBox(height: 5),
                            DropdownSearch<VendorCategoryModel>.multiSelection(
                              items: (String s, LoadProps? data) => controller.vendorCategoryList,
                              key: controller.myKey1,

                              suffixProps: DropdownSuffixProps(
                                dropdownButtonProps: DropdownButtonProps(
                                  focusColor: AppThemeData.primary300,
                                  color: AppThemeData.grey600,
                                  iconClosed: const Icon(Icons.keyboard_arrow_down, color: AppThemeData.grey600),
                                  iconOpened: const Icon(Icons.keyboard_arrow_up, color: AppThemeData.grey600),
                                ),
                              ),
                              decoratorProps: DropDownDecoratorProps(
                                decoration: InputDecoration(
                                  focusColor: AppThemeData.primary300,
                                  contentPadding: const EdgeInsets.only(left: 8, right: 8),
                                  disabledBorder: UnderlineInputBorder(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                  ),
                                  filled: true,
                                  hintStyle: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                                  fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                  hintText: 'Select Categories'.tr,
                                ),
                              ),
                              compareFn: (i1, i2) => i1.title == i2.title,
                              popupProps: PopupPropsMultiSelection.modalBottomSheet(
                                showSearchBox: true,
                                modalBottomSheetProps: ModalBottomSheetProps(backgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey50),
                                itemBuilder: (context, item, bool, isSelected) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(item.title ?? "", style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              itemAsString: (VendorCategoryModel u) => u.title.toString(),
                              selectedItems: controller.selectedCategories,
                              onSaved: (data) {},
                              onChanged: (data) {
                                controller.selectedCategories.clear();
                                controller.selectedCategories.addAll(data);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Constant.selectedSection?.dineInActive == true
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Services".tr,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? AppThemeData.grey800 : AppThemeData.grey200, width: 1),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: MultiSelectDialogField(
                                      backgroundColor: isDark ? AppThemeData.grey700 : AppThemeData.grey50,
                                      items: [
                                        'Good for Breakfast',
                                        'Good for Lunch',
                                        'Good for Dinner',
                                        'Takes Reservations',
                                        'Vegetarian Friendly',
                                        'Live Music',
                                        'Outdoor Seating',
                                        'Free Wi-Fi',
                                      ].map((e) => MultiSelectItem(e, e)).toList(),

                                      initialValue: controller.selectedService,
                                      listType: MultiSelectListType.CHIP,

                                      searchable: false,

                                      title: Text(
                                        "Select Services".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                      ),

                                      buttonText: Text(
                                        controller.selectedService.isEmpty ? "Select Service".tr : "Select Service".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 15),
                                      ),

                                      buttonIcon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white : Colors.black87, size: 26),

                                      decoration: const BoxDecoration(
                                        border: Border.fromBorderSide(BorderSide.none), // remove default border
                                      ),

                                      onConfirm: (values) {
                                        controller.selectedService.value = values;
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox(),
                        const SizedBox(height: 10),
                        if (controller.selectedSectionModel.value.packagingChargeEnable == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10),
                              TextFieldWidget(
                                title: 'Packaging charge'.tr,
                                controller: controller.packagingChargeAmountController.value,
                                maxLine: 1,
                                textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                hintText: 'Enter Packaging charge'.tr,
                              ),
                            ],
                          ),

                        Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                            ? SizedBox()
                            : Column(
                                children: [
                                  if (Constant.isSelfDeliveryFeature == true) const SizedBox(height: 10),
                                  if (Constant.isSelfDeliveryFeature == true)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "Self Delivery Service".tr,
                                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 18),
                                          ),
                                        ),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: CupertinoSwitch(
                                            value: controller.isSelfDelivery.value,
                                            onChanged: (value) {
                                              controller.isSelfDelivery.value = value;
                                              controller.update();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Delivery Settings".tr,
                                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontSize: 18),
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: CupertinoSwitch(value: controller.isEnableDeliverySettings.value, onChanged: (value) {}),
                                      ),
                                    ],
                                  ),
                                  TextFieldWidget(
                                    title: '${'Charges per'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                    controller: controller.chargePerKmController.value,
                                    hintText: 'Enter charges'.tr,
                                    enable: controller.isEnableDeliverySettings.value,
                                    textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                    prefix: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Text(
                                        "${Constant.currencyModel!.symbol}".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  TextFieldWidget(
                                    title: 'Min Delivery Charges'.tr,
                                    controller: controller.minDeliveryChargesController.value,
                                    hintText: 'Enter Min Delivery Charges'.tr,
                                    enable: controller.isEnableDeliverySettings.value,
                                    textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                    prefix: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Text(
                                        "${Constant.currencyModel!.symbol}".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  TextFieldWidget(
                                    title: '${'Min Delivery Charges within'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                    controller: controller.minDeliveryChargesWithinKMController.value,
                                    hintText: '${'Enter Min Delivery Charges within'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                    enable: controller.isEnableDeliverySettings.value,
                                    textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),
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
                title: "Save Details".tr,
                height: 5.5,
                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  controller.saveDetails();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, AddRestaurantController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;
        return StatefulBuilder(
          builder: (context, setState) {
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
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
      },
    );
  }
}
