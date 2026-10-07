import 'package:geolocator/geolocator.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/address_format.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/enter_manually_location_controller.dart';

/// Archetype E — address form: a map-picker card on top, then the grouped
/// address fields and the "save as" chips, with the CTA in a sticky bar.
class EnterManuallyLocationScreen extends StatelessWidget {
  const EnterManuallyLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<EnterManuallyLocationController>(
      init: EnterManuallyLocationController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final isLoading = controller.isLoading.value;
        final isDefault = controller.isDefault.value;
        final selectedSaveAs = controller.selectedSaveAs.value;
        final saveAsList = controller.saveAsList.toList();

        return DsScaffold(
          title: controller.mode == "Edit" ? "Edit Address".tr : "Add a New Address".tr,
          // Keep the screen's original back action.
          onBack: () {
            Get.back();
          },
          maxContentWidth: DsLayout.contentMax,
          body: isLoading
              ? const DsSkeletonForm(fields: 4)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      Text(
                        "Enter your location details so we can deliver your orders quickly and accurately.".tr,
                        style: t.bodySm.withColor(c.textSecondary),
                      ),
                      const DsGap(DsSpace.xl),

                      // Map picker: the row and the GPS button both open it
                      // (_pickLocation), with or without location permission.
                      DsCard.outlined(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                        onTap: () => _pickLocation(context, controller),
                        child: Row(
                          children: [
                            const DsIconWell(icon: Icons.map_outlined, size: 42, circle: true),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Choose Location".tr, style: t.bodyStrong),
                                  const DsGap(DsSpace.xxs),
                                  Text("Pick the exact spot on the map".tr, style: t.bodySm),
                                ],
                              ),
                            ),
                            DsIconButton(
                              icon: Icons.gps_fixed,
                              semanticLabel: "Choose Location".tr,
                              variant: DsIconButtonVariant.tonal,
                              onPressed: () => _pickLocation(context, controller),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),

                      DsFormSection(
                        title: "Address details".tr,
                        icon: Icons.home_outlined,
                        children: [
                          DsTextField(
                            label: "Flat/House/Floor/Building*".tr,
                            hint: "Enter address details".tr,
                            controller: controller.houseBuildingTextEditingController.value,
                          ),
                          DsTextField(
                            label: "Area/Sector/Locality*".tr,
                            hint: "Enter area/locality".tr,
                            controller: controller.localityEditingController.value,
                          ),
                          DsTextField(
                            label: "Nearby Landmark".tr,
                            hint: "Add a landmark".tr,
                            controller: controller.landmarkEditingController.value,
                            bottomSpacing: 0,
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

                      DsFormSection(
                        title: "Save Address As".tr,
                        icon: Icons.bookmark_outline_rounded,
                        children: [
                          Wrap(
                            spacing: DsSpace.sm,
                            runSpacing: DsSpace.sm,
                            children: saveAsList
                                .map(
                                  (item) => _SaveAsChip(
                                    label: controller.getLocalizedSaveAs(item),
                                    selected: selectedSaveAs == item,
                                    onTap: () {
                                      controller.selectedSaveAs.value = item;
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const DsGap(DsSpace.lg),
                          DsListTile(
                            title: "Set as Default Address".tr,
                            padding: EdgeInsets.zero,
                            trailing: Switch(
                              value: isDefault,
                              onChanged: (value) {
                                controller.isDefault.value = value;
                              },
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
          bottomBar: isLoading
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Save Address".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      // Saved through the shared address rule (report 02#18): a
                      // "null" / "undefined" / empty comma segment is never
                      // written into address, locality or landmark, and a field
                      // holding nothing else counts as empty.
                      final String house = cleanAddressPart(controller.houseBuildingTextEditingController.value.text);
                      final String locality = cleanAddressPart(controller.localityEditingController.value.text);
                      final String landmark = cleanAddressPart(controller.landmarkEditingController.value.text);
                      if (controller.location.value.latitude == null || controller.location.value.longitude == null) {
                        ShowToastDialog.showToast("Please select Location".tr);
                      } else if (house.isEmpty) {
                        ShowToastDialog.showToast("Please Enter Flat / House / Floor / Building".tr);
                      } else if (locality.isEmpty) {
                        ShowToastDialog.showToast("Please Enter Area / Sector / Locality".tr);
                      } else {
                        ShowToastDialog.showLoader("Please wait...".tr);

                        //Common values
                        controller.shippingModel.value.location = controller.location.value;
                        controller.shippingModel.value.addressAs = controller.selectedSaveAs.value;
                        controller.shippingModel.value.address = house;
                        controller.shippingModel.value.locality = locality;
                        controller.shippingModel.value.landmark = landmark;

                        if (controller.mode.value == "Edit") {
                          //Edit Mode
                          controller.shippingAddressList.value =
                              controller.shippingAddressList.map((address) {
                                if (address.id == controller.shippingModel.value.id) {
                                  return controller.shippingModel.value; // replace existing one
                                }
                                return address;
                              }).toList();
                          Constant.selectedLocation = controller.shippingModel.value;
                        } else {
                          //Add Mode
                          controller.shippingModel.value.id = Constant.getUuid();
                          controller.shippingModel.value.isDefault = controller.shippingAddressList.isEmpty ? true : false;
                          controller.shippingAddressList.add(controller.shippingModel.value);
                        }

                        //Handle default address switch
                        if (controller.isDefault.value) {
                          controller.shippingAddressList.value =
                              controller.shippingAddressList.map((address) {
                                address.isDefault = address.id == controller.shippingModel.value.id ? true : false;
                                return address;
                              }).toList();
                        }

                        controller.userModel.value.shippingAddress = controller.shippingAddressList;
                        await FireStoreUtils.updateUser(controller.userModel.value);

                        ShowToastDialog.closeLoader();
                        Get.back(result: true);
                      }
                    },
                  ),
                ),
        );
      },
    );
  }
}

/// Selectable "Home / Work / Other" chip.
/// Opens the map picker (OpenStreetMap or Google, per settings) and fills the
/// locality and position. Location permission is asked for but never required:
/// a customer who refuses it can still search or move the map (the picker used
/// to stay closed, so the address could not be saved). The old GPS-button
/// handler also popped this screen right after the pick.
Future<void> _pickLocation(BuildContext context, EnterManuallyLocationController controller) async {
  try {
    final LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) await Geolocator.requestPermission();
  } catch (_) {}
  if (Constant.selectedMapType == 'osm') {
    final result = await Get.to(() => MapPickerPage());
    if (result != null) {
      controller.localityEditingController.value.text = result.address.toString();
      controller.location.value = UserLocation(latitude: result.coordinates.latitude, longitude: result.coordinates.longitude);
    }
    return;
  }
  final dynamic value = await Get.to(const LocationPickerScreen());
  if (value is SelectedLocationModel && value.latLng != null) {
    final String text = Utils.formatAddress(selectedLocation: value);
    controller.localityEditingController.value.text =
        text.isNotEmpty ? text : '${value.latLng!.latitude.toStringAsFixed(5)}, ${value.latLng!.longitude.toStringAsFixed(5)}';
    controller.location.value = UserLocation(latitude: value.latLng!.latitude, longitude: value.latLng!.longitude);
  }
}

class _SaveAsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SaveAsChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brPill,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          curve: DsMotion.standard,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.sm),
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surfaceAlt,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Text(label, textAlign: TextAlign.center, style: t.label.withColor(selected ? c.onBrand : c.textSecondary)),
        ),
      ),
    );
  }
}
