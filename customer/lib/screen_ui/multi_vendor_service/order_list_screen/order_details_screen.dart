import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/order_details_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/order_receipt_pdf.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../chat_screens/chat_screen.dart';
import '../rate_us_screen/rate_product_screen.dart';
import 'live_tracking_screen.dart';

/// Archetype F (detail) — status hero, a journey timeline, the itemised
/// order, a bill card and the primary action in a sticky bar.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OrderDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value;
        // Snapshot the order once, inside the tracked builder, so nothing
        // lazily built below has to read an observable.
        final OrderModel order = controller.orderModel.value;
        final String status = order.status.toString();
        final bool isEcommerce = Constant.sectionConstantModel!.serviceTypeFlag == 'ecommerce-service';
        final CurrencyModel? currency = RegionService.currencyForRecord(order.regionId);

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(
            title: "Order Details".tr,
            actions: [
              // PDF receipt: download / share (spec 7.6).
              if (!isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: DsSpace.sm),
                  child: DsButton.ghost(
                    label: "Receipt".tr,
                    icon: Icons.receipt_long_outlined,
                    size: DsButtonSize.sm,
                    onPressed: () => OrderReceiptPdf.showOptions(context, () => OrderReceiptPdf.fromOrder(controller)),
                  ),
                ),
            ],
          ),
          bottomBar: status == Constant.orderShipped || status == Constant.orderInTransit || status == Constant.orderCompleted
              ? DsStickyBar(
                  child: status == Constant.orderShipped || status == Constant.orderInTransit
                      ? isEcommerce
                            ? const SizedBox()
                            : DsButton.primary(
                                label: "Track Order".tr,
                                icon: Icons.near_me_outlined,
                                size: DsButtonSize.lg,
                                expand: true,
                                onPressed: () async {
                                  Get.to(const LiveTrackingScreen(), arguments: {"orderModel": order});
                                },
                              )
                      : DsButton.primary(
                          label: "Reorder".tr,
                          icon: Icons.refresh_rounded,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () async {
                            for (var element in order.products!) {
                              await controller.addToCart(cartProductModel: element);
                              ShowToastDialog.showToast("Item Added In a cart".tr);
                            }
                          },
                        ),
                )
              : null,
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonDetail(mediaHeight: 120))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      // ---------- status hero ----------
                      DsCard.tinted(
                        tone: DsTone.fromStatus(status),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${'Order'.tr} ${Constant.orderId(orderId: order.id.toString())}".tr,
                                    style: t.title.tabular,
                                  ),
                                  const DsGap(DsSpace.xs),
                                  Text(Constant.timestampToDateTime(order.createdAt!), style: t.caption),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.md),
                            DsStatusChip(
                              label: status.tr,
                              status: status,
                              pulse: status == Constant.orderShipped || status == Constant.orderInTransit,
                            ),
                          ],
                        ),
                      ),

                      // ---------- courier (e-commerce shipments) ----------
                      if (isEcommerce &&
                          (status == Constant.orderShipped || status == Constant.orderInTransit || status == Constant.orderCompleted || status == Constant.orderCancelled))
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.md),
                          child: DsCard.tinted(
                            tone: DsTone.info,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Courier company name :  ${order.courierCompanyName}", style: t.titleSm),
                                const DsGap(DsSpace.xxs),
                                Text("Tracking ID :  ${order.courierTrackingId}", style: t.bodySm.tabular),
                              ],
                            ),
                          ),
                        ),

                      // ---------- pickup / journey ----------
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.md),
                        child: order.takeAway == true
                            ? DsCard(
                                child: _VendorRow(order: order, status: status),
                              )
                            : DsCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DsTimeline(
                                      steps: [
                                        DsTimelineStep(
                                          title: "${order.vendor!.title}",
                                          subtitle: "${order.vendor!.location}",
                                          state: DsStepState.done,
                                          icon: Icons.storefront_rounded,
                                          content: _ContactActions(order: order, status: status),
                                        ),
                                        DsTimelineStep(
                                          title: "${order.address!.addressAs}",
                                          subtitle: order.address!.getFullAddress(),
                                          state: status == Constant.orderCompleted
                                              ? DsStepState.done
                                              : status == Constant.orderRejected || status == Constant.orderCancelled
                                              ? DsStepState.error
                                              : DsStepState.current,
                                          icon: Icons.place_rounded,
                                        ),
                                      ],
                                    ),
                                    if (status != Constant.orderRejected) _DriverBlock(order: order, status: status),
                                  ],
                                ),
                              ),
                      ),

                      // ---------- items ----------
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.lg),
                        child: DsSectionHeader(title: "Your Order".tr, padding: EdgeInsets.zero),
                      ),
                      const DsGap(DsSpace.sm),
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: order.products!.length,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            CartProductModel cartProductModel = order.products![index];
                            return _ProductTile(order: order, cartProductModel: cartProductModel, currency: currency);
                          },
                          separatorBuilder: (context, index) => const DsDivider(spacing: DsSpace.md),
                        ),
                      ),

                      // if (controller.orderModel.value.takeAway != true &&
                      //     controller.orderModel.value.status ==
                      //         Constant.orderCompleted)
                      //   Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       Text(
                      //         "Delivery Man".tr,
                      //       ),
                      //     ],
                      //   ),

                      // ---------- bill ----------
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.lg),
                        child: DsSectionHeader(title: "Bill Details".tr, icon: Icons.receipt_outlined, padding: EdgeInsets.zero),
                      ),
                      const DsGap(DsSpace.sm),
                      DsCard(
                        child: Column(
                          children: [
                            _billRow(context, title: "Item totals".tr, amount: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: currency)),
                            const DsDivider(spacing: DsSpace.md),
                            _billRow(
                              context,
                              title: "Coupon Discount".tr,
                              amount: "- (${Constant.amountShow(amount: controller.couponAmount.value.toString(), currency: currency)})",
                              amountColor: c.dangerStrong,
                            ),
                            if (order.vendor?.specialDiscountEnable == true && Constant.specialDiscountOffer == true) ...[
                              const DsGap(DsSpace.md),
                              _billRow(
                                context,
                                title: "Special Discount".tr,
                                amount: "- (${Constant.amountShow(amount: controller.specialDiscountAmount.value.toString(), currency: currency)})",
                                amountColor: c.dangerStrong,
                              ),
                            ],
                            if (order.packagingChargeEnable == true) ...[
                              const DsGap(DsSpace.md),
                              _billRow(context, title: "Packaging charge".tr, amount: Constant.amountShow(amount: controller.packagingCharge.value.toString(), currency: currency)),
                            ],
                            if (order.takeAway != true) ...[
                              const DsGap(DsSpace.md),
                              (order.vendor?.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true)
                                  ? _billRow(context, title: "Delivery Fee".tr, amount: 'Free Delivery'.tr, amountColor: c.successStrong, strongTitle: true)
                                  : _billRow(
                                      context,
                                      title: "Delivery Fee".tr,
                                      amount: Constant.amountShow(amount: controller.deliveryCharges.value.toString(), currency: currency),
                                      strongTitle: true,
                                    ),
                              const DsGap(DsSpace.md),
                              _billRow(context, title: "Delivery Tips".tr, amount: Constant.amountShow(amount: controller.deliveryTips.toString(), currency: currency)),
                            ],
                            if (order.platformFee != '0.0' && order.platformFee != '0' && order.platformFee != null) ...[
                              const DsGap(DsSpace.md),
                              _billRow(context, title: "Platform fee".tr, amount: Constant.amountShow(amount: controller.platformFee.value.toString(), currency: currency)),
                            ],
                            const DsDivider(spacing: DsSpace.md),
                            InkWell(
                              onTap: () {
                                showBillBifurcationDialog(context, controller);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                                child: _billRow(
                                  context,
                                  title: "Tax amount".tr,
                                  amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString(), currency: currency),
                                  underline: true,
                                ),
                              ),
                            ),
                            const DsDivider(spacing: DsSpace.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Text("To Pay".tr, style: t.titleSm)),
                                const DsGap(DsSpace.md),
                                Text(Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: currency), style: t.title.tabular.withColor(c.brandStrong)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ---------- meta ----------
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.lg),
                        child: DsSectionHeader(title: "Order Details".tr, icon: Icons.info_outline_rounded, padding: EdgeInsets.zero),
                      ),
                      const DsGap(DsSpace.sm),
                      DsCard(
                        child: Column(
                          children: [
                            _billRow(
                              context,
                              title: "Delivery type".tr,
                              amount: order.takeAway == true
                                  ? "TakeAway".tr
                                  : order.scheduleTime == null
                                  ? "Standard".tr
                                  : "Schedule".tr,
                              amountColor: order.scheduleTime != null ? c.brandStrong : null,
                            ),
                            const DsGap(DsSpace.md),
                            _billRow(context, title: "Payment Method".tr, amount: order.paymentMethod.toString()),
                            const DsGap(DsSpace.md),
                            _billRow(context, title: "Date and Time".tr, amount: Constant.timestampToDateTime(order.createdAt!)),
                            const DsGap(DsSpace.md),
                            _billRow(context, title: "Phone Number".tr, amount: order.author!.phoneNumber.toString()),
                          ],
                        ),
                      ),

                      // ---------- remarks ----------
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.lg),
                          child: DsSectionHeader(title: "Remarks".tr, icon: Icons.sticky_note_2_outlined, padding: EdgeInsets.zero),
                        ),
                        const DsGap(DsSpace.sm),
                        DsCard.tinted(
                          tone: DsTone.neutral,
                          child: Text(order.notes.toString(), style: t.body),
                        ),
                      ],
                    ]),
                  ),
                ),
        );
      },
    );
  }

  /// Label / value row used by the bill and the meta card.
  Widget _billRow(BuildContext context, {required String title, required String amount, Color? amountColor, bool underline = false, bool strongTitle = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: (strongTitle ? t.body : t.bodySecondary).copyWith(decoration: underline ? TextDecoration.underline : TextDecoration.none, decorationColor: c.textSecondary),
          ),
        ),
        const DsGap(DsSpace.md),
        Text(amount, textAlign: TextAlign.end, style: t.bodyStrong.tabular.withColor(amountColor ?? c.textPrimary)),
      ],
    );
  }

  void showBillBifurcationDialog(BuildContext context, OrderDetailsController controller) {
    final OrderModel order = controller.orderModel.value;
    final CurrencyModel? currency = RegionService.currencyForRecord(order.regionId);
    showDialog(
      context: context,
      builder: (context) {
        final t = context.dsText;
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.percent_rounded,
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              order.taxScope == 'product'
                  ? _billRow(context, title: "Tax on item total".tr, amount: Constant.amountShow(amount: controller.productTaxAmount.value.toString(), currency: currency))
                  : _billRow(context, title: "Tax on Order Total".tr, amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: currency)),
              if (order.takeAway != true && order.vendor?.isSelfDelivery != true && Constant.driverDeliveryTaxList!.isNotEmpty == true) const DsDivider(spacing: DsSpace.md),
              if (order.takeAway != true && order.vendor?.isSelfDelivery != true)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: order.driverDeliveryTax?.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.sm),
                      child: _billRow(
                        context,
                        title: "${order.driverDeliveryTax![index].title} ${'Tax on Delivery Fee'.tr}",
                        amount: Constant.amountShow(
                          amount: Constant.calculateTax(taxModel: order.driverDeliveryTax![index], amount: (controller.deliveryCharges.value).toString()).toString(),
                          currency: currency,
                        ),
                      ),
                    );
                  },
                ),
              if (order.takeAway != true && order.packagingTax?.isNotEmpty == true) const DsDivider(spacing: DsSpace.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: order.packagingTax!.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.sm),
                    child: _billRow(
                      context,
                      title: "${order.packagingTax![index].title} ${'Tax on Packaging Fee'.tr}",
                      amount: controller.packagingCharge.value == 0.0
                          ? Constant.amountShow(amount: controller.packagingCharge.value.toString(), currency: currency)
                          : Constant.amountShow(
                              amount: Constant.calculateTax(taxModel: order.packagingTax![index], amount: controller.packagingCharge.value.toString()).toString(),
                              currency: currency,
                            ),
                    ),
                  );
                },
              ),
              if (order.platformTax?.isNotEmpty == true) const DsDivider(spacing: DsSpace.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: order.platformTax!.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.sm),
                    child: _billRow(
                      context,
                      title: "${order.platformTax?[index].title} ${'Tax on Platform Fee'.tr}",
                      amount: Constant.amountShow(
                        amount: controller.platformFee.value == 0.0
                            ? Constant.calculateTax(amount: controller.platformFee.value.toString()).toString()
                            : Constant.calculateTax(taxModel: order.platformTax![index], amount: controller.platformFee.value.toString()).toString(),
                        currency: currency,
                      ),
                    ),
                  );
                },
              ),
              const DsDivider(spacing: DsSpace.md),
              Row(
                children: [
                  Expanded(child: Text("Total Tax Amount".tr, style: t.titleSm)),
                  const DsGap(DsSpace.md),
                  Text(
                    Constant.amountShow(amount: controller.totalTaxAmount.value.toString(), currency: currency),
                    style: t.titleSm.tabular.withColor(context.dsColors.brandStrong),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Store row for take-away orders: name, address and the contact actions.
class _VendorRow extends StatelessWidget {
  final OrderModel order;
  final String status;

  const _VendorRow({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      children: [
        DsIconWell(icon: Icons.storefront_rounded, tone: DsTone.brand),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${order.vendor!.title}", style: t.titleSm.withColor(c.brandStrong)),
              const DsGap(DsSpace.xxs),
              Text("${order.vendor!.location}", style: t.bodySm),
            ],
          ),
        ),
        _ContactActions(order: order, status: status),
      ],
    );
  }
}

