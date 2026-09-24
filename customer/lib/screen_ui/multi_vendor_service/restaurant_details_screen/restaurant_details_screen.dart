import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/restaurant_details_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../utils/wholesale_pricing.dart';
import '../../../widget/shop_widgets.dart';
import '../../subscriptions/store_plans_section.dart';
import '../cart_screen/cart_screen.dart';
import '../dine_in_screeen/dine_in_details_screen.dart';
import '../review_list_screen/review_list_screen.dart';

/// Archetype B — store detail. Full-bleed photo hero with floating controls,
/// an overlapping identity card (name, rating, open/closed, timings), then the
/// Delivery/TakeAway switch, offers, plans and the menu with category
/// accordions. A sticky "View cart" bar appears as soon as the cart has items.
class RestaurantDetailsScreen extends StatelessWidget {
  const RestaurantDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RestaurantDetailsController(),
      autoRemove: false,
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isDark = context.dsIsDark;

        // Every observable this screen reacts to is read here, inside the
        // tracked builder (child widgets/builders get plain values).
        final bool isLoading = controller.isLoading.value;
        final VendorModel vendor = controller.vendorModel.value;
        final bool isOpen = controller.isOpen.value;
        final bool isVeg = controller.isVag.value;
        final bool isNonVeg = controller.isNonVag.value;
        final int cartCount = cartItem.length;
        final List<CouponModel> coupons = controller.couponList.toList();
        final List<dynamic>? photos = vendor.photos;
        final double heroHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(220.0, 360.0);

