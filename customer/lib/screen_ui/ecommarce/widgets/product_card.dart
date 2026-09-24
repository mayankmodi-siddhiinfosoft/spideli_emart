import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Product tile used by the e-commerce storefront, brand and category grids.
/// The vendor lookup and price/commission maths are unchanged – only the
/// presentation is DS.
class EcommerceProductCard extends StatelessWidget {
  final ProductModel productModel;

  const EcommerceProductCard({super.key, required this.productModel});

  /// Tile height for a grid of these cards: fixed media plus the text block at
  /// the current text scale, so nothing clips at 1.3x–2x.
  static double gridExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = scaler.scale(20) + scaler.scale(22) + scaler.scale(24);
    return _mediaHeight + text + DsSpace.xxl;
  }

  static const double _mediaHeight = 130;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FireStoreUtils.getVendorById(productModel.vendorID.toString()),
      builder: (context, vendorSnapshot) {
        if (vendorSnapshot.connectionState == ConnectionState.waiting) {
          return const ProductCardSkeleton();
        }
        if (!vendorSnapshot.hasData) {
          return const SizedBox(); // Show placeholder or loader
        }
        VendorModel? vendorModel = vendorSnapshot.data;
        String price = "0.0";
        String disPrice = "0.0";
        List<String> selectedVariants = [];
        List<String> selectedIndexVariants = [];
        List<String> selectedIndexArray = [];
        if (productModel.itemAttribute != null) {
          if (productModel.itemAttribute!.attributes!.isNotEmpty) {
            for (var element in productModel.itemAttribute!.attributes!) {
              if (element.attributeOptions!.isNotEmpty) {
                selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
                selectedIndexVariants.add('${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}');
                selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
              }
            }
          }

          if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
            price = Constant.productCommissionPrice(
              vendorModel!,
              productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0',
            );
            disPrice = "0";
          }
        } else {
          price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
          disPrice = double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
        }

        final c = context.dsColors;
        final t = context.dsText;

        return DsCard.outlined(
          padding: EdgeInsets.zero,
          semanticLabel: productModel.name,
          onTap: () async {
            Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _mediaHeight,
                width: double.infinity,
                child: DsImage(url: productModel.photo.toString(), radius: 0, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpace.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productModel.name!.capitalizeString(), textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                    const DsGap(DsSpace.xs),
                    disPrice == "" || disPrice == "0"
                        ? Text(
                          Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSm.withColor(c.brandStrong).tabular,
                        )
                        : Row(
                          children: [
                            Flexible(
                              child: Text(
                                Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySm.strike.tabular,
                              ),
                            ),
                            const DsGap(DsSpace.xs),
                            Flexible(
                              child: Text(
                                Constant.amountShow(amount: disPrice, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSm.withColor(c.brandStrong).tabular,
                              ),
                            ),
                          ],
                        ),
                    const DsGap(DsSpace.sm),
                    DsBadge(
                      label: "${Constant.calculateReview(reviewCount: productModel.reviewsCount.toString(), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsSum})",
                      tone: DsTone.warning,
                      icon: Icons.star_rounded,
                      small: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer placeholder matching [EcommerceProductCard].
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSkeleton.box(height: EcommerceProductCard._mediaHeight, radius: DsRadius.lg),
          const DsGap(DsSpace.sm),
          DsSkeleton.line(width: 110),
          const DsGap(DsSpace.sm),
          DsSkeleton.line(width: 70, height: 10),
        ],
      ),
    );
  }
}
