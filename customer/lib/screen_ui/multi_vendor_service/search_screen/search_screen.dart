import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/search_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

/// Archetype B — catalogue search. A pinned search field under the app bar,
/// then two clearly separated result groups: dense store rows with a square
/// thumbnail, and item rows with the photo on the trailing edge.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  bool get _isRestaurantSection => Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true;

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SearchScreenController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final List<VendorModel> stores = controller.vendorSearchList.toList();
        final List<ProductModel> products = controller.productSearchList.toList();
        final bool nothingFound = stores.isEmpty && products.isEmpty;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(
            title: _isRestaurantSection ? "Find your favorite products and nearby stores" : "Search Item & Store".tr,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.md),
                child: DsSearchBar(
                  hint: _isRestaurantSection ? 'Find your favorite products and nearby stores'.tr : 'Search the store and item'.tr,
                  controller: null,
                  onChanged: (value) {
                    controller.onSearchTextChanged(value);
                  },
                ),
              ),
            ),
          ),
          body: isLoading
              ? const DsSkeletonList(itemCount: 6)
              : nothingFound
              ? DsEmptyState(
                  icon: Icons.search_rounded,
                  title: "Search Item & Store".tr,
                  message: _isRestaurantSection ? 'Find your favorite products and nearby stores'.tr : 'Search the store and item'.tr,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxl),
                  children: [
                    if (stores.isNotEmpty) ...[
                      DsSectionHeader(title: "Store".tr, icon: Icons.storefront_outlined, subtitle: '${stores.length} ${"Results".tr}'),
                      ...List.generate(stores.length, (index) {
                        final VendorModel vendorModel = stores[index];
                        return DsFadeSlideIn(
                          index: index,
                          child: _StoreResultRow(
                            vendorModel: vendorModel,
                            onTap: () {
                              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                            },
                          ),
                        );
                      }),
                    ],
                    if (products.isNotEmpty) ...[
                      DsSectionHeader(title: "Items".tr, icon: Icons.restaurant_menu_outlined, subtitle: '${products.length} ${"Results".tr}'),
                      ...List.generate(products.length, (index) {
                        final ProductModel productModel = products[index];
                        return DsFadeSlideIn(
                          index: index,
                          child: _ProductResultRow(
                            productModel: productModel,
                            priceFuture: getPrice(productModel),
                            onTap: () async {
                              await FireStoreUtils.getVendorById(productModel.vendorID.toString()).then((value) {
                                if (value != null) {
                                  Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value});
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> getPrice(ProductModel productModel) async {
    String price = "0.0";
    String disPrice = "0.0";
    List<String> selectedVariants = [];
    List<String> selectedIndexVariants = [];
    List<String> selectedIndexArray = [];

    print("=======>");
    print(productModel.price);
    print(productModel.disPrice);

    VendorModel? vendorModel = await FireStoreUtils.getVendorById(productModel.vendorID.toString());
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
        price = Constant.productCommissionPrice(vendorModel!, productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0');
        disPrice = Constant.productCommissionPrice(vendorModel, '0');
      }
    } else {
      price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
      disPrice = Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
    }

    return {'price': price, 'disPrice': disPrice};
  }
}

/// Dense store hit: square photo, name, address and rating / distance chips.
class _StoreResultRow extends StatelessWidget {
  final VendorModel vendorModel;
  final VoidCallback onTap;
  const _StoreResultRow({required this.vendorModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: vendorModel.title.toString(),
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsImage(url: vendorModel.photo.toString(), width: 84, height: 84, radius: DsRadius.md, errorIcon: Icons.storefront_outlined),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                Text(vendorModel.location.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                const DsGap(DsSpace.sm),
                Wrap(
                  spacing: DsSpace.xs,
                  runSpacing: DsSpace.xs,
                  children: [
                    if (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true)
                      DsBadge(label: "Free Delivery".tr, tone: DsTone.success, icon: Icons.delivery_dining_outlined, small: true),
                    DsBadge(
                      label:
                          "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                      tone: DsTone.warning,
                      icon: Icons.star_rounded,
                      small: true,
                    ),
                    DsBadge(
                      label:
                          "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                      tone: DsTone.info,
                      icon: Icons.place_outlined,
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item hit: veg/non-veg marker, name, price pair, rating and description with
/// the photo anchored on the trailing edge.
class _ProductResultRow extends StatelessWidget {
  final ProductModel productModel;
  final Future<Map<String, dynamic>> priceFuture;
  final VoidCallback onTap;
  const _ProductResultRow({required this.productModel, required this.priceFuture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return FutureBuilder(
      future: priceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DsSkeletonList(itemCount: 1, carded: true, trailing: false, padding: EdgeInsets.only(bottom: DsSpace.md));
        } else {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: t.bodySm));
          } else if (snapshot.data == null) {
            return const SizedBox();
          } else {
            Map<String, dynamic> map = snapshot.data!;
            String price = map['price'];
            String disPrice = map['disPrice'];
            return DsCard.outlined(
              onTap: onTap,
              semanticLabel: productModel.name.toString(),
              margin: const EdgeInsets.only(bottom: DsSpace.md),
              padding: const EdgeInsets.all(DsSpace.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Constant.sectionConstantModel!.isProductDetails == false
                            ? const SizedBox()
                            : productModel.nonveg == true || productModel.veg == true
                            ? Row(
                                children: [
                                  productModel.nonveg == true ? SvgPicture.asset("assets/icons/ic_nonveg.svg") : SvgPicture.asset("assets/icons/ic_veg.svg"),
                                  const DsGap(DsSpace.xs),
                                  Text(productModel.nonveg == true ? "Non Veg.".tr : "Pure veg.".tr, style: t.labelSm.withColor(productModel.nonveg == true ? c.dangerStrong : c.successStrong)),
                                ],
                              )
                            : const SizedBox(),
                        const DsGap(DsSpace.xs),
                        Text(productModel.name.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                        const DsGap(DsSpace.xs),
                        double.parse(disPrice) <= 0
                            ? Text(
                                Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                style: t.titleSm.tabular.withColor(c.brandStrong),
                              )
                            : Row(
                                children: [
                                  Text(
                                    Constant.amountShow(amount: disPrice, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                    style: t.titleSm.tabular.withColor(c.brandStrong),
                                  ),
                                  const DsGap(DsSpace.xs),
                                  Text(
                                    Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                    style: t.bodySm.tabular.strike,
                                  ),
                                ],
                              ),
                        const DsGap(DsSpace.xs),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 15, color: c.warning),
                            const DsGap(DsSpace.xs),
                            Text(
                              "${Constant.calculateReview(reviewCount: productModel.reviewsCount!.toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsCount!.toStringAsFixed(0)})",
                              style: t.bodySm.tabular,
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.xs),
                        Text("${productModel.description}", maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  DsImage(url: productModel.photo.toString(), width: 96, height: 96, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
                ],
              ),
            );
          }
        }
      },
    );
  }
}
