import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/on_demand_service/provider_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/provider_serivce_model.dart';
import '../../controllers/on_demand_details_controller.dart';
import '../auth_screens/login_screen.dart';
import 'on_demand_booking_screen.dart';

/// Archetype B – service detail: media hero under a transparent bar, an
/// identity block, segmented About / Gallery / Review tabs and a sticky CTA.
class OnDemandDetailsScreen extends StatelessWidget {
  const OnDemandDetailsScreen({super.key});

  static const List<String> _tabs = ["About", "Gallery", "Review"];

  @override
  Widget build(BuildContext context) {
    return GetX<OnDemandDetailsController>(
      init: OnDemandDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final bool isOpen = controller.isOpen.value;

        return Scaffold(
          backgroundColor: c.background,
          body: buildSliverScrollView(context, controller, controller.provider, isOpen),
          bottomNavigationBar:
              isOpen == false
                  ? SizedBox()
                  : DsStickyBar(
                    child: DsButton.primary(
                      label: "Book Now".tr,
                      icon: Icons.event_available_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () async {
                        if (Constant.userModel == null) {
                          Get.offAll(const LoginScreen());
                        } else {
                          print("providerModel ::::::::${controller.provider.title ?? 'No provider'}");
                          print("categoryTitle ::::::: ${controller.categoryTitle.value}");
                          Get.to(() => OnDemandBookingScreen(), arguments: {'providerModel': controller.provider, 'categoryTitle': controller.categoryTitle.value});
                        }
                      },
                    ),
                  ),
        );
      },
    );
  }

  Widget buildSliverScrollView(BuildContext context, OnDemandDetailsController controller, ProviderServiceModel provider, bool isOpen) {
    final c = context.dsColors;
    final height = MediaQuery.of(context).size.height;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: (height * 0.38).clamp(220.0, 360.0),
          automaticallyImplyLeading: false,
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: c.textPrimary,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(DsSpace.sm),
            child: DsIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Back'.tr,
              variant: DsIconButtonVariant.filled,
              onPressed: () => Get.back(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              child: DsStatusChip(label: isOpen ? "Open".tr : "Close".tr, tone: isOpen ? DsTone.success : DsTone.danger, pulse: isOpen),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                DsImage(url: provider.photos.isNotEmpty ? provider.photos.first : "", radius: 0, fit: BoxFit.cover, heroTag: 'service_${provider.id}'),
                DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
              ],
            ),
          ),
        ),
        DsSliverResponsive(
          maxWidth: DsLayout.wideMax,
          top: DsSpace.lg,
          bottom: DsSpace.xxl,
          sliver: SliverToBoxAdapter(
            child: GetBuilder<OnDemandDetailsController>(
              builder: (controller) {
                final provider = controller.provider;
                final categoryTitle = controller.categoryTitle.value;
                final subCategoryTitle = controller.subCategoryTitle.value;
                // final tabString = controller.tabString.value;
                final t = context.dsText;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: DsFadeSlideIn.stagger([
                    Text(provider.title.toString(), style: t.headline),
                    const DsGap(DsSpace.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _price(context, provider)),
                        DsBadge(
                          label: provider.reviewsCount != 0 ? ((provider.reviewsSum ?? 0.0) / (provider.reviewsCount ?? 0.0)).toStringAsFixed(1) : '0',
                          tone: DsTone.warning,
                          icon: Icons.star_rounded,
                        ),
                        const DsGap(DsSpace.sm),
                        Text("(${provider.reviewsCount} ${'Reviews'.tr})", style: t.bodySm),
                      ],
                    ),
                    if (categoryTitle.isNotEmpty) ...[
                      const DsGap(DsSpace.sm),
                      Text(categoryTitle, style: t.bodySecondary),
                    ],
                    const DsGap(DsSpace.md),
                    Wrap(
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (subCategoryTitle.isNotEmpty) DsBadge(label: subCategoryTitle, tone: DsTone.brand),
                        DsButton.tonal(
                          label: "View Timing".tr,
                          icon: Icons.schedule_rounded,
                          size: DsButtonSize.sm,
                          onPressed: () {
                            showModalBottomSheet(
                              isScrollControlled: true,
                              isDismissible: true,
                              context: context,
                              backgroundColor: Colors.transparent,
                              enableDrag: true,
                              builder: (context) => showTiming(context, controller),
                            );
                          },
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, color: context.dsColors.iconDefault, size: 20),
                        const DsGap(DsSpace.sm),
                        Expanded(child: Text(provider.address.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySecondary)),
                      ],
                    ),
                    const DsGap(DsSpace.lg),
                    const DsDivider(spacing: DsSpace.xs),
                    const DsGap(DsSpace.md),
                    _tabBar(controller),
                    Obx(() {
                      if (controller.tabString.value == "About") {
                        return aboutTabViewWidget(context, controller, controller.provider);
                      } else if (controller.tabString.value == "Gallery") {
                        return galleryTabViewWidget(controller);
                      } else {
                        return reviewTabViewWidget(context, controller);
                      }
                    }),
                    const DsGap(DsSpace.lg),
                  ]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _price(BuildContext context, ProviderServiceModel provider) {
    final c = context.dsColors;
    final t = context.dsText;
    if (provider.disPrice == "" || provider.disPrice == "0") {
      return Text(
        provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.title.withColor(c.brandStrong).tabular,
      );
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.disPrice ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.disPrice ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.title.withColor(c.brandStrong).tabular,
          ),
        ),
        const DsGap(DsSpace.sm),
        Flexible(
          child: Text(
            provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyStrong.strike.tabular,
          ),
        ),
      ],
    );
  }

  Widget _tabBar(OnDemandDetailsController controller) {
    return Obx(() {
      final current = controller.tabString.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.md),
        child: DsSegmentedTabs(
          segments: [for (final tab in _tabs) DsSegment(tab.tr)],
          index: _tabs.contains(current) ? _tabs.indexOf(current) : 0,
          onChanged: (i) => controller.changeTab(_tabs[i]),
        ),
      );
    });
  }

  Widget aboutTabViewWidget(BuildContext context, OnDemandDetailsController controller, ProviderServiceModel providerModel) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text((providerModel.description ?? '').tr, style: t.body.copyWith(height: 1.55)),
        const DsGap(DsSpace.lg),
        Obx(() {
          final user = controller.userModel.value;
          if (user == null) return const SizedBox();
          final c = context.dsColors;
          final rating =
              double.parse(user.reviewsCount.toString()) != 0 ? (double.parse(user.reviewsSum.toString()) / double.parse(user.reviewsCount.toString())).toStringAsFixed(1) : '0';
          return DsCard.outlined(
            padding: const EdgeInsets.all(DsSpace.md),
            semanticLabel: user.fullName(),
            onTap: () {
              Get.to(() => ProviderScreen(), arguments: {'providerId': user.id});
            },
            child: Row(
              children: [
                DsAvatar(imageUrl: user.profilePictureURL ?? '', name: user.fullName(), size: 56, ring: true),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      const DsGap(DsSpace.xxs),
                      Text(user.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                      const DsGap(DsSpace.sm),
                      DsBadge(label: rating, tone: DsTone.warning, icon: Icons.star_rounded, small: true),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget galleryTabViewWidget(OnDemandDetailsController controller) {
    final photos = controller.provider.photos;

    if (photos.isEmpty) {
      return DsEmptyState(compact: true, icon: Icons.photo_library_outlined, title: "No Image Found".tr);
    }

    return GridView.builder(
      itemCount: photos.length,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: DsLayout.gridDelegate(maxItemWidth: 220, mainAxisExtent: 170),
      itemBuilder: (context, index) {
        final imageUrl = photos[index];
        return DsFadeSlideIn(index: index, child: DsImage(url: imageUrl, radius: DsRadius.md, fit: BoxFit.cover));
      },
    );
  }

  Widget reviewTabViewWidget(BuildContext context, OnDemandDetailsController controller) {
    final reviews = controller.ratingService;
    final c = context.dsColors;
    final t = context.dsText;

    if (reviews.isEmpty) {
      return DsEmptyState(compact: true, icon: Icons.reviews_outlined, title: "No review Found".tr);
    }

    return ListView.builder(
      itemCount: reviews.length,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return DsFadeSlideIn(
          index: index,
          child: DsCard.outlined(
            margin: const EdgeInsets.only(bottom: DsSpace.md),
            padding: const EdgeInsets.all(DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsAvatar(name: review.uname ?? '', size: 36),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text(review.uname ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong)),
                    Text(review.createdAt != null ? DateFormat('dd MMM').format(review.createdAt!.toDate()) : '', style: t.caption),
                  ],
                ),
                const DsGap(DsSpace.sm),
                RatingBar.builder(
                  initialRating: double.tryParse(review.rating.toString()) ?? 0,
                  direction: Axis.horizontal,
                  itemSize: 18,
                  ignoreGestures: true,
                  itemPadding: const EdgeInsets.only(right: DsSpace.xs),
                  itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.tone(DsTone.warning).main),
                  onRatingUpdate: (rate) {},
                ),
                if ((review.comment ?? '').isNotEmpty) ...[
                  const DsGap(DsSpace.sm),
                  Text(review.comment ?? '', style: t.body),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget showTiming(BuildContext context, OnDemandDetailsController controller) {
    final provider = controller.provider;
    final t = context.dsText;
    return DsSheet(
      title: "Service Timing".tr,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _timeCard(context, "Start Time : ".tr, provider.startTime.toString())),
              const DsGap(DsSpace.md),
              Expanded(child: _timeCard(context, "End Time : ".tr, provider.endTime.toString())),
            ],
          ),
          const DsGap(DsSpace.xl),
          Text("Service Days".tr, style: t.titleSm),
          const DsGap(DsSpace.md),
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: provider.days.map((day) => DsBadge(label: day, tone: DsTone.brand, style: DsBadgeStyle.outline)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _timeCard(BuildContext context, String title, String value) {
    final t = context.dsText;
    return DsCard.tinted(
      tone: DsTone.brand,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.caption),
          const DsGap(DsSpace.xxs),
          Text(value, style: t.titleSm.tabular),
        ],
      ),
    );
  }
}
