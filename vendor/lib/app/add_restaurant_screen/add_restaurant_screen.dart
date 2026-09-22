import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker_mb/google_maps_place_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:vendor/app/add_restaurant_screen/qr_code_screen.dart';
import 'package:vendor/app/add_restaurant_screen/widgets/form_media_widgets.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_restaurant_controller.dart';
import 'package:vendor/models/region_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/widget/osm_map/map_picker_page.dart';

class AddRestaurantScreen extends StatelessWidget {
  const AddRestaurantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddRestaurantController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final currencySymbol = "${(RegionService.currencyForRegion(controller.selectedRegion.value.id) ?? Constant.currencyModel)!.symbol}".tr;
        return DsScaffold(
          title: controller.isNewStore ? "Add Store".tr : "Store Details".tr,
          maxContentWidth: null,
          actions: [
            Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                ? const SizedBox()
                : Obx(
                    () => controller.canShowQRCodeButton.value && !controller.isNewStore
                        ? Padding(
                            padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                            child: DsButton.tonal(
                              label: "Generate QR Code".tr,
                              icon: Icons.qr_code_2_rounded,
                              size: DsButtonSize.sm,
                              onPressed: () async {
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
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 7)),
                )
              : SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: DsResponsive(
                    padded: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          _StoreProgressCard(controller: controller),
                          const DsGap(DsSpace.lg),
                          // ── Photos ──────────────────────────────────────
                          DsFormSection(
                            title: "Store photos".tr,
                            icon: Icons.photo_library_outlined,
                            trailing: controller.images.isEmpty ? null : DsBadge(label: '${controller.images.length}', tone: DsTone.brand, small: true),
                            children: [
                              FormUploadZone(
                                title: "Choose a image and upload here".tr,
                                caption: "JPEG, PNG".tr,
                                buttonLabel: "Brows Image".tr,
                                icon: Icons.add_a_photo_outlined,
                                compact: controller.images.isNotEmpty,
                                minHeight: controller.images.isEmpty ? 168 : 0,
                                onPressed: () async {
                                  buildBottomSheet(context, controller);
                                },
                              ),
                              AnimatedSize(
                                duration: DsMotion.of(context, DsMotion.base),
                                curve: DsMotion.standard,
                                alignment: Alignment.topCenter,
                                child: controller.images.isEmpty
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: DsSpace.md),
                                        child: SizedBox(
                                          height: 92,
                                          child: ListView.separated(
                                            itemCount: controller.images.length,
                                            scrollDirection: Axis.horizontal,
                                            separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                                            itemBuilder: (context, index) {
                                              return DsFadeSlideIn(
                                                index: index,
                                                offset: const Offset(12, 0),
                                                child: FormMediaThumb(
                                                  onRemove: () {
                                                    controller.images.removeAt(index);
                                                  },
                                                  child: FormPickedImage(source: controller.images[index], width: 92, height: 92),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          // ── Store details ───────────────────────────────
                          DsFormSection(
                            title: "Store Details".tr,
                            icon: Icons.storefront_outlined,
                            children: [
                              InkWell(
                                borderRadius: DsRadius.brMd,
                                onTap: () {
                                  ShowToastDialog.showToast("${'You are not able to change section. because of your plan is purchased on'.tr} ${controller.selectedSectionModel.value.name} ${'section'.tr}");
                                },
                                child: FormInput(
                                  readOnly: true,
                                  label: 'Section'.tr,
                                  controller: null,
                                  hint: 'Section Name'.tr,
                                  initialValue: controller.selectedSectionModel.value.name,
                                  enabled: false,
                                  prefixIcon: Icons.lock_outline_rounded,
                                ),
                              ),
                              FormInput(label: 'Store Name'.tr, controller: controller.restaurantNameController.value, hint: 'Enter Store name'.tr, prefixIcon: Icons.store_mall_directory_outlined),
                              FormInput(
                                label: 'Store Description'.tr,
                                controller: controller.restaurantDescriptionController.value,
                                maxLines: 5,
                                hint: 'Enter short description here....'.tr,
                                textInputAction: TextInputAction.done,
                                bottomSpacing: 0,
                              ),
                            ],
                          ),
                          // ── Contact & location ──────────────────────────
                          DsFormSection(
                            title: "Mobile number and Address".tr,
                            icon: Icons.place_outlined,
                            children: [
                              FormInput(
                                label: 'Phone Number'.tr,
                                controller: controller.mobileNumberController.value,
                                hint: 'Phone Number'.tr,
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                              ),
                              InkWell(
                                borderRadius: DsRadius.brMd,
                                onTap: () {
                                  if (controller.addressController.value.text.isEmpty) {
                                    _pickAddress(context, controller);
                                  }
                                },
                                child: FormInput(
                                  label: 'Address'.tr,
                                  controller: controller.addressController.value,
                                  hint: 'Enter address'.tr,
                                  enabled: controller.isAddressEnable.value,
                                  prefixIcon: Icons.location_on_outlined,
                                  suffix: Padding(
                                    padding: const EdgeInsetsDirectional.only(end: DsSpace.xs),
                                    child: InkWell(
                                      borderRadius: DsRadius.brPill,
                                      onTap: () {
                                        _changeAddress(context, controller);
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
                                        decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brPill),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.my_location_rounded, size: 16, color: c.brandStrong),
                                            const DsGap(DsSpace.xs),
                                            Text("change".tr, style: t.labelSm.withColor(c.brandStrong)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DsAdaptiveGrid(
                                minItemWidth: 260,
                                maxColumns: 2,
                                equalHeight: false,
                                spacing: DsSpace.md,
                                runSpacing: 0,
                                children: [
                                  if (controller.regionList.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.lg),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DsFieldLabel("Region".tr),
                                          DropdownButtonFormField<RegionModel>(
                                            hint: Text('Select region'.tr, style: t.body.withColor(c.textMuted)),
                                            dropdownColor: c.surfaceRaised,
                                            borderRadius: DsRadius.brMd,
                                            isExpanded: true,
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                            decoration: DsInputDecoration.of(context, prefixIcon: Icons.public_rounded),
                                            initialValue: controller.selectedRegion.value.id == null ? null : controller.selectedRegion.value,
                                            onChanged: (value) {
                                              if (value != null) controller.onRegionChanged(value);
                                            },
                                            style: t.bodyStrong,
                                            items: controller.regionList.map((item) {
                                              return DropdownMenuItem<RegionModel>(
                                                value: item,
                                                child: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: DsSpace.xs),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DsFieldLabel("Zone".tr),
                                        DropdownButtonFormField<ZoneModel>(
                                          // Rebuilt when the region changes, so a cleared
                                          // zone selection is reflected.
                                          key: ValueKey("zone_${controller.selectedRegion.value.id}"),
                                          hint: Text('Select zone'.tr, style: t.body.withColor(c.textMuted)),
                                          dropdownColor: c.surfaceRaised,
                                          borderRadius: DsRadius.brMd,
                                          isExpanded: true,
                                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                          decoration: DsInputDecoration.of(context, prefixIcon: Icons.map_outlined),
                                          initialValue: controller.selectedZone.value.id == null ? null : controller.selectedZone.value,
                                          onChanged: (value) {
                                            controller.selectedZone.value = value!;
                                            controller.update();
                                          },
                                          style: t.bodyStrong,
                                          items: controller.zoneList.map((item) {
                                            return DropdownMenuItem<ZoneModel>(
                                              value: item,
                                              child: Text(item.name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // ── Services & categories ───────────────────────
                          DsFormSection(
                            title: "Service and Categories".tr,
                            icon: Icons.category_outlined,
                            children: [
                              DsFieldLabel("Categories".tr),
                              DropdownSearch<VendorCategoryModel>.multiSelection(
                                items: (String s, LoadProps? data) => controller.vendorCategoryList,
                                key: controller.myKey1,
                                suffixProps: DropdownSuffixProps(
                                  dropdownButtonProps: DropdownButtonProps(
                                    focusColor: c.brand,
                                    color: c.textMuted,
                                    iconClosed: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                    iconOpened: Icon(Icons.keyboard_arrow_up_rounded, color: c.brand),
                                  ),
                                ),
                                decoratorProps: DropDownDecoratorProps(
                                  decoration: DsInputDecoration.of(
                                    context,
                                    hint: 'Select Categories'.tr,
                                    prefixIcon: Icons.sell_outlined,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
                                  ),
                                ),
                                compareFn: (i1, i2) => i1.title == i2.title,
                                popupProps: MultiSelectionPopupProps.modalBottomSheet(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(decoration: DsInputDecoration.of(context, hint: 'Search'.tr, prefixIcon: Icons.search_rounded)),
                                  modalBottomSheetProps: ModalBottomSheetProps(backgroundColor: c.surfaceRaised),
                                  itemBuilder: (context, item, isDisabled, isSelected) {
                                    return Container(
                                      constraints: const BoxConstraints(minHeight: 48),
                                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                                      child: Row(
                                        children: [
                                          DsIconWell(icon: Icons.sell_outlined, tone: isSelected ? DsTone.brand : DsTone.neutral, size: 32),
                                          const DsGap(DsSpace.md),
                                          Expanded(child: Text(item.title ?? "", style: isSelected ? t.label : t.body)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                itemAsString: (VendorCategoryModel u) => u.title.toString(),
                                selectedItems: controller.selectedCategories,
                                onSaved: (data) {},
                                onSelected: (data) {
                                  controller.selectedCategories.clear();
                                  controller.selectedCategories.addAll(data);
                                },
                              ),
                              if (Constant.selectedSection?.dineInActive == true) ...[
                                const DsGap(DsSpace.lg),
                                DsFieldLabel("Services".tr),
                                Container(
                                  decoration: BoxDecoration(
                                    color: c.surfaceAlt,
                                    borderRadius: DsRadius.brMd,
                                    border: Border.all(color: c.isDark ? c.border : c.surfaceAlt),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                                  child: MultiSelectDialogField(
                                    backgroundColor: c.surfaceRaised,
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
                                    selectedColor: c.brand,
                                    selectedItemsTextStyle: t.labelSm.withColor(c.onBrand),
                                    itemsTextStyle: t.bodySm,
                                    checkColor: c.onBrand,
                                    chipDisplay: MultiSelectChipDisplay(
                                      chipColor: c.brandSoft,
                                      textStyle: t.labelSm.withColor(c.brandStrong),
                                      shape: const StadiumBorder(),
                                    ),
                                    title: Text("Select Services".tr, style: t.title),
                                    buttonText: Text(
                                      controller.selectedService.isEmpty ? "Select Service".tr : "Select Service".tr,
                                      style: t.bodyStrong,
                                    ),
                                    buttonIcon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted, size: 26),
                                    decoration: const BoxDecoration(
                                      border: Border.fromBorderSide(BorderSide.none), // remove default border
                                    ),
                                    onConfirm: (values) {
                                      controller.selectedService.value = values;
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // ── Delivery & charges ──────────────────────────
                          if (controller.selectedSectionModel.value.packagingChargeEnable == true || Constant.selectedSection!.serviceTypeFlag != "ecommerce-service")
                            DsFormSection(
                              title: "Delivery Settings".tr,
                              icon: Icons.local_shipping_outlined,
                              children: [
                                if (controller.selectedSectionModel.value.packagingChargeEnable == true)
                                  FormInput(
                                    label: 'Packaging charge'.tr,
                                    controller: controller.packagingChargeAmountController.value,
                                    maxLines: 1,
                                    prefixIcon: Icons.inventory_2_outlined,
                                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                    hint: 'Enter Packaging charge'.tr,
                                  ),
                                if (Constant.selectedSection!.serviceTypeFlag != "ecommerce-service") ...[
                                  if (Constant.isSelfDeliveryFeature == true) ...[
                                    FormSwitchTile(
                                      title: "Self Delivery Service".tr,
                                      icon: Icons.delivery_dining_outlined,
                                      tone: DsTone.success,
                                      value: controller.isSelfDelivery.value,
                                      onChanged: (value) {
                                        controller.isSelfDelivery.value = value;
                                        controller.update();
                                      },
                                    ),
                                    const DsGap(DsSpace.sm),
                                  ],
                                  FormSwitchTile(
                                    title: "Delivery Settings".tr,
                                    icon: Icons.tune_rounded,
                                    value: controller.isEnableDeliverySettings.value,
                                    onChanged: (value) {},
                                  ),
                                  const DsGap(DsSpace.lg),
                                  AnimatedOpacity(
                                    duration: DsMotion.of(context, DsMotion.base),
                                    opacity: controller.isEnableDeliverySettings.value ? 1 : 0.7,
                                    child: DsAdaptiveGrid(
                                      minItemWidth: 260,
                                      maxColumns: 2,
                                      equalHeight: false,
                                      runSpacing: 0,
                                      children: [
                                        FormInput(
                                          label: '${'Charges per'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                          controller: controller.chargePerKmController.value,
                                          hint: 'Enter charges'.tr,
                                          enabled: controller.isEnableDeliverySettings.value,
                                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                          textInputAction: TextInputAction.done,
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                          prefix: FormAffix(currencySymbol),
                                        ),
                                        FormInput(
                                          label: 'Min Delivery Charges'.tr,
                                          controller: controller.minDeliveryChargesController.value,
                                          hint: 'Enter Min Delivery Charges'.tr,
                                          enabled: controller.isEnableDeliverySettings.value,
                                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                          textInputAction: TextInputAction.done,
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                          prefix: FormAffix(currencySymbol),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FormInput(
                                    label: '${'Min Delivery Charges within'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                    controller: controller.minDeliveryChargesWithinKMController.value,
                                    hint: '${'Enter Min Delivery Charges within'.tr} ${Constant.distanceType} ${'(distance)'.tr}'.tr,
                                    enabled: controller.isEnableDeliverySettings.value,
                                    prefixIcon: Icons.social_distance_outlined,
                                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                    bottomSpacing: 0,
                                  ),
                                ],
                              ],
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                controller.saveDetails();
              },
            ),
          ),
        );
      },
    );
  }

  /// Address field tapped while empty (unchanged behaviour).
  void _pickAddress(BuildContext context, AddRestaurantController controller) {
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

  /// "change" suffix on the address field (unchanged behaviour).
  void _changeAddress(BuildContext context, AddRestaurantController controller) {
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
  }

  Future buildBottomSheet(BuildContext context, AddRestaurantController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return MediaSourceSheet(
              onCamera: () => controller.pickFile(source: ImageSource.camera),
              onGallery: () => controller.pickFile(source: ImageSource.gallery),
            );
          },
        );
      },
    );
  }
}

/// Hero summary: cover photo, live store name, section badge and an animated
/// completion meter derived from what is already filled in (display only).
class _StoreProgressCard extends StatelessWidget {
  final AddRestaurantController controller;
  const _StoreProgressCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.restaurantNameController.value,
        controller.restaurantDescriptionController.value,
        controller.mobileNumberController.value,
        controller.addressController.value,
      ]),
      builder: (context, _) {
        final checks = <(String, IconData, bool)>[
          ("Photos".tr, Icons.photo_library_outlined, controller.images.isNotEmpty),
          ("Details".tr, Icons.storefront_outlined, controller.restaurantNameController.value.text.trim().isNotEmpty && controller.restaurantDescriptionController.value.text.trim().isNotEmpty),
          ("Location".tr, Icons.place_outlined, controller.addressController.value.text.trim().isNotEmpty && controller.mobileNumberController.value.text.trim().isNotEmpty),
          ("Zone".tr, Icons.map_outlined, controller.selectedZone.value.id != null),
          ("Categories".tr, Icons.category_outlined, controller.selectedCategories.isNotEmpty),
        ];
        final done = checks.where((e) => e.$3).length;
        final progress = done / checks.length;
        final name = controller.restaurantNameController.value.text.trim();
        return DsCard(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(borderRadius: DsRadius.brMd, gradient: DsGradients.brand(context), boxShadow: DsShadows.sm(context)),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedSwitcher(
                      duration: DsMotion.of(context, DsMotion.base),
                      child: controller.images.isNotEmpty
                          ? FormPickedImage(key: ValueKey(controller.images.first), source: controller.images.first, width: 64, height: 64)
                          : const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? (controller.isNewStore ? "Add Store".tr : "Store Details".tr) : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.title,
                        ),
                        const DsGap(DsSpace.xs),
                        Wrap(
                          spacing: DsSpace.xs,
                          runSpacing: DsSpace.xs,
                          children: [
                            if ((controller.selectedSectionModel.value.name ?? '').isNotEmpty)
                              DsBadge(label: controller.selectedSectionModel.value.name.toString(), tone: DsTone.brand, icon: Icons.layers_outlined, small: true),
                            if (controller.selectedZone.value.id != null) DsBadge(label: controller.selectedZone.value.name.toString(), tone: DsTone.info, icon: Icons.map_outlined, small: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DsProgressRing(
                    value: progress,
                    size: 56,
                    stroke: 6,
                    tone: progress >= 1 ? DsTone.success : DsTone.brand,
                    semanticLabel: "Profile completion".tr,
                    center: Text('${(progress * 100).round()}%', style: t.labelSm.withColor(c.textPrimary)),
                  ),
                ],
              ),
              const DsGap(DsSpace.lg),
              Wrap(
                spacing: DsSpace.xs,
                runSpacing: DsSpace.xs,
                children: [
                  for (final check in checks)
                    AnimatedContainer(
                      duration: DsMotion.of(context, DsMotion.base),
                      curve: DsMotion.standard,
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                      decoration: BoxDecoration(color: check.$3 ? c.successSoft : c.surfaceAlt, borderRadius: DsRadius.brPill),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(check.$3 ? Icons.check_circle_rounded : check.$2, size: 14, color: check.$3 ? c.successStrong : c.textMuted),
                          const DsGap(DsSpace.xs),
                          Text(check.$1, style: t.labelSm.withColor(check.$3 ? c.successStrong : c.textSecondary)),
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