        return DsScaffold(
          maxContentWidth: null,
          bottomBar: cartCount == 0
              ? null
              : DsStickyBar(
                  child: DsPressable(
                    onTap: () {
                      Get.to(const CartScreen());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.lg),
                      decoration: BoxDecoration(
                        gradient: DsGradients.brand(context),
                        borderRadius: DsRadius.brLg,
                        boxShadow: DsShadows.glow(context, color: c.brand),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$cartCount ${"items".tr}', style: t.bodyStrong.withColor(c.onBrand)),
                          Row(
                            children: [
                              Text('View Cart'.tr, style: t.label.withColor(c.onBrand)),
                              const DsGap(DsSpace.xs),
                              Icon(Icons.arrow_forward_rounded, size: 18, color: c.onBrand),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: heroHeight,
                floating: true,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: c.brand,
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                title: Row(
                  children: [
                    DsIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back'.tr,
                      variant: DsIconButtonVariant.plain,
                      color: Colors.white,
                      onPressed: () {
                        Get.back();
                      },
                    ),
                    const Expanded(child: SizedBox()),
                    if (vendor.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true) ...[
                      DsBadge(label: "Free Delivery".tr, tone: DsTone.success, style: DsBadgeStyle.solid, icon: Icons.delivery_dining_outlined, small: true),
                      const DsGap(DsSpace.sm),
                    ],
                    // Favourite state is observable: its own observer keeps the
                    // heart in sync without rebuilding the bar.
                    Obx(() {
                      final bool favourite = controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty;
                      return DsIconButton(
                        semanticLabel: "Favourite Store".tr,
                        variant: DsIconButtonVariant.plain,
                        onPressed: () async {
                          if (controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty) {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.removeWhere((item) => item.restaurantId == controller.vendorModel.value.id);
                            await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                          } else {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.add(favouriteModel);
                            await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                          }
                        },
                        child: favourite
                            ? SvgPicture.asset("assets/icons/ic_like_fill.svg", colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))
                            : SvgPicture.asset("assets/icons/ic_like.svg"),
                      );
                    }),
                    Obx(
                      () => DsIconButton(
                        semanticLabel: 'View Cart'.tr,
                        variant: DsIconButtonVariant.plain,
                        badgeCount: cartItem.length,
                        onPressed: () {
                          Get.to(const CartScreen());
                        },
                        child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", width: 24, height: 24, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                      ),
                    ),
                  ],
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _StoreHeroMedia(controller: controller, vendor: vendor, photos: photos, height: heroHeight),
                ),
              ),
              if (isLoading)
                const SliverToBoxAdapter(child: DsSkeletonDetail(mediaHeight: 0))
              else ...[
                DsSliverResponsive(
                  top: DsSpace.lg,
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        _StoreIdentityCard(vendor: vendor, isOpen: isOpen, controller: controller),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.lg),
                          // The toggle owns its own observer so the selection
                          // animates without rebuilding the page.
                          child: Obx(() => OrderTypeToggle(value: controller.orderType.value, isDark: isDark, onChanged: controller.setOrderType)),
                        ),
                        if (vendor.dineInActive == true || (vendor.openDineTime != null && vendor.openDineTime!.isNotEmpty))
                          _TableBookingCard(
                            onTap: () {
                              Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                            },
                          )
                        else
                          const SizedBox(),
                        if (coupons.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DsSectionHeader(
                                title: "Additional Offers".tr,
                                icon: Icons.local_offer_outlined,
                                padding: const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.sm),
                              ),
                              CouponListView(controller: controller),
                            ],
                          )
                        else
                          const SizedBox(),
                        StorePlansSection(vendor: vendor),
                        DsSectionHeader(title: "Menu".tr, icon: Icons.menu_book_outlined),
                        DsSearchBar(
                          controller: controller.searchEditingController.value,
                          hint: 'Search the item and more...'.tr,
                          onChanged: (value) {
                            controller.searchProduct(value);
                          },
                        ),
                        if (Constant.sectionConstantModel!.isProductDetails == false)
                          const SizedBox()
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.md),
                            child: Row(
                              children: [
                                _DietChip(
                                  asset: "assets/icons/ic_veg.svg",
                                  label: 'Veg'.tr,
                                  selected: isVeg,
                                  onTap: () {
                                    if (controller.isVag.value == true) {
                                      controller.isVag.value = false;
                                    } else {
                                      controller.isVag.value = true;
                                    }
                                    controller.filterRecord();
                                  },
                                ),
                                const DsGap(DsSpace.sm),
                                _DietChip(
                                  asset: "assets/icons/ic_nonveg.svg",
                                  label: 'Non Veg'.tr,
                                  selected: isNonVeg,
                                  onTap: () {
                                    if (controller.isNonVag.value == true) {
                                      controller.isNonVag.value = false;
                                    } else {
                                      controller.isNonVag.value = true;
                                    }
                                    controller.filterRecord();
                                  },
                                ),
                              ],
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                DsSliverResponsive(
                  top: DsSpace.lg,
                  bottom: DsSpace.xxl,
                  sliver: SliverToBoxAdapter(child: ProductListView(controller: controller)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future timeShowBottomSheet(BuildContext context, RestaurantDetailsController productModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => StatefulBuilder(
        builder: (context1, setState) {
          final c = DsColors.of(context1);
          final t = DsTextTheme(c);
          return DsSheet(
            title: "View Timings".tr,
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: productModel.vendorModel.value.workingHours!.length,
                  itemBuilder: (context, dayIndex) {
                    WorkingHours workingHours = productModel.vendorModel.value.workingHours![dayIndex];
                    return DsCard.outlined(
                      margin: const EdgeInsets.only(bottom: DsSpace.md),
                      padding: const EdgeInsets.all(DsSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${workingHours.day}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                          const DsGap(DsSpace.sm),
                          workingHours.timeslot == null || workingHours.timeslot!.isEmpty
                              ? const SizedBox()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: workingHours.timeslot!.length,
                                  itemBuilder: (context, timeIndex) {
                                    Timeslot timeSlotModel = workingHours.timeslot![timeIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: _SlotBox(label: timeSlotModel.from.toString())),
                                          const DsGap(DsSpace.sm),
                                          Icon(Icons.arrow_forward_rounded, size: 16, color: c.textMuted),
                                          const DsGap(DsSpace.sm),
                                          Expanded(child: _SlotBox(label: timeSlotModel.to.toString())),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlotBox extends StatelessWidget {
  final String label;
  const _SlotBox({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md, horizontal: DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
      child: Center(child: Text(label, style: t.bodySm.tabular)),
    );
  }
}

/// Hero media: the store photo carousel (or a single photo) under a scrim,
/// with page dots.
class _StoreHeroMedia extends StatelessWidget {
  final RestaurantDetailsController controller;
  final VendorModel vendor;
  final List<dynamic>? photos;
  final double height;
  const _StoreHeroMedia({required this.controller, required this.vendor, required this.photos, required this.height});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    // Child build: observe so `pageController` / `currentPage` reads here stay
    // reactive (the parent observer has already returned).
    return DsObserve(
      builder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          photos == null || photos!.isEmpty
              ? DsImage(url: vendor.photo.toString(), fit: BoxFit.cover, radius: 0, errorIcon: Icons.storefront_outlined)
              : PageView.builder(
                  physics: const BouncingScrollPhysics(),
                  controller: controller.pageController.value,
                  scrollDirection: Axis.horizontal,
                  itemCount: photos!.length,
                  padEnds: false,
                  pageSnapping: true,
                  allowImplicitScrolling: true,
                  itemBuilder: (BuildContext context, int index) {
                    String image = photos![index];
                    return DsImage(url: image.toString(), fit: BoxFit.cover, radius: 0, errorIcon: Icons.storefront_outlined);
                  },
                ),
          const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
          if (photos != null && photos!.isNotEmpty)
            Positioned(
              bottom: DsSpace.md,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(photos!.length, (index) {
                  // Own observer per dot: `currentPage` changes as the hero pages.
                  return Obx(
                    () => AnimatedContainer(
                      duration: DsMotion.of(context, DsMotion.fast),
                      margin: const EdgeInsets.only(right: DsSpace.xs),
                      height: 8,
                      width: controller.currentPage.value == index ? 20 : 8,
                      decoration: BoxDecoration(borderRadius: DsRadius.brPill, color: controller.currentPage.value == index ? c.brand : Colors.white70),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Name, address, rating and open/closed state — the card that overlaps the
/// hero and anchors the page.
class _StoreIdentityCard extends StatelessWidget {
  final VendorModel vendor;
  final bool isOpen;
  final RestaurantDetailsController controller;
  const _StoreIdentityCard({required this.vendor, required this.isOpen, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headline),
                    const DsGap(DsSpace.xxs),
                    Text(vendor.location.toString(), style: t.bodySm),
                  ],
                ),
              ),
              const DsGap(DsSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                    decoration: BoxDecoration(color: c.warningSoft, borderRadius: DsRadius.brPill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: c.warningStrong),
                        const DsGap(DsSpace.xxs),
                        Text(
                          Constant.calculateReview(reviewCount: vendor.reviewsCount.toString(), reviewSum: vendor.reviewsSum.toString()),
                          style: t.labelSm.tabular.withColor(c.warningStrong),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xxs),
                  DsButton.ghost(
                    label: "${vendor.reviewsCount} ${'Ratings'.tr}",
                    size: DsButtonSize.sm,
                    trailingIcon: Icons.chevron_right_rounded,
                    onPressed: () {
                      Get.to(const ReviewListScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                    },
                  ),
                ],
              ),
            ],
          ),
          if (Constant.sectionConstantModel!.serviceTypeFlag == "ecommerce-service")
            const SizedBox()
          else ...[
            const DsGap(DsSpace.md),
            Row(
              children: [
                DsStatusChip(label: isOpen ? "Open".tr : "Close".tr, tone: isOpen ? DsTone.success : DsTone.danger, pulse: isOpen),
                const DsGap(DsSpace.md),
                DsButton.ghost(
                  label: "View Timings".tr,
                  size: DsButtonSize.sm,
                  icon: Icons.schedule_rounded,
                  onPressed: () {
                    if (controller.vendorModel.value.workingHours!.isEmpty) {
                      ShowToastDialog.showToast("Timing is not added by store".tr);
                    } else {
                      const RestaurantDetailsScreen().timeShowBottomSheet(context, controller);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TableBookingCard extends StatelessWidget {
  final VoidCallback onTap;
  const _TableBookingCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsSectionHeader(
          title: "Also applicable on table booking".tr,
          icon: Icons.table_restaurant_outlined,
          padding: const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.sm),
        ),
        DsCard.tinted(
          onTap: onTap,
          semanticLabel: "Table Booking".tr,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset("assets/images/ic_table.gif", height: 52),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Table Booking".tr, style: t.titleSm),
                    Text("Quick Confirmations".tr, style: t.caption),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.brandStrong),
            ],
          ),
        ),
      ],
    );
  }
}

class _DietChip extends StatelessWidget {
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DietChip({required this.asset, required this.label, required this.selected, required this.onTap});

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
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
          decoration: BoxDecoration(
            color: selected ? c.brandSoft : c.surfaceAlt,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(asset, height: 20, width: 20),
              const DsGap(DsSpace.sm),
              Text(label, style: t.label.withColor(selected ? c.brandStrong : c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class CouponListView extends StatelessWidget {
  final RestaurantDetailsController controller;

  const CouponListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.couponList.length,
        itemBuilder: (BuildContext context, int index) {
          CouponModel offerModel = controller.couponList[index];
          return Padding(
            padding: const EdgeInsets.only(right: DsSpace.md),
            child: DsCard.outlined(
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 280,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 68,
                      decoration: const BoxDecoration(
                        image: DecorationImage(image: AssetImage("assets/images/offer_gif.gif"), fit: BoxFit.fill),
                      ),
                      child: Center(
                        child: Text(
                          offerModel.discountType == "Fix Price"
                              ? Constant.amountShow(amount: offerModel.discount, currency: RegionService.currencyForVendor(controller.vendorModel.value))
                              : "${offerModel.discount}%",
                          textAlign: TextAlign.center,
                          style: t.labelSm.withColor(Colors.white),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(offerModel.description.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                            const DsGap(DsSpace.xs),
                            DsPressable(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: offerModel.code.toString())).then((value) {
                                  ShowToastDialog.showToast("Copied".tr);
                                });
                              },
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(offerModel.code.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.brandStrong)),
                                  ),
                                  const DsGap(DsSpace.xs),
                                  SvgPicture.asset("assets/icons/ic_copy.svg"),
                                  const SizedBox(height: 12, child: VerticalDivider()),
                                  Flexible(
                                    child: Text(Constant.timestampToDateTime(offerModel.expiresAt!), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductListView extends StatelessWidget {
  final RestaurantDetailsController controller;

  const ProductListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final isDark = context.dsIsDark;
    // Child build: observe so the category list read below stays reactive.
    return DsObserve(
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: controller.vendorCategoryList.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryList[index];
          return Obx(() {
            final List<ProductModel> categoryProducts = controller.productList.where((p0) => p0.categoryID == vendorCategoryModel.id).toList();
            // Categories are loaded for the whole catalogue; hide the ones the
            // Delivery / TakeAway filter (or the search) leaves empty.
            if (categoryProducts.isEmpty) return const SizedBox.shrink();
            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                childrenPadding: EdgeInsets.zero,
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: c.brandStrong,
                collapsedIconColor: c.textSecondary,
                initiallyExpanded: true,
                title: Row(
                  children: [
                    Expanded(child: Text(vendorCategoryModel.title.toString(), style: t.title)),
                    DsBadge(label: "${categoryProducts.length}", small: true),
                  ],
                ),
                children: [
                  ListView.builder(
                    itemCount: categoryProducts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) => _productItem(context, isDark, categoryProducts[index]),
                  ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _productItem(BuildContext context, bool isDark, ProductModel productModel) {
    final c = DsColors.of(context);
    final t = DsTextTheme(c);
    String price = "0.0";
    String disPrice = "0.0";
    String? defaultVariantId;
    List<String> selectedVariants = [];
    if (productModel.itemAttribute != null) {
      if (productModel.itemAttribute!.attributes!.isNotEmpty) {
        for (var element in productModel.itemAttribute!.attributes!) {
          if (element.attributeOptions!.isNotEmpty) {
            selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
          }
        }
      }
      final Variants? defaultVariant = productModel.itemAttribute!.variants!.firstWhereOrNull((element) => element.variantSku == selectedVariants.join('-'));
      if (defaultVariant != null) {
        price = Constant.productCommissionPrice(controller.vendorModel.value, defaultVariant.variantPrice ?? '0');
        disPrice = "0";
        defaultVariantId = defaultVariant.variantId;
      }
    } else {
      price = Constant.productCommissionPrice(controller.vendorModel.value, productModel.price.toString());
      disPrice = double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(controller.vendorModel.value, productModel.disPrice.toString());
    }

    final currency = RegionService.currencyForVendor(controller.vendorModel.value);
    // Retail + wholesale tiers side by side (spec 8.2), in the store's currency.
    final List<PriceBand> bands = WholesalePricing.bands(
      retail: WholesalePricing.retailPrice(productModel, controller.vendorModel.value, variantId: defaultVariantId),
      tiers: WholesalePricing.customerTiers(productModel, controller.vendorModel.value, variantId: defaultVariantId),
      wholesaleOnly: productModel.isWholesaleOnly,
    );
    final bool businessOnly = productModel.isBusinessOnlyProduct;
    final int minQty = productModel.minOrderQuantity;
    final bool hasOptions = selectedVariants.isNotEmpty || (productModel.addOnsTitle != null && productModel.addOnsTitle!.isNotEmpty);
    final bool canBuy = controller.isOpen.value == true && Constant.userModel != null && !businessOnly;

    /// Opens the options sheet (variants / add-ons), prefilled from the cart.
    void openOptions() {
      controller.selectedVariants.clear();
      controller.selectedIndexVariants.clear();
      controller.selectedIndexArray.clear();
      controller.selectedAddOns.clear();
      controller.quantity.value = 1;
      if (productModel.itemAttribute != null) {
        if (productModel.itemAttribute!.attributes!.isNotEmpty) {
          for (var element in productModel.itemAttribute!.attributes!) {
            if (element.attributeOptions!.isNotEmpty) {
              controller.selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
              controller.selectedIndexVariants.add('${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}');
              controller.selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
            }
          }
        }
        final String cartId =
            "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}";
        final CartProductModel? element = cartItem.firstWhereOrNull((product) => product.id == cartId);
        if (element != null) {
          controller.quantity.value = element.quantity!;
          if (element.extras != null) {
            for (var extra in element.extras!) {
              controller.selectedAddOns.add(extra);
            }
          }
        }
      } else {
        final CartProductModel? element = cartItem.firstWhereOrNull((product) => product.id == "${productModel.id}");
        if (element != null) {
          controller.quantity.value = element.quantity!;
          if (element.extras != null) {
            for (var extra in element.extras!) {
              controller.selectedAddOns.add(extra);
            }
          }
        }
      }
      // Wholesale-only products start at their minimum quantity.
      if (controller.quantity.value < minQty) controller.quantity.value = minQty;
      controller.update();
      controller.calculatePrice(productModel);
      productDetailsBottomSheet(context, productModel);
    }

    /// Adds a product without options at its minimum quantity (or +1 when already in the cart).
    void addSimple() {
      final CartProductModel? inCart = cartItem.firstWhereOrNull((p0) => p0.id == productModel.id);
      final int target = inCart == null ? minQty : (inCart.quantity ?? 0) + 1;
      if (target <= (productModel.quantity ?? 0) || (productModel.quantity ?? 0) == -1) {
        controller.addToCart(productModel: productModel, price: price, discountPrice: disPrice, isIncrement: true, quantity: target);
      } else {
        ShowToastDialog.showToast("Out of stock".tr);
      }
    }

    void addToCartFromInfo() => hasOptions ? openOptions() : addSimple();

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        : Row(
                            children: [
                              productModel.nonveg == true ? SvgPicture.asset("assets/icons/ic_nonveg.svg") : SvgPicture.asset("assets/icons/ic_veg.svg"),
                              const DsGap(DsSpace.xs),
                              Text(productModel.nonveg == true ? "Non Veg.".tr : "Pure veg.".tr, style: t.labelSm.withColor(productModel.nonveg == true ? c.dangerStrong : c.successStrong)),
                            ],
                          ),
                    const DsGap(DsSpace.xs),
                    Text(productModel.name.toString(), style: t.titleSm),
                    const DsGap(DsSpace.xxs),
                    // Wholesale-only products hide the retail price.
                    if (!productModel.isWholesaleOnly)
                      double.parse(disPrice) <= 0
                          ? Text(
                              Constant.amountShow(amount: price, currency: currency),
                              style: t.titleSm.tabular.withColor(c.brandStrong),
                            )
                          : Row(
                              children: [
                                Text(
                                  Constant.amountShow(amount: disPrice, currency: currency),
                                  style: t.titleSm.tabular.withColor(c.brandStrong),
                                ),
                                const DsGap(DsSpace.xs),
                                Text(
                                  Constant.amountShow(amount: price, currency: currency),
                                  style: t.bodySm.tabular.strike,
                                ),
                              ],
                            ),
                    if (productModel.isWholesaleOnly || bands.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                        child: PriceTiersView(bands: bands, currency: currency, isDark: isDark, compact: true),
                      ),
                    if (businessOnly)
                      _note(context, "Business customers only".tr, c.dangerStrong)
                    else if (productModel.isWholesaleOnly)
                      _note(context, "${'Wholesale only'.tr} · ${'Minimum order'.tr}: $minQty ${'pcs'.tr}", c.brandStrong)
                    else if (productModel.hasWholesaleTier && productModel.wholesaleBlockedForCustomer)
                      _note(context, "Wholesale prices for Business customers only".tr, c.textMuted),
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
                    const DsGap(DsSpace.xxs),
                    Text("${productModel.description}", maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                    const DsGap(DsSpace.xs),
                    // "Info" opens the details dropdown on the card (spec 7.3).
                    DsPressable(
                      onTap: () {
                        controller.expandedProductId.value = controller.expandedProductId.value == productModel.id ? '' : (productModel.id ?? '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, color: c.brandStrong, size: 18),
                            const DsGap(DsSpace.sm),
                            Text("Info".tr, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.label.withColor(c.brandStrong)),
                            Obx(
                              () => AnimatedRotation(
                                duration: DsMotion.of(context, DsMotion.fast),
                                turns: controller.expandedProductId.value == productModel.id ? 0.5 : 0,
                                child: Icon(Icons.keyboard_arrow_down_rounded, color: c.brandStrong, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const DsGap(DsSpace.md),
              SizedBox(
                width: 140,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: DsRadius.brMd,
                      child: Stack(
                        children: [
                          DsImage(url: productModel.photo.toString(), fit: BoxFit.cover, height: 140, width: 140, radius: 0, errorIcon: Icons.fastfood_outlined),
                          const Positioned.fill(
                            child: DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Obx(() {
                        final bool favourite = controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty;
                        return DsIconButton(
                          semanticLabel: "Favourite Item".tr,
                          variant: DsIconButtonVariant.plain,
                          size: 32,
                          onPressed: () async {
                            if (controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty) {
                              FavouriteItemModel favouriteModel = FavouriteItemModel(productId: productModel.id, storeId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                              await FireStoreUtils.removeFavouriteItem(favouriteModel);
                            } else {
                              FavouriteItemModel favouriteModel = FavouriteItemModel(productId: productModel.id, storeId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteItemList.add(favouriteModel);
                              await FireStoreUtils.setFavouriteItem(favouriteModel);
                            }
                          },
                          child: favourite ? SvgPicture.asset("assets/icons/ic_like_fill.svg") : SvgPicture.asset("assets/icons/ic_like.svg"),
                        );
                      }),
                    ),
                    canBuy == false
                        ? const SizedBox()
                        : Positioned(
                            bottom: DsSpace.xs,
                            left: 0,
                            right: 0,
                            child: hasOptions
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: PlusButton(isDark: isDark, onTap: openOptions),
                                  )
                                : Obx(
                                    () => cartItem.where((p0) => p0.id == productModel.id).isNotEmpty
                                        ? _QuantityStepper(
                                            quantity: cartItem.where((p0) => p0.id == productModel.id).first.quantity.toString(),
                                            onRemove: () {
                                              final int next = cartItem.where((p0) => p0.id == productModel.id).first.quantity! - 1;
                                              // Below the minimum quantity the line is removed.
                                              controller.addToCart(productModel: productModel, price: price, discountPrice: disPrice, isIncrement: false, quantity: next < minQty ? 0 : next);
                                            },
                                            onAdd: addSimple,
                                          )
                                        : Align(
                                            alignment: Alignment.centerRight,
                                            child: PlusButton(isDark: isDark, onTap: addSimple),
                                          ),
                                  ),
                          ),
                  ],
                ),
              ),
            ],
          ),
          Obx(
            () => AnimatedSize(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.standard,
              alignment: Alignment.topCenter,
              child: controller.expandedProductId.value == productModel.id && productModel.id != null
                  ? _infoPanel(context, isDark, productModel, bands, canBuy, addToCartFromInfo)
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.xxs),
      child: Text(text, style: DsTypography.labelSm.copyWith(color: color)),
    );
  }

  Future productDetailsBottomSheet(BuildContext context, ProductModel productModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: StatefulBuilder(
          builder: (context1, setState) {
            return ProductDetailsView(productModel: productModel);
          },
        ),
      ),
    );
  }

  /// Product details as an expandable dropdown on the card (replaces the
  /// former "Info" popup): images, name, prices (retail + wholesale tiers),
  /// rating, store name and address, description, additional details and an
  /// Add to cart button.
  Widget _infoPanel(BuildContext context, bool isDark, ProductModel productModel, List<PriceBand> bands, bool canBuy, VoidCallback onAdd) {
    final c = DsColors.of(context);
    final t = DsTextTheme(c);
    final currency = RegionService.currencyForVendor(controller.vendorModel.value);
    final List<String> images = <String>[
      if ((productModel.photo ?? '').isNotEmpty) productModel.photo!,
      ...?productModel.photos?.map((e) => e.toString()).where((e) => e.isNotEmpty && e != productModel.photo),
    ];
    final TextStyle labelStyle = t.bodySm;
    final TextStyle valueStyle = t.bodyStrong;
    final bool showDetails = Constant.sectionConstantModel?.isProductDetails != false;

    Widget detailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            Text(value, style: valueStyle.tabular),
          ],
        ),
      );
    }

    Widget heading(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xs),
        child: Text(text, style: t.label),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: DsRadius.brLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                itemBuilder: (context, i) => DsImage(url: images[i], height: 110, width: 110, fit: BoxFit.cover, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
              ),
            ),
          const DsGap(DsSpace.md),
          Text(productModel.name ?? '', style: t.titleSm),
          const DsGap(DsSpace.xs),
          if (bands.isNotEmpty) PriceTiersView(bands: bands, currency: currency, isDark: isDark),
          if (productModel.isBusinessOnlyProduct)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.xs),
              child: _note(context, "Business customers only".tr, c.dangerStrong),
            ),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: c.warning),
              const DsGap(DsSpace.xs),
              Text(
                "${Constant.calculateReview(reviewCount: (productModel.reviewsCount ?? 0).toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${(productModel.reviewsCount ?? 0).toStringAsFixed(0)} ${'Ratings'.tr})",
                style: valueStyle.tabular,
              ),
            ],
          ),
          heading("Store".tr),
          Text(controller.vendorModel.value.title ?? '', style: valueStyle),
          if ((controller.vendorModel.value.location ?? '').isNotEmpty) Text(controller.vendorModel.value.location!, style: labelStyle),
          if ((productModel.description ?? '').isNotEmpty) ...[heading("Description".tr), Text(productModel.description!, style: labelStyle)],
          if (showDetails && ((productModel.grams ?? 0) != 0 || (productModel.calories ?? 0) != 0 || (productModel.proteins ?? 0) != 0 || (productModel.fats ?? 0) != 0)) ...[
            heading("Additional details".tr),
            if ((productModel.grams ?? 0) != 0) detailRow("Gram".tr, productModel.grams.toString()),
            if ((productModel.calories ?? 0) != 0) detailRow("Calories".tr, productModel.calories.toString()),
            if ((productModel.proteins ?? 0) != 0) detailRow("Proteins".tr, productModel.proteins.toString()),
            if ((productModel.fats ?? 0) != 0) detailRow("Fats".tr, productModel.fats.toString()),
          ],
          if (productModel.productSpecification != null && productModel.productSpecification!.isNotEmpty) ...[
            heading("Specification".tr),
            ...productModel.productSpecification!.entries.map((e) => detailRow(e.key, e.value.toString())),
          ],
          if (productModel.brandId != null && productModel.brandId!.isNotEmpty && controller.getBrandName(productModel.brandId!).isNotEmpty) ...[
            heading("Brand".tr),
            Text(controller.getBrandName(productModel.brandId!), style: valueStyle),
          ],
          if (canBuy) ...[const DsGap(DsSpace.md), DsButton.primary(label: "Add to cart".tr, icon: Icons.add_shopping_cart_rounded, expand: true, onPressed: onAdd)],
        ],
      ),
    );
  }
}

/// Inline +/- stepper drawn over the product photo.
class _QuantityStepper extends StatelessWidget {
  final String quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  const _QuantityStepper({required this.quantity, required this.onRemove, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brPill, boxShadow: DsShadows.sm(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsIconButton(icon: Icons.remove_rounded, semanticLabel: 'Remove'.tr, size: 30, onPressed: onRemove),
          Text(quantity, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
          DsIconButton(icon: Icons.add_rounded, semanticLabel: 'Add item'.tr, size: 30, onPressed: onAdd),
        ],
      ),
    );
  }
}

/// Variant / add-on picker sheet with a quantity stepper and the live total.
class ProductDetailsView extends StatelessWidget {
  final ProductModel productModel;

  const ProductDetailsView({super.key, required this.productModel});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RestaurantDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsScaffold(
          backgroundColor: c.surfaceRaised,
          maxContentWidth: DsLayout.contentMax,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.md),
                  child: Row(
                    children: [
                      DsImage(url: productModel.photo.toString(), height: 72, width: 72, fit: BoxFit.cover, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(productModel.name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                                ),
                                Obx(() {
                                  final bool favourite = controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty;
                                  return DsIconButton(
                                    semanticLabel: "Favourite Item".tr,
                                    variant: DsIconButtonVariant.plain,
                                    size: 32,
                                    onPressed: () async {
                                      if (controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty) {
                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                          productId: productModel.id,
                                          storeId: controller.vendorModel.value.id,
                                          userId: FireStoreUtils.getCurrentUid(),
                                        );
                                        controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                                        await FireStoreUtils.removeFavouriteItem(favouriteModel);
                                      } else {
                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                          productId: productModel.id,
                                          storeId: controller.vendorModel.value.id,
                                          userId: FireStoreUtils.getCurrentUid(),
                                        );
                                        controller.favouriteItemList.add(favouriteModel);

                                        await FireStoreUtils.setFavouriteItem(favouriteModel);
                                      }
                                    },
                                    child: favourite
                                        ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                        : SvgPicture.asset("assets/icons/ic_like.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                                  );
                                }),
                              ],
                            ),
                            Text(productModel.description.toString(), style: t.bodySm),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const DsDivider(spacing: 0),
                const DsGap(DsSpace.md),
                productModel.itemAttribute == null || productModel.itemAttribute!.attributes!.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                        itemCount: productModel.itemAttribute!.attributes!.length,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          String title = "";
                          for (var element in controller.attributesList) {
                            if (productModel.itemAttribute!.attributes![index].attributeId == element.id) {
                              title = element.title.toString();
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.md),
                            child: DsCard.outlined(
                              padding: const EdgeInsets.all(DsSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  productModel.itemAttribute!.attributes![index].attributeOptions!.isNotEmpty
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(title, overflow: TextOverflow.ellipsis, style: t.titleSm),
                                            Text("Required • Select any 1 option".tr, overflow: TextOverflow.ellipsis, style: t.caption),
                                            const DsDivider(spacing: DsSpace.md),
                                          ],
                                        )
                                      : const Offstage(),
                                  Wrap(
                                    spacing: DsSpace.sm,
                                    runSpacing: DsSpace.sm,
                                    children: List.generate(productModel.itemAttribute!.attributes![index].attributeOptions!.length, (i) {
                                      final bool selected = controller.selectedVariants.contains(productModel.itemAttribute!.attributes![index].attributeOptions![i].toString());
                                      return _OptionChip(
                                        label: productModel.itemAttribute!.attributes![index].attributeOptions![i].toString(),
                                        selected: selected,
                                        onTap: () async {
                                          if (controller.selectedIndexVariants.where((element) => element.contains('$index _')).isEmpty) {
                                            controller.selectedVariants.insert(index, productModel.itemAttribute!.attributes![index].attributeOptions![i].toString());
                                            controller.selectedIndexVariants.add('$index _${productModel.itemAttribute!.attributes![index].attributeOptions![i].toString()}');
                                            controller.selectedIndexArray.add('${index}_$i');
                                          } else {
                                            controller.selectedIndexArray.remove(
                                              '${index}_${productModel.itemAttribute!.attributes![index].attributeOptions?.indexOf(controller.selectedIndexVariants.where((element) => element.contains('$index _')).first.replaceAll('$index _', ''))}',
                                            );
                                            controller.selectedVariants.removeAt(index);
                                            controller.selectedIndexVariants.remove(controller.selectedIndexVariants.where((element) => element.contains('$index _')).first);
                                            controller.selectedVariants.insert(index, productModel.itemAttribute!.attributes![index].attributeOptions![i].toString());
                                            controller.selectedIndexVariants.add('$index _${productModel.itemAttribute!.attributes![index].attributeOptions![i].toString()}');
                                            controller.selectedIndexArray.add('${index}_$i');
                                          }

                                          final bool productIsInList = cartItem.any(
                                            (product) =>
                                                product.id ==
                                                "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                          );
                                          if (productIsInList) {
                                            CartProductModel element = cartItem.firstWhere(
                                              (product) =>
                                                  product.id ==
                                                  "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                            );
                                            controller.quantity.value = element.quantity!;
                                          } else {
                                            controller.quantity.value = 1;
                                          }

                                          controller.update();
                                          controller.calculatePrice(productModel);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                productModel.addOnsTitle == null || productModel.addOnsTitle!.isEmpty
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.md),
                        child: DsCard.outlined(
                          padding: const EdgeInsets.all(DsSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Addons".tr, overflow: TextOverflow.ellipsis, style: t.titleSm),
                              const DsDivider(spacing: DsSpace.md),
                              ListView.builder(
                                itemCount: productModel.addOnsTitle!.length,
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  String title = productModel.addOnsTitle![index];
                                  String price = productModel.addOnsPrice![index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.body),
                                        ),
                                        const DsGap(DsSpace.sm),
                                        Text(
                                          Constant.amountShow(
                                            amount: Constant.productCommissionPrice(controller.vendorModel.value, price),
                                            currency: RegionService.currencyForVendor(controller.vendorModel.value),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.bodyStrong.tabular,
                                        ),
                                        const DsGap(DsSpace.sm),
                                        Obx(
                                          () => SizedBox(
                                            height: 24.0,
                                            width: 24.0,
                                            child: Checkbox(
                                              value: controller.selectedAddOns.contains(title),
                                              activeColor: c.brand,
                                              onChanged: (value) {
                                                if (value != null) {
                                                  if (value == true) {
                                                    controller.selectedAddOns.add(title);
                                                  } else {
                                                    controller.selectedAddOns.remove(title);
                                                  }
                                                  controller.update();
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
          bottomBar: DsStickyBar(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DsIconButton(
                          icon: Icons.remove_rounded,
                          semanticLabel: 'Remove'.tr,
                          size: 36,
                          onPressed: () {
                            // Wholesale-only products can't go below their minimum quantity.
                            if (controller.quantity.value > productModel.minOrderQuantity) {
                              controller.quantity.value -= 1;
                              controller.update();
                            }
                          },
                        ),
                        Text(controller.quantity.value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
                        DsIconButton(
                          icon: Icons.add_rounded,
                          semanticLabel: 'Add item'.tr,
                          size: 36,
                          onPressed: () {
                            if (productModel.itemAttribute == null) {
                              if (controller.quantity.value < (productModel.quantity ?? 0) || (productModel.quantity ?? 0) == -1) {
                                controller.quantity.value += 1;
                                controller.update();
                              } else {
                                ShowToastDialog.showToast("Out of stock".tr);
                              }
                            } else {
                              int totalQuantity = int.parse(
                                productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantQuantity.toString(),
                              );
                              if (controller.quantity.value < totalQuantity || totalQuantity == -1) {
                                controller.quantity.value += 1;
                                controller.update();
                              } else {
                                ShowToastDialog.showToast("Out of stock".tr);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  flex: 2,
                  child: DsButton.primary(
                    label: "${'Add item'.tr} ${Constant.amountShow(amount: controller.calculatePrice(productModel), currency: RegionService.currencyForVendor(controller.vendorModel.value))}".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      if (productModel.itemAttribute == null) {
                        await controller.addToCart(
                          productModel: productModel,
                          price: Constant.productCommissionPrice(controller.vendorModel.value, productModel.price.toString()),
                          discountPrice: double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(controller.vendorModel.value, productModel.disPrice.toString()),
                          isIncrement: true,
                          quantity: controller.quantity.value,
                        );
                      } else {
                        String variantPrice = "0";
                        if (productModel.itemAttribute!.variants!.any((e) => e.variantSku == controller.selectedVariants.join('-'))) {
                          variantPrice = Constant.productCommissionPrice(
                            controller.vendorModel.value,
                            productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantPrice ?? '0',
                          );
                        }

                        Map<String, String> mapData = {};
                        for (var element in productModel.itemAttribute!.attributes!) {
                          mapData.addEntries([
                            MapEntry(
                              controller.attributesList.firstWhere((e) => e.id == element.attributeId).title.toString(),
                              controller.selectedVariants[productModel.itemAttribute!.attributes!.indexOf(element)],
                            ),
                          ]);
                        }

                        VariantInfo variantInfo = VariantInfo(
                          variantPrice: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantPrice ?? '0',
                          variantSku: controller.selectedVariants.join('-'),
                          variantOptions: mapData,
                          variantImage: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantImage ?? '',
                          variantId: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantId ?? '0',
                        );

                        await controller.addToCart(
                          productModel: productModel,
                          price: variantPrice,
                          discountPrice: "0",
                          isIncrement: true,
                          variantInfo: variantInfo,
                          quantity: controller.quantity.value,
                        );
                      }
                      controller.update();
                      Get.back();
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
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionChip({required this.label, required this.selected, required this.onTap});

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
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surfaceAlt,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Text(label, overflow: TextOverflow.ellipsis, style: t.bodyStrong.withColor(selected ? c.onBrand : c.textPrimary)),
        ),
      ),
    );
  }
}
