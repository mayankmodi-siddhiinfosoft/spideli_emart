import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_payment_controller.dart';
import '../../payment/create_razor_pay_order_model.dart';
import '../../payment/rozorpay_conroller.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';

/// Archetype C – checkout: grouped payment methods with a sticky pay bar.
class OnDemandPaymentScreen extends StatelessWidget {
  const OnDemandPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OnDemandPaymentController>(
      init: OnDemandPaymentController(),
      builder: (controller) {
        final l = context.dsLayout;
        final bool hasPreferred = controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true;

        return DsScaffold(
          title: "Select Payment Method".tr,
          maxContentWidth: DsLayout.contentMax,
          body:
              controller.isLoading.value
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 6, trailing: false))
                  : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        if (hasPreferred)
                          _PaymentGroup(
                            title: "Preferred Payment".tr,
                            icon: Icons.bolt_rounded,
                            children: [
                              Visibility(
                                visible: controller.walletSettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.wallet, "assets/images/ic_wallet.png"),
                              ),
                              Visibility(
                                visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.cod, "assets/images/ic_cash.png"),
                              ),
                            ],
                          ),
                        if (hasPreferred) const DsGap(DsSpace.lg),
                        _PaymentGroup(
                          title: hasPreferred ? "Other Payment Options".tr : "Preferred Payment".tr,
                          icon: Icons.credit_card_rounded,
                          children: [
                            Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                            Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                            Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                            Visibility(
                              visible: controller.mercadoPagoModel.value.isEnabled == true,
                              child: cardDecoration(controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png"),
                            ),
                            Visibility(
                              visible: controller.flutterWaveModel.value.isEnable == true,
                              child: cardDecoration(controller, PaymentGateway.flutterWave, "assets/images/flutterwave_logo.png"),
                            ),
                            Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, "assets/images/payfast.png")),
                            Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, "assets/images/razorpay.png")),
                            Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, "assets/images/midtrans.png")),
                            Visibility(visible: controller.orangeMoneyModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png")),
                            Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, "assets/images/xendit.png")),
                          ],
                        ),
                      ]),
                    ),
                  ),
          bottomBar:
              controller.isLoading.value
                  ? null
                  : DsStickyBar(
                    child: DsButton.primary(
                      label: "Continue".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      icon: Icons.lock_outline_rounded,
                      onPressed: () async {
                        print("getTotalAmount :::::::: ${"${controller.totalAmount.value}"}");
                        if (controller.isOrderPlaced.value == false) {
                          controller.isOrderPlaced.value = true;
                          if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                            controller.stripeMakePayment(amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                            controller.paypalPaymentSheet("${controller.totalAmount.value}", context);
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                            controller.payStackPayment("${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                            controller.mercadoPagoMakePayment(context: context, amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                            controller.flutterWaveInitiatePayment(context: context, amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                            controller.payFastPayment(context: context, amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                            double totalAmount = double.parse("${controller.totalAmount.value}");
                            double walletAmount = double.tryParse(Constant.userModel?.walletAmount?.toString() ?? "0") ?? 0;

                            if (walletAmount == 0) {
                              ShowToastDialog.showToast("Wallet balance is 0. Please recharge wallet.".tr);
                            } else if (walletAmount < totalAmount) {
                              ShowToastDialog.showToast("Insufficient wallet balance. Please add funds.".tr);
                            } else {
                              controller.placeOrder();
                            }
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                            controller.placeOrder();
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                            controller.placeOrder();
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                            controller.midtransMakePayment(context: context, amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                            controller.orangeMakePayment(context: context, amount: "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                            controller.xenditPayment(context, "${controller.totalAmount.value}");
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                            RazorPayController().createOrderRazorPay(amount: double.parse("${controller.totalAmount.value}"), razorpayModel: controller.razorPayModel.value).then((value) {
                              if (value == null) {
                                Get.back();
                                ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                              } else {
                                CreateRazorPayOrderModel result = value;
                                controller.openCheckout(amount: "${controller.totalAmount.value}", orderId: result.id);
                              }
                            });
                          } else {
                            controller.isOrderPlaced.value = false;
                            ShowToastDialog.showToast("Please select payment method".tr);
                          }
                          controller.isOrderPlaced.value = false;
                        }
                      },
                    ),
                  ),
        );
      },
    );
  }

  /// One selectable gateway row. The [Obx] tracks the selected method.
  Widget cardDecoration(OnDemandPaymentController controller, PaymentGateway value, String image) {
    return Obx(() {
      final selected = controller.selectedPaymentMethod.value == value.name;
      return _PaymentTile(
        image: image,
        name: value.name.capitalizeString(),
        walletBalance:
            value.name == "wallet"
                ? Constant.amountShow(amount: Constant.userModel?.walletAmount == null ? '0.0' : Constant.userModel?.walletAmount.toString(), currency: RegionService.customerCurrency)
                : null,
        tightLogo: value.name == "payFast",
        selected: selected,
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
      );
    });
  }
}

/// Grouped card of payment rows with a section label.
class _PaymentGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _PaymentGroup({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: c.brand),
            const DsGap(DsSpace.sm),
            Text(title, style: t.labelSm.withColor(c.textSecondary)),
          ],
        ),
        const DsGap(DsSpace.sm),
        DsCard.outlined(padding: const EdgeInsets.all(DsSpace.sm), child: Column(children: children)),
      ],
    );
  }
}

/// Selectable payment method row (logo, name, optional wallet balance, radio).
class _PaymentTile extends StatelessWidget {
  final String image;
  final String name;
  final String? walletBalance;
  final bool tightLogo;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentTile({required this.image, required this.name, required this.selected, required this.onTap, this.walletBalance, this.tightLogo = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brMd,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          margin: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected ? c.brandSoft : Colors.transparent,
            borderRadius: DsRadius.brMd,
            border: Border.all(color: selected ? c.brand : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                padding: EdgeInsets.all(tightLogo ? 0 : DsSpace.sm),
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: t.bodyStrong),
                    if (walletBalance != null) ...[
                      const DsGap(DsSpace.xxs),
                      Text(walletBalance!, style: t.labelSm.withColor(c.brandStrong).tabular),
                    ],
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              AnimatedContainer(
                duration: DsMotion.of(context, DsMotion.fast),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.brand : Colors.transparent,
                  border: Border.all(color: selected ? c.brand : c.borderStrong, width: 2),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: c.onBrand) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
