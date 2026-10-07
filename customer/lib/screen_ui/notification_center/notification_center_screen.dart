import 'package:customer/controllers/notification_center_controller.dart';
import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/customer_notification_record.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Archetype **J — inbox**: the customer's notifications, newest first
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` §1). Live, so no pull to refresh.
/// Rows unread when shown are bold, tinted and dotted for this visit; a tap
/// opens what the notification is about.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<NotificationCenterController>(
      init: NotificationCenterController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final bool failed = controller.hasError.value;
        final List<CustomerNotificationModel> items = controller.notifications.toList();
        final Set<String> fresh = controller.newThisVisit.toSet();
        final Widget body;
        if (loading) {
          body = const DsSkeletonList(itemCount: 6);
        } else if (failed && items.isEmpty) {
          body = Center(child: DsErrorState(onRetry: controller.retry));
        } else if (!controller.isSignedIn || items.isEmpty) {
          body = Center(
            child: DsEmptyState(
              icon: Icons.notifications_none_rounded,
              title: "No notifications yet".tr,
              message: "Order updates, messages and alerts will appear here.".tr,
            ),
          );
        } else {
          final DateTime now = DateTime.now();
          body = ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final CustomerNotificationModel n = items[index];
              return DsFadeSlideIn(
                index: index,
                child: NotificationRow(
                  notification: n,
                  isNew: !n.read || fresh.contains(n.id),
                  now: now,
                  onTap: () => controller.open(n),
                ),
              );
            },
          );
        }
        return DsScaffold(title: "Notifications".tr, maxContentWidth: DsLayout.contentMax, body: body);
      },
    );
  }
}

/// One notification: category icon, title, body, relative time + date and
/// the status after the event. [isNew] rows are bold, tinted and dotted.
class NotificationRow extends StatelessWidget {
  final CustomerNotificationModel notification;
  final bool isNew;
  final DateTime now;
  final VoidCallback onTap;

  const NotificationRow({super.key, required this.notification, required this.isNew, required this.now, required this.onTap});

  static IconData iconOf(String category) {
    switch (CustomerNotificationRecord.normalizeCategory(category)) {
      case CustomerNotificationRecord.categoryOrder:
        return Icons.receipt_long_outlined;
      case CustomerNotificationRecord.categoryChat:
        return Icons.chat_bubble_outline_rounded;
      case CustomerNotificationRecord.categoryBooking:
        return Icons.event_available_outlined;
      case CustomerNotificationRecord.categoryAccount:
        return Icons.account_circle_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  static DsTone toneOf(String category) {
    switch (CustomerNotificationRecord.normalizeCategory(category)) {
      case CustomerNotificationRecord.categoryOrder:
        return DsTone.brand;
      case CustomerNotificationRecord.categoryChat:
        return DsTone.info;
      case CustomerNotificationRecord.categoryBooking:
        return DsTone.success;
      case CustomerNotificationRecord.categoryAccount:
        return DsTone.warning;
      default:
        return DsTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final n = notification;
    final String title = n.title.isNotEmpty ? n.title : n.body;
    final String body = n.title.isNotEmpty ? n.body : '';
    final String relative = CustomerNotificationRecord.relativeTime(n.createdAt, now);
    final String date = n.createdAt == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt!);
    final String when = [relative, date].where((s) => s.isNotEmpty).join(' · ');

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsIconWell(icon: iconOf(n.category), tone: toneOf(n.category), size: 44),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: isNew ? t.titleSm.w700 : t.titleSm.w500),
                  ),
                  if (isNew) ...[
                    const DsGap(DsSpace.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle)),
                    ),
                  ],
                ],
              ),
              if (body.isNotEmpty) ...[
                const DsGap(DsSpace.xxs),
                Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: isNew ? t.body : t.bodySm),
              ],
              const DsGap(DsSpace.sm),
              Wrap(
                spacing: DsSpace.sm,
                runSpacing: DsSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (n.status.isNotEmpty) DsStatusChip(label: n.status.tr, status: n.status),
                  if (when.isNotEmpty) Text(when, style: t.caption.tabular),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final String semantics = [if (isNew) "New".tr, title, body, when].where((s) => s.isNotEmpty).join(', ');
    const EdgeInsets margin = EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs);
    const EdgeInsets padding = EdgeInsets.all(DsSpace.md);
    return isNew
        ? DsCard.tinted(tone: DsTone.brand, margin: margin, padding: padding, onTap: onTap, semanticLabel: semantics, child: content)
        : DsCard.outlined(margin: margin, padding: padding, onTap: onTap, semanticLabel: semantics, child: content);
  }
}
