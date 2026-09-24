import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/gift_card_controller.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themes/show_toast_dialog.dart';
import '../wallet_screen/wallet_screen.dart';

/// Archetype C — payment step. The wallet is promoted to its own card with the
/// live balance; every other gateway is a selectable row with a radio.
class SelectGiftPaymentScreen extends StatelessWidget {
  const SelectGiftPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: GiftCardController(),
      builder: (controller) {
        final bool walletEnabled = controller.walletSettingModel.value.isEnabled == true;
        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(title: "Payment Option".tr),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Pay Now".tr,
              icon: Icons.lock_outline_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                  controller.stripeMakePayment(amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                  controller.paypalPaymentSheet(controller.amountController.value.text, context);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                  controller.payStackPayment(controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                  controller.mercadoPagoMakePayment(context: context, amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                  controller.flutterWaveInitiatePayment(context: context, amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                  controller.payFastPayment(context: context, amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                  controller.midtransMakePayment(context: context, amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                  controller.orangeMakePayment(context: context, amount: controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                  controller.xenditPayment(context, controller.amountController.value.text);
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                  controller.placeOrder();
                } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                  RazorPayController().createOrderRazorPay(amount: double.parse(controller.amountController.value.text), razorpayModel: controller.razorPayModel.value).then((value) {
                    if (value == null) {
                      Get.back();
                      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                    } else {
                      CreateRazorPayOrderModel result = value;
                      controller.openCheckout(amount: controller.amountController.value.text, orderId: result.id);
                    }
                  });
                } else {
                  ShowToastDialog.showToast("Please select payment method".tr);
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: DsFadeSlideIn.stagger([
                DsSectionHeader(title: "Preferred Payment".tr, padding: EdgeInsets.zero),
                const DsGap(DsSpace.sm),
                if (walletEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                        child: Visibility(
                          visible: controller.walletSettingModel.value.isEnabled == true,
                          child: cardDecoration(context, controller, PaymentGateway.wallet, "assets/images/ic_wallet.png"),
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      DsSectionHeader(title: "Other Payment Options".tr, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.sm),
                    ],
                  ),
                DsCard(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                  child: Column(
                    children: [
                      Visibility(visible: controller.flutterWaveModel.value.isEnable == true, child: cardDecoration(context, controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                      Visibility(visible: controller.paytmModel.value.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                      Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(context, controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                      Visibility(
                        visible: controller.mercadoPagoModel.value.isEnabled == true,
                        child: cardDecoration(context, controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png"),
                      ),
                      Visibility(
                        visible: controller.flutterWaveModel.value.isEnable == true,
                        child: cardDecoration(context, controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png"),
                      ),
                      Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(context, controller, PaymentGateway.payFast, "assets/images/payfast.png")),
                      Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.razorpay, "assets/images/razorpay.png")),
                      Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(context, controller, PaymentGateway.midTrans, "assets/images/midtrans.png")),
                      Visibility(
                        visible: controller.orangeMoneyModel.value.enable == true,
                        child: cardDecoration(context, controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png"),
                      ),
                      Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(context, controller, PaymentGateway.xendit, "assets/images/xendit.png")),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// One gateway row. The selection is observable and this widget is built
  /// lazily inside `Visibility`, so it keeps its own `Obx`.
  Obx cardDecoration(BuildContext context, GiftCardController controller, PaymentGateway value, String image) {
    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      final bool selected = controller.selectedPaymentMethod.value == value.name;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
        child: DsPressable(
          onTap: () {
            controller.selectedPaymentMethod.value = value.name;
          },
          child: AnimatedContainer(
            duration: DsMotion.of(context, DsMotion.fast),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
            decoration: BoxDecoration(
              color: selected ? c.brandSoft : Colors.transparent,
              borderRadius: DsRadius.brMd,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                  child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
                ),
                const DsGap(DsSpace.md),
                value.name == "wallet"
                    ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(value.name.capitalizeString(), style: t.bodyLg),
                            Text(
                              Constant.amountShow(
                                amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString(),
                                currency: RegionService.customerCurrency,
                              ),
                              style: t.titleSm.tabular.withColor(c.brandStrong),
                            ),
                          ],
                        ),
                      )
                    : Expanded(child: Text(value.name.capitalizeString(), style: t.bodyLg)),
                Radio(
                  value: value.name,
                  groupValue: controller.selectedPaymentMethod.value,
                  onChanged: (value) {
                    controller.selectedPaymentMethod.value = value.toString();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
