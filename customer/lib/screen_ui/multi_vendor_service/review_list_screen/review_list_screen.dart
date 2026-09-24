import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/review_list_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/models/review_attribute_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../chat_screens/full_screen_image_viewer.dart';

/// Archetype B/K — social proof. A "score board" hero (average, total and a
/// 5→1 star distribution) sits above the review feed, and every review is a
/// testimonial card with an avatar, its own star row, attribute scores and a
/// photo rail.
class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ReviewListController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final List<RatingModel> reviews = controller.ratingList.toList();
        return DsScaffold.collapsing(
          title: "Reviews".tr,
          subtitle: isLoading || reviews.isEmpty ? null : '${reviews.length} ${"Reviews".tr}',
          onRefresh: controller.getAllReview,
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4, leading: true, trailing: false))
            else if (reviews.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.reviews_outlined, title: "No Review found".tr),
              )
            else ...[
              DsSliverResponsive(
                top: DsSpace.md,
                sliver: SliverToBoxAdapter(
                  child: DsFadeSlideIn(child: _ScoreBoard(reviews: reviews)),
                ),
              ),
              DsSliverResponsive(
                top: DsSpace.lg,
                bottom: DsSpace.xxl,
                sliver: SliverList.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final RatingModel ratingModel = reviews[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _ReviewCard(ratingModel: ratingModel),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Average score + star distribution, derived from the loaded reviews.
class _ScoreBoard extends StatelessWidget {
  final List<RatingModel> reviews;
  const _ScoreBoard({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final counts = List<int>.filled(5, 0);
    double sum = 0;
    for (final r in reviews) {
      final rating = r.rating ?? 0.0;
      sum += rating;
      final bucket = rating.round().clamp(1, 5) - 1;
      counts[bucket] = counts[bucket] + 1;
    }
    final average = reviews.isEmpty ? 0.0 : sum / reviews.length;
    final maxCount = counts.fold<int>(1, (p, e) => e > p ? e : p);

    return DsCard(
      padding: const EdgeInsets.all(DsSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(average.toStringAsFixed(1), style: t.metricLg.tabular),
              _StarRow(rating: average, size: 16),
              const DsGap(DsSpace.xs),
              Text('${reviews.length} ${"Reviews".tr}', style: t.caption),
            ],
          ),
          const DsGap(DsSpace.xl),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[star - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        child: Text('$star', style: t.caption.tabular, textAlign: TextAlign.end),
                      ),
                      const DsGap(DsSpace.xs),
                      Icon(Icons.star_rounded, size: 13, color: c.warning),
                      const DsGap(DsSpace.sm),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: DsRadius.brPill,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: maxCount == 0 ? 0 : count / maxCount),
                            duration: DsMotion.of(context, DsMotion.slower),
                            curve: DsMotion.decelerate,
                            builder: (_, value, _) => LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: c.surfaceAlt, valueColor: AlwaysStoppedAnimation<Color>(c.warning)),
                          ),
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      SizedBox(width: 24, child: Text('$count', style: t.caption.tabular)),
                    ],
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

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      label: '${rating.toStringAsFixed(1)} ${"Reviews".tr}',
      child: RatingBar.builder(
        ignoreGestures: true,
        initialRating: rating,
        minRating: 1,
        direction: Axis.horizontal,
        itemCount: 5,
        itemSize: size,
        itemPadding: const EdgeInsets.only(right: DsSpace.xxs),
        itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.warning),
        unratedColor: c.borderStrong,
        onRatingUpdate: (double rate) {},
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final RatingModel ratingModel;
  const _ReviewCard({required this.ratingModel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final comment = ratingModel.comment;
    final photos = ratingModel.photos;
    final attributes = ratingModel.reviewAttributes;

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsAvatar(name: ratingModel.uname.toString(), size: 40),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ratingModel.uname.toString(), style: t.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (ratingModel.createdAt != null) Text(Constant.timestampToDateTime(ratingModel.createdAt!), style: t.caption),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              _RatingPill(rating: ratingModel.rating ?? 0.0),
            ],
          ),
          if (ratingModel.productId != null)
            FutureBuilder(
              future: FireStoreUtils.fireStore.collection(CollectionName.vendorProducts).doc(ratingModel.productId?.split('~').first).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                } else {
                  if (snapshot.hasError) {
                    return const SizedBox.shrink();
                  } else if (snapshot.data == null) {
                    return const SizedBox.shrink();
                  } else if (snapshot.data != null) {
                    ProductModel model = ProductModel.fromJson(snapshot.data!.data()!);
                    return Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: DsBadge(label: '${'Rate for'.tr} - ${model.name ?? ''}', icon: Icons.local_mall_outlined, tone: DsTone.brand),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }
              },
            ),
          if (comment != '' && comment != null) ...[const DsGap(DsSpace.md), Text(comment.toString(), style: t.body)],
          if (attributes != null && attributes.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
              child: Column(
                children: List.generate(attributes.length, (index) {
                  final String key = attributes.keys.elementAt(index);
                  final dynamic value = attributes[key];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
                    child: Row(
                      children: [
                        FutureBuilder(
                          future: FireStoreUtils.fireStore.collection(CollectionName.reviewAttributes).doc(key).get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Expanded(child: SizedBox.shrink());
                            } else {
                              if (snapshot.hasError) {
                                return const Expanded(child: SizedBox.shrink());
                              } else if (snapshot.data == null) {
                                return const Expanded(child: SizedBox.shrink());
                              } else {
                                ReviewAttributeModel model = ReviewAttributeModel.fromJson(snapshot.data!.data()!);
                                return Expanded(child: Text(model.title.toString(), style: t.bodyStrong));
                              }
                            }
                          },
                        ),
                        const DsGap(DsSpace.sm),
                        _StarRow(rating: value == null ? 0.0 : value ?? 0.0, size: 14),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
          if (photos?.isNotEmpty == true) ...[
            const DsGap(DsSpace.md),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: photos!.length,
                separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                itemBuilder: (context, index) {
                  return DsPressable(
                    onTap: () {
                      Get.to(FullScreenImageViewer(imageUrl: photos[index]));
                    },
                    child: DsImage(url: photos[index]?.toString(), height: 84, width: 76, radius: DsRadius.md, semanticLabel: "Reviews".tr),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: c.warningSoft, borderRadius: DsRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 15, color: c.warningStrong),
          const DsGap(DsSpace.xxs),
          Text(rating.toStringAsFixed(1), style: t.labelSm.tabular.withColor(c.warningStrong)),
        ],
      ),
    );
  }
}
