import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/add_advertisement_screen/add_advertisement_screen.dart';
import 'package:vendor/app/add_advertisement_screen/view_advertisement_screen.dart';
import 'package:vendor/app/chat_screens/admin_inbox_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/advertisement_list_controller.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';

class AdvertisementListScreen extends StatelessWidget {
  const AdvertisementListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AdvertisementListController(),
      builder: (controller) {
        final c = context.dsColors;
        return DefaultTabController(
          length: 7,
          child: Scaffold(
            backgroundColor: c.background,
            appBar: DsAppBar(
              title: "Your Advertisement".tr,
              actions: [
                Visibility(
                  visible: controller.venderModel.value.subscriptionPlan?.features?.chat != false,
                  child: DsIconButton(
                    icon: Icons.forum_outlined,
                    semanticLabel: "Chat".tr,
                    variant: DsIconButtonVariant.tonal,
                    onPressed: () async {
                      Get.to(const AdminInboxScreen());
                    },
                  ),
                ),
              ],
              bottom: DsTabBar(
                scrollable: true,
                onTap: (value) {
                  controller.selectedTabIndex.value = value;
                },
                tabs: const ["All", "Pending", "Approved", "Running", "Paused", "Expired", "Cancelled"],
              ),
            ),
            body: controller.isLoading.value
                ? DsResponsive(
                    maxWidth: DsLayout.wideMax,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(context.dsLayout.gutter),
                      child: const Column(children: [DsSkeletonCard(height: 96), DsGap(DsSpace.lg), DsSkeletonCard(height: 260), DsGap(DsSpace.lg), DsSkeletonCard(height: 260)]),
                    ),
                  )
                : TabBarView(
                    children: [
                      _tabList(context, controller, controller.allAdvertisementList, header: _CampaignOverview(controller: controller)),
                      _tabList(context, controller, controller.pendingAdvertisementList),
                      _tabList(context, controller, controller.appovedAdvertisementList),
                      _tabList(context, controller, controller.runningAdvertisementList),
                      _tabList(context, controller, controller.pausedAdvertisementList),
                      _tabList(context, controller, controller.expiredAdvertisementList),
                      _tabList(context, controller, controller.cancelAdvertisementList),
                    ],
                  ),
            bottomNavigationBar: DsStickyBar(
              child: DsButton.primary(
                label: "New Advertisement".tr,
                icon: Icons.add_rounded,
                expand: true,
                size: DsButtonSize.lg,
                onPressed: () {
                  Get.to(AddAdvertisementScreen())?.then((value) async {
                    if (value != null) {
                      await controller.getAdvertisement();
                      if (value == 'Save') {
                        showAdSuccessBottomSheet(context);
                      }
                    }
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabList(BuildContext context, AdvertisementListController controller, List<AdvertisementModel> list, {Widget? header}) {
    final c = context.dsColors;
    final l = context.dsLayout;
    if (list.isEmpty) {
      return DsEmptyState(icon: Icons.campaign_outlined, title: "Advertisement not found.".tr);
    }
    return RefreshIndicator(
      color: c.brand,
      backgroundColor: c.surface,
      onRefresh: () => controller.getAdvertisement(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, DsSpace.sm, 0, DsSpace.xxl),
        children: [
          DsResponsive(
            maxWidth: DsLayout.wideMax,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: l.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) ...[DsFadeSlideIn(child: header), const DsGap(DsSpace.lg)],
                  DsAdaptiveGrid(
                    minItemWidth: 360,
                    maxColumns: 3,
                    equalHeight: false,
                    spacing: DsSpace.lg,
                    runSpacing: DsSpace.lg,
                    children: [
                      for (int index = 0; index < list.length; index++)
                        DsFadeSlideIn(index: index + 1, child: AdvertisementCard(index: index, controller: controller, model: list[index])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campaign summary shown above the "All" tab.
class _CampaignOverview extends StatelessWidget {
  final AdvertisementListController controller;
  const _CampaignOverview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    Widget metric(String label, int value, IconData icon) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const DsGap(DsSpace.xs),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.withColor(Colors.white.withValues(alpha: 0.8)))),
            ],
          ),
          const DsGap(DsSpace.xs),
          DsAnimatedCounter(value: value, style: t.metric.withColor(Colors.white)),
        ],
      ),
    );
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Row(
        children: [
          metric("Running".tr, controller.runningAdvertisementList.length, Icons.play_circle_outline_rounded),
          metric("Pending".tr, controller.pendingAdvertisementList.length, Icons.hourglass_top_rounded),
          metric("Paused".tr, controller.pausedAdvertisementList.length, Icons.pause_circle_outline_rounded),
          metric("All".tr, controller.allAdvertisementList.length, Icons.campaign_outlined),
        ],
      ),
    );
  }
}

void showAdSuccessBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) {
      return Builder(
        builder: (context) {
          final c = context.dsColors;
          final t = context.dsText;
          return DsSheet(
            actions: DsButton.primary(
              label: "Okay".tr,
              expand: true,
              onPressed: () {
                Get.back();
              },
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsFadeSlideIn(
                  child: Container(
                    padding: const EdgeInsets.all(DsSpace.lg),
                    decoration: BoxDecoration(color: c.successSoft, shape: BoxShape.circle),
                    child: Image.asset('assets/images/ads_image.png', height: 88),
                  ),
                ),
                const DsGap(DsSpace.lg),
                Text('Ad Created Successfully!'.tr, textAlign: TextAlign.center, style: t.title),
                const DsGap(DsSpace.sm),
                Text(
                  '${"Congratulations on creating your ad! It's now awaiting approval.To finalize the process & make payment arrangements, please contact our Admin.".tr}\n${Constant.adminEmail}',
                  textAlign: TextAlign.center,
                  style: t.bodySecondary,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class AdvertisementCard extends StatelessWidget {
  final int index;
  final AdvertisementModel model;
  final AdvertisementListController controller;

  const AdvertisementCard({super.key, required this.index, required this.model, required this.controller});

  String _status() {
    try {
      return Constant.getAdsStatus(model);
    } catch (_) {
      return model.status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final c = context.dsColors;
    final t = context.dsText;
    final status = _status();
    final isStore = model.type == 'restaurant_promotion';
    final start = model.startDate?.toDate();
    final end = model.endDate?.toDate();
    return DsCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Get.to(ViewAdvertisementScreen(), arguments: {'advsModel': model})?.then((value) async {
          if (value == true) {
            await controller.getAdvertisement();
            controller.update();
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                isStore
                    ? NetworkImageWidget(imageUrl: model.coverImage ?? '', height: 170, width: double.infinity, fit: BoxFit.cover)
                    : VideoAdvWidget(url: model.video ?? '', height: 170, width: double.infinity),
                const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim))),
                if (status.isNotEmpty)
                  PositionedDirectional(
                    top: DsSpace.md,
                    start: DsSpace.md,
                    child: DsStatusChip(label: status.capitalizeString(), status: status, pulse: status == Constant.adsRunning),
                  ),
                PositionedDirectional(
                  top: DsSpace.xs,
                  end: DsSpace.xs,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: PopupMenuButton<String>(
                      tooltip: "More".tr,
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      color: c.surfaceRaised,
                      shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
                      onSelected: (value) {
                        // Handle menu selection
                      },
                      itemBuilder: (context) => [
                        if ((model.status == Constant.adsApproved || model.status != Constant.adsUpdated) && !model.endDate!.toDate().isBefore(DateTime.now()))
                          model.isPaused == true
                              ? PopupMenuItem(
                                  onTap: () {
                                    controller.resumeAdvertisement(model, index, context, isDark);
                                  },
                                  value: 'resume',
                                  child: _MenuRow(icon: Icons.play_circle_outline_rounded, label: 'Resume Ads'.tr, tone: DsTone.success),
                                )
                              : PopupMenuItem(
                                  onTap: () {
                                    controller.pauseNote.value.text = '';
                                    controller.pauseAdvertisement(model, index, context, isDark);
                                  },
                                  value: 'pause',
                                  child: _MenuRow(icon: Icons.pause_circle_outline_rounded, label: 'Pause Ads'.tr, tone: DsTone.warning),
                                ),
                        PopupMenuItem(
                          onTap: () {
                            Get.to(AddAdvertisementScreen(), arguments: {'advsModel': model, 'isCopy': true})?.then((v) {
                              if (v == true) {
                                controller.getAdvertisement();
                              }
                            });
                          },
                          value: 'copy',
                          child: _MenuRow(icon: Icons.copy_rounded, label: 'Copy Ads'.tr, tone: DsTone.info),
                        ),
                        PopupMenuItem(
                          onTap: () async {
                            controller.deleteAdvertisement(model, index, context, isDark);
                          },
                          value: 'delete',
                          child: _MenuRow(icon: Icons.delete_outline_rounded, label: 'Delete Ads'.tr, tone: DsTone.danger),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  bottom: DsSpace.md,
                  start: DsSpace.md,
                  child: DsBadge(
                    label: isStore ? 'Store Promotion'.tr : 'Video Promotion'.tr,
                    icon: isStore ? Icons.storefront_rounded : Icons.play_circle_fill_rounded,
                    tone: DsTone.neutral,
                    style: DsBadgeStyle.solid,
                    small: true,
                  ),
                ),
                if (model.type != 'video_promotion' && (model.showRating == true || model.showReview == true))
                  PositionedDirectional(
                    bottom: DsSpace.md,
                    end: DsSpace.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brPill, boxShadow: DsShadows.sm(context)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          model.showRating == true ? Icon(Icons.star_rounded, color: c.warning, size: 16) : const SizedBox(),
                          const DsGap(DsSpace.xs),
                          Text(
                            '${model.showRating == true ? Constant.calculateReview(reviewCount: controller.venderModel.value.reviewsCount?.toStringAsFixed(0), reviewSum: controller.venderModel.value.reviewsSum.toString()) : ""}${model.showRating == true && model.showReview == true ? ' ' : ''}${model.showReview == true ? '(${controller.venderModel.value.reviewsCount?.toStringAsFixed(0)})' : ''}',
                            style: t.labelSm.withColor(c.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStore) ...[
                  DsAvatar(imageUrl: model.profileImage ?? '', name: model.title ?? '', size: 44, ring: true),
                  const DsGap(DsSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.title ?? '', style: t.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const DsGap(2),
                      Text(model.description ?? '', style: t.bodySm, overflow: TextOverflow.ellipsis, maxLines: 2),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
                DsIconWell(icon: isStore ? Icons.favorite_border_rounded : Icons.arrow_forward_rounded, tone: isStore ? DsTone.neutral : DsTone.brand, size: 36),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 16, color: c.textMuted),
                const DsGap(DsSpace.xs),
                Expanded(
                  child: Text(
                    start == null || end == null ? '-' : '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.withColor(c.textSecondary),
                  ),
                ),
                DsBadge(
                  label: model.paymentStatus == true ? 'Paid'.tr : 'Unpaid'.tr,
                  tone: model.paymentStatus == true ? DsTone.success : DsTone.danger,
                  icon: model.paymentStatus == true ? Icons.verified_rounded : Icons.error_outline_rounded,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DsTone tone;
  const _MenuRow({required this.icon, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Icon(icon, size: 20, color: c.tone(tone).strong),
        const DsGap(DsSpace.md),
        Text(label, style: context.dsText.body),
      ],
    );
  }
}
