import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../constant/assets.dart';
import '../../utils/utils.dart';
import 'package:customer/utils/address_format.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: DsResponsive(
          maxWidth: 520,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: DsFadeSlideIn.stagger([
                  const DsGap(DsSpace.xl),
                  // Illustration sits in a soft brand halo so it reads on
                  // both light and dark surfaces.
                  Container(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft),
                    child: Image.asset(AppAssets.icLocation, height: 150, fit: BoxFit.contain),
                  ),
                  const DsGap(DsSpace.xxxl),
                  Text("Enable Location for a Personalized Experience".tr, style: t.display.w700, textAlign: TextAlign.center),
                  const DsGap(DsSpace.md),
                  Text(
                    "Allow location access to discover beauty stores and services near you.".tr,
                    style: t.bodyLg.withColor(c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const DsGap(DsSpace.xxxl),
                  DsButton.primary(
                    label: "Use current location".tr,
                    icon: Icons.my_location_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      Constant.checkPermission(
                        context: context,
                        onTap: () async {
                          ShowToastDialog.showLoader("Please wait...".tr);
                          ShippingAddress addressModel = ShippingAddress();
                          try {
                            await Geolocator.requestPermission();
                            Position newLocalData = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                            // The geocoder may return nothing (no locality, rural point) or fail
                            // offline: never index [0] of its result, never throw out of here (02#27).
                            final Placemark? placeMark = await Utils.firstPlacemark(newLocalData.latitude, newLocalData.longitude);
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(latitude: newLocalData.latitude, longitude: newLocalData.longitude);
                            // Placemark fields are nullable: interpolating one that the geocoder did
                            // not return printed the four characters "null" into the stored address
                            // (report #17). Same fields, same order, through formatAddressLine.
                            String currentLocation = placeMark == null ? '' : formatAddressLine([
                              placeMark.name,
                              placeMark.subLocality,
                              placeMark.locality,
                              placeMark.administrativeArea,
                              placeMark.postalCode,
                              placeMark.country,
                            ]);
                            addressModel.locality = currentLocation;

                            Constant.selectedLocation = addressModel;
                            // The fix just taken; a second request could only fail differently.
                            Constant.currentLocation = newLocalData;

                            ShowToastDialog.closeLoader();

                            Get.offAll(const ServiceListScreen());
                          } catch (e) {
                            // The geocoder may return nothing (no locality, rural point) or fail
                            // offline: never index [0] of its result, never throw out of here (02#27).
                            final Placemark? placeMark = await Utils.firstPlacemark(19.228825, 72.854118);
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
                            // Placemark fields are nullable: interpolating one that the geocoder did
                            // not return printed the four characters "null" into the stored address
                            // (report #17). Same fields, same order, through formatAddressLine.
                            String currentLocation = placeMark == null ? '' : formatAddressLine([
                              placeMark.name,
                              placeMark.subLocality,
                              placeMark.locality,
                              placeMark.administrativeArea,
                              placeMark.postalCode,
                              placeMark.country,
                            ]);
                            addressModel.locality = currentLocation;

                            Constant.selectedLocation = addressModel;
                            // Permission refused for good throws here: the loader must still close.
                            try {
                              Constant.currentLocation = await Utils.getCurrentLocation();
                            } catch (_) {
                              Constant.currentLocation = null;
                            }

                            ShowToastDialog.closeLoader();

                            Get.offAll(const ServiceListScreen());
                          }
                        },
                      );
                    },
                  ),
                  const DsGap(DsSpace.md),
                  DsButton.secondary(
                    label: "Set from map".tr,
                    icon: Icons.map_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      Constant.checkPermission(
                        context: context,
                        onTap: () async {
                          ShowToastDialog.showLoader("Please wait...".tr);
                          ShippingAddress addressModel = ShippingAddress();
                          try {
                            await Geolocator.requestPermission();
                            await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                            ShowToastDialog.closeLoader();
                            if (Constant.selectedMapType == 'osm') {
                              final result = await Get.to(() => MapPickerPage());
                              if (result != null) {
                                final firstPlace = result;
                                final lat = firstPlace.coordinates.latitude;
                                final lng = firstPlace.coordinates.longitude;
                                final address = firstPlace.address;

                                addressModel.addressAs = "Home";
                                addressModel.locality = address.toString();
                                addressModel.location = UserLocation(latitude: lat, longitude: lng);
                                Constant.selectedLocation = addressModel;
                                Get.offAll(const ServiceListScreen());
                              }
                            } else {
                              Get.to(LocationPickerScreen())!.then((value) async {
                                if (value != null) {
                                  SelectedLocationModel selectedLocationModel = value;

                                  addressModel.addressAs = "Home";
                                  addressModel.locality = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                  addressModel.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                  Constant.selectedLocation = addressModel;

                                  Get.offAll(const ServiceListScreen());
                                }
                              });
                            }
                          } catch (e) {
                            // The geocoder may return nothing (no locality, rural point) or fail
                            // offline: never index [0] of its result, never throw out of here (02#27).
                            final Placemark? placeMark = await Utils.firstPlacemark(19.228825, 72.854118);
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
                            // Placemark fields are nullable: interpolating one that the geocoder did
                            // not return printed the four characters "null" into the stored address
                            // (report #17). Same fields, same order, through formatAddressLine.
                            String currentLocation = placeMark == null ? '' : formatAddressLine([
                              placeMark.name,
                              placeMark.subLocality,
                              placeMark.locality,
                              placeMark.administrativeArea,
                              placeMark.postalCode,
                              placeMark.country,
                            ]);
                            addressModel.locality = currentLocation;

                            Constant.selectedLocation = addressModel;
                            ShowToastDialog.closeLoader();

                            Get.offAll(const ServiceListScreen());
                          }
                        },
                      );
                    },
                  ),
                  const DsGap(DsSpace.lg),
                  Constant.userModel == null
                      ? const SizedBox()
                      : DsButton.ghost(
                          label: "Enter Manually location".tr,
                          trailingIcon: Icons.chevron_right_rounded,
                          onPressed: () async {
                            Get.to(AddressListScreen())!.then((value) {
                              if (value != null) {
                                ShippingAddress addressModel = value;
                                Constant.selectedLocation = addressModel;
                                Get.offAll(const ServiceListScreen());
                              }
                            });
                          },
                        ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
