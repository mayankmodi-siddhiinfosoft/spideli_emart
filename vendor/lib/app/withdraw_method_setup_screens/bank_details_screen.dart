import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/controller/bank_details_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';

class BankDetailsScreen extends StatelessWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: BankDetailsController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, size: 20),
            title: Text(
              "Bank Setup".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFieldWidget(title: 'Bank Name'.tr, controller: controller.bankNameController.value, hintText: 'Enter Bank Name'.tr),
                  TextFieldWidget(title: 'Branch Name'.tr, controller: controller.branchNameController.value, hintText: 'Enter Branch Name'.tr),
                  TextFieldWidget(title: 'Holder Name'.tr, controller: controller.holderNameController.value, hintText: 'Enter Holder Name'.tr),
                  TextFieldWidget(title: 'Account Number'.tr, controller: controller.accountNoController.value, hintText: 'Enter Account Number'.tr),
                  TextFieldWidget(title: 'Other Information'.tr, controller: controller.otherInfoController.value, hintText: 'Enter Other Information'.tr),
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
                title: "Add Bank".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  controller.saveBank();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
