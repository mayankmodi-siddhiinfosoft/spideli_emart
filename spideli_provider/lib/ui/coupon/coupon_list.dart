import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/coupon_controller.dart';
import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/coupon/add_or_update_coupon.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Coupon list (archetype K): ticket cards – a tinted discount stub, a
/// perforated edge, then the code, validity and status. Drawer tab of the
/// dashboard, and it already had a Scaffold, so it keeps exactly one.
class CouponList extends StatelessWidget {
  const CouponList({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetBuilder<CouponController>(
        init: CouponController(),
        builder: (controller) {
          final l = context.dsLayout;
          return DsScaffold(
            maxContentWidth: DsLayout.wideMax,
            body: DsAsync(
              isLoading: false,
              isEmpty: controller.couponModel.isEmpty,
              empty: DsEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: "Coupon not found".tr,
                message: 'Create a coupon to give your customers a discount.'.tr,
              ),
              builder: (_) => GridView.builder(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.huge + DsSpace.xxl),
                gridDelegate: DsLayout.gridDelegate(maxItemWidth: 460, mainAxisExtent: 176),
                itemCount: controller.couponModel.length,
                scrollDirection: Axis.vertical,
                itemBuilder: (context, index) {
                  CouponModel couponModel = controller.couponModel[index];
                  return DsFadeSlideIn(
                    index: index,
                    child: _CouponTicket(
                      couponModel: couponModel,
                      index: index,
                      onTap: () {
                        Get.to(AddOrUpdateCouponScreen(), arguments: {'couponModel': couponModel})!.then((value) {
                          if (value != null) {
                            controller.getCouponData();
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Get.to(AddOrUpdateCouponScreen())!.then((value) {
                  if (value != null) {
                    controller.getCouponData();
                  }
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: Text("Add Coupon".tr),
            ),
          );
        });
  }
}

/// One ticket-style coupon card: discount stub + perforation + details.
class _CouponTicket extends StatelessWidget {
  final CouponModel couponModel;
  final int index;
  final VoidCallback onTap;

  const _CouponTicket({required this.couponModel, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DateTime expiresAt = couponModel.expiresAt!.toDate();
    final bool isExpired = expiresAt.isBefore(DateTime.now());
    final String discount = couponModel.discountType == "Fix Price"
        ? (currencyData!.symbolatright == true)
            ? "${couponModel.discount}${currencyData!.symbol.toString()}"
            : "${currencyData!.symbol.toString()}${couponModel.discount}"
        : "${couponModel.discount} %";

    return DsCard.outlined(
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel: couponModel.code,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Discount stub.
            Container(
              width: 104,
              color: isExpired ? c.surfaceAlt : c.brandSoft,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.md),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      discount,
                      maxLines: 1,
                      style: t.headline.withColor(isExpired ? c.textMuted : c.brandStrong).tabular,
                    ),
                  ),
                  const DsGap(DsSpace.xxs),
                  Text(
                    "OFF".tr,
                    style: t.overline.withColor(isExpired ? c.textMuted : c.brandStrong),
                  ),
                ],
              ),
            ),
            const _Perforation(),
            // Details.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: DsRadius.brSm,
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              couponModel.code!,
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.label.withColor(c.brandStrong).copyWith(letterSpacing: 1.2),
                            ),
                          ),
                        ),
                        const DsGap(DsSpace.sm),
                        _CouponThumb(imageUrl: couponModel.image ?? '', index: index),
                      ],
                    ),
                    const DsGap(DsSpace.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_outlined, size: 16, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Expanded(
                          child: Text(
                            "This offer is expire on".tr + " " + dateFormatDDMMMYYYY(couponModel.expiresAt!.toDate().toString())!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption,
                          ),
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.sm),
                    DsStatusChip(
                      label: isExpired ? 'Expired'.tr : 'Active'.tr,
                      tone: isExpired ? DsTone.danger : DsTone.success,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "tear here" edge between the stub and the coupon body.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SizedBox(
      width: 13,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int dots = (constraints.maxHeight / 10).floor().clamp(1, 20);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < dots; i++)
                      Container(
                        width: 2,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 2.5),
                        decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Coupon artwork with the app's alternating offer placeholders as fallback.
class _CouponThumb extends StatelessWidget {
  final String imageUrl;
  final int index;

  const _CouponThumb({required this.imageUrl, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    Widget placeholder() => Image(
          image: index % 2 == 0 ? const AssetImage("assets/images/offer_placeholder_1.png") : const AssetImage("assets/images/offer_placeholder_2.png"),
          fit: BoxFit.cover,
        );
    return ClipRRect(
      borderRadius: DsRadius.brSm,
      child: SizedBox(
        width: 44,
        height: 36,
        child: imageUrl.isEmpty
            ? placeholder()
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => placeholder(),
                placeholder: (context, url) => Container(color: c.shimmerBase),
              ),
      ),
    );
  }
}
