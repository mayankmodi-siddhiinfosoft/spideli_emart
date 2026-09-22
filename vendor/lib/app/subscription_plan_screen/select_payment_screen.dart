import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/subscription_controller.dart';
import 'package:vendor/payment/create_razor_pay_order_model.dart';
import 'package:vendor/payment/rozorpay_conroller.dart';
import 'package:vendor/themes/ds/ds.dart';

class SelectPaymentScreen extends StatelessWidget {
  const SelectPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        final t = context.dsText;
        final l = context.dsLayout;
        final plan = controller.selectedSubscriptionPlan.value;
        return DsScaffold(
          title: "Payment Option".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const DsSkeletonList(itemCount: 6, trailing: true),
            builder: (context) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxl),
              child: DsResponsive(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([
                    // Order summary for the plan being purchased.
                    DsCard.gradient(
                      gradient: DsGradients.deep(context),
                      child: Row(
                        children: [
                          const DsIconWell(icon: Icons.workspace_premium_rounded, onBrand: true, size: 48),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan.name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(Colors.white)),
                                if ((plan.expiryDay ?? '').isNotEmpty)
                                  Text(
                                    plan.expiryDay == "-1" ? "Lifetime".tr : "${plan.expiryDay} ${"Days".tr}",
                                    style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.75)),
                                  ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.sm),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(Constant.amountShow(amount: controller.totalAmount.value.toString()), style: t.metric.withColor(Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.walletSettingModel.value.isEnabled == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DsSectionHeader(title: "Preferred Payment".tr, icon: Icons.star_outline_rounded),
                          Visibility(
                            visible: controller.walletSettingModel.value.isEnabled == true,
                            child: cardDecoration(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png"),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DsSectionHeader(
                          title: controller.walletSettingModel.value.isEnabled == true ? "Other Payment Options".tr : "Preferred Payment".tr,
                          icon: Icons.payments_outlined,
                        ),
                        Visibility(
                          visible: controller.stripeModel.value.isEnabled == true,
                          child: cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png"),
                        ),
                        Visibility(
                          visible: controller.payPalModel.value.isEnabled == true,
                          child: cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png"),
                        ),
                        Visibility(
                          visible: controller.payStackModel.value.isEnable == true,
                          child: cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png"),
                        ),
                        Visibility(
                          visible: controller.mercadoPagoModel.value.isEnabled == true,
                          child: cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png"),
                        ),
                        Visibility(
                          visible: controller.flutterWaveModel.value.isEnable == true,
                          child: cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png"),
                        ),
                        Visibility(
                          visible: controller.payFastModel.value.isEnable == true,
                          child: cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png"),
                        ),
                        // Visibility(
                        //   visible: controller.paytmModel.value.isEnabled == true,
                        //   child: cardDecoration(controller, PaymentGateway.paytm, isDark, "assets/images/paytm.png"),
                        // ),
                        Visibility(
                          visible: controller.razorPayModel.value.isEnabled == true,
                          child: cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png"),
                        ),
                        Visibility(
                          visible: controller.midTransModel.value.enable == true,
                          child: cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png"),
                        ),
                        Visibility(
                          visible: controller.orangeMoneyModel.value.enable == true,
                          child: cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png"),
                        ),
                        Visibility(
                          visible: controller.xenditModel.value.enable == true,
                          child: cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png"),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: context.dsColors.textMuted),
                          const DsGap(DsSpace.xs),
                          Flexible(child: Text("Payments are processed securely.".tr, style: t.caption)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "${"Pay Now".tr} | ${Constant.amountShow(amount: controller.totalAmount.value.toString())}".tr,
              icon: Icons.lock_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                if (controller.selectedPaymentMethod.value == '') {
                  ShowToastDialog.showToast("Please Select Payment Method.".tr);
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
                    if (controller.walletBalance >= controller.totalAmount.value) {
                      Get.back();
                      controller.placeOrder();
                    } else {
                      ShowToastDialog.showToast("You don't have sufficient wallet balance to purchase the subscription plan".tr);
                    }
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                    controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                    controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                    controller.xenditPayment(context, controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                    RazorPayController()
                        .createOrderRazorPay(
                          amount: (double.parse(controller.totalAmount.value.toString()) * 100).round(),
                          razorpayModel: controller.razorPayModel.value,
                        )
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
        );
      },
    );
  }

  Obx cardDecoration(SubscriptionController controller, PaymentGateway value, isDark, String image) {
    return Obx(() {
      // Read observables synchronously here so the Obx tracks them (reads
      // inside the Builder below run later and would not be observed).
      final selected = controller.selectedPaymentMethod.value == value.name;
      final walletBalance = controller.walletBalance;
      return Builder(
        builder: (context) {
          final c = context.dsColors;
          final t = context.dsText;
          final br = DsRadius.brLg;
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              checked: selected,
              label: value.name.capitalizeString(),
              child: AnimatedContainer(
                duration: DsMotion.of(context, DsMotion.base),
                curve: DsMotion.standard,
                decoration: BoxDecoration(
                  color: selected ? c.brandSoft : c.surface,
                  borderRadius: br,
                  border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.6 : 1),
                  boxShadow: selected ? DsShadows.sm(context) : null,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: br,
                    onTap: () {
                      controller.selectedPaymentMethod.value = value.name;
                    },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.md, DsSpace.md, DsSpace.xs, DsSpace.md),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: DsRadius.brMd,
                              border: Border.all(color: c.border),
                            ),
                            child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
                          ),
                          const DsGap(DsSpace.md),
                          value == PaymentGateway.wallet
                              ? Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                                      Text(
                                        Constant.amountShow(amount: walletBalance.toString()),
                                        textAlign: TextAlign.start,
                                        style: t.titleSm.tabular.withColor(c.brandStrong),
                                      ),
                                    ],
                                  ),
                                )
                              : Expanded(
                                  child: Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                                ),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: AnimatedContainer(
                                duration: DsMotion.of(context, DsMotion.fast),
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: selected ? c.brand : c.borderStrong, width: 2),
                                ),
                                child: AnimatedScale(
                                  duration: DsMotion.of(context, DsMotion.base),
                                  curve: DsMotion.spring,
                                  scale: selected ? 1 : 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
