import 'package:customer/utils/region_service.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/screen_ui/parcel_service/parcel_coupon_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_confirmation_controller.dart';
import '../../payment/create_razor_pay_order_model.dart';
import '../../payment/rozorpay_conroller.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../widgets/order_ui.dart';
import 'parcel_shipping_widgets.dart';

/// Parcel checkout (archetype C — cart / checkout): the route recap and the
/// trip metrics sit on top, then the shipment and price cards, the coupon
/// block, the bill summary and who pays; the total plus the primary action
/// ride in a sticky bar.
class ParcelOrderConfirmationScreen extends StatelessWidget {
  const ParcelOrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final l = context.dsLayout;
    return GetX(
      init: ParcelOrderConfirmationController(),
      builder: (controller) {
        return DsScaffold(
          title: "Order Confirmation".tr,
          onBack: () => Get.back(),
          maxContentWidth: DsLayout.contentMax,
          body: controller.isLoading.value
              ? const DsSkeletonDetail(mediaHeight: 140)
              : ListView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
                  children: DsFadeSlideIn.stagger([
                    // Pickup and Delivery Info
                    ParcelCard(
                      child: ParcelRouteBlock(
                        senderName: controller.parcelOrder.value.sender?.name ?? '',
                        senderAddress: controller.parcelOrder.value.sender?.address ?? '',
                        senderPhone: controller.parcelOrder.value.sender?.phone ?? '',
                        receiverName: controller.parcelOrder.value.receiver?.name ?? '',
                        receiverAddress: controller.parcelOrder.value.receiver?.address ?? '',
                        receiverPhone: controller.parcelOrder.value.receiver?.phone ?? '',
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    // Distance, Weight, Rate
                    DsAdaptiveGrid(
                      minItemWidth: 110,
                      children: [
                        ParcelMetricTile(value: "${controller.parcelOrder.value.distance ?? '--'} ${'KM'.tr}", label: "Distance".tr, asset: "assets/icons/ic_distance_parcel.svg"),
                        ParcelMetricTile(value: controller.parcelOrder.value.parcelWeight ?? '--', label: "Weight".tr, asset: "assets/icons/ic_weight_parcel.svg"),
                        ParcelMetricTile(
                          value: Constant.amountShow(
                            amount: ((double.tryParse(controller.parcelOrder.value.subTotal ?? '') ?? 0) + controller.scopeTax).toString(),
                            currency: controller.parcelCurrency,
                          ),
                          label: "Rate".tr,
                          asset: "assets/icons/ic_rate_parcel.svg",
                        ),
                      ],
                    ),
                    if (!controller.parcelOrder.value.isLegacyShape) ...[
                      const DsGap(DsSpace.lg),
                      ParcelShippingSummaryCard(order: controller.parcelOrder.value),
                    ],
                    if (controller.parcelOrder.value.priceBreakdown != null && !controller.isQuotePayment && !controller.parcelOrder.value.isLegacyShape) ...[
                      const DsGap(DsSpace.lg),
                      ParcelBreakdownCard(currency: controller.parcelCurrency, breakdown: controller.parcelOrder.value.priceBreakdown!),
                    ],
                    if (controller.isQuoteRequest) ...[
                      const DsGap(DsSpace.lg),
                      DsInlineAlert(
                        tone: DsTone.info,
                        icon: Icons.request_quote_outlined,
                        message: "No carrier serves this route yet. Send the request: the Spideli team will set a price, then you can pay it from the order details.".tr,
                      ),
                    ],
                    if (!controller.isQuoteRequest) ...[
                      const DsGap(DsSpace.xl),
                      DsSectionHeader(
                        title: "Coupons".tr,
                        icon: Icons.local_activity_outlined,
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        actionLabel: "View All".tr,
                        onAction: () {
                          Get.to(ParcelCouponScreen())!.then((value) {
                            if (value != null) {
                              double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                              if (couponAmount < controller.subTotal.value) {
                                controller.selectedCouponModel.value = value;
                                controller.calculatePrice();
                              } else {
                                ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                              }
                            }
                          });
                        },
                      ),
                      // Coupon input
                      DsCard.tinted(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.md, DsSpace.md),
                        child: Row(
                          children: [
                            SvgPicture.asset("assets/icons/ic_coupon_parcel.svg", height: 28, width: 28),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: TextField(
                                controller: controller.couponController.value,
                                style: t.bodyStrong,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: "Write coupon code".tr,
                                  hintStyle: t.bodySecondary,
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const DsGap(DsSpace.sm),
                            DsButton.primary(
                              label: "Redeem now".tr,
                              size: DsButtonSize.sm,
                              onPressed: () {
                                if (controller.couponList.where((element) => element.code!.toLowerCase() == controller.couponController.value.text.toLowerCase()).isNotEmpty) {
                                  CouponModel couponModel = controller.couponList.firstWhere((p0) => p0.code!.toLowerCase() == controller.couponController.value.text.toLowerCase());
                                  if (couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                    double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);
                                    if (couponAmount < controller.subTotal.value) {
                                      controller.selectedCouponModel.value = couponModel;
                                      controller.calculatePrice();
                                      controller.update();
                                    } else {
                                      ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                    }
                                  } else {
                                    ShowToastDialog.showToast("This coupon code has been expired".tr);
                                  }
                                } else {
                                  ShowToastDialog.showToast("Invalid coupon code".tr);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      ParcelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ParcelCardTitle("Order Summary".tr, icon: Icons.receipt_long_rounded),

                            // Subtotal
                            ParcelSummaryRow(label: "Subtotal".tr, value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: controller.parcelCurrency)),

                            // Discount
                            ParcelSummaryRow(
                              label: "Discount".tr,
                              value: "-${Constant.amountShow(amount: controller.discount.value.toString(), currency: controller.parcelCurrency)}",
                              tone: DsTone.danger,
                            ),
                            // Fixed intercity / intercountry tax: outside VAT and coupons.
                            if (controller.scopeTax > 0)
                              ParcelSummaryRow(label: "Fixed tax".tr, value: Constant.amountShow(amount: controller.scopeTax.toString(), currency: controller.parcelCurrency)),
                            if (Constant.platformFeeModel?.enable == true)
                              ParcelSummaryRow(label: "Platform fee".tr, value: Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: controller.parcelCurrency)),

                            // Tax List
                            ParcelSummaryRow(
                              label: "Tax amount".tr,
                              value: Constant.amountShow(amount: (controller.taxAmount.value).toString(), currency: controller.parcelCurrency),
                              underline: true,
                              onTap: () {
                                showBillBifurcationDialog(context, controller);
                              },
                            ),

                            const DsDivider(spacing: DsSpace.md),

                            // Total
                            ParcelSummaryRow(
                              label: "Order Total".tr,
                              value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.parcelCurrency),
                              emphasis: true,
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                      ParcelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            ParcelCardTitle("Payment by".tr, icon: Icons.account_balance_wallet_outlined),

                            // Row with Sender and Receiver options
                            Row(
                              children: [
                                // Sender
                                Expanded(
                                  child: _PayerOption(
                                    label: "Sender".tr,
                                    icon: Icons.outbound_outlined,
                                    selected: controller.paymentBy.value == "Sender",
                                    onTap: () => controller.paymentBy.value = "Sender",
                                  ),
                                ),

                                // Receiver (same-city only)
                                if (!controller.senderMustPay) ...[
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: _PayerOption(
                                      label: "Receiver".tr,
                                      icon: Icons.move_to_inbox_outlined,
                                      selected: controller.paymentBy.value == "Receiver",
                                      onTap: () => controller.paymentBy.value = "Receiver",
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: controller.isQuoteRequest
                      ? DsButton.primary(
                          label: "Request a quote".tr,
                          icon: Icons.request_quote_outlined,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () => controller.placeOrder(),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OrderTotalRow(
                              label: "Order Total".tr,
                              value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.parcelCurrency),
                              divider: false,
                              padding: EdgeInsets.zero,
                            ),
                            const DsGap(DsSpace.md),
                            DsButton.primary(
                              label: controller.paymentBy.value == "Sender" ? "Select Payment Method".tr : "Continue".tr,
                              icon: controller.paymentBy.value == "Sender" ? Icons.credit_card_rounded : null,
                              size: DsButtonSize.lg,
                              expand: true,
                              onPressed: () async {
                                if (controller.paymentBy.value == "Sender") {
                                  Get.bottomSheet(
                                    paymentBottomSheet(context, controller), // your widget
                                    isScrollControlled: true, // ✅ allows full drag scrolling
                                    backgroundColor: Colors.transparent, // so your rounded corners are visible
                                  );
                                } else {
                                  controller.placeOrder();
                                }
                              },
                            ),
                          ],
                        ),
                ),
        );
      },
    );
  }

  Widget paymentBottomSheet(BuildContext context, ParcelOrderConfirmationController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.30,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        final c = context.dsColors;
        final t = context.dsText;
        // Reads of controller observables happen in this lazily-run builder,
        // so they need their own observer.
        return DsObserve(
          builder: (context) => Container(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: DsRadius.sheetTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill)),
                ),
                const DsGap(DsSpace.md),
                Row(
                  children: [
                    Expanded(child: Text("Select Payment Method".tr, style: t.title)),
                    DsIconButton(
                      icon: Icons.close_rounded,
                      semanticLabel: "Close".tr,
                      onPressed: () {
                        Get.back();
                      },
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      Text("Preferred Payment".tr, textAlign: TextAlign.start, style: t.overline),
                      const DsGap(DsSpace.sm),
                      if (controller.walletSettingModel.value.isEnabled == true || (controller.cashOnDeliverySettingModel.value.isEnabled == true && controller.cashAllowed))
                        DsCard.outlined(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                          child: Column(
                            children: [
                              Visibility(
                                visible: controller.walletSettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.wallet, "assets/images/ic_wallet.png"),
                              ),
                              Visibility(
                                visible: controller.cashOnDeliverySettingModel.value.isEnabled == true && controller.cashAllowed,
                                child: cardDecoration(controller, PaymentGateway.cod, "assets/images/ic_cash.png"),
                              ),
                            ],
                          ),
                        ),
                      if (controller.walletSettingModel.value.isEnabled == true || (controller.cashOnDeliverySettingModel.value.isEnabled == true && controller.cashAllowed)) const DsGap(DsSpace.lg),
                      Text("Other Payment Options".tr, textAlign: TextAlign.start, style: t.overline),
                      const DsGap(DsSpace.sm),
                      DsCard.outlined(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                        child: Column(
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
                            Visibility(
                              visible: controller.orangeMoneyModel.value.enable == true,
                              child: cardDecoration(controller, PaymentGateway.orangeMoney, "assets/images/orange_money.png"),
                            ),
                            Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, "assets/images/xendit.png")),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: DsButton.primary(
                    label: "Continue".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
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
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                        controller.placeOrder();
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                        double walletBalance = double.tryParse(controller.userModel.value.walletAmount.toString()) ?? 0.0;
                        double amountToPay = double.tryParse(controller.totalAmount.value.toString()) ?? 0.0;
                        if (walletBalance < amountToPay) {
                          ShowToastDialog.showToast("Insufficient wallet balance".tr);
                          return;
                        }
                        controller.placeOrder();
                      }
                      // else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                      //   controller.placeOrder();
                      // }
                      else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                        controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                        controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                        controller.xenditPayment(context, controller.totalAmount.value.toString());
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                        RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((value) {
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
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Obx cardDecoration(ParcelOrderConfirmationController controller, PaymentGateway value, String image) {
    return Obx(
      () => ParcelPaymentRow(
        image: image,
        name: value.name,
        selected: controller.selectedPaymentMethod.value == value.name,
        walletAmount: value.name == "wallet"
            ? Constant.amountShow(amount: Constant.userModel?.walletAmount == null ? '0.0' : Constant.userModel?.walletAmount.toString(), currency: RegionService.customerCurrency)
            : null,
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, ParcelOrderConfirmationController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.percent_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ParcelSummaryRow(label: "Tax on Order Total".tr, value: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: controller.parcelCurrency)),
              const DsDivider(spacing: DsSpace.md),
              ParcelSummaryRow(label: "Tax on Platform Fee".tr, value: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: controller.parcelCurrency)),
              const DsDivider(spacing: DsSpace.md),
              ParcelSummaryRow(label: "Total Tax Amount".tr, value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: controller.parcelCurrency), emphasis: true),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}

/// Sender → receiver rail used by the confirmation and the order details.
class ParcelRouteBlock extends StatelessWidget {
  final String senderName;
  final String senderAddress;
  final String senderPhone;
  final String receiverName;
  final String receiverAddress;
  final String receiverPhone;

  const ParcelRouteBlock({
    super.key,
    required this.senderName,
    required this.senderAddress,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverAddress,
    required this.receiverPhone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget party(String title, String name, String address, String phone) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.overline),
        const DsGap(DsSpace.xxs),
        if (name.isNotEmpty) Text(name, style: t.titleSm),
        if (address.isNotEmpty) Text(address, style: t.bodySecondary),
        if (phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.xxs),
            child: Row(
              children: [
                Icon(Icons.call_outlined, size: 13, color: c.textMuted),
                const DsGap(DsSpace.xs),
                Text(phone, style: t.bodySm.tabular),
              ],
            ),
          ),
      ],
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Icon(Icons.trip_origin_rounded, size: 16, color: c.brandStrong),
                Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: DsSpace.xs), color: c.border)),
                Icon(Icons.place_rounded, size: 18, color: c.brandStrong),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                party("Pickup Address (Sender):".tr, senderName, senderAddress, senderPhone),
                const DsGap(DsSpace.xl),
                party("Delivery Address (Receiver):".tr, receiverName, receiverAddress, receiverPhone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance / weight / rate tile.
class ParcelMetricTile extends StatelessWidget {
  final String value;
  final String label;
  final String asset;

  const ParcelMetricTile({super.key, required this.value, required this.label, required this.asset});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(asset, height: 26, width: 26, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
          const DsGap(DsSpace.md),
          Text(value, style: t.titleSm.tabular, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const DsGap(DsSpace.xxs),
          Text(label, style: t.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// One bill line. [emphasis] is the total row, [onTap] opens the tax details.
/// Both come from the shared order widgets, so the parcel bill lines up with
/// every other bill in the app.
class ParcelSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final bool underline;
  final DsTone? tone;
  final VoidCallback? onTap;

  const ParcelSummaryRow({super.key, required this.label, required this.value, this.emphasis = false, this.underline = false, this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (emphasis) return OrderTotalRow(label: label, value: value, divider: false);
    return OrderMoneyRow(label: label, value: value, tone: tone, underline: underline, onTap: onTap);
  }
}

/// A payment gateway row inside the payment sheet.
class ParcelPaymentRow extends StatelessWidget {
  final String image;
  final String name;
  final bool selected;
  final String? walletAmount;
  final VoidCallback onTap;

  const ParcelPaymentRow({super.key, required this.image, required this.name, required this.selected, required this.onTap, this.walletAmount});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: InkWell(
        borderRadius: DsRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                child: Padding(padding: EdgeInsets.all(name == "payFast" ? 0 : DsSpace.sm), child: Image.asset(image)),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.capitalizeString(), textAlign: TextAlign.start, style: t.titleSm),
                    if (walletAmount != null) Text(walletAmount!, textAlign: TextAlign.start, style: t.bodyStrong.tabular.withColor(c.brandStrong)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 22,
                color: selected ? c.brand : c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sender / receiver payer choice.
class _PayerOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayerOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
      borderColor: selected ? c.brand : null,
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: selected ? c.brandStrong : c.textMuted),
          const DsGap(DsSpace.sm),
          Expanded(child: Text(label, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? c.brand : c.textMuted,
          ),
        ],
      ),
    );
  }
}
