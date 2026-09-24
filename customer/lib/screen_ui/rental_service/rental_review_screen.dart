import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import '../../controllers/rental_review_controller.dart';

/// Rate the rental driver (archetype K — review): driver avatar and vehicle
/// plate on top, one focused rating card, sticky submit.
class RentalReviewScreen extends StatelessWidget {
  const RentalReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;

    return GetX<RentalReviewController>(
      init: RentalReviewController(),
      builder: (controller) {
        return DsScaffold(
          title: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
          onBack: () => Get.back(),
          maxContentWidth: DsLayout.contentMax,
          body: Obx(() {
            if (controller.isLoading.value) return const DsSkeletonForm(fields: 3);
            final sid = controller.order.value?.sectionId ?? '';
            final vehicle = controller.driverUser.value?.vehicleDetails?[sid];
            final vType = vehicle?['vehicleType']?.toString() ?? '';
            final brand = vehicle?['carBrand']?.toString() ?? '';
            final carModel = vehicle?['carModel']?.toString() ?? '';
            final plate = vehicle?['carPlateNumber']?.toString() ?? '';
            final driverName = controller.order.value!.driver?.fullName() ?? "";
            return ListView(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xl, l.gutter, DsSpace.xxxl),
              children: DsFadeSlideIn.stagger([
                Center(
                  child: DsAvatar(
                    imageUrl: controller.order.value?.driver?.profilePictureURL ?? '',
                    name: driverName,
                    size: 110,
                    ring: true,
                  ),
                ),
                const DsGap(DsSpace.lg),
                Text(driverName, style: t.headline, textAlign: TextAlign.center),
                if (vType.isNotEmpty) ...[
                  const DsGap(DsSpace.xxs),
                  Text(vType, style: t.bodySecondary, textAlign: TextAlign.center),
                ],
                if (plate.isNotEmpty || brand.isNotEmpty || carModel.isNotEmpty) ...[
                  const DsGap(DsSpace.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.xs,
                    children: [
                      if (plate.isNotEmpty) DsBadge(label: plate.toUpperCase(), style: DsBadgeStyle.outline, icon: Icons.directions_car_outlined),
                      if (brand.isNotEmpty || carModel.isNotEmpty) DsBadge(label: "$brand $carModel".trim()),
                    ],
                  ),
                ],
                const DsGap(DsSpace.xxl),
                DsCard(
                  padding: const EdgeInsets.all(DsSpace.xl),
                  child: Column(
                    children: [
                      Text('How is your trip?'.tr, style: t.title, textAlign: TextAlign.center),
                      const DsGap(DsSpace.sm),
                      Text(
                        'Your feedback will help us improve \n driving experience better'.tr,
                        textAlign: TextAlign.center,
                        style: t.bodySecondary,
                      ),
                      const DsGap(DsSpace.xl),
                      Text('Rate for'.tr, style: t.caption),
                      const DsGap(DsSpace.xxs),
                      Text(driverName, style: t.titleSm, textAlign: TextAlign.center),
                      const DsGap(DsSpace.lg),
                      RatingBar.builder(
                        initialRating: controller.ratings.value,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 40,
                        itemPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                        itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                        unratedColor: c.surfaceAlt,
                        onRatingUpdate: (rating) => controller.ratings.value = rating,
                      ),
                      const DsGap(DsSpace.xl),
                      DsTextField(
                        label: "Type comment....".tr,
                        hint: "Type comment....".tr,
                        controller: controller.comment.value,
                        maxLines: 5,
                        minLines: 4,
                        bottomSpacing: 0,
                      ),
                    ],
                  ),
                ),
              ]),
            );
          }),
          bottomBar: DsStickyBar(
            child: Obx(
              () => DsButton.primary(
                label: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
                icon: Icons.rate_review_outlined,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: controller.submitReview,
              ),
            ),
          ),
        );
      },
    );
  }
}
