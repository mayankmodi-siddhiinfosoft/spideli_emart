import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:vendor/utils/store_chat.dart';
import 'package:vendor/utils/store_chat_topic.dart';

/// Keeps this device's store chat topic subscription ([StoreChatTopic]) in
/// line with the signed-in user: subscribed to `store_chat_<vendorID>` only
/// for an employee whose role allows Chat, nothing otherwise.
///
/// Checked when the FCM token is saved (start-up, sign-in, sign-up, OTP),
/// when the token changes, and every time the app comes back to the
/// foreground (the owner may have changed the role or moved the employee to
/// another store). [signOut] removes it before signing out. The subscribed
/// topic is remembered in preferences, so a stale one (another store, a
/// revoked permission, another account on this phone) is removed.
///
/// Never throws. A failed read changes nothing (a network blip must not drop
/// a working subscription); it is checked again on the next resume.
class StoreChatTopicService with WidgetsBindingObserver {
  StoreChatTopicService._();

  static final StoreChatTopicService _instance = StoreChatTopicService._();

  /// Preferences key of the subscribed topic ('' = none).
  static const String prefKey = 'storeChatTopic';

  static bool _observing = false;
  static bool _checkedThisRun = false;
  static Future<void> _queue = Future<void>.value();

  /// Re-check on every return to the foreground. Once per run.
  static void observeLifecycle() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(_instance);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  /// Brings the subscription in line with the signed-in user. [resubscribe]
  /// subscribes again even when unchanged (a new FCM token).
  static Future<void> sync({bool resubscribe = false}) => _enqueue(() => _sync(resubscribe));

  /// Before signing out: leaves the remembered topic (bounded).
  static Future<void> signOut() => _enqueue(() => _apply(StoreChatTopic.change(remembered: _remembered(), desired: null))).timeout(
    const Duration(seconds: 8),
    onTimeout: () => log("store chat topic: unsubscribe on sign-out timed out"),
  );

  static Future<void> _enqueue(Future<void> Function() run) {
    final Future<void> next = _queue.then((_) => run()).catchError((Object e) => log("store chat topic: $e"));
    _queue = next;
    return next;
  }

  static String _remembered() {
    try {
      return Preferences.getString(prefKey);
    } catch (_) {
      return '';
    }
  }

  static Future<void> _sync(bool resubscribe) async {
    final User? user = FirebaseAuth.instance.currentUser;
    String? desired;
    if (user != null) {
      final _Access? access = await _readAccess(user.uid);
      if (access == null) return; // unknown: change nothing
      desired = StoreChatTopic.desired(signedIn: true, role: access.user?.role, vendorId: access.user?.vendorID, permissions: access.role?.permissions);
    }
    final bool heal = resubscribe || !_checkedThisRun;
    _checkedThisRun = true;
    await _apply(StoreChatTopic.change(remembered: _remembered(), desired: desired, resubscribe: heal));
  }

  /// The user's profile and (for an employee) role, read fresh. Null when a
  /// read failed.
  static Future<_Access?> _readAccess(String uid) async {
    try {
      final UserModel? me = await FireStoreUtils.getUserById(uid);
      final String roleId = (me?.employeePermissionId ?? '').trim();
      if (me == null || !StoreChat.isEmployee(me.role) || roleId.isEmpty) return _Access(me, null);
      final snapshot = await FireStoreUtils.fireStore.collection(CollectionName.vendorEmployeeRoles).doc(roleId).get();
      final Map<String, dynamic>? data = snapshot.data();
      // A deleted role: no role, so no chat.
      return _Access(me, snapshot.exists && data != null ? EmployeeRoleModel.fromJson(data) : null);
    } catch (e) {
      log("store chat topic: access read failed: $e");
      return null;
    }
  }

  static Future<void> _apply(StoreChatTopicChange change) async {
    if (change.isNone) return;
    final String? old = change.unsubscribe;
    if (old != null) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(old);
        await Preferences.setString(prefKey, '');
        log("store chat topic: left $old");
      } catch (e) {
        // Kept remembered: retried on the next check. Nothing new is joined
        // meanwhile (two stores' chats on one phone).
        log("store chat topic: unsubscribe failed: $e");
        return;
      }
    }
    final String? topic = change.subscribe;
    if (topic != null) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        await Preferences.setString(prefKey, topic);
        log("store chat topic: joined $topic");
      } catch (e) {
        // iOS before the APNs token, or offline: retried on the next check.
        log("store chat topic: subscribe failed: $e");
      }
    }
  }
}

class _Access {
  const _Access(this.user, this.role);

  /// Null: the profile does not exist (no topic).
  final UserModel? user;
  final EmployeeRoleModel? role;
}
