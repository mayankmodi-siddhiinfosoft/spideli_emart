import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/services/customer_notification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

/// The number of unread messages of one conversation, live
/// (.claude/CUSTOMER-NOTIFICATIONS.md section 2): a solid badge, "99+" above
/// 99, nothing when there are none.
///
/// The listener is opened once per conversation ([conversationKey]) and kept
/// across rebuilds of the row, so a live inbox does not re-subscribe on every
/// change.
class UnreadChatBadge extends StatefulWidget {
  /// Identifies the conversation; a new key opens a new listener.
  final String conversationKey;

  /// The live unread count of the conversation.
  final Stream<int> Function() countStream;

  const UnreadChatBadge({super.key, required this.conversationKey, required this.countStream});

  /// The badge of an order chat of the inbox (`chat/{orderId}/thread`).
  factory UnreadChatBadge.orderChat(String orderId, {Key? key}) =>
      UnreadChatBadge(key: key, conversationKey: 'order:$orderId', countStream: () => FireStoreUtils.unreadOrderChatCount(orderId));

  /// The badge of the Help & Support thread (messages from the admin).
  factory UnreadChatBadge.adminChat({Key? key}) => UnreadChatBadge(key: key, conversationKey: 'admin', countStream: FireStoreUtils.unreadAdminChatCount);

  @override
  State<UnreadChatBadge> createState() => _UnreadChatBadgeState();
}

class _UnreadChatBadgeState extends State<UnreadChatBadge> {
  late Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.countStream();
  }

  @override
  void didUpdateWidget(covariant UnreadChatBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationKey != widget.conversationKey) _stream = widget.countStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      initialData: 0,
      builder: (context, snapshot) {
        final int count = snapshot.data ?? 0;
        final String label = unreadBadgeLabel(count);
        if (label.isEmpty) return const SizedBox.shrink();
        return Semantics(
          label: '${'Unread messages'.tr}: $label',
          excludeSemantics: true,
          child: DsBadge(label: label, tone: DsTone.danger, style: DsBadgeStyle.solid, small: true),
        );
      },
    );
  }
}