/// Call / chat with the store. Hidden for placed, rejected and completed
/// orders, exactly as before.
class _ContactActions extends StatelessWidget {
  final OrderModel order;
  final String status;

  const _ContactActions({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    final bool hidden = status == Constant.orderPlaced || status == Constant.orderRejected || status == Constant.orderCompleted;
    if (hidden) return const SizedBox();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIconButton(
          semanticLabel: "Call Now".tr,
          variant: DsIconButtonVariant.outlined,
          child: SvgPicture.asset("assets/icons/ic_phone_call.svg", width: 20, height: 20),
          onPressed: () {
            Constant.makePhoneCall(order.vendor!.phonenumber.toString());
          },
        ),
        const DsGap(DsSpace.sm),
        DsIconButton(
          semanticLabel: "Chat".tr,
          variant: DsIconButtonVariant.outlined,
          child: SvgPicture.asset("assets/icons/ic_wechat.svg", width: 20, height: 20),
          onPressed: () async {
            ShowToastDialog.showLoader("Please wait...".tr);

            UserModel? customer = await FireStoreUtils.getUserProfile(order.authorID.toString());
            UserModel? restaurantUser = await FireStoreUtils.getUserProfile(order.vendor!.author.toString());
            VendorModel? vendorModel = await FireStoreUtils.getVendorById(restaurantUser!.vendorID.toString());
            ShowToastDialog.closeLoader();

            Get.to(
              const ChatScreen(),
              arguments: {
                "senderName": customer!.fullName(),
                "receivedName": vendorModel!.title,
                "orderId": order.id,
                "receivedId": restaurantUser.id,
                "senderId": customer.id,
                "senderProfileUrl": customer.profilePictureURL,
                "receivedProfileUrl": vendorModel.photo,
                "token": restaurantUser.fcmToken,
                "chatType": Constant.userRoleVendor,
              },
            );
          },
        ),
      ],
    );
  }
}

