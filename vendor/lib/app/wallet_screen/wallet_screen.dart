import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vendor/app/wallet_screen/wallet_tabs.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/wallet_controller.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: WalletController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              "Wallet".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Container(
                        width: Responsive.width(100, context),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          image: DecorationImage(image: AssetImage("assets/images/wallet.png"), fit: BoxFit.fill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Column(
                            children: [
                              Text(
                                "Total Wallet amount".tr,
                                maxLines: 1,
                                style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey900, fontSize: 16, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.regular),
                              ),
                              Text(
                                Constant.amountShow(amount: controller.storeBalance.toString()),
                                maxLines: 1,
                                style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey900, fontSize: 22, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.bold),
                              ),
                              const Divider(color: AppThemeData.grey600),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          "Order Amount".tr,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey900,
                                            fontSize: 14,
                                            overflow: TextOverflow.ellipsis,
                                            fontFamily: AppThemeData.regular,
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(amount: controller.orderAmount.value.toString()),
                                          maxLines: 1,
                                          style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey900, fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          "Total Tax.".tr,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey900,
                                            fontSize: 14,
                                            overflow: TextOverflow.ellipsis,
                                            fontFamily: AppThemeData.regular,
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(amount: controller.taxAmount.value.toString()),
                                          maxLines: 1,
                                          style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey900, fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  (controller.userModel.value.isDocumentVerify == false && controller.userModel.value.isAutoVerify == false) ||
                                          (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                                      ? const SizedBox()
                                      : Expanded(
                                          child: RoundedButtonFill(
                                            title: "Withdraw".tr,
                                            width: 24,
                                            height: 5,
                                            fontSizes: 14,
                                            color: AppThemeData.primary300,
                                            textColor: AppThemeData.grey50,
                                            onPress: () {
                                              if ((Constant.userModel!.userBankDetails != null && Constant.userModel!.userBankDetails!.accountNumber.isNotEmpty) ||
                                                  controller.withdrawMethodModel.value.id != null) {
                                                withdrawalCardBottomSheet(context, controller);
                                              } else {
                                                ShowToastDialog.showToast("Please setup payment method".tr);
                                              }
                                            },
                                          ),
                                        ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: RoundedButtonFill(
                                      title: "Download Statement".tr,
                                      height: 5,
                                      fontSizes: 14,
                                      color: AppThemeData.success500,
                                      textColor: AppThemeData.grey50,
                                      onPress: () {
                                        controller.createAndSavePdf();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: InkWell(
                                      onTap: () {
                                        datePicker(context, controller);
                                      },
                                      child: const Icon(Icons.filter_alt, size: 32),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: DefaultTabController(
                        length: 3,
                        initialIndex: controller.selectedTabIndex.value,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TabBar(
                                onTap: (value) {
                                  controller.selectedTabIndex.value = value;
                                },
                                padding: EdgeInsets.zero,
                                labelStyle: const TextStyle(fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                labelColor: AppThemeData.primary300,
                                unselectedLabelStyle: const TextStyle(fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                unselectedLabelColor: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                indicatorColor: AppThemeData.primary300,
                                tabs: [
                                  Tab(text: "Earnings".tr),
                                  Tab(text: "Commissions".tr),
                                  Tab(text: "Payouts".tr),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  WalletEarningsTab(controller: controller, isDark: isDark),
                                  WalletCommissionsTab(controller: controller, isDark: isDark),
                                  WalletPayoutsTab(controller: controller, isDark: isDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future datePicker(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 440, // Height of the bottom sheet
          color: AppThemeData.grey50,
          child: Column(
            children: [
              SfDateRangePicker(
                backgroundColor: AppThemeData.grey50,
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  // Store the selected date range
                  if (args.value is PickerDateRange) {
                    controller.startDate.value = args.value.startDate;
                    controller.endDate.value = args.value.endDate;
                  }
                },
                selectionMode: DateRangePickerSelectionMode.range,
                maxDate: DateTime.now(),
                initialSelectedRange: PickerDateRange(controller.startDate.value, controller.endDate.value),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RoundedButtonFill(
                  title: "Filter".tr,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
                    Get.back();
                    await controller.getWalletTransaction(true);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RoundedButtonFill(
                  title: "Clear".tr,
                  color: AppThemeData.grey50,
                  textColor: AppThemeData.primary300,
                  onPress: () async {
                    Get.back();
                    await controller.getWalletTransaction(false);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future withdrawalCardBottomSheet(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: StatefulBuilder(
          builder: (context1, setState) {
            final themeController = Get.find<ThemeController>();
            final isDark = themeController.isDark.value;
            return Obx(
              () => Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Withdrawal".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 18, fontFamily: AppThemeData.semiBold),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Get.back();
                                },
                                child: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        TextFieldWidget(
                          title: 'Withdrawal amount'.tr,
                          controller: controller.amountTextFieldController.value,
                          hintText: 'Enter withdrawal amount'.tr,
                          textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                          prefix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Text(
                              "${Constant.currencyModel!.symbol}".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                            ),
                          ),
                        ),
                        TextFieldWidget(title: 'Notes'.tr, controller: controller.noteTextFieldController.value, hintText: 'Add Notes'.tr),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            "Select Withdraw Method".tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontFamily: AppThemeData.medium),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(20)), color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              children: [
                                Constant.userModel!.userBankDetails == null || Constant.userModel!.userBankDetails!.accountNumber.isEmpty
                                    ? const SizedBox()
                                    : InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 0;
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_building_four.svg")),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Bank Transfer".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                            Radio(
                                              value: 0,
                                              groupValue: controller.selectedValue.value,
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                controller.selectedValue.value = value!;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 10),
                                controller.withdrawMethodModel.value.flutterWave == null || (controller.flutterWaveSettingData.value.isWithdrawEnabled == false)
                                    ? const SizedBox()
                                    : InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 1;
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: Image.asset("assets/images/flutterwave.png")),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Flutter wave".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                            Radio(
                                              value: 1,
                                              groupValue: controller.selectedValue.value,
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                controller.selectedValue.value = value!;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 10),
                                controller.withdrawMethodModel.value.paypal == null || (controller.paypalDataModel.value.isWithdrawEnabled == false)
                                    ? const SizedBox()
                                    : InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 2;
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: Image.asset("assets/images/paypal.png")),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "PayPal".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                            Radio(
                                              value: 2,
                                              groupValue: controller.selectedValue.value,
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                controller.selectedValue.value = value!;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 10),
                                controller.withdrawMethodModel.value.razorpay == null || (controller.razorPayModel.value.isWithdrawEnabled == false)
                                    ? const SizedBox()
                                    : InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 3;
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: Image.asset("assets/images/razorpay.png")),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "RazorPay".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                            Radio(
                                              value: 3,
                                              groupValue: controller.selectedValue.value,
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                controller.selectedValue.value = value!;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 10),
                                controller.withdrawMethodModel.value.stripe == null || (controller.stripeSettingData.value.isWithdrawEnabled == false)
                                    ? const SizedBox()
                                    : InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 4;
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: Image.asset("assets/images/stripe.png")),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Stripe".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                              ),
                                            ),
                                            Radio(
                                              value: 4,
                                              groupValue: controller.selectedValue.value,
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                controller.selectedValue.value = value!;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
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
                      title: "Withdraw".tr,
                      height: 5.5,
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      fontSizes: 16,
                      onPress: () async {
                        if (controller.amountTextFieldController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter amount".tr);
                        } else if (controller.noteTextFieldController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter note".tr);
                        } else if ((double.tryParse(controller.amountTextFieldController.value.text) ?? 0) <= 0) {
                          ShowToastDialog.showToast("Please enter a valid amount".tr);
                        } else if (controller.storeBalance <= 0 ||
                            double.parse(controller.amountTextFieldController.value.text) > controller.storeBalance) {
                          // Withdrawals come out of this store's own balance,
                          // as in the store panel's Payouts screen.
                          ShowToastDialog.showToast("You are not able to place Withdraw request due to insufficient wallet amount".tr);
                        } else {
                          WithdrawalModel withdrawHistory = WithdrawalModel(
                            amount: controller.amountTextFieldController.value.text,
                            vendorID: controller.vendorModel.value.id ?? controller.userModel.value.vendorID,
                            paymentStatus: "Pending",
                            paidDate: Timestamp.now(),
                            id: Constant.getUuid(),
                            note: controller.noteTextFieldController.value.text,
                            withdrawMethod: controller.selectedValue.value == 0
                                ? "bank"
                                : controller.selectedValue.value == 1
                                ? "flutterwave"
                                : controller.selectedValue.value == 2
                                ? "paypal"
                                : controller.selectedValue.value == 3
                                ? "razorpay"
                                : "stripe",
                          );
                          final double withdrawAmount = double.parse(controller.amountTextFieldController.value.text);
                          final String vendorId = controller.vendorModel.value.id ?? controller.userModel.value.vendorID ?? '';
                          final String ownerId = controller.vendorModel.value.author ?? FireStoreUtils.getCurrentUid();
                          ShowToastDialog.showLoader("Please wait".tr);
                          // Debit first, with the balance re-checked inside the
                          // transaction, so a double tap or a second device
                          // can't withdraw the same money twice.
                          try {
                            final num? debited = await FireStoreUtils.adjustVendorWallet(
                              amount: -withdrawAmount,
                              vendorId: vendorId,
                              ownerId: ownerId,
                              requireStoreFunds: true,
                            );
                            if (debited == null) {
                              ShowToastDialog.closeLoader();
                              ShowToastDialog.showToast("Could not place withdraw request. Please try again.".tr);
                              return;
                            }
                          } on InsufficientStoreFunds {
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast("You are not able to place Withdraw request due to insufficient wallet amount".tr);
                            return;
                          }
                          final bool created = await FireStoreUtils.withdrawWalletAmount(withdrawHistory);
                          if (!created) {
                            // Put the money back rather than leave a debit with no payout request.
                            await FireStoreUtils.adjustVendorWallet(amount: withdrawAmount, vendorId: vendorId, ownerId: ownerId);
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast("Could not place withdraw request. Please try again.".tr);
                            return;
                          }
                          ShowToastDialog.closeLoader();
                          Get.back();
                          FireStoreUtils.sendPayoutMail(amount: controller.amountTextFieldController.value.text, payoutrequestid: withdrawHistory.id.toString());
                          controller.getWalletTransaction(false);
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
