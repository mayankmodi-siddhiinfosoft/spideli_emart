import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/subscription_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/payment/createRazorPayOrderModel.dart';
import 'package:spideliprovider/payment/rozorpayConroller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Payment option (archetype J – payment). The wallet is promoted to its own
/// balance card above the gateway list; every gateway is a selectable row with
/// its logo, and the total rides in a sticky pay bar.
class SelectPaymentScreen extends StatelessWidget {
  const SelectPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<SubscriptionController>(
      init: SubscriptionController(),
      builder: (controller) {
        final bool walletEnabled = controller.walletSettingModel.value?.isEnabled == true;
        return DsScaffold(
          title: "Payment Option",
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
              child: DsSkeletonList(itemCount: 6, trailing: false),
            ),
            builder: (context) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  if (walletEnabled) ...[
                    DsSectionHeader(title: "Preferred Payment", icon: Icons.account_balance_wallet_outlined),
                    Visibility(visible: walletEnabled, child: cardDecoration(context, controller, PaymentGateway.wallet, "assets/images/walltet_icons.png")),
                    DsSectionHeader(title: "Other Payment Options", icon: Icons.credit_card_outlined),
                  ] else
                    DsSectionHeader(title: "Preferred Payment", icon: Icons.credit_card_outlined),
                  DsCard(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
                    child: Column(
                      children: [
                        Visibility(visible: controller.stripeModel.value?.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                        Visibility(visible: controller.payPalModel.value?.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                        Visibility(visible: controller.payStackModel.value?.isEnable == true, child: cardDecoration(context, controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                        Visibility(
                          visible: controller.mercadoPagoModel.value?.isEnabled == true,
                          child: cardDecoration(context, controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png"),
                        ),
                        Visibility(
                          visible: controller.flutterWaveModel.value?.isEnable == true,
                          child: cardDecoration(context, controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png"),
                        ),
                        Visibility(visible: controller.payFastModel.value?.isEnable == true, child: cardDecoration(context, controller, PaymentGateway.payFast, "assets/images/payfast.png")),
                        Visibility(visible: controller.razorPayModel.value?.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.razorpay, "assets/images/razorpay.png")),
                        Visibility(visible: controller.midTransModel.value?.enable == true, child: cardDecoration(context, controller, PaymentGateway.midTrans, "assets/images/midtrans.png")),
                        Visibility(
                          visible: controller.orangeMoneyModel.value?.enable == true,
                          child: cardDecoration(context, controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png"),
                        ),
                        Visibility(visible: controller.xenditModel.value?.enable == true, child: cardDecoration(context, controller, PaymentGateway.xendit, "assets/images/xendit.png")),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Pay Now | ${amountShow(amount: controller.totalAmount.value.toString())}".tr,
              icon: Icons.lock_outline_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
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
                    RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()).toInt(), razorpayModel: controller.razorPayModel.value).then((value) {
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
        );
      },
    );
  }

  /// One selectable gateway row. The `Obx` reads `selectedPaymentMethod`
  /// synchronously (before building the row), so the selection is tracked even
  /// though the row itself is composed further down.
  Widget cardDecoration(BuildContext context, SubscriptionController controller, PaymentGateway value, String image) {
    return Obx(() {
      final bool selected = controller.selectedPaymentMethod.value == value.name;
      final c = context.dsColors;
      final t = context.dsText;
      final bool isWallet = value == PaymentGateway.wallet;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
        child: DsCard.outlined(
          onTap: () {
            controller.selectedPaymentMethod.value = value.name;
          },
          borderColor: selected ? c.brand : null,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: ShapeDecoration(
                  color: c.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 1, color: selected ? c.brand : c.border),
                    borderRadius: DsRadius.brSm,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0),
                  child: Image.asset(image, color: isWallet ? c.brand : null),
                ),
              ),
              const DsGap(DsSpace.md),
              isWallet
                  ? Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                          const DsGap(DsSpace.xxs),
                          Text(
                            amountShow(amount: MyAppState.currentUser?.walletAmount == null || MyAppState.currentUser?.walletAmount == 0 ? '0.0' : MyAppState.currentUser?.walletAmount.toString()),
                            textAlign: TextAlign.start,
                            style: t.titleSm.tabular.withColor(c.brandStrong),
                          ),
                        ],
                      ),
                    )
                  : Expanded(
                      child: Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                    ),
              Radio<String>(
                value: value.name,
                groupValue: controller.selectedPaymentMethod.value,
                onChanged: (value) {
                  controller.selectedPaymentMethod.value = value.toString();
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
