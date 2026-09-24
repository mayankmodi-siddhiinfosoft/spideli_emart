import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_restaurant_details_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../chat_screens/full_screen_image_viewer.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../review_list_screen/review_list_screen.dart';
import 'book_table_screen.dart';
import 'widgets/dine_in_widgets.dart';

/// Archetype B (detail) — a photo hero with floating chrome, an identity block
/// that overlaps it, two big "what do you want to do" choice cards, the menu
/// gallery and a facts block.
class DineInDetailsScreen extends StatelessWidget {
  const DineInDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInRestaurantDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value;
        final VendorModel vendor = controller.vendorModel.value;
        final List<dynamic> photos = vendor.photos ?? <dynamic>[];
        final List<dynamic> menuPhotos = vendor.restaurantMenuPhotos ?? <dynamic>[];
        final bool isOpen = controller.isOpen.value;
        final List tags = controller.tags.toList();

        return Scaffold(
          backgroundColor: c.background,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: 260,
                  floating: true,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: c.brand,
                  title: Row(
                    children: [
                      DineInGlassIconButton(
                        icon: Icons.arrow_back,
                        semanticLabel: 'Back'.tr,
                        onPressed: () {
                          Get.back();
                        },
                      ),
                      const Expanded(child: SizedBox()),
                      Obx(
                        () => DineInFavouriteButton(
                          isFavourite: controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty,
                          onTap: () async {
                            if (controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty) {
                              FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteList.removeWhere((item) => item.restaurantId == controller.vendorModel.value.id);
                              await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                            } else {
                              FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteList.add(favouriteModel);
                              await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        photos.isEmpty
                            ? DsImage(url: vendor.photo.toString(), radius: 0, errorIcon: Icons.storefront_outlined)
                            : PageView.builder(
                                physics: const BouncingScrollPhysics(),
                                controller: controller.pageController.value,
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                padEnds: false,
                                pageSnapping: true,
                                onPageChanged: (value) {
                                  controller.currentPage.value = value;
                                },
                                itemBuilder: (BuildContext context, int index) {
                                  return DsImage(url: photos[index].toString(), radius: 0, errorIcon: Icons.storefront_outlined);
                                },
                              ),
                        const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                        Positioned(
                          bottom: DsSpace.md,
                          right: 0,
                          left: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(photos.length, (index) {
                              return Obx(
                                () => AnimatedContainer(
                                  duration: DsMotion.of(context, DsMotion.fast),
                                  margin: const EdgeInsets.only(right: DsSpace.xs),
                                  height: 7,
                                  width: controller.currentPage.value == index ? 20 : 7,
                                  decoration: BoxDecoration(
                                    borderRadius: DsRadius.brPill,
                                    color: controller.currentPage.value == index ? c.brand : Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: isLoading
                ? const SingleChildScrollView(child: DsSkeletonDetail(mediaHeight: 0))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                    child: DsResponsive(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: DsFadeSlideIn.stagger([
                          // ---------- identity ----------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(vendor.title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headline),
                                    const DsGap(DsSpace.xxs),
                                    Text(vendor.location.toString(), style: t.bodySm),
                                  ],
                                ),
                              ),
                              const DsGap(DsSpace.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  DineInRatingChip(vendorModel: vendor, showCount: false),
                                  const DsGap(DsSpace.xs),
                                  DsButton.ghost(
                                    label: "${vendor.reviewsCount} ${'Ratings'.tr}",
                                    size: DsButtonSize.sm,
                                    color: c.textSecondary,
                                    onPressed: () {
                                      Get.to(const ReviewListScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const DsGap(DsSpace.md),
                          Wrap(
                            spacing: DsSpace.sm,
                            runSpacing: DsSpace.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DsBadge(
                                label: isOpen ? "Open".tr : "Close".tr,
                                tone: isOpen ? DsTone.success : DsTone.danger,
                                icon: isOpen ? Icons.check_circle_outline_rounded : Icons.do_not_disturb_on_outlined,
                              ),
                              DsButton.ghost(
                                label: "View Timings".tr,
                                icon: Icons.schedule_rounded,
                                size: DsButtonSize.sm,
                                onPressed: () {
                                  timeShowBottomSheet(context, controller);
                                },
                              ),
                              DsBadge(
                                label: "${Constant.amountShow(amount: vendor.restaurantCost, currency: RegionService.currencyForVendor(vendor))} ${'for two'.tr}".tr,
                                tone: DsTone.brand,
                              ),
                            ],
                          ),

                          // ---------- what would you like to do ----------
                          const DsGap(DsSpace.xxl),
                          Text("Also applicable on food delivery".tr, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                          const DsGap(DsSpace.md),
                          _ChoiceCard(
                            image: context.dsIsDark ? "assets/images/ic_table_dark.gif" : "assets/images/ic_table.gif",
                            title: "Table Booking".tr,
                            subtitle: "Quick Confirmations".tr,
                            imagePadding: EdgeInsets.zero,
                            onTap: () {
                              if (Constant.userModel == null) {
                                ShowToastDialog.showToast("Please log in to the application. You are not logged in.".tr);
                              } else {
                                Get.to(const BookTableScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                              }
                            },
                          ),
                          const DsGap(DsSpace.md),
                          _ChoiceCard(
                            image: context.dsIsDark ? "assets/images/food_delivery_dark.gif" : "assets/images/food_delivery.gif",
                            title: "Available food delivery".tr,
                            subtitle: "in 30-45 mins.".tr,
                            imagePadding: const EdgeInsets.all(4),
                            onTap: () {
                              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                            },
                          ),

                          // ---------- menu gallery ----------
                          if (menuPhotos.isNotEmpty) ...[
                            const DsGap(DsSpace.xxl),
                            Text("Menu".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                            const DsGap(DsSpace.md),
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                itemCount: menuPhotos.length,
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: DsSpace.md),
                                    child: DsPressable(
                                      onTap: () {
                                        Get.to(FullScreenImageViewer(imageUrl: menuPhotos[index]));
                                      },
                                      child: DsImage(url: menuPhotos[index].toString(), height: 110, width: 110, radius: DsRadius.md, errorIcon: Icons.menu_book_outlined),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // ---------- facts ----------
                          const DsGap(DsSpace.xxl),
                          Text("Location, Timing & Costs".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                          const DsGap(DsSpace.md),
                          DsCard(
                            child: Column(
                              children: [
                                _FactRow(
                                  leading: SvgPicture.asset("assets/icons/ic_location.svg", width: 20, height: 20),
                                  label: vendor.location.toString(),
                                  value: "View on Map".tr,
                                  onTap: () {
                                    launchUrl(Constant.createCoordinatesUrl(vendor.latitude ?? 0.0, vendor.longitude ?? 0.0, vendor.title));
                                  },
                                ),
                                const DsDivider(spacing: DsSpace.md),
                                _FactRow(
                                  leading: SvgPicture.asset("assets/icons/ic_alarm_clock.svg", width: 20, height: 20),
                                  label: "Timing".tr,
                                  value:
                                      "${vendor.openDineTime == '' ? "10:00 AM" : vendor.openDineTime.toString()} ${"To".tr} ${vendor.closeDineTime == '' ? "10:00 PM" : vendor.closeDineTime.toString()}",
                                  onTap: () {},
                                ),
                                const DsDivider(spacing: DsSpace.md),
                                _FactRow(
                                  leading: Text(
                                    (RegionService.currencyForVendor(vendor) ?? Constant.currencyModel!).symbol.toString(),
                                    textAlign: TextAlign.center,
                                    style: t.titleSm.tabular.withColor(c.textMuted),
                                  ),
                                  label: "Cost for Two".tr,
                                  value: "${Constant.amountShow(amount: vendor.restaurantCost ?? "0.0", currency: RegionService.currencyForVendor(vendor))} ${'(approx)'.tr}",
                                ),
                              ],
                            ),
                          ),

                          // ---------- cuisines ----------
                          const DsGap(DsSpace.xxl),
                          Text("Cuisines".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                          const DsGap(DsSpace.md),
                          Wrap(
                            spacing: DsSpace.sm,
                            runSpacing: DsSpace.sm,
                            children: <Widget>[...tags.map((tag) => DsBadge(label: "$tag"))],
                          ),
                        ]),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future timeShowBottomSheet(BuildContext context, DineInRestaurantDetailsController productModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.70,
        child: StatefulBuilder(
          builder: (context1, setState) {
            final c = context.dsColors;
            final t = context.dsText;
            final List<WorkingHours> hours = productModel.vendorModel.value.workingHours ?? <WorkingHours>[];
            return DsSheet(
              title: "View Timings".tr,
              showClose: true,
              padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.lg, DsSpace.xl, DsSpace.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(hours.length, (dayIndex) {
                  WorkingHours workingHours = hours[dayIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${workingHours.day}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                        const DsGap(DsSpace.sm),
                        if (workingHours.timeslot != null && workingHours.timeslot!.isNotEmpty)
                          Column(
                            children: List.generate(workingHours.timeslot!.length, (timeIndex) {
                              Timeslot timeSlotModel = workingHours.timeslot![timeIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _SlotBox(label: timeSlotModel.from.toString())),
                                    const DsGap(DsSpace.md),
                                    Icon(Icons.arrow_forward_rounded, size: 16, color: c.textMuted),
                                    const DsGap(DsSpace.md),
                                    Expanded(child: _SlotBox(label: timeSlotModel.to.toString())),
                                  ],
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Big "choose an experience" card (table booking / food delivery).
class _ChoiceCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final EdgeInsetsGeometry imagePadding;
  final VoidCallback onTap;

  const _ChoiceCard({required this.image, required this.title, required this.subtitle, required this.imagePadding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm),
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: imagePadding, child: Image.asset(image, fit: BoxFit.cover)),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSm),
                const DsGap(DsSpace.xxs),
                Text(subtitle, style: t.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.iconDefault),
        ],
      ),
    );
  }
}

/// Icon + label + (tappable) value row of the facts card.
class _FactRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _FactRow({required this.leading, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Widget valueText = Text(value, style: t.bodyStrong.withColor(onTap == null ? c.textPrimary : c.brandStrong));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 24, child: Center(child: leading)),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodySecondary),
              const DsGap(DsSpace.xxs),
              onTap == null
                  ? valueText
                  : InkWell(
                      onTap: onTap,
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.xs), child: valueText),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotBox extends StatelessWidget {
  final String label;

  const _SlotBox({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      decoration: BoxDecoration(borderRadius: DsRadius.brMd, border: Border.all(color: c.border), color: c.surfaceAlt),
      child: Center(child: Text(label, style: t.bodyStrong.tabular)),
    );
  }
}
