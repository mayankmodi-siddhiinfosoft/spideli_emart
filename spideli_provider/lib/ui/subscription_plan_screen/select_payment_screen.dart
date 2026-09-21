import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/subscription_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/payment/createRazorPayOrderModel.dart';
import 'package:spideliprovider/payment/rozorpayConroller.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/round_button_fill.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class SelectPaymentScreen extends StatelessWidget {
  const SelectPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              "Payment Option",
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: AppThemeData.medium,
                fontSize: 16,
                color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
              ),
            ),
          ),
          body: controller.isLoading.value
              ? loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Preferred Payment",
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: AppThemeData.semiBold,
                            fontSize: 16,
                            color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        if (controller.walletSettingModel.value?.isEnabled == true)
                          Container(
                            decoration: ShapeDecoration(
                              color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadows: const [
                                BoxShadow(
                                  color: Color(0x07000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 0),
                                  spreadRadius: 0,
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Visibility(
                                    visible: controller.walletSettingModel.value?.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.wallet, themeChange, "assets/images/walltet_icons.png"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (controller.walletSettingModel.value?.isEnabled == true)
                          Column(
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                "Other Payment Options",
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontFamily: AppThemeData.semiBold,
                                  fontSize: 16,
                                  color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        Container(
                          decoration: ShapeDecoration(
                            color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadows: const [
                              BoxShadow(
                                color: Color(0x07000000),
                                blurRadius: 20,
                                offset: Offset(0, 0),
                                spreadRadius: 0,
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Visibility(
                                  visible: controller.stripeModel.value?.isEnabled == true,
                                  child: cardDecoration(controller, PaymentGateway.stripe, themeChange, "assets/images/stripe.png"),
                                ),
                                Visibility(
                                  visible: controller.payPalModel.value?.isEnabled == true,
                                  child: cardDecoration(controller, PaymentGateway.paypal, themeChange, "assets/images/paypal.png"),
                                ),
                                Visibility(
                                  visible: controller.payStackModel.value?.isEnable == true,
                                  child: cardDecoration(controller, PaymentGateway.payStack, themeChange, "assets/images/paystack.png"),
                                ),
                                Visibility(
                                  visible: controller.mercadoPagoModel.value?.isEnabled == true,
                                  child: cardDecoration(controller, PaymentGateway.mercadoPago, themeChange, "assets/images/mercado-pago.png"),
                                ),
                                Visibility(
                                  visible: controller.flutterWaveModel.value?.isEnable == true,
                                  child: cardDecoration(controller, PaymentGateway.flutterWave, themeChange, "assets/images/flutterwave_logo.png"),
                                ),
                                Visibility(
                                  visible: controller.payFastModel.value?.isEnable == true,
                                  child: cardDecoration(controller, PaymentGateway.payFast, themeChange, "assets/images/payfast.png"),
                                ),
                                Visibility(
                                  visible: controller.razorPayModel.value?.isEnabled == true,
                                  child: cardDecoration(controller, PaymentGateway.razorpay, themeChange, "assets/images/razorpay.png"),
                                ),
                                Visibility(
                                  visible: controller.midTransModel.value?.enable == true,
                                  child: cardDecoration(controller, PaymentGateway.midTrans, themeChange, "assets/images/midtrans.png"),
                                ),
                                Visibility(
                                  visible: controller.orangeMoneyModel.value?.enable == true,
                                  child: cardDecoration(controller, PaymentGateway.orangeMoney, themeChange, "assets/images/orange_money.png"),
                                ),
                                Visibility(
                                  visible: controller.xenditModel.value?.enable == true,
                                  child: cardDecoration(controller, PaymentGateway.xendit, themeChange, "assets/images/xendit.png"),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
                color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Pay Now | ${amountShow(amount: controller.totalAmount.value.toString())}".tr,
                height: 5,
                color: themeChange.getTheme() ? AppThemeData.secondary300 : AppThemeData.secondary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  if (controller.selectedPaymentMethod.value == '') {
                    ShowToastDialog.showToast("Please Select Payment Method.");
                  } else {
                    if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                      controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                      controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                      controller.payStackPayment(controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                      controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                      controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                      controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.paytm.name) {
                      controller.getPaytmCheckSum(context, amount: double.parse(controller.totalAmount.value.toString()));
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                      if ((controller.userModel.value.walletAmount) >= controller.totalAmount.value) {
                        controller.setOrder();
                      } else {
                        ShowToastDialog.showToast("You don't have sufficient wallet balance to purchase the subscription plan");
                      }
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                      controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                      controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                      controller.xenditPayment(context, controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                      
                      RazorPayController()
                          .createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()).toInt(), razorpayModel: controller.razorPayModel.value)
                          .then((value) {
                        if (value == null) {
                          Get.back();
                          ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                        } else {
                          CreateRazorPayOrderModel result = value;
                          controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                        }
                      });
                    } else {
                      ShowToastDialog.showToast("Please select payment method".tr);
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  cardDecoration(SubscriptionController controller, PaymentGateway value, themeChange, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0),
                      child: Image.asset(
                        image,
                        color: value.name == "wallet" ? AppThemeData.secondary300 : null,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  value == PaymentGateway.wallet
                      ? Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value.name.capitalizeString(),
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontFamily: AppThemeData.medium,
                                  fontSize: 16,
                                  color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                                ),
                              ),
                              Text(
                                amountShow(
                                    amount: MyAppState.currentUser?.walletAmount == null || MyAppState.currentUser?.walletAmount == 0
                                        ? '0.0'
                                        : MyAppState.currentUser?.walletAmount.toString()),
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontFamily: AppThemeData.semiBold,
                                  fontSize: 16,
                                  color: AppThemeData.secondary300,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Expanded(
                          child: Text(
                            value.name.capitalizeString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.medium,
                              fontSize: 16,
                              color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                            ),
                          ),
                        ),
                  const Expanded(
                    child: SizedBox(),
                  ),
                  Radio(
                    value: value.name,
                    groupValue: controller.selectedPaymentMethod.value,
                    activeColor: AppThemeData.secondary300,
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value.toString();
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
