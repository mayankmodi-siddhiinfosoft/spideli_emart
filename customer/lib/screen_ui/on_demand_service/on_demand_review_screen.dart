import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_review_controller.dart';

/// Archetype K – rating / result screen: identity card, big star row and a
/// comment field over a sticky submit bar.
class OnDemandReviewScreen extends StatelessWidget {
  const OnDemandReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OnDemandReviewController>(
      init: OnDemandReviewController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;

        return DsScaffold(
          title: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
          maxContentWidth: DsLayout.contentMax,
          body: Obx(
            () =>
                (controller.reviewFor.value == "Worker" && controller.workerModel.value == null) || (controller.reviewFor.value == "Provider" && controller.provider.value == null)
                    ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 3))
                    : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.xl, context.dsLayout.gutter, DsSpace.xxxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          DsCard(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
                            child: Column(
                              children: [
                                DsAvatar(
                                  imageUrl: controller.reviewFor.value == "Provider" ? controller.order.value?.provider.authorProfilePic ?? '' : controller.workerModel.value?.profilePictureURL ?? '',
                                  name: controller.reviewFor.value == "Provider" ? controller.order.value!.provider.authorName ?? "" : controller.workerModel.value!.fullName(),
                                  size: 100,
                                  ring: true,
                                ),
                                const DsGap(DsSpace.lg),
                                Text('Rate for'.tr, textAlign: TextAlign.center, style: t.caption),
                                const DsGap(DsSpace.xxs),
                                Text(
                                  controller.reviewFor.value == "Provider" ? controller.order.value!.provider.authorName ?? "" : controller.workerModel.value!.fullName(),
                                  textAlign: TextAlign.center,
                                  style: t.title,
                                ),
                                const DsGap(DsSpace.lg),
                                RatingBar.builder(
                                  initialRating: controller.ratings.value,
                                  minRating: 1,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 40,
                                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.tone(DsTone.warning).main),
                                  unratedColor: c.surfaceAlt,
                                  onRatingUpdate: (rating) {
                                    controller.ratings.value = rating;
                                  },
                                ),
                                const DsGap(DsSpace.sm),
                                Text(_ratingLabel(controller.ratings.value), style: t.labelSm.withColor(c.brandStrong)),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.lg),
                          DsFormSection(
                            title: 'Your review'.tr,
                            icon: Icons.rate_review_outlined,
                            children: [
                              DsTextField(hint: "Type comment....".tr, controller: controller.comment, maxLines: 5, minLines: 4, bottomSpacing: 0),
                            ],
                          ),
                        ]),
                      ),
                    ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
              icon: Icons.check_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: controller.submitReview,
            ),
          ),
        );
      },
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 4.5) return 'Excellent'.tr;
    if (rating >= 3.5) return 'Good'.tr;
    if (rating >= 2.5) return 'Average'.tr;
    if (rating > 0) return 'Poor'.tr;
    return 'Tap a star to rate'.tr;
  }
}
