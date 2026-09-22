import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/add_advertisement_screen/add_advertisement_screen.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/view_advertisement_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';

class ViewAdvertisementScreen extends StatelessWidget {
  const ViewAdvertisementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ViewAdvertisementController(),
      builder: (controller) {
        final t = context.dsText;
        final ad = controller.advertisementModel.value;
        final isVideo = ad.type == 'video_promotion';
        final status = Constant.getAdsStatus(controller.advertisementModel.value);

        final media = _MediaHero(
          isVideo: isVideo,
          coverImage: ad.coverImage ?? '',
          profileImage: ad.profileImage ?? '',
          video: ad.video,
          title: ad.title ?? '',
        );

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: DsFadeSlideIn.stagger([
            // Title block
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advertisement Title (Default)'.tr, style: t.overline),
                const DsGap(DsSpace.xs),
                Text(ad.title ?? '', style: t.headline),
                const DsGap(DsSpace.md),
                Text('Description:'.tr, style: t.overline),
                const DsGap(DsSpace.xs),
                Text(ad.description ?? '', style: t.bodySecondary),
              ],
            ),
            const DsGap(DsSpace.lg),
            DsSectionHeader(title: "Ad Status".tr, icon: Icons.insights_outlined, padding: const EdgeInsets.only(bottom: DsSpace.md)),
            DsCard(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Request Verify Status:'.tr,
                    trailing: DsStatusChip(label: status.capitalizeString(), status: status, pulse: status == Constant.adsRunning),
                  ),
                  _InfoRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payment Status:'.tr,
                    trailing: DsBadge(
                      label: controller.advertisementModel.value.paymentStatus == true ? 'Paid'.tr : 'Unpaid'.tr,
                      tone: controller.advertisementModel.value.paymentStatus == true ? DsTone.success : DsTone.danger,
                      icon: controller.advertisementModel.value.paymentStatus == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    ),
                  ),
                  _InfoRow(
                    icon: isVideo ? Icons.play_circle_outline_rounded : Icons.storefront_outlined,
                    label: 'Ad Type:'.tr,
                    value: controller.advertisementModel.value.type == 'restaurant_promotion' ? 'Store Promotion'.tr : 'Video Promotion'.tr,
                  ),
                  _InfoRow(
                    icon: Icons.event_note_outlined,
                    label: 'Ad Created Date:'.tr,
                    value: DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.createdAt!.toDate()),
                  ),
                  _InfoRow(
                    icon: Icons.date_range_outlined,
                    label: 'Duration:'.tr,
                    value:
                        '${DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.startDate!.toDate())} - ${DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.endDate!.toDate())}',
                    last: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.md),
                    child: DsProgressBar(
                      value: _elapsed(controller.advertisementModel.value.startDate!.toDate(), controller.advertisementModel.value.endDate!.toDate()),
                      tone: DsTone.fromStatus(status) == DsTone.neutral ? DsTone.brand : DsTone.fromStatus(status),
                      height: 6,
                      showPercent: true,
                      label: 'Duration:'.tr,
                    ),
                  ),
                ],
              ),
            ),
            if (controller.advertisementModel.value.isPaused == true &&
                controller.advertisementModel.value.status != Constant.adsCancel &&
                Constant.getAdsStatus(controller.advertisementModel.value) != Constant.adsExpire) ...[
              const DsGap(DsSpace.md),
              DsInlineAlert(tone: DsTone.warning, icon: Icons.pause_circle_outline_rounded, title: 'Ad Paused Note:'.tr, message: controller.advertisementModel.value.pauseNote ?? ''),
            ],
            if (controller.advertisementModel.value.status == Constant.adsCancel) ...[
              const DsGap(DsSpace.md),
              DsInlineAlert(tone: DsTone.danger, icon: Icons.cancel_outlined, title: 'Ad Cancel Note:'.tr, message: controller.advertisementModel.value.canceledNote ?? ''),
            ],
          ]),
        );

        return DsScaffold(
          title: "View Advertisement".tr,
          maxContentWidth: null,
          actions: [
            Visibility(
              visible: controller.vendorModel.value?.subscriptionPlan?.features?.chat != false,
              child: DsIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                semanticLabel: "Chat".tr,
                variant: DsIconButtonVariant.tonal,
                onPressed: () async {
                  ShowToastDialog.showLoader("Please wait".tr);
                  VendorModel? vendorModel = await FireStoreUtils.getVendorById(controller.advertisementModel.value.vendorId.toString());
                  ShowToastDialog.closeLoader();

                  Get.to(
                    const ChatScreen(),
                    arguments: {
                      "senderName": vendorModel?.title,
                      "senderId": Constant.userModel?.id,
                      "senderProfileUrl": vendorModel?.photo,
                      "receivedName": 'Admin',
                      "receivedId": 'admin',
                      "receivedProfileUrl": '',
                      "orderId": controller.advertisementModel.value.id,
                      "token": '',
                      "chatType": 'admin',
                    },
                  );
                },
              ),
            ),
          ],
          body: SingleChildScrollView(
            child: DsResponsive(
              maxWidth: DsLayout.wideMax,
              padded: true,
              child: Padding(
                padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
                child: DsResponsiveBuilder(
                  builder: (context, l) => l.isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: DsFadeSlideIn(child: media)),
                            const DsGap(DsSpace.xxl),
                            Expanded(flex: 4, child: details),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DsFadeSlideIn(child: media),
                            DsGap(isVideo ? DsSpace.xl : DsSpace.huge),
                            details,
                          ],
                        ),
                ),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Edit Details".tr,
              icon: Icons.edit_outlined,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                Get.to(AddAdvertisementScreen(), arguments: {'advsModel': controller.advertisementModel.value});
              },
            ),
          ),
        );
      },
    );
  }

  static double _elapsed(DateTime start, DateTime end) {
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 1;
    final done = DateTime.now().difference(start).inMinutes;
    return (done / total).clamp(0.0, 1.0);
  }
}

/// Cover (with overlapping profile avatar) or video.
class _MediaHero extends StatelessWidget {
  final bool isVideo;
  final String coverImage;
  final String profileImage;
  final dynamic video;
  final String title;

  const _MediaHero({required this.isVideo, required this.coverImage, required this.profileImage, required this.video, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (isVideo) {
      return ClipRRect(
        borderRadius: DsRadius.brXl,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(builder: (context, cons) => VideoAdvWidget(width: cons.maxWidth, url: video)),
          ),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: DsRadius.brXl,
          child: AspectRatio(
            aspectRatio: 2 / 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImageWidget(imageUrl: coverImage, fit: BoxFit.cover),
                const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                PositionedDirectional(
                  top: DsSpace.md,
                  start: DsSpace.md,
                  child: DsBadge(label: "Cover Image".tr, icon: Icons.image_outlined, tone: DsTone.neutral, style: DsBadgeStyle.solid, small: true),
                ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: DsSpace.lg,
          bottom: -32,
          child: Semantics(
            label: "Profile Image".tr,
            image: true,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.background, width: 4), boxShadow: DsShadows.md(context)),
              child: DsAvatar(imageUrl: profileImage, name: title, size: 72),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final bool last;

  const _InfoRow({required this.icon, required this.label, this.value, this.trailing, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.divider))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const DsGap(DsSpace.md),
          Flexible(child: Text(label, style: t.bodySecondary)),
          const DsGap(DsSpace.md),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailing ?? Text(value ?? '', textAlign: TextAlign.end, maxLines: 2, style: t.label),
            ),
          ),
        ],
      ),
    );
  }
}
