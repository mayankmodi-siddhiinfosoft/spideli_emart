import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import '../../controllers/rental_review_controller.dart';
import '../../themes/ds/ds.dart';

/// Archetype H / L – a single focused rating form with the customer's avatar
/// overlapping the card.
class RentalReviewScreen extends StatelessWidget {
  const RentalReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<RentalReviewController>(
      init: RentalReviewController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsScaffold(
          title: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
          onBack: () => Get.back(),
          bottomBar: controller.customerUser.value == null
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
                    icon: Icons.rate_review_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: controller.submitReview,
                  ),
                ),
          body: Obx(
            () => controller.customerUser.value == null
                ? const DsSkeletonForm(fields: 3)
                : DsResponsive(
                    padded: true,
                    maxWidth: 560,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const DsGap(DsSpace.xl),
                          Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 55),
                                child: DsCard(
                                  padding: const EdgeInsets.fromLTRB(DsSpace.xl, 65, DsSpace.xl, DsSpace.xl),
                                  child: Column(
                                    children: [
                                      // Customer Name
                                      Text(
                                        "${controller.customerUser.value?.firstName ?? ''} ${controller.customerUser.value?.lastName ?? ''}",
                                        textAlign: TextAlign.center,
                                        style: t.title,
                                      ),
                                      const DsGap(DsSpace.xs),
                                      // Customer Email & Phone
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: DsSpace.sm,
                                        children: [
                                          Text(controller.customerUser.value?.email ?? '', style: t.bodySm),
                                          Text(controller.customerUser.value?.phoneNumber ?? '', style: t.bodySm.tabular),
                                        ],
                                      ),

                                      const DsDivider(),

                                      // Title
                                      Text('How was your customer?'.tr, textAlign: TextAlign.center, style: t.headline),
                                      const DsGap(DsSpace.sm),
                                      Text(
                                        "Share your feedback about the customer.".tr,
                                        textAlign: TextAlign.center,
                                        style: t.bodySecondary,
                                      ),

                                      // Rating
                                      const DsGap(DsSpace.xl),
                                      Text('Rate the Customer'.tr, textAlign: TextAlign.center, style: t.labelSm),
                                      const DsGap(DsSpace.md),
                                      RatingBar.builder(
                                        initialRating: controller.ratings.value,
                                        minRating: 1,
                                        direction: Axis.horizontal,
                                        allowHalfRating: true,
                                        itemCount: 5,
                                        itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.warning),
                                        unratedColor: c.surfaceAlt,
                                        onRatingUpdate: (rating) => controller.ratings.value = rating,
                                      ),

                                      // Comment
                                      const DsGap(DsSpace.xl),
                                      DsTextField(
                                        hint: "Type comment....".tr,
                                        controller: controller.comment.value,
                                        maxLines: 5,
                                        bottomSpacing: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DsAvatar(
                                imageUrl: controller.customerUser.value?.profilePictureURL ?? '',
                                name: "${controller.customerUser.value?.firstName ?? ''} ${controller.customerUser.value?.lastName ?? ''}",
                                size: 110,
                                ring: true,
                              ),
                            ],
                          ),
                          const DsGap(DsSpace.xl),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
