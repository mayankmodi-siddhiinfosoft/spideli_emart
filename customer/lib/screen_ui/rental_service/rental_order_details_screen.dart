import 'package:customer/utils/order_receipt_pdf.dart';
import 'package:customer/utils/ride_receipt_pdf.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_review_screen.dart';
import 'package:customer/screen_ui/rental_service/widget/rental_common_widgets.dart';
import 'package:customer/screen_ui/rental_service/widget/rental_proposal_widgets.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/rental_order_details_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';

/// Rental booking details (archetype F — order detail): the negotiation card
/// first, then the booking id, the trip, the driver, the vehicle, the package
/// breakdown and the bill; the stateful action sits in a sticky bar.
class RentalOrderDetailsScreen extends StatelessWidget {
  const RentalOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    return GetX(
      init: RentalOrderDetailsController(),
      builder: (controller) {
        final sid = controller.order.value.sectionId ?? '';
        final vehicle = controller.order.value.driver?.vehicleDetails?[sid];
        final vType = vehicle?['vehicleType']?.toString() ?? '';
        final brand = vehicle?['carBrand']?.toString() ?? '';
        final carModel = vehicle?['carModel']?.toString() ?? '';
        final plate = vehicle?['carPlateNumber']?.toString() ?? '';
        final bool showPay = controller.order.value.status == Constant.orderInTransit && controller.order.value.paymentStatus == false;
        final bool showCancel = controller.order.value.status == Constant.orderPlaced || controller.order.value.status == Constant.driverAccepted;
        return DsScaffold(
          appBar: DsAppBar(
            title: "Order Details".tr,
            onBack: () {
              Get.back();
            },
            actions: [
              // PDF receipt: download / share (spec 7.6).
              if (!controller.isLoading.value)
                DsIconButton(
                  icon: Icons.receipt_long_outlined,
                  semanticLabel: "Receipt".tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: () => OrderReceiptPdf.showOptions(context, () => RideReceiptPdf.fromRentalOrder(controller)),
                ),
            ],
          ),
          maxContentWidth: DsLayout.contentMax,
          body: controller.isLoading.value
              ? const DsSkeletonDetail(mediaHeight: 120)
              : ListView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xl, l.gutter, DsSpace.xxl),
                  children: DsFadeSlideIn.stagger([
                    // Price proposal & negotiation (spec 4.9); hidden without one.
                    RentalProposalCard(order: controller.order.value, currency: controller.bookingCurrency),
                    RentalInfoCard(
                      child: Column(
                        children: [
                          OrderIdHeader(
                            title: 'Booking Id :'.tr,
                            id: controller.order.value.id.toString(),
                            statusLabel: controller.order.value.status,
                            status: controller.order.value.status,
                            copySemanticLabel: "Booking ID copied to clipboard".tr,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: controller.order.value.id.toString()));
                              ShowToastDialog.showToast("Booking ID copied to clipboard".tr);
                            },
                          ),
                          const DsGap(DsSpace.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const DsIconWell(icon: Icons.trip_origin_rounded, size: 40),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(controller.order.value.sourceLocationName ?? "-", style: t.titleSm),
                                    if (controller.order.value.bookingDateTime != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: DsSpace.xxs),
                                        child: Row(
                                          children: [
                                            Icon(Icons.event_rounded, size: 13, color: c.textMuted),
                                            const DsGap(DsSpace.xs),
                                            Expanded(child: Text(Constant.timestampToDate(controller.order.value.bookingDateTime!), style: t.caption)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    if (controller.order.value.rentalPackageModel != null)
                      RentalInfoCard(
                        title: "Your Preference".tr,
                        icon: Icons.tune_rounded,
                        child: OrderItemRow(
                          name: controller.order.value.rentalPackageModel!.name ?? "-",
                          price: Constant.amountShow(amount: controller.order.value.rentalPackageModel!.baseFare.toString(), currency: controller.bookingCurrency),
                          footer: Padding(
                            padding: const EdgeInsets.only(top: DsSpace.xs),
                            child: Text(controller.order.value.rentalPackageModel!.description ?? "", maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySecondary),
                          ),
                        ),
                      ),
                    const DsGap(DsSpace.lg),
                    if (controller.order.value.driver != null) ...[
                      RentalInfoCard(
                        title: "About Driver".tr,
                        icon: Icons.badge_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsAvatar(
                                  imageUrl: controller.driverUser.value?.profilePictureURL ?? '',
                                  name: controller.order.value.driver?.fullName() ?? '',
                                  size: 52,
                                  ring: true,
                                ),
                                const DsGap(DsSpace.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(controller.order.value.driver?.fullName() ?? '', style: t.title),
                                      if (vType.isNotEmpty) Text(vType, style: t.bodySecondary),
                                      if (brand.isNotEmpty || carModel.isNotEmpty) Text("$brand $carModel".trim(), style: t.bodySecondary),
                                      if (plate.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: DsSpace.xs),
                                          child: DsBadge(label: plate.toUpperCase(), style: DsBadgeStyle.outline, icon: Icons.directions_car_outlined),
                                        ),
                                    ],
                                  ),
                                ),
                                const DsGap(DsSpace.sm),
                                DsBadge(label: controller.driverUser.value?.averageRating.toString() ?? '', tone: DsTone.warning, icon: Icons.star_rounded),
                              ],
                            ),
                            Visibility(
                              visible: controller.order.value.status == Constant.orderCompleted ? true : false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: DsSpace.lg),
                                child: DsButton.tonal(
                                  label: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                                  icon: Icons.rate_review_outlined,
                                  expand: true,
                                  onPressed: () async {
                                    final result = await Get.to(() => RentalReviewScreen(), arguments: {'order': controller.order.value});

                                    // If review was submitted successfully
                                    if (result == true) {
                                      await controller.fetchDriverDetails();
                                    }
                                  },
                                ),
                              ),
                            ),
                            controller.order.value.status == Constant.orderCompleted || controller.order.value.status == Constant.orderCancelled
                                ? const SizedBox()
                                : Padding(
                                    padding: const EdgeInsets.only(top: DsSpace.lg),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: DsButton.secondary(
                                            label: "Call".tr,
                                            icon: Icons.call_outlined,
                                            expand: true,
                                            onPressed: () {
                                              Constant.makePhoneCall(controller.order.value.driver!.phoneNumber ?? '');
                                            },
                                          ),
                                        ),
                                        const DsGap(DsSpace.md),
                                        Expanded(
                                          child: DsButton.secondary(
                                            label: "Chat".tr,
                                            icon: Icons.chat_bubble_outline_rounded,
                                            expand: true,
                                            onPressed: () async {
                                              ShowToastDialog.showLoader("Please wait...".tr);

                                              UserModel? customer = await FireStoreUtils.getUserProfile(controller.order.value.authorID ?? '');
                                              UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.order.value.driverId ?? '');

                                              ShowToastDialog.closeLoader();

                                              Get.to(
                                                const ChatScreen(),
                                                arguments: {
                                                  "senderName": customer?.fullName(),
                                                  "receivedName": driverUser?.fullName(),
                                                  "orderId": controller.order.value.id,
                                                  "receivedId": driverUser?.id,
                                                  "senderId": customer?.id,
                                                  "senderProfileUrl": customer?.profilePictureURL,
                                                  "receivedProfileUrl": driverUser?.profilePictureURL,
                                                  "token": driverUser?.fcmToken,
                                                  "chatType": Constant.userRoleDriver,
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                    ],
                    if (controller.order.value.rentalVehicleType != null)
                      RentalInfoCard(
                        title: "Vehicle Type".tr,
                        icon: Icons.directions_car_filled_outlined,
                        child: Row(
                          children: [
                            DsImage(
                              url: controller.order.value.rentalVehicleType!.rentalVehicleIcon ?? "",
                              height: 50,
                              width: 50,
                              radius: DsRadius.sm,
                              errorIcon: Icons.directions_car_outlined,
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(controller.order.value.rentalVehicleType!.name ?? "", style: t.title),
                                  const DsGap(DsSpace.xxs),
                                  Text(controller.order.value.rentalVehicleType!.shortDescription ?? "", style: t.bodySecondary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const DsGap(DsSpace.lg),
                    RentalInfoCard(
                      title: "Rental Details".tr,
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RentalDetailRow(label: 'Rental Package'.tr, value: controller.order.value.rentalPackageModel!.name.toString().tr),
                          const DsDivider(spacing: DsSpace.xs),
                          RentalDetailRow(
                            label: 'Rental Package Price'.tr,
                            value: Constant.amountShow(amount: controller.order.value.rentalPackageModel!.baseFare.toString(), currency: controller.bookingCurrency).tr,
                          ),
                          const DsDivider(spacing: DsSpace.xs),
                          RentalDetailRow(
                            label: '${'Including'.tr} ${Constant.distanceType.tr}',
                            value: "${controller.order.value.rentalPackageModel!.includedDistance.toString()} ${Constant.distanceType}".tr,
                          ),
                          const DsDivider(spacing: DsSpace.xs),
                          RentalDetailRow(
                            label: 'Including Hours'.tr,
                            value: "${controller.order.value.rentalPackageModel!.includedHours.toString()} ${'Hr'.tr}".tr,
                          ),
                          const DsDivider(spacing: DsSpace.xs),
                          RentalDetailRow(label: '${'Extra'.tr} ${Constant.distanceType}', value: controller.getExtraKm()),
                          controller.order.value.endTime == null
                              ? const SizedBox()
                              : Column(
                                  children: [
                                    const DsDivider(spacing: DsSpace.xs),
                                    RentalDetailRow(
                                      label: 'Extra Minutes'.tr,
                                      value:
                                          "${controller.order.value.endTime == null ? "0" : (((controller.order.value.endTime!.toDate().difference(controller.order.value.startTime!.toDate()).inMinutes) - (int.parse(controller.order.value.rentalPackageModel!.includedHours.toString()) * 60)).clamp(0, double.infinity).toInt().toString())} ${'Min'.tr}",
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    RentalInfoCard(
                      title: "Order Summary".tr,
                      icon: Icons.receipt_long_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RentalSummaryRow(label: "Subtotal".tr, value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: controller.bookingCurrency)),
                          RentalSummaryRow(
                            label: "Discount".tr,
                            value: Constant.amountShow(amount: controller.discount.value.toString(), currency: controller.bookingCurrency),
                            tone: DsTone.danger,
                          ),
                          if (double.parse(controller.order.value.platformFee ?? '0.0') > 0)
                            RentalSummaryRow(label: "Platform fee".tr, value: Constant.amountShow(amount: controller.order.value.platformFee.toString(), currency: controller.bookingCurrency)),
                          RentalSummaryRow(
                            label: "Tax amount".tr,
                            value: Constant.amountShow(amount: (controller.taxAmount.value).toString(), currency: controller.bookingCurrency),
                            underline: true,
                            onTap: () {
                              showBillBifurcationDialog(context, controller);
                            },
                          ),

                          const DsDivider(spacing: DsSpace.md),
                          RentalSummaryRow(label: "Order Total".tr, value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: controller.bookingCurrency), emphasis: true),
                        ],
                      ),
                    ),
                  ]),
                ),
          bottomBar: controller.isLoading.value || (!showPay && !showCancel)
              ? null
              : DsStickyBar(
                  child: Row(
                    children: [
                      if (showPay)
                        Expanded(
                          child: DsButton.primary(
                            label: "Pay Now".tr,
                            icon: Icons.payments_outlined,
                            size: DsButtonSize.lg,
                            expand: true,
                            onPressed: () {
                              if (controller.order.value.endKitoMetersReading == null ||
                                  controller.order.value.endKitoMetersReading == "0.0" ||
                                  controller.order.value.endKitoMetersReading!.isEmpty) {
                                ShowToastDialog.showToast("You are not able to pay now until driver adds kilometer".tr);
                              } else {
                                Get.bottomSheet(paymentBottomSheet(controller), isScrollControlled: true, backgroundColor: Colors.transparent);
                              }
                            },
                          ),
                        ),
                      if (showPay && showCancel) const DsGap(DsSpace.md),
                      if (showCancel)
                        Expanded(
                          child: DsButton.dangerTonal(
                            label: "Cancel Booking",
                            icon: Icons.cancel_outlined,
                            size: DsButtonSize.lg,
                            expand: true,
                            onPressed: () {
                              controller.cancelRentalRequest(controller.order.value);
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

  Widget paymentBottomSheet(RentalOrderDetailsController controller) {
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
        final t = context.dsText;
        // Reads of controller observables happen in this lazily-run builder.
        return DsObserve(
          builder: (context) => RentalSheetShell(
            title: "Select Payment Method".tr,
            footer: DsButton.primary(
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
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                    controller.completeOrder();
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
            child: ListView(
              padding: EdgeInsets.zero,
              controller: scrollController,
              children: [
                Text("Preferred Payment".tr, textAlign: TextAlign.start, style: t.overline),
                const DsGap(DsSpace.sm),
                if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                  DsCard.outlined(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                    child: Column(
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
                  ),
                if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DsGap(DsSpace.lg),
                      Text("Other Payment Options".tr, textAlign: TextAlign.start, style: t.overline),
                      const DsGap(DsSpace.sm),
                    ],
                  ),
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
        );
      },
    );
  }

  Obx cardDecoration(RentalOrderDetailsController controller, PaymentGateway value, String image) {
    return Obx(
      () => RentalPaymentRow(
        image: image,
        name: value.name,
        selected: controller.selectedPaymentMethod.value == value.name,
        walletAmount: value.name == "wallet"
            ? Constant.amountShow(amount: Constant.userModel!.walletAmount == null ? '0.0' : Constant.userModel!.walletAmount.toString(), currency: RegionService.customerCurrency)
            : null,
        onTap: () {
          controller.selectedPaymentMethod.value = value.name;
        },
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, RentalOrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.percent_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RentalSummaryRow(label: "Tax on Order Total".tr, value: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: controller.bookingCurrency)),
              const DsDivider(spacing: DsSpace.md),
              RentalSummaryRow(label: "Tax on Platform Fee".tr, value: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: controller.bookingCurrency)),
              const DsDivider(spacing: DsSpace.md),
              RentalSummaryRow(label: "Total Tax Amount".tr, value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: controller.bookingCurrency), emphasis: true),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}
