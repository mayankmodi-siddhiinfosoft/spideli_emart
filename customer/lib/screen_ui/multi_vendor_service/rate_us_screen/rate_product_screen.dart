import 'dart:io';

import 'package:customer/controllers/rate_product_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Archetype K — review / result. A gradient "how was it?" hero carries the
/// big tappable star row, then quality attributes, a photo drop-zone with a
/// thumbnail rail and the comment box. Submit lives in a sticky bar.
class RateProductScreen extends StatelessWidget {
  const RateProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RateProductController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final double rating = controller.ratings.value;
        final String productName = "${controller.productModel.value.name}";
        final images = controller.images.toList();
        final attributes = controller.reviewAttributeList.toList();
        final noSavedRating = controller.ratingModel.value.id == null;
        final savedAttributes = controller.ratingModel.value.reviewAttributes;

        return DsScaffold(
          title: "Rate the item".tr,
          maxContentWidth: DsLayout.contentMax,
          body: isLoading
              ? const SingleChildScrollView(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: DsFadeSlideIn.stagger([
                      _RatingHero(
                        productName: productName,
                        rating: rating,
                        onRatingUpdate: (double rate) {
                          controller.ratings.value = rate;
                        },
                      ),
                      if (attributes.isNotEmpty)
                        _AttributeCard(
                          titles: [for (final a in attributes) a.title.toString()],
                          initialRatings: [for (final a in attributes) noSavedRating ? 0.0 : savedAttributes?[a.id] ?? 0.0],
                          onRatingUpdate: (int index, double rate) {
                            controller.reviewAttribute.addEntries([MapEntry(attributes[index].id.toString(), rate)]);
                          },
                        ),
                      _PhotoCard(
                        images: images,
                        onBrowse: () async {
                          buildBottomSheet(context, controller);
                        },
                        onRemove: (int index) {
                          controller.images.removeAt(index);
                        },
                      ),
                      DsFormSection(
                        title: "Type comment".tr,
                        icon: Icons.mode_comment_outlined,
                        children: [
                          DsTextField(
                            hint: "Type comment".tr,
                            controller: controller.commentController.value,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            textInputAction: TextInputAction.done,
                            bottomSpacing: 0,
                          ),
                        ],
                      ),
                    ], offset: const Offset(0, 20)),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Submit Review".tr,
              icon: Icons.send_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                controller.saveRating();
              },
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, RateProductController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DsSheet(
              title: "Please Select".tr,
              child: Row(
                children: [
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: "Camera".tr,
                      onTap: () => controller.pickFile(source: ImageSource.camera),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.photo_library_rounded,
                      label: "Gallery".tr,
                      onTap: () => controller.pickFile(source: ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Gradient hero with the product name and a 48dp-target star picker.
class _RatingHero extends StatelessWidget {
  final String productName;
  final double rating;
  final ValueChanged<double> onRatingUpdate;
  const _RatingHero({required this.productName, required this.rating, required this.onRatingUpdate});

  static const List<String> _labels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.gradient(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Rate for".tr, style: t.overline.withColor(Colors.white70), textAlign: TextAlign.center),
          const DsGap(DsSpace.xs),
          Text(productName.tr, style: t.headline.withColor(Colors.white), textAlign: TextAlign.center),
          const DsGap(DsSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              final bool filled = rating >= star;
              return DsIconButton(
                icon: filled ? Icons.star_rounded : Icons.star_outline_rounded,
                semanticLabel: '$star ${_labels[index].tr}',
                color: filled ? Colors.white : Colors.white70,
                size: 44,
                onPressed: () => onRatingUpdate(star.toDouble()),
              );
            }),
          ),
          const DsGap(DsSpace.sm),
          AnimatedSwitcher(
            duration: DsMotion.of(context, DsMotion.fast),
            child: Text(rating <= 0 ? "Rate the item".tr : _labels[rating.round().clamp(1, 5) - 1].tr, key: ValueKey<int>(rating.round()), style: t.label.withColor(Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Per-attribute star rows (taste, packaging, ...).
class _AttributeCard extends StatelessWidget {
  final List<String> titles;
  final List<dynamic> initialRatings;
  final void Function(int index, double rate) onRatingUpdate;
  const _AttributeCard({required this.titles, required this.initialRatings, required this.onRatingUpdate});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      margin: const EdgeInsets.only(top: DsSpace.lg),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: Column(
        children: List.generate(titles.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Row(
              children: [
                Expanded(child: Text(titles[index], style: t.bodyStrong)),
                const DsGap(DsSpace.sm),
                RatingBar.builder(
                  initialRating: initialRatings[index],
                  minRating: 1,
                  direction: Axis.horizontal,
                  itemCount: 5,
                  itemSize: 24,
                  unratedColor: c.borderStrong,
                  itemPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xxs),
                  itemBuilder: (context, _) => Icon(Icons.star_rounded, color: c.warning),
                  onRatingUpdate: (double rate) => onRatingUpdate(index, rate),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Dashed drop-zone plus the picked-photo rail.
class _PhotoCard extends StatelessWidget {
  final List<dynamic> images;
  final VoidCallback onBrowse;
  final ValueChanged<int> onRemove;
  const _PhotoCard({required this.images, required this.onBrowse, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      margin: const EdgeInsets.only(top: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DottedBorder(
            options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.md), dashPattern: const [6, 6, 6, 6], color: c.borderStrong),
            child: Container(
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/icons/ic_folder.svg'),
                  const DsGap(DsSpace.md),
                  Text("Choose a image and upload here".tr, textAlign: TextAlign.center, style: t.bodyStrong),
                  const DsGap(DsSpace.xs),
                  Text("JPEG, PNG".tr, style: t.caption),
                  const DsGap(DsSpace.md),
                  DsButton.tonal(label: "Brows Image".tr, icon: Icons.upload_rounded, size: DsButtonSize.sm, onPressed: onBrowse),
                ],
              ),
            ),
          ),
          if (images.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: images.length,
                separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                itemBuilder: (context, index) {
                  final dynamic image = images[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: DsRadius.brMd,
                        child: (image is XFile)
                            ? Image.file(File(image.path), fit: BoxFit.cover, width: 84, height: 84)
                            : DsImage(url: image?.toString() ?? '', fit: BoxFit.cover, width: 84, height: 84, radius: DsRadius.md),
                      ),
                      Positioned(
                        top: -DsSpace.sm,
                        right: -DsSpace.sm,
                        child: DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, variant: DsIconButtonVariant.filled, size: 26, color: c.danger, onPressed: () => onRemove(index)),
                      ),
                    ],
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

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIconWell(icon: icon, circle: true, size: 52),
          const DsGap(DsSpace.sm),
          Text(label, style: t.label),
        ],
      ),
    );
  }
}
