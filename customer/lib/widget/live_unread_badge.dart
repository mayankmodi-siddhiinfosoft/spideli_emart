import 'dart:async';

import 'package:customer/service/chat_unread_service.dart';
import 'package:customer/service/customer_notification_service.dart';
import 'package:customer/service/inbox_unread_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/unread_badge.dart';
import 'package:customer/utils/unread_sum.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A red count pill fed by a live unread-count stream: nothing at zero,
/// `99+` past 99 ([UnreadBadge.label]). The stream is created once per
/// [streamKey], so a rebuild of the row does not re-subscribe.
class LiveUnreadBadge extends StatefulWidget {
  /// Identifies the stream (thread id, uid...): a new key re-subscribes.
  final String streamKey;
  final Stream<int> Function() create;

  const LiveUnreadBadge({super.key, required this.streamKey, required this.create});

  /// The unread badge of the order chat [threadId] with [peerId] (a store,
  /// driver, provider or worker conversation row): only that peer's messages
  /// count, since the store and driver (or provider and worker) chats of one
  /// order share the thread. Nothing when signed out or without a thread.
  static Widget orderChat(String? threadId, [String? peerId]) {
    final String id = threadId?.trim() ?? '';
    final String peer = peerId?.trim() ?? '';
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (id.isEmpty || uid.isEmpty) return const SizedBox.shrink();
    return LiveUnreadBadge(streamKey: '$uid/$id/$peer', create: () => ChatUnreadService.orderThread(threadId: id, uid: uid, peerId: peer));
  }

  /// The unread badge of the Help & Support chat.
  static Widget supportChat() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return LiveUnreadBadge(streamKey: 'support/$uid', create: () => ChatUnreadService.supportThread(uid: uid));
  }

  /// The unread count of the Notification Center. Follows sign-in /
  /// sign-out itself (nothing while signed out), so it is right even when
  /// built before the auth state is restored.
  static Widget notifications() {
    return LiveUnreadBadge(
      streamKey: 'notifications',
      create: () => UnreadSum.perUser(InboxUnreadService.authUids(), CustomerNotificationService.unreadCount),
    );
  }

  /// The total unread count of the [kind] inbox (its newest
  /// [InboxUnreadService.conversationCap] conversations, each counted like
  /// its row badge in the inbox screen). Follows sign-in / sign-out itself.
  static Widget inbox(InboxKind kind) {
    return LiveUnreadBadge(streamKey: 'inbox/${kind.name}', create: () => InboxUnreadService.total(kind));
  }

  @override
  State<LiveUnreadBadge> createState() => _LiveUnreadBadgeState();
}

class _LiveUnreadBadgeState extends State<LiveUnreadBadge> {
  StreamSubscription<int>? _sub;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamKey != widget.streamKey) {
      _count = 0;
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.create().listen(
      (count) {
        if (mounted && count != _count) setState(() => _count = count);
      },
      // A failed listener (offline, rules) just shows no badge.
      onError: (Object _) {
        if (mounted && _count != 0) setState(() => _count = 0);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String label = UnreadBadge.label(_count);
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.xs),
      child: Semantics(
        label: '@n unread'.trParams({'n': label}),
        excludeSemantics: true,
        child: DsBadge(label: label, tone: DsTone.danger, style: DsBadgeStyle.solid, small: true),
      ),
    );
  }
}