/// Delivered note / preparation note / driver card, under the journey.
class _DriverBlock extends StatelessWidget {
  final OrderModel order;
  final String status;

  const _DriverBlock({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    Widget body;
    if (status == Constant.orderCompleted && order.driver != null) {
      body = Row(
        children: [
          SvgPicture.asset("assets/icons/ic_check_small.svg"),
          const DsGap(DsSpace.sm),
          Expanded(
            child: Text("${order.driver!.fullName()} ${"Order Delivered.".tr}", style: t.bodyStrong),
          ),
        ],
      );
    } else if (status == Constant.orderAccepted || status == Constant.driverPending) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset("assets/icons/ic_timer.svg"),
          const DsGap(DsSpace.sm),
          Expanded(
            child: Text(
              "${'Your Order has been Preparing and assign to the driver'.tr}\n${'Preparation Time'.tr} ${order.estimatedTimeToPrepare}".tr,
              style: t.bodyStrong.withColor(c.warningStrong),
            ),
          ),
        ],
      );
    } else if (order.driver != null) {
      body = Row(
        children: [
          DsAvatar(imageUrl: order.author!.profilePictureURL.toString(), name: order.driver!.fullName(), size: 44, ring: true),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.driver!.fullName().toString(), style: t.titleSm),
                Text(order.driver!.email.toString(), style: t.caption.withColor(c.successStrong)),
              ],
            ),
          ),
          DsIconButton(
            semanticLabel: "Call Now".tr,
            variant: DsIconButtonVariant.outlined,
            child: SvgPicture.asset("assets/icons/ic_phone_call.svg", width: 20, height: 20),
            onPressed: () {
              Constant.makePhoneCall(order.driver!.phoneNumber.toString());
            },
          ),
          const DsGap(DsSpace.sm),
          DsIconButton(
            semanticLabel: "Chat".tr,
            variant: DsIconButtonVariant.outlined,
            child: SvgPicture.asset("assets/icons/ic_wechat.svg", width: 20, height: 20),
            onPressed: () async {
              ShowToastDialog.showLoader("Please wait...".tr);

              UserModel? customer = await FireStoreUtils.getUserProfile(order.authorID.toString());
              UserModel? restaurantUser = await FireStoreUtils.getUserProfile(order.driverID.toString());

              ShowToastDialog.closeLoader();

              Get.to(
                const ChatScreen(),
                arguments: {
                  "senderName": customer!.fullName(),
                  "receivedName": restaurantUser?.fullName(),
                  "orderId": order.id,
                  "receivedId": restaurantUser?.id,
                  "senderId": customer.id,
                  "senderProfileUrl": customer.profilePictureURL,
                  "receivedProfileUrl": restaurantUser?.profilePictureURL,
                  "token": restaurantUser?.fcmToken,
                  "chatType": Constant.userRoleDriver,
                },
              );
            },
          ),
        ],
      );
    } else {
      return const SizedBox();
    }

    return Column(
      children: [
        const DsDivider(spacing: DsSpace.md),
        body,
      ],
    );
  }
}

