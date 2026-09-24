import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/wallet_controller.dart';
import 'package:driver/payment/create_razor_pay_order_model.dart';
import 'package:driver/payment/rozorpay_conroller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Archetype E – top-up: the amount is the hero, the gateways are a single
/// selectable list, and the minimum deposit is stated before the driver pays.
class PaymentListScreen extends StatelessWidget {
  const PaymentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: WalletController(),
        builder: (controller) {
          final t = context.dsText;
          return DsScaffold(
            title: "Top up Wallet".tr,
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
              child: DsResponsive(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: DsFadeSlideIn.stagger([
                    DsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DsTextField(
                            label: 'Amount'.tr,
                            hint: 'Enter Amount'.tr,
                            controller: controller.topUpAmountController.value,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            prefix: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                              child: Text(
                                Constant.currencyModel!.symbol.toString(),
                                style: t.title.tabular,
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                            ],
                            textInputAction: TextInputAction.done,
                            bottomSpacing: DsSpace.md,
                          ),
                          DsInlineAlert(
                            tone: DsTone.info,
                            icon: Icons.info_outline_rounded,
                            message:
                                "${'Please enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit)}",
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.xl),
                    DsSectionHeader(title: "Payment method".tr),
                    const DsGap(DsSpace.md),
                    DsCard(
                      padding: const EdgeInsets.all(DsSpace.sm),
                      child: Column(
                        children: [
                          Visibility(
                            visible: controller.stripeModel.value.isEnabled == true,
                            child: cardDecoration(controller, PaymentGateway.stripe, "assets/images/stripe.png"),
                          ),
                          Visibility(
                            visible: controller.payPalModel.value.isEnabled == true,
                            child: cardDecoration(controller, PaymentGateway.paypal, "assets/images/paypal.png"),
                          ),
                          Visibility(
                            visible: controller.payStackModel.value.isEnable == true,
                            child: cardDecoration(controller, PaymentGateway.payStack, "assets/images/paystack.png"),
                          ),
                          Visibility(
                            visible: controller.mercadoPagoModel.value.isEnabled == true,
                            child: cardDecoration(controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png"),
                          ),
                          Visibility(
                            visible: controller.flutterWaveModel.value.isEnable == true,
                            child: cardDecoration(controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png"),
                          ),
                          Visibility(
                            visible: controller.payFastModel.value.isEnable == true,
                            child: cardDecoration(controller, PaymentGateway.payFast, "assets/images/payfast.png"),
                          ),
                          Visibility(
                            visible: controller.razorPayModel.value.isEnabled == true,
                            child: cardDecoration(controller, PaymentGateway.razorpay, "assets/images/razorpay.png"),
                          ),
                          Visibility(
                            visible: controller.midTransModel.value.enable == true,
                            child: cardDecoration(controller, PaymentGateway.midTrans, "assets/images/midtrans.png"),
                          ),
                          Visibility(
                            visible: controller.orangeMoneyModel.value.enable == true,
                            child: cardDecoration(controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png"),
                          ),
                          Visibility(
                            visible: controller.xenditModel.value.enable == true,
                            child: cardDecoration(controller, PaymentGateway.xendit, "assets/images/xendit.png"),
                          ),
                        ],
                      ),
                    ),
                  ], offset: const Offset(0, 18)),
                ),
              ),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Top-up".tr,
                icon: Icons.add_card_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  if (controller.topUpAmountController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter amount".tr);
                  } else if ((double.tryParse(controller.topUpAmountController.value.text.trim()) ?? 0) <= 0) {
                    ShowToastDialog.showToast("Please enter amount greater than 0".tr);
                  } else if ((double.tryParse(controller.topUpAmountController.value.text.trim()) ?? 0) < double.parse(Constant.minimumAmountToDeposit.toString())) {
                    ShowToastDialog.showToast(
                      "${'Please enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit)}".tr,
                    );
                  } else {
                    if (double.parse(controller.topUpAmountController.value.text) >= double.parse(Constant.minimumAmountToDeposit.toString())) {
                      if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                        controller.stripeMakePayment(amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                        controller.paypalPaymentSheet(controller.topUpAmountController.value.text, context);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                        controller.payStackPayment(controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                        controller.mercadoPagoMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                        controller.flutterWaveInitiatePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                        controller.payFastPayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                        controller.midtransMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                        controller.orangeMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                        controller.xenditPayment(context, controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                        RazorPayController()
                            .createOrderRazorPay(amount: double.parse(controller.topUpAmountController.value.text), razorpayModel: controller.razorPayModel.value)
                            .then((value) {
                          if (value == null) {
                            Get.back();
                            ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                          } else {
                            CreateRazorPayOrderModel result = value;
                            controller.openCheckout(amount: controller.topUpAmountController.value.text, orderId: result.id);
                          }
                        });
                      } else {
                        ShowToastDialog.showToast("Please select payment method".tr);
                      }
                    } else {
                      ShowToastDialog.showToast("${'Please Enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit)}".tr);
                    }
                  }
                },
              ),
            ),
          );
        });
  }

  Obx cardDecoration(WalletController controller, PaymentGateway value, String image) {
    // The closure reads `selectedPaymentMethod`, so this Obx is a valid
    // observer and rebuilds when the driver picks another gateway.
    return Obx(
      () {
        final selected = controller.selectedPaymentMethod.value == value.name;
        return Builder(builder: (context) {
          final c = DsColors.of(context);
          final t = context.dsText;
          return Padding(
            padding: const EdgeInsets.all(DsSpace.xs),
            child: DsCard.outlined(
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              borderColor: selected ? c.brand : null,
              color: selected ? c.brandSoft : null,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              semanticLabel: value.name,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.all(value.name == "payFast" ? 0 : DsSpace.sm),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: DsRadius.brSm,
                      border: Border.all(color: c.border),
                    ),
                    child: Image.asset(image),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Text(
                      value.name,
                      textAlign: TextAlign.start,
                      style: selected ? t.bodyStrong.withColor(c.brandStrong) : t.bodyStrong,
                    ),
                  ),
                  Semantics(
                    selected: selected,
                    child: IconButton(
                      icon: Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        color: selected ? c.brand : c.textMuted,
                      ),
                      tooltip: value.name,
                      onPressed: () {
                        controller.selectedPaymentMethod.value = value.name;
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

enum PaymentGateway { payFast, mercadoPago, paypal, stripe, flutterWave, payStack, paytm, razorpay, cod, wallet, midTrans, orangeMoney, xendit }
