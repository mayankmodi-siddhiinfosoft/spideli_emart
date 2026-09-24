import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cart_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../wallet_screen/wallet_screen.dart';

/// Archetype C — checkout step. Preferred methods (wallet / cash) in their own
/// group, every gateway below as a selectable row with the logo in a tile and
/// a radio on the trailing edge. The total travels in the sticky bar.
class SelectPaymentScreen extends StatelessWidget {
  const SelectPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CartController(),
      builder: (controller) {
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value == true;
        final bool hasPreferred = controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true;

        return DsScaffold(
          title: "Payment Option".tr,
          maxContentWidth: DsLayout.contentMax,
          body: isLoading
              ? Align(
                  alignment: Alignment.center,
                  child: Text("Loading, please wait...".tr, textAlign: TextAlign.center, style: t.titleSm),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      if (hasPreferred)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DsSectionHeader(
                              title: "Preferred Payment".tr,
                              icon: Icons.bolt_outlined,
                              padding: const EdgeInsets.only(bottom: DsSpace.sm),
                            ),
                            DsCard(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                              child: Column(
                                children: [
                                  Visibility(
                                    visible: controller.walletSettingModel.value.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.wallet, false, "assets/images/ic_wallet.png"),
                                  ),
                                  Visibility(
                                    visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.cod, false, "assets/images/ic_cash.png"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                      if (hasPreferred)
                        DsSectionHeader(
                          title: "Other Payment Options".tr,
                          icon: Icons.credit_card_outlined,
                          padding: const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.sm),
                        )
                      else
                        const SizedBox(),
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                        child: Column(
                          children: [
                            Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, false, "assets/images/stripe.png")),
                            Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, false, "assets/images/paypal.png")),
                            Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, false, "assets/images/paystack.png")),
                            Visibility(
                              visible: controller.mercadoPagoModel.value.isEnabled == true,
                              child: cardDecoration(controller, PaymentGateway.mercadoPago, false, "assets/images/mercado-pago.png"),
                            ),
                            Visibility(
                              visible: controller.flutterWaveModel.value.isEnable == true,
                              child: cardDecoration(controller, PaymentGateway.flutterWave, false, "assets/images/flutterwave_logo.png"),
                            ),
                            Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, false, "assets/images/payfast.png")),
                            Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, false, "assets/images/razorpay.png")),
                            Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, false, "assets/images/midtrans.png")),
                            Visibility(
                              visible: controller.orangeMoneyModel.value.enable == true,
                              child: cardDecoration(controller, PaymentGateway.orangeMoney, false, "assets/images/orange_money.png"),
                            ),
                            Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, false, "assets/images/xendit.png")),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "${'Pay Now'.tr} | ${Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.storeCurrency)}".tr,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                Get.back();
              },
            ),
          ),
        );
      },
    );
  }

  /// One selectable gateway row. Its own [Obx] keeps the radio in sync.
  Obx cardDecoration(CartController controller, PaymentGateway value, isDark, String image) {
    return Obx(() {
      final bool selected = controller.selectedPaymentMethod.value == value.name;
      return _PaymentRow(
        selected: selected,
        image: image,
        name: value.name,
        walletBalance: value.name == "wallet"
            ? Constant.amountShow(amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString(), currency: RegionService.customerCurrency)
            : null,
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
      );
    });
  }
}

class _PaymentRow extends StatelessWidget {
  final bool selected;
  final String image;
  final String name;
  final String? walletBalance;
  final VoidCallback onTap;
  const _PaymentRow({required this.selected, required this.image, required this.name, required this.walletBalance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      selected: selected,
      button: true,
      child: DsPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          constraints: const BoxConstraints(minHeight: 64),
          margin: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
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
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: DsRadius.brSm,
                  border: Border.all(color: c.border),
                ),
                child: Padding(padding: EdgeInsets.all(name == "payFast" ? 0 : DsSpace.sm), child: Image.asset(image)),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: walletBalance == null
                    ? Text(name.capitalizeString(), style: t.bodyStrong)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.capitalizeString(), style: t.bodyStrong),
                          Text(walletBalance!, style: t.titleSm.tabular.withColor(c.brandStrong)),
                        ],
                      ),
              ),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection indicator for a payment row (the whole row is the hit target).
class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return AnimatedContainer(
      duration: DsMotion.of(context, DsMotion.fast),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.brand : c.borderStrong, width: 2),
        color: Colors.transparent,
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: DsMotion.of(context, DsMotion.fast),
        scale: selected ? 1 : 0,
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.brand),
        ),
      ),
    );
  }
}
