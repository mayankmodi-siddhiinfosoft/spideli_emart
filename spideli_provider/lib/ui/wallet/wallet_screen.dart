import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/wallet_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/topupTranHistory.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/wallet/withdraw_history.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<WalletController>(
        init: WalletController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)), image: DecorationImage(fit: BoxFit.fitWidth, image: AssetImage("assets/images/wallet_img_@3x.png"))),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 15,
                            ),
                            Text(
                              "Total Balance".tr,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: controller.userQuery,
                                builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> asyncSnapshot) {
                                  if (asyncSnapshot.hasError) {
                                    return Text(
                                      "Error".tr,
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
                                    );
                                  }
                                  if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                                    return Center(
                                        child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 0.8,
                                              color: Colors.white,
                                              backgroundColor: Colors.transparent,
                                            )));
                                  }
                                  User userData = User.fromJson(asyncSnapshot.data!.data()!);
                                  controller.walletAmount.value = userData.walletAmount.toString();
                                  return Text(
                                    "${amountShow(amount: userData.walletAmount.toString())}",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: showTopUpHistory(context, controller),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: MaterialButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      color: AppColors.colorPrimary,
                      height: 45,
                      onPressed: () {
                        if (MyAppState.currentUser!.id.isNotEmpty) {
                          if (MyAppState.currentUser!.userBankDetails.accountNumber.isNotEmpty ||
                              (controller.withdrawMethodModel.value.id != null &&
                                  (controller.withdrawMethodModel.value.flutterWave != null ||
                                      controller.withdrawMethodModel.value.paypal != null ||
                                      controller.withdrawMethodModel.value.razorpay != null ||
                                      controller.withdrawMethodModel.value.stripe != null))) {
                            withdrawAmount(context, controller);
                          } else {
                            ShowToastDialog.showToast("Please add payment method");
                          }
                        }
                      },
                      child: Text(
                        'WITHDRAW'.tr,
                        style: TextStyle(fontSize: 19, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: MaterialButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      color: AppColors.colorPrimary,
                      height: 45,
                      onPressed: () {
                        Get.to(WithdrawHistoryScreen());
                      },
                      child: Text(
                        'HISTORY',
                        style: TextStyle(fontSize: 19, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  Widget showTopUpHistory(BuildContext context, controller) {
    return controller.topupHistoryQuery.isEmpty
        ? Center(child: Text("No transaction found".tr))
        : ListView.builder(
            itemCount: controller.topupHistoryQuery.length,
            itemBuilder: (context, index) {
              TopupTranHistoryModel topUpTranHistory = controller.topupHistoryQuery[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: GestureDetector(
                  onTap: () => showTransactionDetails(topupTranHistory: topUpTranHistory, context: context, currency: controller.currencyForRow(topUpTranHistory)),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: Container(
                              color: AppColors.colorPrimary.withOpacity(0.06),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Icon(Icons.account_balance_wallet_rounded, size: 28, color: AppColors.colorPrimary),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        topUpTranHistory.note.toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Opacity(
                                        opacity: 0.65,
                                        child: Text(
                                          "${DateFormat('KK:mm:ss a, dd MMM yyyy').format(topUpTranHistory.date.toDate()).toUpperCase()}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0, left: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        topUpTranHistory.isTopup
                                            ? "${"+"} ${amountShow(currency: controller.currencyForRow(topUpTranHistory), amount: topUpTranHistory.amount.toString())}"
                                            : "(${"-"} ${amountShow(currency: controller.currencyForRow(topUpTranHistory), amount: topUpTranHistory.amount.toString())})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: topUpTranHistory.isTopup ? Colors.green : Colors.red,
                                          fontSize: 18,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 8,
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 15,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            });
  }

  buildButton(context, {required String title, required Function()? onPress}) {
    return SizedBox(
      width: Responsive.width(70, context),
      child: MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        color: AppColors.colorPrimary,
        height: 45,
        onPressed: onPress,
        child: Text(
          title,
          style: TextStyle(fontSize: 19, color: Colors.white),
        ),
      ),
    );
  }

  showTransactionDetails({required TopupTranHistoryModel topupTranHistory, required BuildContext context, CurrencyModel? currency}) {
    return showModalBottomSheet(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))),
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 25.0),
                  child: Text(
                    "Transaction Details".tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15.0,
                  ),
                  child: Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Transaction ID".tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Opacity(
                                opacity: 0.8,
                                child: Text(
                                  topupTranHistory.id,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 30),
                    child: Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipOval(
                              child: Container(
                                color: AppColors.colorPrimary.withOpacity(0.05),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(Icons.account_balance_wallet_rounded, size: 28, color: AppColors.colorPrimary),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: Responsive.width(50, context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${DateFormat('KK:mm:ss a, dd MMM yyyy').format(topupTranHistory.date.toDate())}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Opacity(
                                    opacity: 0.7,
                                    child: Text(
                                      topupTranHistory.isTopup ? "Order Amount".tr : "Admin commission Deducted".tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  topupTranHistory.isTopup ? "${"+"} ${amountShow(currency: currency, amount: topupTranHistory.amount.toString())}" : "(${"-"} ${amountShow(currency: currency, amount: topupTranHistory.amount.toString())})",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: topupTranHistory.isTopup ? Colors.green : Colors.red,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Date in UTC Format".tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Opacity(
                                      opacity: 0.7,
                                      child: Text(
                                        "${DateFormat('KK:mm:ss a, dd MMM yyyy').format(topupTranHistory.date.toDate()).toUpperCase()}",
                                        style: TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            // await FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(topupTranHistory.orderId).get().then((value) {
                            //   OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(value.data()!);
                            //
                            // });
                            Get.to(const BookingDetailsScreen(), arguments: {
                              "orderId": topupTranHistory.orderId,
                            });
                          },
                          child: Text(
                            "View Booking".tr.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.colorPrimary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                )
              ],
            );
          });
        });
  }

  withdrawAmount(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final themeChange = Provider.of<DarkThemeProvider>(context);
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 5),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 25.0, bottom: 10),
                      child: Text(
                        "Withdraw".tr,
                        style: TextStyle(
                          fontSize: 18,
                          color: themeChange.getTheme() ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Obx(
                          () => Column(
                            children: [
                              MyAppState.currentUser!.userBankDetails.accountNumber.isEmpty
                                  ? SizedBox()
                                  : Card(
                                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // if you need this
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 0;
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/ic_bank_line.png",
                                                      height: 20,
                                                    ),
                                                    SizedBox(
                                                      width: 10,
                                                    ),
                                                    Text(
                                                      "Bank Transfer",
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.black, fontSize: 16),
                                                    )
                                                  ],
                                                ),
                                                Radio(
                                                  value: 0,
                                                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                                  groupValue: controller.selectedValue.value,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      controller.selectedValue.value = 0;
                                                    });
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              controller.withdrawMethodModel.value.id == null ||
                                      controller.withdrawMethodModel.value.flutterWave == null ||
                                      (controller.flutterWaveSettingData.value.isWithdrawEnabled != null && controller.flutterWaveSettingData.value.isWithdrawEnabled == false)
                                  ? SizedBox()
                                  : Card(
                                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // if you need this
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 1;
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Image.asset(
                                                  "assets/images/flutterwave.png",
                                                  height: 20,
                                                ),
                                                Radio(
                                                  value: 1,
                                                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                                  groupValue: controller.selectedValue.value,
                                                  onChanged: (value) {
                                                    controller.selectedValue.value = 1;
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              controller.withdrawMethodModel.value.id == null ||
                                      controller.withdrawMethodModel.value.paypal == null ||
                                      (controller.paypalDataModel.value.isWithdrawEnabled != null && controller.paypalDataModel.value.isWithdrawEnabled == false)
                                  ? SizedBox()
                                  : Card(
                                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // if you need this
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          controller.selectedValue.value = 2;
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Image.asset(
                                                  "assets/images/paypal.png",
                                                  height: 20,
                                                ),
                                                Radio(
                                                  value: 2,
                                                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                                  groupValue: controller.selectedValue.value,
                                                  onChanged: (value) {
                                                    controller.selectedValue.value = 2;
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              controller.withdrawMethodModel.value.id == null ||
                                      controller.withdrawMethodModel.value.razorpay == null ||
                                      (controller.razorPayModel.value.isWithdrawEnabled != null && controller.razorPayModel.value.isWithdrawEnabled == false)
                                  ? SizedBox()
                                  : Card(
                                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // if you need this
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                                        child: InkWell(
                                          onTap: () {
                                            controller.selectedValue.value = 3;
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Image.asset(
                                                  "assets/images/razorpay.png",
                                                  height: 20,
                                                ),
                                                Radio(
                                                  value: 3,
                                                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                                  groupValue: controller.selectedValue.value,
                                                  onChanged: (value) {
                                                    controller.selectedValue.value = 3;
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              controller.withdrawMethodModel.value.id == null ||
                                      controller.withdrawMethodModel.value.stripe == null ||
                                      (controller.stripeSettingData.value.isWithdrawEnabled != null && controller.stripeSettingData.value.isWithdrawEnabled == false)
                                  ? SizedBox()
                                  : Card(
                                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // if you need this
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                                        child: InkWell(
                                          onTap: () {
                                            controller.selectedValue.value = 4;
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Image.asset(
                                                  "assets/images/stripe.png",
                                                  height: 20,
                                                ),
                                                Radio(
                                                  value: 4,
                                                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                                  groupValue: controller.selectedValue.value,
                                                  onChanged: (value) {
                                                    controller.selectedValue.value = 4;
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        )),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                          child: RichText(
                            text: TextSpan(
                              text: "Amount to Withdraw".tr,
                              style: TextStyle(
                                fontSize: 16,
                                color: themeChange.getTheme() ? Colors.white70 : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
                      child: TextFormField(
                        controller: controller.amountController.value,
                        style: TextStyle(
                          color: AppColors.colorPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        //initialValue:"50",
                        maxLines: 1,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return "*required Field".tr;
                          } else {
                            if (double.parse(value) <= 0) {
                              return "*Invalid Amount".tr;
                            } else if (double.parse(value) > double.parse(controller.walletAmount.toString())) {
                              return "*withdraw is more then wallet balance".tr;
                            } else {
                              return null;
                            }
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 2),
                          prefix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
                            child: Text(
                              currencyData!.symbol.toString(),
                              style: TextStyle(
                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          fillColor: Colors.grey[200],
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 1.50)),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: TextFormField(
                        controller: controller.noteController.value,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return "*required Field".tr;
                          }
                          return null;
                        },
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'Add note'.tr,
                          contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                          fillColor: Colors.grey[200],
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 1.50)),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: buildButton(context, title: "WITHDRAW".tr, onPress: () {
                        if (controller.amountController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter amount");
                        } else {
                          withdrawRequest(controller);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }

  withdrawRequest(WalletController controller) {
    Get.back();
    ShowToastDialog.showLoader("Please wait");

    FireStoreUtils.createPaymentId(collectionName: PAYOUTS).then((value) async {
      final paymentID = value;

      WithdrawHistoryModel withdrawHistory = WithdrawHistoryModel(
        amount: double.parse(controller.amountController.value.text.toString()),
        vendorID: controller.userId.value.toString(),
        paymentStatus: "Pending".tr,
        paidDate: Timestamp.now(),
        id: paymentID.toString(),
        note: controller.noteController.value.text,
        role: "provider",
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

      print(withdrawHistory.vendorID);

      await FireStoreUtils.withdrawWalletAmount(withdrawHistory: withdrawHistory).then((value) async {
        await FireStoreUtils.updateWalletAmount(userId: controller.userId.value.toString(), amount: -double.parse(controller.amountController.value.text)).whenComplete(() async {
          Get.back();
          controller.getData();
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("WithDraw request place successfully");
          await FireStoreUtils.sendPayoutMail(amount: controller.amountController.value.text, payoutrequestid: paymentID.toString());
        });
      });
    });
  }
}
