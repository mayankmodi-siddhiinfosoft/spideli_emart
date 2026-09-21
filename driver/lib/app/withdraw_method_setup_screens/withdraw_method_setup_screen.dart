import 'package:driver/app/withdraw_method_setup_screens/bank_details_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/withdraw_method_setup_controller.dart';
import 'package:driver/models/withdraw_method_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class WithdrawMethodSetupScreen extends StatelessWidget {
  const WithdrawMethodSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: WithdrawMethodSetupController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            body: controller.isLoading.value
                ? Constant.loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: ShapeDecoration(
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: SvgPicture.asset("assets/icons/ic_building_four.svg"),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Bank Transfer".tr,
                                          style: TextStyle(
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Get.to(const BankDetailsScreen())!.then((value) {
                                            if (value != null && value == true) {
                                              controller.getPaymentSettings();
                                              controller.isBankDetailsAdded.value = true;
                                            }
                                          });
                                        },
                                        child: Container(
                                          decoration: ShapeDecoration(
                                            shape: RoundedRectangleBorder(
                                              side: BorderSide(width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                              borderRadius: BorderRadius.circular(120),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  ),
                                  controller.isBankDetailsAdded.value == false
                                      ? Row(
                                          children: [
                                            Text(
                                              "Your Setup is pending".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                Get.to(const BankDetailsScreen())!.then((value) {
                                                  if (value != null && value == true) {
                                                    controller.getPaymentSettings();
                                                    controller.isBankDetailsAdded.value = true;
                                                  }
                                                });
                                              },
                                              child: Text(
                                                "Setup now".tr,
                                                style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppThemeData.secondary300,
                                                    color: isDark ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Text(
                                              "Setup was done.".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.success400 : AppThemeData.success400,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                          ],
                                        )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: ShapeDecoration(
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset("assets/images/flutterwave.png"),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Flutter wave".tr,
                                          style: TextStyle(
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      controller.withdrawMethodModel.value.flutterWave != null
                                          ? Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return flutterWaveDialog(controller, isDark);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg"),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    controller.withdrawMethodModel.value.flutterWave = null;
                                                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                                                      (value) async {
                                                        ShowToastDialog.showLoader("Please wait.".tr);

                                                        await controller.getPaymentMethod();
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Payment Method remove successfully".tr);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_delete-one.svg"),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                          : const SizedBox()
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  ),
                                  controller.withdrawMethodModel.value.flutterWave == null
                                      ? Row(
                                          children: [
                                            Text(
                                              "Your Setup is pending".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return flutterWaveDialog(controller, isDark);
                                                  },
                                                );
                                              },
                                              child: Text(
                                                "Setup now".tr,
                                                style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppThemeData.secondary300,
                                                    color: isDark ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Text(
                                              "Setup was done.".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.success400 : AppThemeData.success400,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                          ],
                                        )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: ShapeDecoration(
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset("assets/images/paypal.png"),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          "PayPal".tr,
                                          style: TextStyle(
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      controller.withdrawMethodModel.value.paypal != null
                                          ? Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return payPalDialog(controller, isDark);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg"),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    controller.withdrawMethodModel.value.paypal = null;
                                                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                                                      (value) async {
                                                        ShowToastDialog.showLoader("Please wait.".tr);

                                                        await controller.getPaymentMethod();
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Payment Method remove successfully".tr);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_delete-one.svg"),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                          : const SizedBox()
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  ),
                                  controller.withdrawMethodModel.value.paypal == null
                                      ? Row(
                                          children: [
                                            Text(
                                              "Your Setup is pending".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return payPalDialog(controller, isDark);
                                                  },
                                                );
                                              },
                                              child: Text(
                                                "Setup now".tr,
                                                style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppThemeData.secondary300,
                                                    color: isDark ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Text(
                                              "Setup was done.".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.success400 : AppThemeData.success400,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                          ],
                                        )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: ShapeDecoration(
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset("assets/images/razorpay.png"),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          "RazorPay".tr,
                                          style: TextStyle(
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      controller.withdrawMethodModel.value.razorpay != null
                                          ? Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return razorPayDialog(controller, isDark);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg"),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    controller.withdrawMethodModel.value.razorpay = null;
                                                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                                                      (value) async {
                                                        ShowToastDialog.showLoader("Please wait.".tr);

                                                        await controller.getPaymentMethod();
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Payment Method remove successfully".tr);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_delete-one.svg"),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                          : const SizedBox()
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  ),
                                  controller.withdrawMethodModel.value.razorpay == null
                                      ? Row(
                                          children: [
                                            Text(
                                              "Your Setup is pending".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return razorPayDialog(controller, isDark);
                                                  },
                                                );
                                              },
                                              child: Text(
                                                "Setup now".tr,
                                                style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppThemeData.secondary300,
                                                    color: isDark ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Text(
                                              "Setup was done.".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.success400 : AppThemeData.success400,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                          ],
                                        )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: ShapeDecoration(
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset("assets/images/stripe.png"),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Stripe".tr,
                                          style: TextStyle(
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      controller.withdrawMethodModel.value.stripe != null
                                          ? Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return stripeDialog(controller, isDark);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg"),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    controller.withdrawMethodModel.value.stripe = null;
                                                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                                                      (value) async {
                                                        ShowToastDialog.showLoader("Please wait.".tr);

                                                        await controller.getPaymentMethod();
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Payment Method remove successfully".tr);
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: ShapeDecoration(
                                                      shape: RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                        borderRadius: BorderRadius.circular(120),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: SvgPicture.asset("assets/icons/ic_delete-one.svg"),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                          : const SizedBox()
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  ),
                                  controller.withdrawMethodModel.value.stripe == null
                                      ? Row(
                                          children: [
                                            Text(
                                              "Your Setup is pending".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return stripeDialog(controller, isDark);
                                                  },
                                                );
                                              },
                                              child: Text(
                                                "Setup now".tr,
                                                style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppThemeData.secondary300,
                                                    color: isDark ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Text(
                                              "Setup was done.".tr,
                                              style: TextStyle(
                                                  color: isDark ? AppThemeData.success400 : AppThemeData.success400,
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.medium),
                                            ),
                                          ],
                                        )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        });
  }

  Dialog flutterWaveDialog(WithdrawMethodSetupController controller, isDark) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldWidget(
                title: 'Account Number'.tr,
                controller: controller.accountNumberFlutterWave.value,
                hintText: 'Account Number'.tr,
              ),
              TextFieldWidget(
                title: 'Bank Code'.tr,
                controller: controller.bankCodeFlutterWave.value,
                hintText: 'Bank Code'.tr,
              ),
              RoundedButtonFill(
                title: "Save".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                onPress: () async {
                  if (controller.accountNumberFlutterWave.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter account Number".tr);
                  } else if (controller.bankCodeFlutterWave.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter bank code".tr);
                  } else {
                    FlutterWave? flutterWave = controller.withdrawMethodModel.value.flutterWave;
                    if (flutterWave != null) {
                      flutterWave.accountNumber = controller.accountNumberFlutterWave.value.text;
                      flutterWave.bankCode = controller.bankCodeFlutterWave.value.text;
                    } else {
                      flutterWave = FlutterWave(
                          accountNumber: controller.accountNumberFlutterWave.value.text,
                          bankCode: controller.bankCodeFlutterWave.value.text,
                          name: "FlutterWave");
                    }
                    controller.withdrawMethodModel.value.flutterWave = flutterWave;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                      (value) async {
                        ShowToastDialog.showLoader("Please wait.".tr);

                        await controller.getPaymentMethod();
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Payment Method save successfully".tr);
                        Get.back();
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Dialog payPalDialog(WithdrawMethodSetupController controller, isDark) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldWidget(
                title: 'Paypal Email'.tr,
                controller: controller.emailPaypal.value,
                hintText: 'Paypal Email'.tr,
              ),
              RoundedButtonFill(
                title: "Save".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                onPress: () async {
                  if (controller.emailPaypal.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter Paypal email".tr);
                  } else {
                    Paypal? payPal = controller.withdrawMethodModel.value.paypal;
                    if (payPal != null) {
                      payPal.email = controller.emailPaypal.value.text;
                    } else {
                      payPal = Paypal(email: controller.emailPaypal.value.text, name: "PayPal");
                    }
                    controller.withdrawMethodModel.value.paypal = payPal;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                      (value) async {
                        ShowToastDialog.showLoader("Please wait.".tr);

                        await controller.getPaymentMethod();
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Payment Method save successfully".tr);
                        Get.back();
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Dialog razorPayDialog(WithdrawMethodSetupController controller, isDark) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldWidget(
                title: 'Razorpay account Id'.tr,
                controller: controller.accountIdRazorPay.value,
                hintText: 'Razorpay account Id'.tr,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Add your Account ID. For example, acc_GLGeLkU2JUeyDZ".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              RoundedButtonFill(
                title: "Save".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                onPress: () async {
                  if (controller.accountIdRazorPay.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter RazorPay account Id".tr);
                  } else {
                    RazorpayModel? razorPay = controller.withdrawMethodModel.value.razorpay;
                    if (razorPay != null) {
                      razorPay.accountId = controller.accountIdRazorPay.value.text;
                    } else {
                      razorPay = RazorpayModel(accountId: controller.accountIdRazorPay.value.text, name: "RazorPay");
                    }
                    controller.withdrawMethodModel.value.razorpay = razorPay;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                      (value) async {
                        ShowToastDialog.showLoader("Please wait.".tr);

                        await controller.getPaymentMethod();
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Payment Method save successfully".tr);
                        Get.back();
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Dialog stripeDialog(WithdrawMethodSetupController controller, isDark) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldWidget(
                title: 'Stripe Account Id'.tr,
                controller: controller.accountIdStripe.value,
                hintText: 'Stripe Account Id'.tr,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Go to your Stripe account settings > Account details > Copy your account ID on the right-hand side. For example, acc_GLGeLkU2JUeyDZ"
                      .tr,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              RoundedButtonFill(
                title: "Save".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                onPress: () async {
                  if (controller.accountIdStripe.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter stripe account Id".tr);
                  } else {
                    Stripe? stripe = controller.withdrawMethodModel.value.stripe;
                    if (stripe != null) {
                      stripe.accountId = controller.accountIdStripe.value.text;
                    } else {
                      stripe = Stripe(accountId: controller.accountIdStripe.value.text, name: "Stripe");
                    }
                    controller.withdrawMethodModel.value.stripe = stripe;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
                      (value) async {
                        ShowToastDialog.showLoader("Please wait.".tr);

                        await controller.getPaymentMethod();
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Payment Method save successfully".tr);
                        Get.back();
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
