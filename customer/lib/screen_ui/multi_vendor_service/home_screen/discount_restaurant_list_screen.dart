import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/discount_restaurant_list_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

/// Archetype B — catalogue list, "voucher" variant. Each row is a coupon: a
/// photo stub with the discount flag, the store beside it and a torn-edge
/// code strip along the bottom.
class DiscountRestaurantListScreen extends StatelessWidget {
  const DiscountRestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DiscountRestaurantListController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final stores = controller.vendorList;
        return DsScaffold.collapsing(
          title: controller.title.value,
          subtitle: isLoading || stores.isEmpty ? null : '${stores.length} ${"Offers".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4, trailing: false))
            else if (stores.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.local_offer_outlined, title: "No offers right now".tr, message: "New deals appear here as soon as stores publish them.".tr),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final VendorModel vendorModel = stores[index];
                    final CouponModel offerModel = controller.couponList[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _OfferVoucherCard(vendorModel: vendorModel, offerModel: offerModel),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OfferVoucherCard extends StatelessWidget {
  final VendorModel vendorModel;
  final CouponModel offerModel;
  const _OfferVoucherCard({required this.vendorModel, required this.offerModel});

  String get _discountLabel =>
      "${offerModel.discountType == "Fix Price" ? (RegionService.currencyForVendorId(offerModel.vendorID) ?? Constant.currencyModel!).symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".toUpperCase().tr : " off".toUpperCase().tr}";

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      semanticLabel: vendorModel.title.toString(),
      onTap: () {
        Get.to(RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: DsRadius.brMd,
                      child: NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: 104, width: 104),
                    ),
                    Positioned(
                      top: DsSpace.xs,
                      left: DsSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 3),
                        decoration: BoxDecoration(color: c.brand, borderRadius: DsRadius.brPill),
                        child: Text(_discountLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.onBrand)),
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(vendorModel.title.toString(), textAlign: TextAlign.start, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm.w600),
                      const DsGap(DsSpace.xs),
                      Row(
                        children: [
                          SvgPicture.asset("assets/icons/ic_star.svg", width: 14, height: 14, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
                          const DsGap(DsSpace.xs),
                          Flexible(
                            child: Text(
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSm.withColor(c.brandStrong).tabular,
                            ),
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 15, color: c.textMuted),
                          const DsGap(DsSpace.xs),
                          Expanded(
                            child: Text(vendorModel.location.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Torn-edge coupon strip.
          Container(
            width: double.infinity,
            color: c.brandSoft,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 18, color: c.brandStrong),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text("Use code".tr, style: t.bodySm.withColor(c.brandStrong)),
                ),
                DottedBorder(
                  options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.xs), color: c.brandStrong, strokeWidth: 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                    child: Text("${offerModel.code}", textAlign: TextAlign.start, style: t.label.withColor(c.brandStrong).tabular),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