/// One ordered product: photo, name, quantity, price, variants, add-ons and
/// the "Rate us" action.
class _ProductTile extends StatelessWidget {
  final OrderModel order;
  final CartProductModel cartProductModel;
  final CurrencyModel? currency;

  const _ProductTile({required this.order, required this.cartProductModel, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool discounted =
        double.parse(cartProductModel.discountPrice == null || cartProductModel.discountPrice?.isEmpty == true ? "0.0" : cartProductModel.discountPrice.toString()) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsImage(url: cartProductModel.photo.toString(), width: 56, height: 56, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text("${cartProductModel.name}", style: t.bodyLg)),
                      const DsGap(DsSpace.sm),
                      Text("x ${cartProductModel.quantity}", style: t.bodyLg.tabular.withColor(c.textSecondary)),
                    ],
                  ),
                  const DsGap(DsSpace.xxs),
                  discounted
                      ? Row(
                          children: [
                            Text(Constant.amountShow(amount: cartProductModel.discountPrice.toString(), currency: currency), style: t.titleSm.tabular),
                            const DsGap(DsSpace.sm),
                            Text(
                              Constant.amountShow(amount: cartProductModel.price, currency: currency),
                              style: t.bodySm.tabular.withColor(c.textMuted).strike,
                            ),
                          ],
                        )
                      : Text(Constant.amountShow(amount: cartProductModel.price, currency: currency), style: t.titleSm.tabular),
                  if (cartProductModel.isWholesale == true)
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xs),
                      child: DsBadge(
                        small: true,
                        tone: DsTone.brand,
                        label: (cartProductModel.wholesaleMinQty ?? '').isEmpty
                            ? 'Wholesale price'.tr
                            : "${'Wholesale price'.tr} · ${'from'.tr} ${cartProductModel.wholesaleMinQty} ${'pcs'.tr}",
                      ),
                    ),
                  if (Constant.taxScope == "product")
                    cartProductModel.taxSetting?.isEmpty == true
                        ? const SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(top: DsSpace.xs),
                            child: Text(
                              "${'Tax:'.tr} ${Constant.getTaxDisplayText(cartProductModel.taxSetting, currency: currency)}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.withColor(c.infoStrong),
                            ),
                          ),
                ],
              ),
            ),
          ],
        ),
        if (cartProductModel.variantInfo != null && cartProductModel.variantInfo!.variantOptions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Variants".tr, style: t.label.withColor(c.textSecondary)),
                const DsGap(DsSpace.sm),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: List.generate(cartProductModel.variantInfo!.variantOptions!.length, (i) {
                    return DsBadge(
                      label:
                          "${cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)} : ${cartProductModel.variantInfo!.variantOptions![cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)]}",
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        if (cartProductModel.extras != null && cartProductModel.extras!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Addons".tr, style: t.label.withColor(c.textSecondary))),
                    const DsGap(DsSpace.sm),
                    Text(
                      Constant.amountShow(
                        amount: (double.parse(cartProductModel.extrasPrice.toString()) * double.parse(cartProductModel.quantity.toString())).toString(),
                        currency: currency,
                      ),
                      style: t.bodyStrong.tabular.withColor(c.brandStrong),
                    ),
                  ],
                ),
                const DsGap(DsSpace.sm),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: List.generate(cartProductModel.extras!.length, (i) {
                    return DsBadge(label: cartProductModel.extras![i].toString());
                  }).toList(),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: DsButton.tonal(
            label: "Rate us".tr,
            icon: Icons.star_rounded,
            size: DsButtonSize.sm,
            onPressed: () async {
              Get.to(const RateProductScreen(), arguments: {"orderModel": order, "productId": cartProductModel.id});
            },
          ),
        ),
      ],
    );
  }
}
