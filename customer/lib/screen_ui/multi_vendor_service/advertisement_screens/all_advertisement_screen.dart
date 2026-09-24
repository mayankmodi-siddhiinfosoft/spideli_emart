import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/advertisement_list_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/video_widget.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

/// Archetype B — a promoted-media feed. Every entry is a wide media card
/// (photo or video) with the store identity on a floating footer.
class AllAdvertisementScreen extends StatelessWidget {
  const AllAdvertisementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AdvertisementListController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final ads = controller.advertisementList;
        return DsScaffold.collapsing(
          title: "Highlights for you".tr,
          subtitle: isLoading || ads.isEmpty ? null : '${ads.length} ${"Promotions".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 3, leading: false, trailing: false))
            else if (ads.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.campaign_outlined, title: "Highlights for you not found.".tr, message: "Featured stores and clips will show up here.".tr),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: ads.length,
                  itemBuilder: (BuildContext context, int index) {
                    return DsFadeSlideIn(index: index, child: AdvertisementCard(controller: controller, model: ads[index]));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdvertisementCard extends StatelessWidget {
  final AdvertisementModel model;
  final AdvertisementListController controller;

  const AdvertisementCard({super.key, required this.controller, required this.model});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      semanticLabel: model.title ?? '',
      onTap: () async {
        ShowToastDialog.showLoader("Please wait...".tr);
        VendorModel? vendorModel = await FireStoreUtils.getVendorById(model.vendorId!);
        ShowToastDialog.closeLoader();
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              model.type == 'restaurant_promotion'
                  ? NetworkImageWidget(imageUrl: model.coverImage ?? '', height: 190, width: double.infinity, fit: BoxFit.cover)
                  : VideoAdvWidget(url: model.video ?? '', height: 190, width: double.infinity),
              if (model.type != 'video_promotion' && model.vendorId != null && (model.showRating == true || model.showReview == true))
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: FutureBuilder(
                    future: FireStoreUtils.getVendorById(model.vendorId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox();
                      } else {
                        if (snapshot.hasError) {
                          return const SizedBox();
                        } else if (snapshot.data == null) {
                          return const SizedBox();
                        } else {
                          VendorModel vendorModel = snapshot.data!;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                            decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brPill),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (model.showRating == true) SvgPicture.asset("assets/icons/ic_star.svg", width: 14, height: 14, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
                                if (model.showRating == true) const DsGap(DsSpace.xs),
                                Text(
                                  "${model.showRating == true ? Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString()) : ''}${model.showRating == true && model.showReview == true ? ' ' : ''}${model.showReview == true ? '(${vendorModel.reviewsCount!.toStringAsFixed(0)})' : ''}",
                                  style: t.label.withColor(c.brandStrong).tabular,
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (model.type == 'restaurant_promotion') ...[
                  ClipOval(child: NetworkImageWidget(imageUrl: model.profileImage ?? '', height: 48, width: 48, fit: BoxFit.cover)),
                  const DsGap(DsSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(model.title ?? '', style: t.titleSm.w600, overflow: TextOverflow.ellipsis, maxLines: 1),
                      const DsGap(DsSpace.xxs),
                      Text(model.description ?? '', style: t.bodySm, overflow: TextOverflow.ellipsis, maxLines: 2),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
                model.type == 'restaurant_promotion'
                    // Favourite state is observable: read it inside its own
                    // observer so only the heart rebuilds.
                    ? Obx(
                        () => DsIconButton(
                          semanticLabel: controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty ? "Remove from favourites".tr : "Add to favourites".tr,
                          child: controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty
                              ? SvgPicture.asset("assets/icons/ic_like_fill.svg", width: 20, height: 20)
                              : SvgPicture.asset("assets/icons/ic_like.svg", width: 20, height: 20, colorFilter: ColorFilter.mode(c.iconDefault, BlendMode.srcIn)),
                          onPressed: () async {
                            if (controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty) {
                              FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteList.removeWhere((item) => item.restaurantId == model.vendorId);
                              await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                            } else {
                              FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteList.add(favouriteModel);
                              await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                            }
                          },
                        ),
                      )
                    : DsIconWell(icon: Icons.arrow_forward_rounded, size: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
