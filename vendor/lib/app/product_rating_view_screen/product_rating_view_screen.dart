import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:vendor/app/chat_screens/full_screen_image_viewer.dart';
import 'package:vendor/controller/product_rating_view_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Review detail: brand score hero, per-attribute breakdown with bars,
/// the customer's comment as a quote card and a photo gallery.
class ProductRatingViewScreen extends StatelessWidget {
  const ProductRatingViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ProductRatingViewController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        // Read the observables here so the GetX builder tracks them.
        final bool isLoading = controller.isLoading.value;
        final double overall = isLoading ? 0 : double.parse(controller.ratingModel.value.rating == null ? "0.0" : controller.ratingModel.value.rating.toString());
        final bool hasComment = !(controller.ratingModel.value.comment == null || controller.ratingModel.value.comment!.isEmpty);
        final bool hasPhotos = controller.ratingModel.value.photos?.isNotEmpty == true;
        final String productName = "${controller.productModel.value.name}";
        final int attributeCount = controller.reviewAttributeList.length;
        return DsScaffold(
          title: "View Review".tr,
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: isLoading,
            skeleton: const DsSkeletonDetail(mediaHeight: 170),
            builder: (context) {
              return ListView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
                children: DsFadeSlideIn.stagger([
                  // Score hero
                  DsCard.gradient(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: DsRadius.brLg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DsAnimatedCounter(
                                value: overall,
                                format: (v) => v.toDouble().toStringAsFixed(1),
                                style: DsTypography.metricLg.copyWith(color: Colors.white),
                              ),
                              Text("/ 5", style: DsTypography.caption.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Rate for".tr, style: DsTypography.overline.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                              const DsGap(DsSpace.xxs),
                              Text(
                                productName.tr,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.title.copyWith(color: Colors.white),
                              ),
                              const DsGap(DsSpace.sm),
                              RatingBar.builder(
                                ignoreGestures: true,
                                initialRating: overall,
                                minRating: 1,
                                direction: Axis.horizontal,
                                itemCount: 5,
                                itemSize: 24,
                                unratedColor: Colors.white.withValues(alpha: 0.3),
                                itemPadding: const EdgeInsets.only(right: 4.0),
                                itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.warning),
                                onRatingUpdate: (double rate) {
                                  // print(ratings);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Per-attribute breakdown
                  if (attributeCount > 0) ...[
                    DsSectionHeader(title: "Rating breakdown".tr, icon: Icons.insights_rounded),
                    DsCard(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                      child: ListView.separated(
                        itemCount: attributeCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        separatorBuilder: (_, _) => Divider(height: 1, color: c.divider),
                        itemBuilder: (context, index) {
                          final double value = controller.ratingModel.value.id == null
                              ? 0.0
                              : (controller.ratingModel.value.reviewAttributes![controller.reviewAttributeList[index].id] ?? 0.0).toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(controller.reviewAttributeList[index].title.toString(), style: t.label)),
                                    const DsGap(DsSpace.sm),
                                    RatingBar.builder(
                                      ignoreGestures: true,
                                      initialRating: controller.ratingModel.value.id == null
                                          ? 0.0
                                          : controller.ratingModel.value.reviewAttributes![controller.reviewAttributeList[index].id] ?? 0.0,
                                      minRating: 1,
                                      direction: Axis.horizontal,
                                      itemCount: 5,
                                      itemSize: 18,
                                      itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                                      unratedColor: c.border,
                                      itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.warning),
                                      onRatingUpdate: (double rate) {
                                        // print(ratings);
                                      },
                                    ),
                                  ],
                                ),
                                const DsGap(DsSpace.sm),
                                DsProgressBar(value: value / 5, tone: DsTone.warning, height: 6),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Comment
                  if (hasComment) ...[
                    DsSectionHeader(title: "Comment".tr, icon: Icons.chat_bubble_outline_rounded),
                    DsCard.tinted(
                      tone: DsTone.neutral,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded, size: 28, color: c.brand),
                          const DsGap(DsSpace.sm),
                          Expanded(child: Text("${controller.ratingModel.value.comment}".tr, style: t.bodyLg)),
                        ],
                      ),
                    ),
                  ],

                  // Photos
                  if (hasPhotos) ...[
                    DsSectionHeader(title: "Photos".tr, icon: Icons.photo_library_outlined),
                    Wrap(
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.sm,
                      children: List.generate(controller.ratingModel.value.photos?.length ?? 0, (index) {
                        return DsPressable(
                          semanticLabel: "Photos".tr,
                          onTap: () {
                            Get.to(FullScreenImageViewer(imageUrl: controller.ratingModel.value.photos?[index]));
                          },
                          child: DsImage(url: controller.ratingModel.value.photos?[index], width: 96, height: 96, radius: DsRadius.md),
                        );
                      }),
                    ),
                  ],
                ]),
              );
            },
          ),
        );
      },
    );
  }
}
