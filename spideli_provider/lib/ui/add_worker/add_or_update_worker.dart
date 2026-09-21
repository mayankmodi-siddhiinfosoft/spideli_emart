import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/add_worker_controller.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/geoflutterfire.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/models/point.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:spideliprovider/widgets/place_picker/location_picker_screen.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../widgets/osm_map/map_picker_page.dart';

class AddOrUpdateWorkerScreen extends StatelessWidget {
  const AddOrUpdateWorkerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateWorkerController>(
        init: AddOrUpdateWorkerController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
              title: Text(
                controller.user.value.id != "" ? 'Edit Worker'.tr : "Add Worker".tr,
                style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
              ),
              leading: InkWell(
                onTap: () {
                  Get.back();
                },
                child: Icon(
                  Icons.arrow_back,
                  color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Form(
                key: controller.formKey.value,
                autovalidateMode: controller.validate,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active'.tr,
                            style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18),
                          ),
                          Switch(
                            splashRadius: 40.0,
                            value: controller.isActive.value,
                            onChanged: (value) {
                              controller.isActive.value = value;
                            },
                          ),
                        ],
                      ),
                      controller.user.value.id != ""
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: ClipOval(
                                  child: NetworkImageWidget(
                                    imageUrl: controller.user.value.profilePictureURL.toString(),
                                    height: Responsive.width(30, context),
                                    width: Responsive.width(30, context),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(),
                      Text(
                        'First Name'.tr,
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: TextFormField(
                            controller: controller.firstName.value,
                            cursorColor: AppColors.colorPrimary,
                            textAlignVertical: TextAlignVertical.center,
                            validator: validateName,
                            onSaved: (String? val) {
                              controller.firstName.value.text = val.toString();
                            },
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              fillColor: Colors.white,
                              hintText: 'First Name'.tr,
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          'Last Name'.tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: TextFormField(
                          controller: controller.lastName.value,
                          cursorColor: AppColors.colorPrimary,
                          textAlignVertical: TextAlignVertical.center,
                          validator: validateName,
                          onSaved: (String? val) {
                            controller.lastName.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            fillColor: Colors.white,
                            hintText: 'Last Name'.tr,
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          'Email Address'.tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: TextFormField(
                          controller: controller.email.value,
                          cursorColor: AppColors.colorPrimary,
                          textAlignVertical: TextAlignVertical.center,
                          validator: validateEmail,
                          onSaved: (String? val) {
                            controller.email.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            enabled: Get.arguments == null ? true : false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            fillColor: Colors.white,
                            hintText: 'Email Address'.tr,
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          'Phone Number'.tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: TextFormField(
                          controller: controller.mobile.value,
                          cursorColor: AppColors.colorPrimary,
                          textAlignVertical: TextAlignVertical.center,
                          validator: validateEmptyField,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            fillColor: Colors.white,
                            hintText: 'Phone Number'.tr,
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          'Address'.tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: TextFormField(
                          controller: controller.address.value,
                          cursorColor: AppColors.colorPrimary,
                          textAlignVertical: TextAlignVertical.center,
                          validator: validateEmptyField,
                          onTap: () {
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
                                      Get.back();
                                    }
                                  });
                                }
                              } catch (e) {
                                print(e.toString());
                              }
                            }, context);
                          },
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            fillColor: Colors.white,
                            hintText: 'Address'.tr,
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          'Salary'.tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        child: TextFormField(
                          controller: controller.salary.value,
                          cursorColor: AppColors.colorPrimary,
                          textAlignVertical: TextAlignVertical.center,
                          validator: validateEmptyField,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          onSaved: (String? val) {
                            controller.salary.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            fillColor: Colors.white,
                            hintText: 'Salary'.tr,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Text(currencyData!.symbol.toString()),
                            ),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                          ),
                        ),
                      ),
                      controller.user.value.id == ""
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                                  child: Text(
                                    'Password'.tr,
                                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: double.infinity),
                                  child: TextFormField(
                                    controller: controller.password.value,
                                    cursorColor: AppColors.colorPrimary,
                                    textAlignVertical: TextAlignVertical.center,
                                    validator: validatePassword,
                                    onSaved: (String? val) {
                                      controller.password.value.text = val.toString();
                                    },
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      fillColor: Colors.white,
                                      hintText: 'Password'.tr,
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                        borderRadius: BorderRadius.circular(15.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                        borderRadius: BorderRadius.circular(15.0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(15.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(),
                      SizedBox(
                        height: 14,
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: AppColors.colorPrimary),
                            ),
                            backgroundColor: AppColors.colorPrimary),
                        onPressed: () {
                          _validate(controller, context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Save'.tr,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeChange.getTheme() ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  _validate(AddOrUpdateWorkerController controller, BuildContext context) async {
    if (controller.formKey.value.currentState?.validate() ?? false) {
      controller.formKey.value.currentState!.save();
      ShowToastDialog.showLoader('Saving Worker...'.tr);

      User? user = controller.user.value;

      GeoFirePoint myLocation = Geoflutterfire().point(latitude: controller.latValue.value, longitude: controller.longValue.value);

      user.firstName = controller.firstName.value.text;
      user.lastName = controller.lastName.value.text;
      user.email = controller.email.value.text;
      user.phoneNumber = controller.mobile.value.text;
      user.salary = controller.salary.value.text;
      user.address = controller.address.value.text;
      user.geoFireData = GeoFireData(geohash: myLocation.hash, geoPoint: GeoPoint(controller.latValue.value, controller.longValue.value));
      user.latitude = controller.latValue.value;
      user.longitude = controller.longValue.value;
      user.active = controller.isActive.value;

      if (Get.arguments != null) {
        await FireStoreUtils.firebaseUpdateWorker(user);
        Get.back(result: true);
      } else {
        await controller.signUpWithWorkerEmailAndPassword(user, controller.password.value.text, context);
      }
      ShowToastDialog.closeLoader();
    } else {
      controller.validate = AutovalidateMode.onUserInteraction;
    }
  }
}
