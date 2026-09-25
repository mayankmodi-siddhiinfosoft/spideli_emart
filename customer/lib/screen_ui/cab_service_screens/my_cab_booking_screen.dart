import 'package:customer/utils/region_service.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constant/constant.dart';
import '../../controllers/my_cab_booking_controller.dart';
import 'widget/cab_ride_options_widgets.dart';

import 'cab_order_details.dart';

/// Ride history (archetype F — booking history): DS pill tabs over route
/// cards that read as A → B with a status chip, the trip OTP and an inline
/// "Pay Now" when the fare is still open.
class MyCabBookingScreen extends StatelessWidget {
  const MyCabBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: MyCabBookingController(),
      builder: (controller) {
        final c = context.dsColors;
        return DefaultTabController(
          // length: controller.tabTitles.length,
          // initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          length: controller.tabKeys.length,
          initialIndex: controller.tabKeys.indexOf(controller.selectedTab.value),
          child: Scaffold(
            backgroundColor: c.background,
            appBar: DsAppBar(
              title: "Ride History".tr,
              showBack: false,
              bottom: DsTabBar(
                scrollable: controller.tabKeys.length > 3,
                onTap: (index) {
                  controller.selectTab(controller.tabKeys[index]);
                },
                tabs: controller.tabKeys.map((key) => controller.getLocalizedTabTitle(key)).toList(),
              ),
            ),
            body: controller.isLoading.value
                ? const DsSkeletonList(itemCount: 4, leading: false)
                : Constant.userModel == null
                ? DsEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: "Please Log In to Continue".tr,
                    message: "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                    actionLabel: "Log in".tr,
                    actionIcon: Icons.login_rounded,
                    onAction: () async {
                      Get.offAll(const LoginScreen());
                    },
                  )
                : TabBarView(
                    children: controller.tabKeys.map((title) {
                      final orders = controller.getOrdersForTab(title);

                      if (orders.isEmpty) {
                        return DsEmptyState(icon: Icons.local_taxi_outlined, title: "No order found".tr, compact: true);
                      }

                      return DsResponsive(
                        maxWidth: DsLayout.contentMax,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.xxxl),
                          itemCount: orders.length,
                          separatorBuilder: (context, index) => const DsGap(DsSpace.md),
                          itemBuilder: (context, index) {
                            final CabOrderModel order = orders[index];
                            return DsFadeSlideIn(
                              index: index,
                              child: _RideHistoryCard(
                                order: order,
                                controller: controller,
                                onTap: () {
                                  Get.to(() => CabOrderDetails(), arguments: {"cabOrderModel": order});
                                },
                                onPayNow: () async {
                                  controller.selectedPaymentMethod.value = order.paymentMethod.toString();
                                  await controller.preparePaymentFor(order);
                                  controller.calculateTotalAmount(order);
                                  Get.bottomSheet(paymentBottomSheet(context, controller), isScrollControlled: true, backgroundColor: Colors.transparent);
                                },
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }

  Widget paymentBottomSheet(BuildContext context, MyCabBookingController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      // Start height
      minChildSize: 0.30,
      // Minimum height
      maxChildSize: 0.8,
      // Maximum height
      expand: false,
      //Prevents full-screen takeover
      builder: (context, scrollController) {
        // Built lazily by the sheet, after the enclosing observer has run:
        // DsObserve tracks the settings observables read below.
        return DsObserve(
          builder: (context) {
            final c = context.dsColors;
            final t = context.dsText;
            final hasPreferred = controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true;
            return Container(
              decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: DsRadius.sheetTop),
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: DsSpace.md),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("Select Payment Method".tr, style: t.title)),
                      DsIconButton(
                        icon: Icons.close_rounded,
                        semanticLabel: "Close".tr,
                        variant: DsIconButtonVariant.tonal,
                        size: 36,
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      controller: scrollController,
                      children: [
                        if (hasPreferred) ...[
                          Text("Preferred Payment".tr, textAlign: TextAlign.start, style: t.overline),
                          const DsGap(DsSpace.sm),
                          DsCard.outlined(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            child: Column(
                              children: [
                                Visibility(visible: controller.walletSettingModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.wallet, "assets/images/ic_wallet.png")),
                                Visibility(visible: controller.cashOnDeliverySettingModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.cod, "assets/images/ic_cash.png")),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.lg),
                          Text("Other Payment Options".tr, textAlign: TextAlign.start, style: t.overline),
                          const DsGap(DsSpace.sm),
                        ],
                        DsCard.outlined(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                          child: Column(
                            children: [
                              Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, "assets/images/stripe.png")),
                              Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, "assets/images/paypal.png")),
                              Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, "assets/images/paystack.png")),
                              Visibility(visible: controller.mercadoPagoModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.mercadoPago, "assets/images/mercado-pago.png")),
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
                        ),
                        const DsGap(DsSpace.xl),
                      ],
                    ),
                  ),
                  DsButton.primary(
                    label: "Continue".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      if (controller.selectedPaymentMethod.value.isEmpty) {
                        ShowToastDialog.showToast("Please select a payment method".tr);
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
                        } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                          controller.completeOrder();
                        } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                          if (Constant.userModel!.walletAmount == null || Constant.userModel!.walletAmount! < controller.totalAmount.value) {
                            ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                          } else {
                            controller.completeOrder();
                          }
                        } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
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
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// One gateway row. [DsObserve] (not `Obx(() => Builder(...))`) so the
  /// `selectedPaymentMethod` read below is tracked by the observer that is
  /// actually running when it happens.
  Widget cardDecoration(MyCabBookingController controller, PaymentGateway value, String image) {
    return DsObserve(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        final selected = controller.selectedPaymentMethod.value == value.name;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: DsRadius.brMd,
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs, vertical: DsSpace.xs),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.brSm,
                        border: Border.all(color: selected ? c.brand : c.border),
                        color: c.surface,
                      ),
                      child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : DsSpace.sm), child: Image.asset(image)),
                    ),
                    const DsGap(DsSpace.md),
                    value.name == "wallet"
                        ? Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                                Text(
                                  Constant.amountShow(amount: Constant.userModel!.walletAmount == null ? '0.0' : Constant.userModel!.walletAmount.toString(), currency: RegionService.customerCurrency),
                                  textAlign: TextAlign.start,
                                  style: t.labelSm.withColor(c.brandStrong).tabular,
                                ),
                              ],
                            ),
                          )
                        : Expanded(
                            child: Text(value.name.capitalizeString(), textAlign: TextAlign.start, style: t.bodyStrong),
                          ),
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
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One ride in the history: date + status, the A → B route, the trip OTP and
/// the outstanding-fare action.
class _RideHistoryCard extends StatelessWidget {
  final CabOrderModel order;
  final MyCabBookingController controller;
  final VoidCallback onTap;
  final Future<void> Function() onPayNow;

  const _RideHistoryCard({required this.order, required this.controller, required this.onTap, required this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final showPay = order.status == Constant.orderInTransit && order.paymentStatus == false;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "${'Booking Date:'.tr} ${controller.formatDate(order.scheduleDateTime!)}".tr,
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSm,
                ),
              ),
              const DsGap(DsSpace.sm),
              DsStatusChip(label: order.status.toString(), status: order.status),
            ],
          ),
          OrderIdLine(id: order.id.toString(), compact: true, copyable: false),
          const DsGap(DsSpace.sm),
          CabRouteRail(source: order.sourceLocationName.toString(), destination: order.destinationLocationName.toString()),
          if (Constant.isEnableOTPTripStart == true) ...[
            const DsGap(DsSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Otp :".tr, style: t.bodySecondary),
                const DsGap(DsSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                  decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brSm),
                  child: Text(order.otpCode ?? '', style: t.titleSm.withColor(c.brandStrong).tabular),
                ),
              ],
            ),
          ],
          if (showPay) ...[const DsGap(DsSpace.lg), DsButton.primary(label: "Pay Now".tr, icon: Icons.account_balance_wallet_outlined, expand: true, onPressed: () => onPayNow())],
        ],
      ),
    );
  }
}
