import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/auth_screen/phone_number_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/region_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../constant/constant.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: SignupController(),
        builder: (SignupController controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create an Account".tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                    ),
                    Text(
                      "Sign up now to start your journey as a spideli driver and begin earning with every delivery.".tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontFamily: AppThemeData.regular),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already Have an account?'.tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                          ),
                          const WidgetSpan(child: SizedBox(width: 5)),
                          TextSpan(
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Get.offAll(const LoginScreen());
                              },
                            text: 'Log in'.tr,
                            style: TextStyle(
                              color: AppThemeData.primary300,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: AppThemeData.primary300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Individual / Company ─────────────────────────────
                    Text('Continue as'.tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Individual'.tr, style: TextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700)),
                            value: 'Individual',
                            groupValue: controller.selectedValue.value,
                            activeColor: AppThemeData.primary300,
                            onChanged: (v) => controller.onRoleChanged(v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Company'.tr, style: TextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700)),
                            value: 'Company',
                            groupValue: controller.selectedValue.value,
                            activeColor: AppThemeData.primary300,
                            onChanged: (v) => controller.onRoleChanged(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Section selection ─────────────────────────────────
                    Text(
                      "Select Sections".tr,
                      style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                    ),
                    const SizedBox(height: 5),
                    controller.visibleSections.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(controller.allSections.isEmpty ? "Loading sections...".tr : "No sections available".tr, style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey600)),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                            ),
                            child: Column(
                              children: controller.visibleSections.map((section) {
                                final isChecked = controller.isSectionSelected(section);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(
                                    section.name ?? '',
                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                                  ),
                                  subtitle: Text(
                                    controller.serviceFlagLabel(section.serviceTypeFlag),
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600, fontFamily: AppThemeData.regular),
                                  ),
                                  value: isChecked,
                                  activeColor: AppThemeData.primary300,
                                  checkColor: Colors.white,
                                  onChanged: (_) async {
                                    await controller.toggleSection(section);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                    const SizedBox(height: 10),

                    // ── Per-section vehicle type + car details (cab / rental, Individual only) ───
                    if (controller.selectedValue.value == "Individual")
                    ...controller.selectedSections
                        .where((s) => controller.sectionNeedsVehicle(s))
                        .map((section) {
                      final sid = section.id!;
                      final vehicles = controller.vehicleTypesPerSection[sid] ?? [];
                      final selectedVehicle = controller.selectedVehiclePerSection[sid];
                      final sectionCarMakes = controller.selectedCarMakesPerSection[sid];
                      final sectionCarModels = controller.carModelListPerSection[sid] ?? <CarModel>[].obs;
                      final sectionCarModel = controller.selectedCarModelPerSection[sid];
                      final sectionCarPlate = controller.carPlatePerSection[sid];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.name ?? '',
                            style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: AppThemeData.primary300),
                          ),
                          const SizedBox(height: 5),
                          if (vehicles.isNotEmpty)
                            DropdownButtonFormField<VehicleType>(
                              hint: Text('Vehicle Type'.tr, style: TextStyle(fontSize: 14, color: AppThemeData.grey700, fontFamily: AppThemeData.regular)),
                              icon: const Icon(Icons.keyboard_arrow_down),
                              dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              decoration: _dropdownDecoration(isDark),
                              value: selectedVehicle,
                              onChanged: (value) {
                                if (value != null) {
                                  controller.selectedVehiclePerSection[sid] = value;
                                  controller.update();
                                }
                              },
                              style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                              items: vehicles.map((item) => DropdownMenuItem<VehicleType>(value: item, child: Text(item.name.toString()))).toList(),
                            ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<CarMakes>(
                            hint: Text('Car Brand'.tr, style: TextStyle(fontSize: 14, color: AppThemeData.grey700, fontFamily: AppThemeData.regular)),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                            decoration: _dropdownDecoration(isDark),
                            value: sectionCarMakes?.value.id == null ? null : sectionCarMakes?.value,
                            onChanged: (value) {
                              if (value != null) {
                                controller.selectedCarMakesPerSection[sid]?.value = value;
                                controller.getCarModelForSection(sid);
                                controller.update();
                              }
                            },
                            style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                            items: controller.carMakesList.map((item) => DropdownMenuItem<CarMakes>(value: item, child: Text(item.name.toString()))).toList(),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<CarModel>(
                            key: ValueKey('carModel_${sectionCarMakes?.value.id}_${sectionCarModels.length}'),
                            hint: Text('Car Model'.tr, style: TextStyle(fontSize: 14, color: AppThemeData.grey700, fontFamily: AppThemeData.regular)),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                            decoration: _dropdownDecoration(isDark),
                            value: sectionCarModel?.value.id == null ? null : sectionCarModel?.value,
                            onChanged: (value) {
                              if (value != null) {
                                controller.selectedCarModelPerSection[sid]?.value = value;
                                controller.update();
                              }
                            },
                            style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                            items: sectionCarModels.map((item) => DropdownMenuItem<CarModel>(value: item, child: Text(item.name.toString()))).toList(),
                          ),
                          const SizedBox(height: 10),
                          TextFieldWidget(
                            title: 'Car Plate Number'.tr,
                            controller: sectionCarPlate?.value ?? TextEditingController(),
                            hintText: 'Enter Car Plate Number'.tr,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),

                    // ── Name fields ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextFieldWidget(
                            title: 'First Name'.tr,
                            controller: controller.firstNameEditingController.value,
                            hintText: 'Enter First Name'.tr,
                            prefix: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset("assets/icons/ic_user.svg",
                                  colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFieldWidget(
                            title: 'Last Name'.tr,
                            controller: controller.lastNameEditingController.value,
                            hintText: 'Enter Last Name'.tr,
                            prefix: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset("assets/icons/ic_user.svg",
                                  colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),

                    // ── Email ─────────────────────────────────────────────
                    TextFieldWidget(
                      title: 'Email Address'.tr,
                      textInputType: TextInputType.emailAddress,
                      controller: controller.emailEditingController.value,
                      hintText: 'Enter Email Address'.tr,
                      enable: controller.type.value == "google" || controller.type.value == "apple" ? false : true,
                      prefix: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset("assets/icons/ic_mail.svg",
                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                      ),
                      textInputAction: TextInputAction.next,
                    ),

                    // ── Phone number ──────────────────────────────────────
                    TextFieldWidget(
                      title: 'Phone Number'.tr,
                      controller: controller.phoneNUmberEditingController.value,
                      hintText: 'Enter Phone Number'.tr,
                      enable: controller.type.value == "mobileNumber" ? false : true,
                      textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                      prefix: CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                        },
                        enabled: controller.type.value == "mobileNumber" ? false : true,
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                        },
                        dialogTextStyle: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontWeight: FontWeight.w500, fontFamily: AppThemeData.medium),
                        dialogBackgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                        initialSelection: controller.countryISOCodeEditingController.value.text,
                        comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                        textStyle: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                        searchDecoration: InputDecoration(iconColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        searchStyle: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontWeight: FontWeight.w500, fontFamily: AppThemeData.medium),
                      ),
                    ),

                    // ── Zone ──────────────────────────────────────────────
                    controller.selectedValue.value == "Company"
                        ? const SizedBox()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Zone".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<ZoneModel>(
                                hint: Text('Select zone'.tr, style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey700 : AppThemeData.grey700, fontFamily: AppThemeData.regular)),
                                dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                decoration: InputDecoration(
                                  errorStyle: const TextStyle(color: Colors.red),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                  disabledBorder: UnderlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1)),
                                  focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, width: 1)),
                                  enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1)),
                                  errorBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1)),
                                  border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1)),
                                ),
                                initialValue: controller.selectedZone.value.id == null ? null : controller.selectedZone.value,
                                onChanged: (value) {
                                  controller.selectedZone.value = value!;
                                  controller.update();
                                },
                                style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                                items: controller.zoneList.map((item) => DropdownMenuItem<ZoneModel>(value: item, child: Text(item.name.toString()))).toList(),
                              ),
                            ],
                          ),
                    const SizedBox(height: 10),

                    // ── Management zone (region) ──────────────────────────
                    if (controller.regionList.isNotEmpty) ...[
                      Text("Management zone".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<RegionModel>(
                        hint: Text('Select management zone'.tr, style: TextStyle(fontSize: 14, color: AppThemeData.grey700, fontFamily: AppThemeData.regular)),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                        decoration: _dropdownDecoration(isDark),
                        initialValue: controller.selectedRegion.value,
                        onChanged: (value) {
                          controller.selectedRegion.value = value;
                          controller.update();
                        },
                        style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                        items: controller.regionList.map((item) => DropdownMenuItem<RegionModel>(value: item, child: Text(item.displayName))).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Company identification (spec 4.11) ────────────────
                    if (controller.isCompany) ...[
                      Text("Company information".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                      const SizedBox(height: 5),
                      TextFieldWidget(
                        title: 'Company Name'.tr,
                        controller: controller.companyNameController.value,
                        hintText: 'Enter Company Name'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      TextFieldWidget(
                        title: 'Operating Licence'.tr,
                        controller: controller.operatingLicenceController.value,
                        hintText: 'Enter Operating Licence Number'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      TextFieldWidget(
                        title: 'Commercial Register'.tr,
                        controller: controller.commercialRegisterController.value,
                        hintText: 'Enter Commercial Register Number'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      TextFieldWidget(
                        title: 'Unique Identification Number'.tr,
                        controller: controller.uniqueIdNumberController.value,
                        hintText: 'Enter Unique Identification Number'.tr,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 5),
                      Text("Company documents".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                      ...SignupController.companyFileFields.entries.map((entry) {
                        final picked = controller.companyFiles[entry.key];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(picked == null ? Icons.upload_file : Icons.check_circle, color: picked == null ? AppThemeData.grey500 : AppThemeData.success400),
                          title: Text(entry.value.tr, style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium)),
                          subtitle: Text(picked == null ? "Not uploaded".tr : picked.split('/').last,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600)),
                          trailing: PopupMenuButton<ImageSource>(
                            icon: Icon(Icons.add_a_photo_outlined, color: AppThemeData.primary300),
                            onSelected: (source) => controller.pickCompanyFile(entry.key, source),
                            itemBuilder: (_) => [
                              PopupMenuItem(value: ImageSource.camera, child: Text("Camera".tr)),
                              PopupMenuItem(value: ImageSource.gallery, child: Text("Gallery".tr)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // ── Password (email sign-up only) ─────────────────────
                    controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber"
                        ? const SizedBox()
                        : Column(
                            children: [
                              TextFieldWidget(
                                title: 'Password'.tr,
                                controller: controller.passwordEditingController.value,
                                hintText: 'Enter Password'.tr,
                                obscureText: controller.passwordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset("assets/icons/ic_lock.svg",
                                      colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    onTap: () => controller.passwordVisible.value = !controller.passwordVisible.value,
                                    child: SvgPicture.asset(
                                      controller.passwordVisible.value ? "assets/icons/ic_password_show.svg" : "assets/icons/ic_password_close.svg",
                                      colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              TextFieldWidget(
                                title: 'Confirm Password'.tr,
                                controller: controller.conformPasswordEditingController.value,
                                hintText: 'Enter Confirm Password'.tr,
                                obscureText: controller.conformPasswordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset("assets/icons/ic_lock.svg",
                                      colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    onTap: () => controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value,
                                    child: SvgPicture.asset(
                                      controller.conformPasswordVisible.value ? "assets/icons/ic_password_show.svg" : "assets/icons/ic_password_close.svg",
                                      colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Log in with'.tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                      ),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(const PhoneNumberScreen());
                          },
                        text: 'Mobile Number'.tr,
                        style: TextStyle(
                          color: AppThemeData.primary300,
                          fontFamily: AppThemeData.medium,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppThemeData.primary300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    if (controller.selectedSections.isEmpty) {
                      ShowToastDialog.showToast("Please select at least one section".tr);
                      return;
                    }
                    if (controller.firstNameEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter first name".tr);
                    } else if (controller.lastNameEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter last name".tr);
                    } else if (controller.emailEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter valid email".tr);
                    } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter Phone number".tr);
                    } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.passwordEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter password".tr);
                    } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.conformPasswordEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter Confirm password".tr);
                    } else if (controller.type.value != "google" && controller.type.value != "apple" && controller.type.value != "mobileNumber" && controller.passwordEditingController.value.text != controller.conformPasswordEditingController.value.text) {
                      ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                    } else if (controller.selectedValue.value == "Individual" && controller.selectedZone.value.id == null) {
                      ShowToastDialog.showToast("Please select zone".tr);
                    } else if (controller.regionRequired && controller.selectedRegion.value == null) {
                      ShowToastDialog.showToast("Please select your management zone".tr);
                    } else if (controller.isCompany && controller.companyNameController.value.text.trim().isEmpty) {
                      ShowToastDialog.showToast("Please enter company name".tr);
                    } else if (controller.isCompany &&
                        (controller.operatingLicenceController.value.text.trim().isEmpty ||
                            controller.commercialRegisterController.value.text.trim().isEmpty ||
                            controller.uniqueIdNumberController.value.text.trim().isEmpty)) {
                      ShowToastDialog.showToast("Please enter the operating licence, commercial register and unique identification number".tr);
                    } else {
                      controller.signUpWithEmailAndPassword();
                    }
                  },
                  child: Container(
                    color: AppThemeData.primary300,
                    width: Responsive.width(100, context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "Sign up".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppThemeData.grey50, fontSize: 16, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  InputDecoration _dropdownDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppThemeData.grey400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2)),
    );
  }
}
