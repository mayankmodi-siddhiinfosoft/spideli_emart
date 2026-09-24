import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/themes/ds/ds.dart';
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
import '../../models/user_model.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../../models/parcel_order_model.dart';
import '../../models/parcel_shipping_models.dart';
import '../../utils/parcel_pricing.dart';
import 'parcel_shipping_widgets.dart';
import 'pickup_point_picker_screen.dart';

/// Book a parcel (archetype E — booking wizard): a pinned progress stepper
/// tracks the four stages (shipment, sender, receiver, parcel), every stage is
/// a `DsFormSection` card and the Continue action lives in a sticky bar.
class BookParcelScreen extends StatelessWidget {
  const BookParcelScreen({super.key});

  /// Which wizard stage the form is on, from the reactive fields only.
  int _currentStep(BookParcelController controller) {
    if (controller.receiverLocation.value != null) return 3;
    if (controller.senderLocation.value != null) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return GetX(
      init: BookParcelController(),
      builder: (controller) {
        final int step = _currentStep(controller);
        return DsScaffold(
          appBar: DsAppBar(
            title: "Book Your Document Delivery".tr,
            subtitle: "Schedule a secure and timely pickup & delivery".tr,
            onBack: () => Get.back(),
          ),
          maxContentWidth: DsLayout.contentMax,
          body: ListView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxl),
            children: DsFadeSlideIn.stagger([
              DsCard(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.md),
                child: DsStepper(
                  steps: ["Shipment".tr, "Sender".tr, "Receiver".tr, "Parcel".tr],
                  current: step,
                ),
              ),
              const DsGap(DsSpace.lg),
              typeAndScopeView(controller, context),
              const DsGap(DsSpace.lg),
              selectDeliveryTypeView(controller, context),
              const DsGap(DsSpace.lg),
              buildUploadBoxView(context, controller),
              const DsGap(DsSpace.lg),
              buildInfoSectionView(
                title: "Sender Information".tr,
                icon: Icons.person_outline_rounded,
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
              const DsGap(DsSpace.lg),
              buildInfoSectionView(
                title: "Receiver Information".tr,
                icon: Icons.person_pin_circle_outlined,
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
              const DsGap(DsSpace.lg),
              parcelDetailsView(controller, context),
              const DsGap(DsSpace.lg),
              methodsView(controller, context),
            ]),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Continue".tr,
              trailingIcon: Icons.arrow_forward_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () {
                controller.bookNow();
              },
            ),
          ),
        );
      },
    );
  }

  /// Spec 4.2 step 1: parcel or mail; same city / other city / other country.
  Widget typeAndScopeView(BookParcelController controller, BuildContext context) {
    const List<String> scopes = [ParcelScope.city, ParcelScope.intercity, ParcelScope.intercountry];
    final int rawScopeIndex = scopes.indexOf(controller.scope.value);
    final int scopeIndex = rawScopeIndex < 0 ? 0 : rawScopeIndex;
    return DsFormSection(
      title: "What are you sending?".tr,
      icon: Icons.inventory_2_outlined,
      children: [
        DsSegmentedTabs(
          segments: [DsSegment("Parcel".tr, icon: Icons.inventory_2_outlined), DsSegment("Mail".tr, icon: Icons.mail_outline_rounded)],
          index: controller.shipmentType.value == ParcelShipping.mail ? 1 : 0,
          onChanged: (i) => controller.shipmentType.value = i == 1 ? ParcelShipping.mail : ParcelShipping.parcel,
        ),
        const DsGap(DsSpace.xl),
        DsFieldLabel("Where to?".tr),
        DsSegmentedTabs(
          scrollable: true,
          segments: [for (final sc in scopes) DsSegment(ParcelLabels.scope(sc))],
          index: scopeIndex,
          onChanged: (i) {
            final sc = scopes[i];
            controller.scope.value = sc;
            if (sc == ParcelScope.city && controller.receiverLocation.value != null) {
              final loc = controller.receiverLocation.value!;
              if (Constant.checkZoneCheck(loc.latitude ?? 0, loc.longitude ?? 0) != true) {
                // A receiver outside the zones cannot be a same-city delivery.
                controller.receiverLocation.value = null;
                controller.receiverLocationController.value.clear();
              }
            }
          },
        ),
      ],
    );
  }

  /// Spec 4.2 step 2: weight, dimensions, declared value, content description.
  Widget parcelDetailsView(BookParcelController controller, BuildContext context) {
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return DsFormSection(
      title: "Parcel details".tr,
      icon: Icons.straighten_rounded,
      children: [
        DsTextField(
          hint: controller.isCityScope ? "Weight in kg (optional)".tr : "Weight in kg".tr,
          controller: controller.weightKgController.value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numeric,
          prefixIcon: Icons.scale_outlined,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DsTextField(hint: "L (cm)".tr, controller: controller.lengthController.value, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric),
            ),
            const DsGap(DsSpace.sm),
            Expanded(
              child: DsTextField(hint: "W (cm)".tr, controller: controller.widthController.value, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric),
            ),
            const DsGap(DsSpace.sm),
            Expanded(
              child: DsTextField(hint: "H (cm)".tr, controller: controller.heightController.value, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numeric),
            ),
          ],
        ),
        DsTextField(
          hint: "Declared value (optional)".tr,
          controller: controller.declaredValueController.value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numeric,
          prefixIcon: Icons.shield_outlined,
        ),
        DsTextField(hint: "Content description".tr, controller: controller.contentDescriptionController.value, prefixIcon: Icons.description_outlined, bottomSpacing: 0),
      ],
    );
  }

  /// Spec 4.2 steps 3-4: how the parcel leaves and how the receiver gets it.
  Widget methodsView(BookParcelController controller, BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget option(String label, bool selected, IconData icon, VoidCallback onTap) => DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.sm),
      padding: const EdgeInsets.all(DsSpace.md),
      borderColor: selected ? c.brand : null,
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          DsIconWell(icon: icon, size: 38, tone: selected ? DsTone.brand : DsTone.neutral),
          const DsGap(DsSpace.md),
          Expanded(child: Text(label, style: t.bodyStrong)),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? c.brand : c.textMuted,
          ),
        ],
      ),
    );
    Widget pointTile(PickupPointModel? point, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsButton.tonal(
        label: point == null ? "Choose a pickup point".tr : "${point.name}${point.subtitle.isEmpty ? '' : ' - ${point.subtitle}'}",
        icon: Icons.storefront_outlined,
        size: DsButtonSize.sm,
        expand: true,
        onPressed: onTap,
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

    return DsFormSection(
      title: "Pickup method".tr,
      icon: Icons.swap_horiz_rounded,
      children: [
        option(ParcelLabels.pickupMethod(ParcelShipping.home), controller.pickupMethod.value == ParcelShipping.home, Icons.home_outlined, () => controller.pickupMethod.value = ParcelShipping.home),
        option(ParcelLabels.pickupMethod(ParcelShipping.pickupPoint), controller.pickupMethod.value == ParcelShipping.pickupPoint, Icons.storefront_outlined, () {
          controller.pickupMethod.value = ParcelShipping.pickupPoint;
          if (controller.originPickupPoint.value == null) pick(origin: true);
        }),
        if (controller.pickupMethod.value == ParcelShipping.pickupPoint) pointTile(controller.originPickupPoint.value, () => pick(origin: true)),
        const DsDivider(spacing: DsSpace.xl),
        DsFieldLabel("Delivery method".tr),
        option(ParcelLabels.deliveryMethod(ParcelShipping.home), controller.deliveryMethod.value == ParcelShipping.home, Icons.home_outlined, () => controller.deliveryMethod.value = ParcelShipping.home),
        option(ParcelLabels.deliveryMethod(ParcelShipping.pickupPoint), controller.deliveryMethod.value == ParcelShipping.pickupPoint, Icons.storefront_outlined, () {
          if (controller.receiverLocation.value == null) {
            ShowToastDialog.showToast("Please select the receiver address first".tr);
            return;
          }
          controller.deliveryMethod.value = ParcelShipping.pickupPoint;
          if (controller.destinationPickupPoint.value == null) pick(origin: false);
        }),
        if (controller.deliveryMethod.value == ParcelShipping.pickupPoint) pointTile(controller.destinationPickupPoint.value, () => pick(origin: false)),
      ],
    );
  }

  Widget selectDeliveryTypeView(BookParcelController controller, BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool now = controller.selectedDeliveryType.value == 'now';
    final bool later = controller.selectedDeliveryType.value == 'later';
    Widget typeCard({required String asset, required String label, required bool selected, required VoidCallback onTap, Widget? extra}) => DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.sm),
      padding: const EdgeInsets.all(DsSpace.md),
      borderColor: selected ? c.brand : null,
      semanticLabel: label,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(asset, height: 38, width: 38),
              const DsGap(DsSpace.lg),
              Expanded(child: Text(label, style: t.titleSm)),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? c.brand : c.textMuted,
                size: 20,
              ),
            ],
          ),
          if (extra != null) ...[const DsGap(DsSpace.lg), extra],
        ],
      ),
    );

    return DsFormSection(
      title: "Select delivery type".tr,
      icon: Icons.schedule_rounded,
      children: [
        typeCard(
          asset: "assets/images/image_parcel.png",
          label: "As soon as possible".tr,
          selected: now,
          onTap: () {
            controller.selectedDeliveryType.value = 'now';
            controller.isScheduled.value = false;
          },
        ),
        typeCard(
          asset: "assets/images/image_parcel_scheduled.png",
          label: "Scheduled".tr,
          selected: later,
          onTap: () {
            controller.selectedDeliveryType.value = 'later';
            controller.isScheduled.value = true;
          },
          extra: later
              ? Column(
                  children: [
                    DsTextField(
                      hint: "When to pickup at this address".tr,
                      controller: controller.scheduledDateController.value,
                      readOnly: true,
                      onTap: () => controller.pickScheduledDate(context),
                      suffix: const Icon(Icons.calendar_month_outlined),
                      bottomSpacing: DsSpace.md,
                    ),
                    DsTextField(
                      hint: "When to pickup at this address".tr,
                      controller: controller.scheduledTimeController.value,
                      readOnly: true,
                      // onchange: (v) => controller.pickScheduledTime(context),
                      onTap: () => controller.pickScheduledTime(context),
                      suffix: const Icon(Icons.access_time),
                      bottomSpacing: 0,
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  Widget buildUploadBoxView(BuildContext context, BookParcelController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsFormSection(
      title: "Upload parcel image".tr,
      icon: Icons.photo_camera_outlined,
      children: [
        DottedBorder(
          options: RoundedRectDottedBorderOptions(strokeWidth: 1.4, radius: const Radius.circular(DsRadius.md), color: c.borderStrong, dashPattern: const [6, 4]),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: DsRadius.brMd, color: c.surfaceAlt),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset("assets/icons/ic_upload_parcel.svg", height: 40, width: 40),
                const DsGap(DsSpace.md),
                Text("Upload Parcel Image".tr, style: t.titleSm, textAlign: TextAlign.center),
                const DsGap(DsSpace.xs),
                Text("Supported: .jpg, .jpeg, .png".tr, style: t.caption, textAlign: TextAlign.center),
                Text("Max size 1MB".tr, style: t.caption, textAlign: TextAlign.center),
                const DsGap(DsSpace.lg),
                DsButton.tonal(
                  label: "Browse Image".tr,
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: () {
                    controller.onCameraClick(Get.context!);
                  },
                ),
              ],
            ),
          ),
        ),
        if (controller.images.isEmpty) const SizedBox(),
        if (controller.images.isNotEmpty) const DsGap(DsSpace.lg),
        Wrap(
          spacing: DsSpace.md,
          runSpacing: DsSpace.md,
          children: controller.images.map((image) {
            return Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: DsSpace.xl, right: DsSpace.xl),
                  child: ClipRRect(borderRadius: DsRadius.brSm, child: Image.file(File(image.path), width: 70, height: 70, fit: BoxFit.cover)),
                ),
                Positioned.fill(
                  top: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: DsIconButton(
                      icon: Icons.cancel_rounded,
                      semanticLabel: "Remove".tr,
                      size: 32,
                      color: c.dangerStrong,
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
    );
  }

  Widget buildInfoSectionView({
    required String title,
    required IconData icon,
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
    required BookParcelController controller,
    required BuildContext context,
  }) {
    final c = context.dsColors;
    final isDark = context.dsIsDark;
    return DsFormSection(
      title: title,
      icon: icon,
      children: [
        DsTextField(
          hint: "Your Location".tr,
          controller: locationController,
          readOnly: true,
          onTap: onTap,
          prefixIcon: Icons.location_on_outlined,
          suffix: const Icon(Icons.map_outlined),
        ),
        DsTextField(hint: "Name".tr, controller: nameController, prefixIcon: Icons.person_outline_rounded, textCapitalization: TextCapitalization.words),
        DsTextField(
          hint: "Enter Mobile number".tr,
          controller: mobileController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
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
                textStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                dialogTextStyle: DsTypography.body.copyWith(color: c.textPrimary),
                searchStyle: DsTypography.body.copyWith(color: c.textPrimary),
                dialogBackgroundColor: c.surfaceRaised,
                padding: EdgeInsets.zero,
              ),
              // const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppThemeData.grey400),
              Container(height: 24, width: 1, color: c.borderStrong),
              const DsGap(DsSpace.xs),
            ],
          ),
        ),
        DsTextField(hint: "Email (optional)".tr, controller: emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.alternate_email_rounded),
        if (!controller.isCityScope)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: DsTextField(hint: "City".tr, controller: cityController, prefixIcon: Icons.location_city_outlined)),
              const DsGap(DsSpace.sm),
              Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd, border: Border.all(color: isDark ? c.border : c.surfaceAlt)),
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
                  textStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                  dialogTextStyle: DsTypography.body.copyWith(color: c.textPrimary),
                  searchStyle: DsTypography.body.copyWith(color: c.textPrimary),
                  dialogBackgroundColor: c.surfaceRaised,
                ),
              ),
            ],
          ),
        if (showWeight)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.lg),
            child: DropDownTextField(
              controller: controller.senderWeightController.value,
              clearOption: false,
              enableSearch: false,
              textFieldDecoration: DsInputDecoration.of(context, hint: "Select parcel Weight".tr, prefixIcon: Icons.scale_outlined),
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
          ),
        DsTextField(hint: "Notes (Optional)".tr, controller: noteController, prefixIcon: Icons.sticky_note_2_outlined, maxLines: 3, minLines: 2, bottomSpacing: 0),
      ],
    );
  }
}
