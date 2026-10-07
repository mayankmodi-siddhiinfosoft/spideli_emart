import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/model/inbox_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/chat_screen/chat_screen.dart';
import 'package:spideliworker/utils/chat_unread.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Inbox (archetype B): avatar rows in `DsCard.outlined`, each with the
/// customer's name, the booking reference and the time of the last message.
/// A skeleton row stands in while the customer is being fetched.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  /// One profile read per customer for the life of the screen. The inbox is
  /// live: every update rebuilds the rows, and a new future each time put
  /// each row back on its skeleton, which unmounted `_InboxRow` and re-opened
  /// its unread badge listener (the count flickered).
  final Map<String, Future<User?>> _profiles = {};

  Future<User?> _profile(String id) => _profiles.putIfAbsent(id, () => FireStoreUtils.getUser(id));

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final l = context.dsLayout;
    return DsScaffold(
      title: "Woker Inbox".tr,
      maxContentWidth: DsLayout.contentMax,
      body: FirestorePagination(
        query: FireStoreUtils.firestore
            .collection("chat")
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: userRoleWorker)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxxl),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<User?>(
            future: _profile(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              // Skeleton only until the first profile: a refetch keeps the row
              // (and its badge listener) mounted.
              if (!snapshot.hasData || snapshot.hasError) {
                return const _InboxRowSkeleton();
              } else {
                User? customer = snapshot.data;
                return DsFadeSlideIn(
                  index: index,
                  child: _InboxRow(
                    customer: customer,
                    inboxModel: inboxModel,
                    onTap: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      User? worker = await FireStoreUtils.getWorkerCurrentUser(FireStoreUtils.getCurrentUid());
                      User? customer = snapshot.data;
                      ShowToastDialog.closeLoader();
                      Get.to(
                        const ChatScreen(),
                        arguments: {
                          "senderName": worker!.fullName(),
                          "senderId": worker.id,
                          "senderProfileUrl": worker.profilePictureURL,
                          "receivedName": customer?.fullName(),
                          "receivedId": customer?.id,
                          "receivedProfileUrl": customer?.profilePictureURL,
                          "orderId": inboxModel.orderId,
                          "token": worker.fcmToken,
                          "chatType": userRoleWorker,
                        },
                      );
                    },
                  ),
                );
              }
            },
          );
        },

        shrinkWrap: true,
        onEmpty: showEmptyView(message: "No conversion found".tr, themeChange: themeChange.getTheme()),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: const DsSkeletonList(itemCount: 6, leading: true, trailing: false),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}

/// One conversation. Its unread badge (`.claude/CUSTOMER-NOTIFICATIONS.md`
/// 2) is the live number of messages in this thread addressed to the worker
/// and not seen yet ([FireStoreUtils.orderChatUnreadCount]: a listener on at
/// most 100 of them, never the whole thread); 0 shows no badge, more than 99
/// shows `99+`. Opening the conversation marks them seen, so it clears.
class _InboxRow extends StatefulWidget {
  final User? customer;
  final InboxModel inboxModel;
  final VoidCallback onTap;

  const _InboxRow({required this.customer, required this.inboxModel, required this.onTap});

  @override
  State<_InboxRow> createState() => _InboxRowState();
}

class _InboxRowState extends State<_InboxRow> {
  // Created once per conversation, not on every rebuild of the live list.
  late Stream<int> _unread;

  @override
  void initState() {
    super.initState();
    _unread = FireStoreUtils.orderChatUnreadCount(widget.inboxModel.orderId);
  }

  @override
  void didUpdateWidget(covariant _InboxRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inboxModel.orderId != widget.inboxModel.orderId) {
      _unread = FireStoreUtils.orderChatUnreadCount(widget.inboxModel.orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unread,
      initialData: 0,
      builder: (context, snapshot) => _buildRow(context, snapshot.data ?? 0),
    );
  }

  Widget _buildRow(BuildContext context, int unread) {
    final c = context.dsColors;
    final t = context.dsText;
    final User? customer = widget.customer;
    final InboxModel inboxModel = widget.inboxModel;
    final String badge = chatUnreadBadgeLabel(unread);
    final bool hasUnread = badge.isNotEmpty;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      onTap: widget.onTap,
      semanticLabel: hasUnread ? "${customer?.fullName()}, ${"{0} unread messages".tr.replaceAll('{0}', badge)}" : "${customer?.fullName()}",
      child: Row(
        children: [
          DsAvatar(imageUrl: customer?.profilePictureURL ?? '', name: customer?.fullName(), size: 52),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${customer?.fullName()}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: hasUnread ? t.titleSm.copyWith(fontWeight: FontWeight.w800) : t.titleSm,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(
                      timestampToDate(inboxModel.createdAt!),
                      textAlign: TextAlign.start,
                      style: hasUnread ? t.caption.copyWith(color: c.brand, fontWeight: FontWeight.w700) : t.caption,
                    ),
                  ],
                ),
                const DsGap(DsSpace.xs),
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Expanded(
                      child: Text(
                        "${"Order".tr} ${orderId(orderId: inboxModel.orderId.toString())}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: t.bodySm.tabular,
                      ),
                    ),
                    if (hasUnread) ...[
                      const DsGap(DsSpace.sm),
                      ExcludeSemantics(child: DsBadge(label: badge, tone: DsTone.brand, style: DsBadgeStyle.solid, small: true)),
                    ],
                    Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxRowSkeleton extends StatelessWidget {
  const _InboxRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsShimmer(
        child: Row(
          children: [
            DsSkeleton.circle(size: 52),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsSkeleton.line(width: 160, height: 14),
                  const DsGap(DsSpace.sm),
                  DsSkeleton.line(width: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
