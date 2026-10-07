import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/chat_unread.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Live unread-message badge of one conversation row in a chat inbox
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` section 2). Nothing is shown while the
/// count loads, when it is zero, or when it cannot be read.
///
/// The count is [FireStoreUtils.unreadChatCount]: a limited listener on that
/// conversation's unread messages for the store side (see
/// `lib/utils/chat_unread.dart`). The stream is made once per row, not on
/// every rebuild.
class ChatUnreadBadge extends StatefulWidget {
  /// `chat/{threadId}` (the order id, or the advertisement id for an admin
  /// conversation).
  final String threadId;

  /// The store side's user id: counts messages it received.
  final String? receiverId;

  /// `admin` for an admin conversation: counts messages admin sent.
  final String? senderId;

  const ChatUnreadBadge({super.key, required this.threadId, this.receiverId, this.senderId});

  @override
  State<ChatUnreadBadge> createState() => _ChatUnreadBadgeState();
}

class _ChatUnreadBadgeState extends State<ChatUnreadBadge> {
  late Stream<int> _count;

  @override
  void initState() {
    super.initState();
    _count = _stream();
  }

  @override
  void didUpdateWidget(covariant ChatUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId || oldWidget.receiverId != widget.receiverId || oldWidget.senderId != widget.senderId) {
      _count = _stream();
    }
  }

  Stream<int> _stream() => FireStoreUtils.unreadChatCount(threadId: widget.threadId, receiverId: widget.receiverId, senderId: widget.senderId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _count,
      builder: (context, snapshot) {
        final int count = snapshot.hasError ? 0 : (snapshot.data ?? 0);
        if (!ChatUnread.hasBadge(count)) return const SizedBox.shrink();
        return ChatUnreadCountPill(count: count);
      },
    );
  }
}

/// The badge itself: a solid brand pill with the capped count (`99+`).
class ChatUnreadCountPill extends StatelessWidget {
  final int count;

  const ChatUnreadCountPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final String label = ChatUnread.label(count);
    if (label.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: "@count unread messages".trParams({'count': label}),
      excludeSemantics: true,
      child: DsBadge(label: label, tone: DsTone.brand, style: DsBadgeStyle.solid, small: true),
    );
  }
}
