import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/favourite_ondemmand_controller.dart';
import 'package:customer/models/category_model.dart';
import 'package:customer/models/favorite_ondemand_service_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/on_demand_service/on_demand_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype B – saved services. Cards resolve their service document lazily,
/// with a shimmer card while each one loads.
class FavouriteOndemandScreen extends StatelessWidget {
  const FavouriteOndemandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: FavouriteOndemmandController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<FavouriteOndemandServiceModel> favourites = controller.lstFav.toList();

        return DsScaffold.collapsing(
          title: "Favourite Services".tr,
          showBack: false,
          subtitle: isLoading || Constant.userModel == null ? null : "${favourites.length} ${'saved'.tr}",
          slivers: [
            if (isLoading)
              const DsSliverResponsive(top: DsSpace.md, sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 5)))
            else if (Constant.userModel == null)
              DsSliverResponsive(
                top: DsSpace.xxl,
                sliver: SliverToBoxAdapter(
                  child: DsEmptyState(
                    illustration: Image.asset("assets/images/login.gif", height: 120),
                    title: "Please Log In to Continue".tr,
                    message: "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                    actionLabel: "Log in".tr,
                    actionIcon: Icons.login_rounded,
                    onAction: () async {
                      Get.offAll(const LoginScreen());
                    },
                  ),
                ),
              )
            else if (favourites.isEmpty)
              DsSliverResponsive(
                top: DsSpace.xxl,
                sliver: SliverToBoxAdapter(child: DsEmptyState(icon: Icons.favorite_border_rounded, title: "Favourite Service not found.".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.md,
                bottom: DsSpace.xl,
                sliver: SliverList.builder(
                  itemCount: favourites.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<List<ProviderServiceModel>>(
                      future: FireStoreUtils.getCurrentProviderService(favourites[index]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const _FavouriteSkeleton();
                        }

                        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                          return const SizedBox(); // or a placeholder widget
                        }

                        final provider = snapshot.data!.first; // safer way than [0]

                        return DsFadeSlideIn(index: index, child: _FavouriteCard(provider: provider, controller: controller));
                      },
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

/// One saved service (image, title, category, price, rating, unfavourite).
class _FavouriteCard extends StatelessWidget {
  final ProviderServiceModel provider;
  final FavouriteOndemmandController controller;

  const _FavouriteCard({required this.provider, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      semanticLabel: provider.title ?? "",
      onTap: () {
        Get.to(() => OnDemandDetailsScreen(), arguments: {'providerModel': provider});
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 118,
              child: DsImage(url: provider.photos.isNotEmpty ? provider.photos.first : Constant.placeHolderImage, radius: 0, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.sm, DsSpace.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(provider.title ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                        Obx(() {
                          final bool fav = controller.lstFav.where((element) => element.service_id == provider.id).isNotEmpty;
                          return DsIconButton(
                            icon: fav ? Icons.favorite : Icons.favorite_border,
                            semanticLabel: 'Favourite Services'.tr,
                            size: 36,
                            color: fav ? c.brandStrong : c.textMuted,
                            onPressed: () => controller.toggleFavourite(provider),
                          );
                        }),
                      ],
                    ),
                    FutureBuilder<CategoryModel?>(
                      future: controller.getCategory(provider.categoryId ?? ""),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: DsSpace.xxs),
                          child: Text(snap.data?.title ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                        );
                      },
                    ),
                    const DsGap(DsSpace.sm),
                    Row(children: [Expanded(child: _buildPrice(context, provider)), _buildRating(provider)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrice(BuildContext context, ProviderServiceModel provider) {
    final c = context.dsColors;
    final t = context.dsText;
    if (provider.disPrice == "" || provider.disPrice == "0") {
      return Text(
        provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price, currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? "0", currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.titleSm.withColor(c.brandStrong).tabular,
      );
    } else {
      return Row(
        children: [
          Flexible(
            child: Text(
              provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.disPrice ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.disPrice, currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleSm.withColor(c.brandStrong).tabular,
            ),
          ),
          const DsGap(DsSpace.xs),
          Flexible(
            child: Text(
              provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price, currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? "0", currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySm.strike.tabular,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildRating(ProviderServiceModel provider) {
    double rating = 0;
    if (provider.reviewsCount != null && provider.reviewsCount != 0) {
      rating = (provider.reviewsSum ?? 0) / (provider.reviewsCount ?? 1);
    }
    return DsBadge(label: rating.toStringAsFixed(1), tone: DsTone.warning, icon: Icons.star_rounded, small: true);
  }
}

/// Shimmer placeholder for a favourite card that is still resolving.
class _FavouriteSkeleton extends StatelessWidget {
  const _FavouriteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.box(width: 118, height: 104),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsSkeleton.line(width: 160),
                  const DsGap(DsSpace.sm),
                  DsSkeleton.line(width: 100, height: 10),
                  const DsGap(DsSpace.lg),
                  DsSkeleton.line(width: 80, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
