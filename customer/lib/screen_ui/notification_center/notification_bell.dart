import 'dart:async';

import 'package:customer/screen_ui/notification_center/notification_center_screen.dart';
import 'package:customer/service/customer_notification_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The bell that opens the Notification Center, with the live unread count
/// as its badge (`.claude/CUSTOMER-NOTIFICATIONS.md` §1). Hidden while
/// signed out; follows sign-in / sign-out on its own.
class NotificationBell extends StatefulWidget {
  final DsIconButtonVariant variant;
  final double size;

  /// Icon color (white on the brand gradient headers).
  final Color? color;

  /// Space after the bell, shown only with it (no stray gap while signed out).
  final double trailingGap;

  const NotificationBell({super.key, this.variant = DsIconButtonVariant.plain, this.size = 40, this.color, this.trailingGap = 0});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<int>? _countSub;
  String? _uid;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _setUser(FirebaseAuth.instance.currentUser?.uid, rebuild: false);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) => _setUser(user?.uid), onError: (Object _) {});
  }

  void _setUser(String? uid, {bool rebuild = true}) {
    final String? id = (uid == null || uid.trim().isEmpty) ? null : uid.trim();
    if (id == _uid && (_countSub != null || id == null)) return;
    _countSub?.cancel();
    _countSub = null;
    _uid = id;
    _unread = 0;
    if (id != null) {
      _countSub = CustomerNotificationService.unreadCount(id).listen(
        (count) {
          if (mounted && count != _unread) setState(() => _unread = count);
        },
        onError: (Object _) {
          if (mounted && _unread != 0) setState(() => _unread = 0);
        },
      );
    }
    if (rebuild && mounted) setState(() {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _countSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const SizedBox.shrink();
    final Widget bell = DsIconButton(
      icon: _unread > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
      semanticLabel: _unread > 0 ? '@n unread notifications'.trParams({'n': '$_unread'}) : 'Notifications'.tr,
      variant: widget.variant,
      size: widget.size,
      color: widget.color,
      badgeCount: _unread,
      onPressed: () => Get.to(() => const NotificationCenterScreen()),
    );
    if (widget.trailingGap <= 0) return bell;
    return Padding(padding: EdgeInsetsDirectional.only(end: widget.trailingGap), child: bell);
  }
}
