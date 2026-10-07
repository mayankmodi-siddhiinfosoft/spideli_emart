import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/chat_unread.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Unread count of one order conversation, live
/// (`FireStoreUtils.unreadOrderChatCount`: `receiverId == me`,
/// `seen == false`, limited listener). Nothing is shown at zero; more than
/// [ChatUnread.displayCap] shows as `99+`.
class ChatUnreadBadge extends StatefulWidget {
  final String orderId;

  const ChatUnreadBadge({super.key, required this.orderId});

  @override
  State<ChatUnreadBadge> createState() => _ChatUnreadBadgeState();
}

class _ChatUnreadBadgeState extends State<ChatUnreadBadge> {
  late Stream<int> _count;

  @override
  void initState() {
    super.initState();
    _count = FireStoreUtils.unreadOrderChatCount(widget.orderId);
  }

  @override
  void didUpdateWidget(covariant ChatUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _count = FireStoreUtils.unreadOrderChatCount(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _count,
      builder: (context, snapshot) {
        final String label = ChatUnread.label(snapshot.data ?? 0);
        if (label.isEmpty) return const SizedBox.shrink();
        return Semantics(
          label: "$label ${"unread messages".tr}",
          excludeSemantics: true,
          child: DsBadge(label: label, tone: DsTone.danger, style: DsBadgeStyle.solid, small: true),
        );
      },
    );
  }
}
