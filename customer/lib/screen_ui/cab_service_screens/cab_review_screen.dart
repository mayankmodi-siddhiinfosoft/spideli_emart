import 'package:customer/controllers/cab_review_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';

import '../../themes/text_field_widget.dart';

/// Rate the driver (archetype K — review): a gradient hero carrying the
/// driver's avatar and vehicle, an overlapping rating card with a large star
/// row, then the comment and a sticky submit bar.
class CabReviewScreen extends StatelessWidget {
  const CabReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<CabReviewController>(
      init: CabReviewController(),
      builder: (controller) {
        final isUpdate = controller.ratingModel.value != null;
        final title = isUpdate ? "Update Review".tr : "Add Review".tr;
        return Obx(
          () => controller.isLoading.value
              ? DsScaffold(title: title, onBack: () => Get.back(), body: const DsSkeletonDetail(mediaHeight: 180))
              : DsScaffold.hero(
                  title: title,
                  onBack: () => Get.back(),
                  hero: _DriverHero(controller: controller),
                  heroOverlap: _RatingCard(controller: controller),
                  slivers: [
                    DsSliverResponsive(
                      maxWidth: DsLayout.contentMax,
                      top: DsSpace.lg,
                      bottom: DsSpace.xxxl,
                      sliver: SliverToBoxAdapter(
                        child: DsFormSection(
                          title: 'Your comment'.tr,
                          icon: Icons.chat_bubble_outline_rounded,
                          children: [
                            Obx(() => TextFieldWidget(hintText: "Type comment....".tr, controller: controller.comment.value, maxLine: 5)),
                            const DsGap(DsSpace.sm),
                          ],
                        ),
                      ),
                    ),
                  ],
                  bottomBar: DsStickyBar(
                    child: DsButton.primary(label: title, icon: Icons.star_rounded, size: DsButtonSize.lg, expand: true, onPressed: controller.submitReview),
                  ),
                ),
        );
      },
    );
  }
}

/// Driver avatar, name and vehicle on the gradient hero.
class _DriverHero extends StatelessWidget {
  final CabReviewController controller;

  const _DriverHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsObserve(
      builder: (_) {
        final driverName = controller.order.value!.driver?.fullName() ?? "";
        final sid = controller.order.value?.sectionId ?? '';
        final vehicle = controller.driverUser.value?.vehicleDetails?[sid];
        final vType = vehicle?['vehicleType']?.toString() ?? '';
        final brand = vehicle?['carBrand']?.toString() ?? '';
        final carModel = vehicle?['carModel']?.toString() ?? '';
        final plate = vehicle?['carPlateNumber']?.toString() ?? '';
        final car = "$brand $carModel".trim();
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.28)),
              child: DsAvatar(imageUrl: controller.order.value?.driver?.profilePictureURL ?? '', name: driverName, size: 96),
            ),
            const DsGap(DsSpace.md),
            Text(driverName, textAlign: TextAlign.center, style: t.headline.withColor(Colors.white)),
            if (vType.isNotEmpty || car.isNotEmpty) ...[
              const DsGap(DsSpace.xxs),
              Text([if (vType.isNotEmpty) vType, if (car.isNotEmpty) car].join(' · '), textAlign: TextAlign.center, style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.86))),
            ],
            if (plate.isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                decoration: BoxDecoration(
                  borderRadius: DsRadius.brSm,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: Text(plate.toUpperCase(), style: t.label.withColor(Colors.white).tabular),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Overlapping card with the prompt and the 5-star row.
class _RatingCard extends StatelessWidget {
  final CabReviewController controller;

  const _RatingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final star = c.tone(DsTone.warning);
    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.xxl),
      child: Column(
        children: [
          Text('How is your trip?'.tr, textAlign: TextAlign.center, style: t.title),
          const DsGap(DsSpace.sm),
          Text('Your feedback will help us improve \n driving experience better'.tr, textAlign: TextAlign.center, style: t.bodySecondary),
          const DsGap(DsSpace.xl),
          Text('Rate for'.tr, textAlign: TextAlign.center, style: t.labelSm),
          const DsGap(DsSpace.xs),
          DsObserve(
            builder: (_) => Text(controller.order.value!.driver?.fullName() ?? "", textAlign: TextAlign.center, style: t.titleSm),
          ),
          const DsGap(DsSpace.lg),
          DsObserve(
            builder: (_) => RatingBar.builder(
              initialRating: controller.ratings.value,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 40,
              glow: false,
              itemBuilder: (context, _) => Icon(Icons.star_rounded, color: star.main),
              unratedColor: c.borderStrong,
              onRatingUpdate: (rating) => controller.ratings.value = rating,
            ),
          ),
        ],
      ),
    );
  }
}
