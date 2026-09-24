import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/wallet_controller.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../themes/show_toast_dialog.dart';

/// Archetype **C — checkout**: an amount field, then payment providers as
/// selectable outlined rows with a radio trailing, and the action in a
/// sticky bar.
class PaymentListScreen extends StatelessWidget {
  const PaymentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: WalletController(),
      builder: (controller) {
        final t = context.dsText;
        final symbol = (RegionService.customerCurrency ?? Constant.currencyModel!).symbol.toString();
        return DsScaffold(
          title: "Top up Wallet".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Top-up".tr,
              size: DsButtonSize.lg,
              expand: true,
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () async {
                if (controller.topUpAmountController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please Enter Amount".tr);
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
                      RazorPayController().createOrderRazorPay(amount: double.parse(controller.topUpAmountController.value.text), razorpayModel: controller.razorPayModel.value).then((value) {
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
                    ShowToastDialog.showToast("${'Please Enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit, currency: RegionService.customerCurrency)}");
                  }
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                DsCard.tinted(
                  tone: DsTone.brand,
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
                  child: DsTextField(
                    label: 'Amount'.tr,
                    hint: 'Enter Amount'.tr,
                    controller: controller.topUpAmountController.value,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    prefix: Padding(padding: const EdgeInsets.all(12.0), child: Text(symbol, style: t.title.tabular)),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                    helper: "${'Please Enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit, currency: RegionService.customerCurrency)}",
                  ),
                ),
                DsSectionHeader(title: "Select Top up Options".tr, icon: Icons.credit_card_rounded),
                Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(context, controller, PaymentGateway.paypal, "assets/images/paypal.png")),
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
                Visibility(visible: controller.orangeMoneyModel.value.enable == true, child: cardDecoration(context, controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png")),
                Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(context, controller, PaymentGateway.xendit, "assets/images/xendit.png")),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// One provider row. Wrapped in its own `Obx` because the selected method is
  /// read while this row builds.
  Obx cardDecoration(BuildContext context, WalletController controller, PaymentGateway value, String image) {
    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      final selected = controller.selectedPaymentMethod.value == value.name;
      return DsCard.outlined(
        margin: const EdgeInsets.only(bottom: DsSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        borderColor: selected ? c.brand : null,
        color: selected ? c.brandSoft : null,
        semanticLabel: value.name.capitalizeString(),
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
              child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
            ),
            const DsGap(DsSpace.md),
            Expanded(child: Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: selected ? t.label.withColor(c.brandStrong) : t.bodyStrong)),
            Radio(
              value: value.name,
              groupValue: controller.selectedPaymentMethod.value,
              activeColor: c.brand,
              onChanged: (value) {
                controller.selectedPaymentMethod.value = value.toString();
              },
            ),
          ],
        ),
      );
    });
  }
}
