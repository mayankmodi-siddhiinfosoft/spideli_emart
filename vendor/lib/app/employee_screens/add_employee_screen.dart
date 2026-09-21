import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_employee_controller.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddEmployeeController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
            title: Text(
              controller.employeeModel.value.id == null ? "Add Employee Man".tr : "Edit Employee Man".tr,
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
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFieldWidget(
                                  title: 'First Name'.tr,
                                  controller: controller.firstNameEditingController.value,
                                  hintText: 'Enter First Name'.tr,
                                  prefix: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset("assets/icons/ic_user.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                  ),
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
                                    child: SvgPicture.asset("assets/icons/ic_user.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Role".tr,
                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                            ),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<EmployeeRoleModel>(
                              dropdownColor: isDark ? AppThemeData.grey800 : Colors.white,
                              hint: Text(
                                'Select Role'.tr,
                                style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey700 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down),
                              decoration: InputDecoration(
                                errorStyle: const TextStyle(color: Colors.red),
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
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
                              initialValue: controller.selectEmployeeRole.value.title == null || controller.selectEmployeeRole.value.title?.isEmpty == true
                                  ? null
                                  : controller.selectEmployeeRole.value,
                              onChanged: (value) {
                                controller.selectEmployeeRole.value = value!;
                                controller.update();
                              },

                              style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                              items: controller.employeeRolelList.map((employeeRole) {
                                return DropdownMenuItem<EmployeeRoleModel>(value: employeeRole, child: Text(employeeRole.title ?? ''));
                              }).toList(),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextFieldWidget(
                          readOnly: (controller.employeeModel.value.id != null && controller.employeeModel.value.id != ''),
                          title: 'Email Address'.tr,
                          textInputType: TextInputType.emailAddress,
                          controller: controller.emailEditingController.value,
                          hintText: 'Enter Email Address'.tr,
                          enable: true,
                          prefix: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                          ),
                        ),
                        TextFieldWidget(
                          title: 'Phone Number'.tr,
                          controller: controller.phoneNUmberEditingController.value,
                          hintText: 'Enter Phone Number'.tr,
                          enable: true,
                          textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                          prefix: CountryCodePicker(
                            onInit: (value) {
                              controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                              controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                            },
                            enabled: true,
                            onChanged: (value) {
                              controller.countryCodeEditingController.value.text = value.dialCode.toString();
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
                        Visibility(
                          visible: controller.employeeModel.value.id == null,
                          child: Column(
                            children: [
                              TextFieldWidget(
                                title: 'Password'.tr,
                                controller: controller.passwordEditingController.value,
                                hintText: 'Enter Password'.tr,
                                obscureText: controller.passwordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    onTap: () {
                                      controller.passwordVisible.value = !controller.passwordVisible.value;
                                    },
                                    child: controller.passwordVisible.value
                                        ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn))
                                        : SvgPicture.asset("assets/icons/ic_password_close.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                  ),
                                ),
                              ),
                              TextFieldWidget(
                                title: 'Confirm Password'.tr,
                                controller: controller.conformPasswordEditingController.value,
                                hintText: 'Enter Confirm Password'.tr,
                                obscureText: controller.conformPasswordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    onTap: () {
                                      controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                                    },
                                    child: controller.conformPasswordVisible.value
                                        ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn))
                                        : SvgPicture.asset("assets/icons/ic_password_close.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: controller.isLoading.value
              ? null
              : Container(
                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: RoundedButtonFill(
                      title: "Save Details".tr,
                      height: 5.5,
                      color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      fontSizes: 16,
                      onPress: () async {
                        if (controller.firstNameEditingController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter first name".tr);
                        } else if (controller.lastNameEditingController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter last name".tr);
                        } else if (controller.selectEmployeeRole.value.id?.isEmpty == true || controller.selectEmployeeRole.value.id == null) {
                          ShowToastDialog.showToast("Please select the role".tr);
                        } else if (controller.emailEditingController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter valid email".tr);
                        } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter Phone number".tr);
                        } else if (controller.passwordEditingController.value.text.isEmpty && controller.employeeModel.value.id == null) {
                          ShowToastDialog.showToast("Please enter password".tr);
                        } else if (controller.conformPasswordEditingController.value.text.isEmpty && controller.employeeModel.value.id == null) {
                          ShowToastDialog.showToast("Please enter Confirm password".tr);
                        } else if (controller.passwordEditingController.value.text != controller.conformPasswordEditingController.value.text && controller.employeeModel.value.id == null) {
                          ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                        } else {
                          controller.signUpWithEmailAndPassword();
                        }
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}
