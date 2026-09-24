import 'package:customer/controllers/parcel_review_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';

/// Rate the parcel driver (archetype K — review): the driver sits in a
/// gradient header, the stars and comment live on one focused card and the
/// submit action is pinned to a sticky bar.
class ParcelReviewScreen extends StatelessWidget {
  const ParcelReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;

    return GetX<ParcelReviewController>(
      init: ParcelReviewController(),
      builder: (controller) {
        final bool isUpdate = controller.ratingModel.value != null && controller.ratingModel.value!.id!.isNotEmpty;
        return DsScaffold(
          title: isUpdate ? "Update Review".tr : "Add Review".tr,
          onBack: () => Get.back(),
          maxContentWidth: DsLayout.contentMax,
          body: Obx(
            () => controller.isLoading.value
                ? const DsSkeletonForm(fields: 3)
                : ListView(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xl, l.gutter, DsSpace.xxxl),
                    children: DsFadeSlideIn.stagger([
                      Center(
                        child: DsAvatar(
                          imageUrl: controller.order.value?.driver?.profilePictureURL ?? '',
                          name: controller.order.value!.driver?.fullName() ?? "",
                          size: 110,
                          ring: true,
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                      Text(controller.order.value!.driver?.fullName() ?? "", style: t.headline, textAlign: TextAlign.center),
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
                            Text(controller.order.value!.driver?.fullName() ?? "", style: t.titleSm, textAlign: TextAlign.center),
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
                  ),
          ),
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
