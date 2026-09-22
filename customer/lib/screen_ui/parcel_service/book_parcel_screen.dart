import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/utils.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/book_parcel_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../../models/parcel_order_model.dart';
import '../../models/parcel_shipping_models.dart';
import '../../utils/parcel_pricing.dart';
import 'parcel_shipping_widgets.dart';
import 'pickup_point_picker_screen.dart';

class BookParcelScreen extends StatelessWidget {
  const BookParcelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: BookParcelController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Book Your Document Delivery".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                        Text(
                          "Schedule a secure and timely pickup & delivery".tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppThemeData.mediumTextStyle(fontSize: 12, color: AppThemeData.grey900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                typeAndScopeView(controller, isDark),
                const SizedBox(height: 16),
                selectDeliveryTypeView(controller, isDark, context),
                const SizedBox(height: 16),
                buildUploadBoxView(isDark, controller),
                const SizedBox(height: 16),
                buildInfoSectionView(
                  title: "Sender Information".tr,
                  locationController: controller.senderLocationController.value,
                  nameController: controller.senderNameController.value,
                  mobileController: controller.senderMobileController.value,
                  noteController: controller.senderNoteController.value,
                  countryCodeController: controller.senderCountryCodeController.value,
                  countryISOCodeController: controller.senderCountryISOCodeController.value,
                  emailController: controller.senderEmailController.value,
                  cityController: controller.senderCityController.value,
                  isSender: true,
                  showWeight: controller.isCityScope,
                  isDark: isDark,
                  context: context,
                  controller: controller,
                  onTap: () async {
                    if (Constant.selectedMapType == 'osm') {
                      final result = await Get.to(() => MapPickerPage());
                      if (result != null) {
                        final firstPlace = result;

                        if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                          final address = firstPlace.address;
                          final lat = firstPlace.coordinates.latitude;
                          final lng = firstPlace.coordinates.longitude;
                          controller.senderLocationController.value.text = address; // ✅
                          controller.senderLocation.value = UserLocation(latitude: lat, longitude: lng); // ✅ <-- Add this
                          controller.originPickupPoint.value = null;
                          controller.fillPlace(sender: true, latitude: lat, longitude: lng);
                        } else {
                          ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                        }
                      }
                    } else {
                      Get.to(LocationPickerScreen())!.then((value) async {
                        if (value != null) {
                          SelectedLocationModel selectedLocationModel = value;

                          if (Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                            controller.senderLocationController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                            controller.senderLocation.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                            controller.originPickupPoint.value = null;
                            controller.fillPlace(sender: true, latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                          } else {
                            ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                          }
                          // ✅ <-- Add this
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                buildInfoSectionView(
                  title: "Receiver Information".tr,
                  locationController: controller.receiverLocationController.value,
                  nameController: controller.receiverNameController.value,
                  mobileController: controller.receiverMobileController.value,
                  noteController: controller.receiverNoteController.value,
                  countryCodeController: controller.receiverCountryCodeController.value,
                  countryISOCodeController: controller.receiverISOCountryCodeController.value,
                  emailController: controller.receiverEmailController.value,
                  cityController: controller.receiverCityController.value,
                  isSender: false,
                  showWeight: false,
                  isDark: isDark,
                  context: context,
                  controller: controller,
                  onTap: () async {
                    if (Constant.selectedMapType == 'osm') {
                      final result = await Get.to(() => MapPickerPage());
                      if (result != null) {
                        final firstPlace = result;

                        // Another city / country is outside the delivery zones by design.
                        if (!controller.isCityScope || Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                          final lat = firstPlace.coordinates.latitude;
                          final lng = firstPlace.coordinates.longitude;
                          final address = firstPlace.address;

                          controller.receiverLocationController.value.text = address; // ✅
                          controller.receiverLocation.value = UserLocation(latitude: lat, longitude: lng);
                          controller.destinationPickupPoint.value = null;
                          controller.fillPlace(sender: false, latitude: lat, longitude: lng);
                        } else {
                          ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                        }
                      }
                    } else {
                      Get.to(LocationPickerScreen())!.then((value) async {
                        if (value != null) {
                          SelectedLocationModel selectedLocationModel = value;

                          if (!controller.isCityScope || Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                            controller.receiverLocationController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                            controller.receiverLocation.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude); // ✅ <-- Add this
                            controller.destinationPickupPoint.value = null;
                            controller.fillPlace(sender: false, latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                          } else {
                            ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                          }
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                parcelDetailsView(controller, isDark),
                const SizedBox(height: 16),
                methodsView(controller, isDark),
                const SizedBox(height: 15),
                RoundedButtonFill(
                  title: "Continue".tr,
                  onPress: () {
                    controller.bookNow();
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppThemeData.primary300,
        labelStyle: AppThemeData.semiBoldTextStyle(fontSize: 14, color: selected ? AppThemeData.grey900 : (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) =>
      Text(title, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13));

  /// Spec 4.2 step 1: parcel or mail; same city / other city / other country.
  Widget typeAndScopeView(BookParcelController controller, bool isDark) {
    return ParcelCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("What are you sending?".tr, isDark),
          const SizedBox(height: 8),
          Wrap(
            children: [
              _chip("Parcel".tr, controller.shipmentType.value == ParcelShipping.parcel, isDark, () => controller.shipmentType.value = ParcelShipping.parcel),
              _chip("Mail".tr, controller.shipmentType.value == ParcelShipping.mail, isDark, () => controller.shipmentType.value = ParcelShipping.mail),
            ],
          ),
          const SizedBox(height: 4),
          _sectionTitle("Where to?".tr, isDark),
          const SizedBox(height: 8),
          Wrap(
            children: [
              for (final sc in [ParcelScope.city, ParcelScope.intercity, ParcelScope.intercountry])
                _chip(ParcelLabels.scope(sc), controller.scope.value == sc, isDark, () {
                  controller.scope.value = sc;
                  if (sc == ParcelScope.city && controller.receiverLocation.value != null) {
                    final loc = controller.receiverLocation.value!;
                    if (Constant.checkZoneCheck(loc.latitude ?? 0, loc.longitude ?? 0) != true) {
                      // A receiver outside the zones cannot be a same-city delivery.
                      controller.receiverLocation.value = null;
                      controller.receiverLocationController.value.clear();
                    }
                  }
                }),
            ],
          ),
        ],
      ),
    );
  }

  /// Spec 4.2 step 2: weight, dimensions, declared value, content description.
  Widget parcelDetailsView(BookParcelController controller, bool isDark) {
    final Color bg = isDark ? AppThemeData.surfaceDark : AppThemeData.surface;
    final Color border = isDark ? AppThemeData.greyDark200 : AppThemeData.grey200;
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return ParcelCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Parcel details".tr, isDark),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: controller.isCityScope ? "Weight in kg (optional)".tr : "Weight in kg".tr,
            controller: controller.weightKgController.value,
            textInputType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numeric,
            backgroundColor: bg,
            borderColor: border,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextFieldWidget(hintText: "L (cm)".tr, controller: controller.lengthController.value, textInputType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric, backgroundColor: bg, borderColor: border)),
              const SizedBox(width: 8),
              Expanded(child: TextFieldWidget(hintText: "W (cm)".tr, controller: controller.widthController.value, textInputType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric, backgroundColor: bg, borderColor: border)),
              const SizedBox(width: 8),
              Expanded(child: TextFieldWidget(hintText: "H (cm)".tr, controller: controller.heightController.value, textInputType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric, backgroundColor: bg, borderColor: border)),
            ],
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Declared value (optional)".tr,
            controller: controller.declaredValueController.value,
            textInputType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numeric,
            backgroundColor: bg,
            borderColor: border,
          ),
          const SizedBox(height: 10),
          TextFieldWidget(hintText: "Content description".tr, controller: controller.contentDescriptionController.value, backgroundColor: bg, borderColor: border),
        ],
      ),
    );
  }

  /// Spec 4.2 steps 3-4: how the parcel leaves and how the receiver gets it.
  Widget methodsView(BookParcelController controller, bool isDark) {
    Widget option(String label, bool selected, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: selected ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppThemeData.semiBoldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
          ],
        ),
      ),
    );
    Widget pointTile(PickupPointModel? point, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.storefront_outlined, size: 18),
        label: Text(point == null ? "Choose a pickup point".tr : "${point.name}${point.subtitle.isEmpty ? '' : ' - ${point.subtitle}'}", maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
    Future<void> pick({required bool origin}) async {
      final PickupPointModel? current = origin ? controller.originPickupPoint.value : controller.destinationPickupPoint.value;
      final result = await Get.to(
        () => PickupPointPickerScreen(
          title: origin ? "Drop-off point".tr : "Collection point".tr,
          regionId: origin ? controller.originRegionId : controller.destinationRegionId,
          city: origin ? controller.senderCityController.value.text : controller.receiverCityController.value.text,
          selectedId: current?.id,
        ),
      );
      if (result is PickupPointModel) {
        if (origin) {
          controller.originPickupPoint.value = result;
        } else {
          controller.destinationPickupPoint.value = result;
        }
      }
    }

    return ParcelCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Pickup method".tr, isDark),
          option(ParcelLabels.pickupMethod(ParcelShipping.home), controller.pickupMethod.value == ParcelShipping.home, () => controller.pickupMethod.value = ParcelShipping.home),
          option(ParcelLabels.pickupMethod(ParcelShipping.pickupPoint), controller.pickupMethod.value == ParcelShipping.pickupPoint, () {
            controller.pickupMethod.value = ParcelShipping.pickupPoint;
            if (controller.originPickupPoint.value == null) pick(origin: true);
          }),
          if (controller.pickupMethod.value == ParcelShipping.pickupPoint) pointTile(controller.originPickupPoint.value, () => pick(origin: true)),
          const Divider(height: 20),
          _sectionTitle("Delivery method".tr, isDark),
          option(ParcelLabels.deliveryMethod(ParcelShipping.home), controller.deliveryMethod.value == ParcelShipping.home, () => controller.deliveryMethod.value = ParcelShipping.home),
          option(ParcelLabels.deliveryMethod(ParcelShipping.pickupPoint), controller.deliveryMethod.value == ParcelShipping.pickupPoint, () {
            if (controller.receiverLocation.value == null) {
              ShowToastDialog.showToast("Please select the receiver address first".tr);
              return;
            }
            controller.deliveryMethod.value = ParcelShipping.pickupPoint;
            if (controller.destinationPickupPoint.value == null) pick(origin: false);
          }),
          if (controller.deliveryMethod.value == ParcelShipping.pickupPoint) pointTile(controller.destinationPickupPoint.value, () => pick(origin: false)),
        ],
      ),
    );
  }

  Widget selectDeliveryTypeView(BookParcelController controller, bool isDark, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select delivery type".tr, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              controller.selectedDeliveryType.value = 'now';
              controller.isScheduled.value = false;
            },
            child: Row(
              children: [
                Image.asset("assets/images/image_parcel.png", height: 38, width: 38),
                const SizedBox(width: 20),
                Expanded(child: Text("As soon as possible".tr, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16))),
                Icon(
                  controller.selectedDeliveryType.value == 'now' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: controller.selectedDeliveryType.value == 'now' ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              controller.selectedDeliveryType.value = 'later';
              controller.isScheduled.value = true;
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset("assets/images/image_parcel_scheduled.png", height: 38, width: 38),
                    const SizedBox(width: 20),
                    Expanded(child: Text("Scheduled".tr, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16))),
                    Icon(
                      controller.selectedDeliveryType.value == 'later' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: controller.selectedDeliveryType.value == 'later' ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                      size: 20,
                    ),
                  ],
                ),
                if (controller.selectedDeliveryType.value == 'later') ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => controller.pickScheduledDate(context),
                    child: TextFieldWidget(
                      hintText: "When to pickup at this address".tr,
                      controller: controller.scheduledDateController.value,
                      enable: false,
                      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                      borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                      suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.calendar_month_outlined)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => controller.pickScheduledTime(context),
                    child: TextFieldWidget(
                      hintText: "When to pickup at this address".tr,
                      controller: controller.scheduledTimeController.value,
                      enable: false,
                      // onchange: (v) => controller.pickScheduledTime(context),
                      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                      borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                      suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.access_time)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUploadBoxView(bool isDark, BookParcelController controller) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upload parcel image".tr, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          DottedBorder(
            options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(10), color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset("assets/icons/ic_upload_parcel.svg", height: 40, width: 40),
                  const SizedBox(height: 10),
                  Text("Upload Parcel Image".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  const SizedBox(height: 4),
                  Text("Supported: .jpg, .jpeg, .png".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                  Text("Max size 1MB".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                  const SizedBox(height: 8),
                  RoundedButtonFill(
                    title: "Browse Image".tr,
                    onPress: () {
                      controller.onCameraClick(Get.context!);
                    },
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey900,
                    width: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (controller.images.isEmpty) const SizedBox(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                controller.images.map((image) {
                  return Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 20, right: 20),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(image.path), width: 70, height: 70, fit: BoxFit.cover)),
                      ),
                      Positioned.fill(
                        top: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: AppThemeData.danger300, size: 20),
                            onPressed: () {
                              controller.images.remove(image);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildInfoSectionView({
    required String title,
    required TextEditingController locationController,
    required TextEditingController nameController,
    required TextEditingController mobileController,
    required TextEditingController noteController,
    required TextEditingController countryCodeController,
    required TextEditingController countryISOCodeController,
    required TextEditingController emailController,
    required TextEditingController cityController,
    required bool isSender,
    bool showWeight = false,
    GestureTapCallback? onTap,
    required bool isDark,
    required BookParcelController controller,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: TextFieldWidget(
              hintText: "Your Location".tr,
              controller: locationController,
              suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.location_on_outlined)),
              backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
              borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
              enable: false,
            ),
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Name".tr,
            controller: nameController,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Enter Mobile number".tr,
            controller: mobileController,
            textInputType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountryCodePicker(
                  onInit: (value) {
                    countryCodeController.text = value?.dialCode ?? Constant.defaultCountryCode;
                    countryISOCodeController.text = value?.code ?? Constant.defaultCountryCode;
                  },
                  onChanged: (value) {
                    countryCodeController.text = value.dialCode ?? Constant.defaultCountryCode;
                    countryISOCodeController.text = value.code ?? Constant.defaultCountryCode;
                  },
                  initialSelection: countryISOCodeController.text.isNotEmpty ? countryISOCodeController.text : Constant.defaultCountryCode,
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  textStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : Colors.black),
                  dialogTextStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                  searchStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                  dialogBackgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                  padding: EdgeInsets.zero,
                ),
                // const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppThemeData.grey400),
                Container(height: 24, width: 1, color: AppThemeData.grey400),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Email (optional)".tr,
            controller: emailController,
            textInputType: TextInputType.emailAddress,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
          ),
          if (!controller.isCityScope) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFieldWidget(
                    hintText: "City".tr,
                    controller: cityController,
                    backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                    borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                  ),
                  child: CountryCodePicker(
                    key: ValueKey('${isSender ? 's' : 'r'}-${isSender ? controller.senderCountryCode.value : controller.receiverCountryCode.value}'),
                    onChanged: (value) {
                      if (isSender) {
                        controller.senderCountry.value = value.name ?? '';
                        controller.senderCountryCode.value = value.code ?? '';
                      } else {
                        controller.receiverCountry.value = value.name ?? '';
                        controller.receiverCountryCode.value = value.code ?? '';
                      }
                    },
                    initialSelection:
                        (isSender ? controller.senderCountryCode.value : controller.receiverCountryCode.value).isNotEmpty
                            ? (isSender ? controller.senderCountryCode.value : controller.receiverCountryCode.value)
                            : Constant.defaultCountryCode,
                    showCountryOnly: true,
                    showOnlyCountryWhenClosed: true,
                    textStyle: TextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : Colors.black),
                    dialogTextStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    searchStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    dialogBackgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                  ),
                ),
              ],
            ),
          ],
          if (showWeight) ...[
            const SizedBox(height: 10),
            DropDownTextField(
              controller: controller.senderWeightController.value,
              clearOption: false,
              enableSearch: false,
              textFieldDecoration: InputDecoration(
                hintText: "Select parcel Weight".tr,
                hintStyle: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.greyDark400),
                filled: true,
                fillColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
              ),
              dropDownList:
                  controller.parcelWeight.map((e) {
                    return DropDownValueModel(
                      name: e.title ?? 'Normal'.tr,
                      value: e.title ?? 'Normal'.tr, // safer to use title string
                    );
                  }).toList(),
              onChanged: (val) {
                if (val is DropDownValueModel) {
                  controller.senderWeightController.value.setDropDown(val);

                  // Link it to the selectedWeight object
                  controller.selectedWeight = controller.parcelWeight.firstWhereOrNull((e) => e.title == val.value);
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Notes (Optional)".tr,
            controller: noteController,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
          ),
        ],
      ),
    );
  }
}
