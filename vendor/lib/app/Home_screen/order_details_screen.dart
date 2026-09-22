import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/product_rating_view_screen/product_rating_view_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/order_details_controller.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/widget/wholesale_tag.dart';

/// Order detail: a status hero, customer / items / bill / driver sections
/// (two panes on tablets) and the receipt + print actions in a sticky bar.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: OrderDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;

        if (controller.isLoading.value) {
          return DsScaffold(title: "Order Summary".tr, body: const DsSkeletonDetail(mediaHeight: 140));
        }

        final OrderModel order = controller.orderModel.value;
        final String status = order.status.toString();
        final DsTone statusTone = DsTone.fromStatus(status);

        // ---------------- Status hero ----------------
        final Widget statusHero = DsCard.gradient(
          gradient: DsGradients.tone(context, statusTone == DsTone.neutral ? DsTone.brand : statusTone),
          child: Row(
            children: [
              DsIconWell(icon: _statusIcon(statusTone), onBrand: true, size: 52),
              DsGap.lg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${"Order".tr} ${Constant.orderId(orderId: controller.orderModel.value.id.toString())}",
                      textAlign: TextAlign.start,
                      style: t.title.copyWith(color: Colors.white),
                    ),
                    const DsGap(DsSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: DsRadius.brPill),
                      child: Text(controller.orderModel.value.status.toString().tr, style: t.labelSm.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // ---------------- Customer ----------------
        final Widget customer = DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DsAvatar(imageUrl: controller.orderModel.value.author!.profilePictureURL.toString(), name: controller.orderModel.value.author!.fullName(), size: 48),
                  DsGap.md,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.orderModel.value.author!.fullName().toString().tr, style: t.titleSm),
                        const DsGap(DsSpace.xxs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(controller.orderModel.value.takeAway == true ? Icons.shopping_bag_outlined : Icons.location_on_outlined, size: 15, color: c.textMuted),
                            ),
                            DsGap.xs,
                            Expanded(
                              child: controller.orderModel.value.takeAway == true
                                  ? Text("Take Away".tr, style: t.bodySm)
                                  : Text(controller.orderModel.value.address?.getFullAddress() ?? ''.tr, style: t.bodySm),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.orderModel.value.scheduleTime != null) ...[
                DsGap.md,
                DsCard.tinted(
                  tone: DsTone.warning,
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                  radius: DsRadius.md,
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: c.warningStrong),
                      DsGap.sm,
                      Expanded(child: Text("Schedule Time".tr, style: t.bodySm.copyWith(color: c.textPrimary))),
                      Text(Constant.timestampToDateTime(controller.orderModel.value.scheduleTime!).tr, style: t.label.copyWith(color: c.warningStrong)),
                    ],
                  ),
                ),
              ],
              if (!(controller.orderModel.value.notes == null || controller.orderModel.value.notes!.isEmpty)) ...[
                DsGap.xs,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(
                    label: "View Remarks".tr,
                    icon: Icons.sticky_note_2_outlined,
                    size: DsButtonSize.sm,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return viewRemarkDialog(controller, isDark, controller.orderModel.value);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );

        // ---------------- Items ----------------
        final List<CartProductModel> products = controller.orderModel.value.products!;
        final Widget items = DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int index = 0; index < products.length; index++) ...[
                if (index > 0) Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.md), child: Divider(height: 1, thickness: 1, color: c.divider)),
                _productBlock(context, controller, products[index], isDark),
              ],
            ],
          ),
        );

        // ---------------- Bill ----------------
        final Widget bill = DsCard(
          child: Column(
            children: [
              /// Item Total
              amountRow(
                title: "Item totals".tr,
                amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.subTotal.value.toString()),
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              /// Coupon Discount
              amountRow(
                title: "Coupon Discount",
                amount: "- (${Constant.amountShow(currency: controller.orderCurrency, amount: controller.couponAmount.value.toString())})",
                isDark: isDark,
                amountColor: c.dangerStrong,
              ),

              /// Special Discount
              if (controller.orderModel.value.vendor?.specialDiscountEnable == true) ...[
                const SizedBox(height: 10),
                amountRow(
                  title: "Special Discount",
                  amount: "- (${Constant.amountShow(currency: controller.orderCurrency, amount: controller.specialDiscountAmount.value.toString())})",
                  isDark: isDark,
                  amountColor: c.dangerStrong,
                ),
              ],
              if (controller.orderModel.value.packagingChargeEnable == true) const SizedBox(height: 10),

              if (controller.orderModel.value.packagingChargeEnable == true)
                amountRow(
                  title: "Packaging charge",
                  amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.packagingCharge.value.toString()),
                  isDark: isDark,
                ),
              if (controller.orderModel.value.packagingChargeEnable == true) const SizedBox(height: 10),
              sectionDivider(isDark),

              /// Tax
              InkWell(
                borderRadius: DsRadius.brSm,
                onTap: () {
                  showBillBifurcationDialog(context, isDark, controller);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    child: amountRow(
                      title: "Tax amount",
                      amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.totalTaxAmount.value.toString()),
                      isDark: isDark,
                      textColour: c.brandStrong,
                      underline: true,
                    ),
                  ),
                ),
              ),

              sectionDivider(isDark),

              /// To Pay
              Container(
                padding: const EdgeInsets.all(DsSpace.md),
                decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brMd),
                child: Row(
                  children: [
                    Expanded(child: Text("To Pay".tr, style: t.titleSm)),
                    Text(
                      Constant.amountShow(currency: controller.orderCurrency, amount: controller.totalAmount.value.toString()),
                      style: t.title.tabular.copyWith(color: c.brandStrong),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // ---------------- Delivery man ----------------
        final bool showDriver =
            controller.orderModel.value.takeAway != true &&
            controller.orderModel.value.isPosOrder == false &&
            (controller.orderModel.value.status == Constant.orderCompleted || controller.orderModel.value.status == Constant.orderInTransit);
        final Widget? driver = showDriver
            ? DsCard(
                child: Row(
                  children: [
                    DsAvatar(imageUrl: controller.orderModel.value.driver?.profilePictureURL ?? '', name: controller.orderModel.value.driver?.fullName(), size: 44, fallbackIcon: Icons.delivery_dining_rounded),
                    DsGap.md,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.orderModel.value.driver?.fullName() ?? '', style: t.bodyStrong),
                          Text(controller.orderModel.value.driver?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                        ],
                      ),
                    ),
                    DsIconButton(
                      semanticLabel: "Call".tr,
                      variant: DsIconButtonVariant.brand,
                      size: 48,
                      onPressed: () {
                        Constant.makePhoneCall(controller.orderModel.value.driver?.phoneNumber ?? '');
                      },
                      child: SvgPicture.asset("assets/icons/ic_phone_call.svg", width: 22, height: 22, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
                    ),
                  ],
                ),
              )
            : null;

        Widget section(String? title, IconData? icon, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) DsSectionHeader(title: title, icon: icon, padding: const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.sm)),
            child,
          ],
        );

        final List<Widget> primaryColumn = [
          statusHero,
          section(null, null, Padding(padding: const EdgeInsets.only(top: DsSpace.lg), child: customer)),
          section("Items".tr, Icons.receipt_long_outlined, items),
        ];
        final List<Widget> secondaryColumn = [
          section("Bill details".tr, Icons.payments_outlined, bill),
          if (driver != null) section("Delivery Man Information".tr, Icons.delivery_dining_outlined, driver),
        ];

        final Widget content = l.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: DsFadeSlideIn.stagger(primaryColumn))),
                  DsGap.xl,
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: DsFadeSlideIn.stagger(secondaryColumn, delay: DsMotion.stagger * 2)),
                  ),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: DsFadeSlideIn.stagger([...primaryColumn, ...secondaryColumn]));

        return DsScaffold(
          title: "Order Summary".tr,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxl),
            child: content,
          ),
          bottomBar: DsStickyBar(
            maxWidth: DsLayout.wideMax,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DsButton.secondary(label: "Download receipt".tr, icon: Icons.download_rounded, onPressed: () => controller.downloadReceipt()),
                    ),
                    DsGap.md,
                    Expanded(
                      child: DsButton.primary(label: "Share receipt".tr, icon: Icons.ios_share_rounded, onPressed: () => controller.shareReceipt()),
                    ),
                  ],
                ),
                DsGap.sm,
                DsButton.tonal(
                  label: "Print Invoice".tr,
                  icon: Icons.print_outlined,
                  expand: true,
                  onPressed: () async {
                    controller.printTicket(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _statusIcon(DsTone tone) => switch (tone) {
    DsTone.success => Icons.task_alt_rounded,
    DsTone.danger => Icons.block_rounded,
    DsTone.warning => Icons.schedule_rounded,
    DsTone.info => Icons.local_shipping_outlined,
    _ => Icons.receipt_long_rounded,
  };

  Widget _productBlock(BuildContext context, OrderDetailsController controller, CartProductModel product, bool isDark) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
      child: Text(text, textAlign: TextAlign.start, style: t.bodySm),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("${product.quantity}x ${product.name}".tr, style: t.bodyStrong),
                  WholesaleTag(product: product, isDark: isDark),
                  product.taxSetting!.isEmpty
                      ? const SizedBox()
                      : Padding(
                          padding: const EdgeInsets.only(top: DsSpace.xxs),
                          child: Text(
                            "Tax: ${Constant.getTaxDisplayText(product.taxSetting, currency: controller.orderCurrency)}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: c.brandStrong),
                          ),
                        ),
                ],
              ),
            ),
            DsGap.md,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Constant.amountShow(currency: controller.orderCurrency, amount: (product.unitPrice * double.parse(product.quantity.toString())).toString()),
                  style: t.bodyStrong.tabular,
                ),
                Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: DsRadius.brXs,
                    splashColor: Colors.transparent,
                    onTap: () {
                      Get.to(const ProductRatingViewScreen(), arguments: {"orderModel": controller.orderModel.value, "productId": product.id});
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: c.warning),
                          const DsGap(DsSpace.xxs),
                          Text("View Ratings".tr, style: t.link.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!(product.variantInfo == null || product.variantInfo!.variantOptions!.isEmpty)) ...[
          const DsGap(DsSpace.xs),
          Text("Variants".tr.toUpperCase(), textAlign: TextAlign.start, style: t.overline),
          const DsGap(DsSpace.xs),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List.generate(product.variantInfo!.variantOptions!.length, (i) {
              return chip(
                "${product.variantInfo!.variantOptions!.keys.elementAt(i)} : ${product.variantInfo!.variantOptions![product.variantInfo!.variantOptions!.keys.elementAt(i)]}",
              );
            }).toList(),
          ),
        ],
        if (!(product.extras == null || product.extras!.isEmpty)) ...[
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Expanded(child: Text("Addons".tr.toUpperCase(), textAlign: TextAlign.start, style: t.overline)),
              Text(
                Constant.amountShow(currency: controller.orderCurrency, amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
                textAlign: TextAlign.start,
                style: t.labelSm.copyWith(color: c.brandStrong),
              ),
            ],
          ),
          const DsGap(DsSpace.xs),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List.generate(product.extras!.length, (i) {
              return chip(product.extras![i].toString());
            }).toList(),
          ),
        ],
      ],
    );
  }

  Dialog viewRemarkDialog(OrderDetailsController controller, isDark, OrderModel orderModel) {
    return Dialog(
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (context) {
          final t = context.dsText;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DsSpace.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const DsIconWell(icon: Icons.sticky_note_2_outlined),
                      DsGap.md,
                      Expanded(child: Text("View Remarks".tr, style: t.title)),
                    ],
                  ),
                  DsGap.xl,
                  Text(orderModel.notes.toString(), textAlign: TextAlign.start, style: t.bodyLg),
                  DsGap.xxl,
                  DsButton.secondary(
                    label: "Cancel".tr,
                    expand: true,
                    onPressed: () async {
                      Get.back();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget amountRow({required String title, required String amount, required bool isDark, Color? textColour, Color? amountColor, bool? underline, Widget? trailing}) {
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.tr,
                style: t.body.copyWith(
                  color: textColour ?? c.textSecondary,
                  decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: textColour ?? c.textSecondary,
                ),
              ),
            ),
            DsGap.sm,
            trailing ?? Text(amount, style: t.bodyStrong.tabular.copyWith(color: amountColor ?? c.textPrimary)),
          ],
        );
      },
    );
  }

  Widget sectionDivider(bool isDark) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, thickness: 1, color: context.dsColors.divider),
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, OrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        return Dialog(
          insetPadding: const EdgeInsets.all(DsSpace.lg),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.xxl, DsSpace.xxl, DsSpace.xxl, DsSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const DsIconWell(icon: Icons.receipt_long_outlined),
                      DsGap.md,
                      Expanded(child: Text("Tax Details".tr, style: t.title)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (controller.productTaxAmount.value > 0)
                    amountRow(
                      title: "Tax on item total",
                      amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.productTaxAmount.value.toString()),
                      isDark: isDark,
                    ),
                  if (controller.orderTaxAmount.value > 0)
                    amountRow(
                      title: "Tax on Order Total",
                      amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.orderTaxAmount.value.toString()),
                      isDark: isDark,
                    ),
                  sectionDivider(isDark),
                  if (controller.packagingTaxAmount.value > 0)
                    for (int index = 0; index < controller.orderModel.value.packagingTax!.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.xs),
                        child: amountRow(
                          title: "${controller.orderModel.value.packagingTax![index].title} ${'Tax on Packaging Fee'.tr}",
                          amount: Constant.amountShow(
                            currency: controller.orderCurrency,
                            amount: Constant.calculateTax(taxModel: controller.orderModel.value.packagingTax![index], amount: controller.packagingCharge.value.toString()).toString(),
                          ),
                          isDark: isDark,
                        ),
                      ),
                  if (controller.packagingTaxAmount.value > 0) const SizedBox(height: 10),
                  if (controller.packagingTaxAmount.value > 0) sectionDivider(isDark),

                  /// To Pay
                  amountRow(
                    title: "Total Tax Amount",
                    amount: Constant.amountShow(currency: controller.orderCurrency, amount: controller.totalTaxAmount.value.toString()),
                    amountColor: c.brandStrong,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DsButton.ghost(label: "Close".tr, onPressed: () => Navigator.pop(context)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
