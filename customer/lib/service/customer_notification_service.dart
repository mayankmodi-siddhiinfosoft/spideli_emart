import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/customer_notification_record.dart';
import 'package:customer/utils/push_tap.dart';
import 'package:customer/utils/unread_badge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Firestore side of the customer Notification Center:
/// `users/{customerId}/notifications/{id}` (`.claude/CUSTOMER-NOTIFICATIONS.md` §1).
/// The pure rules (ids, categories) are [CustomerNotificationRecord].
abstract final class CustomerNotificationService {
  /// How many notifications the center lists (newest first).
  static const int pageSize = 100;

  /// Firestore allows 500 writes per batch.
  static const int _batchSize = 450;

  static CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).collection(CollectionName.userNotifications);

  /// The signed-in customer's uid, null when signed out.
  static String? get currentUid {
    final String uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  /// The newest [pageSize] notifications of [uid], live.
  static Stream<List<CustomerNotificationModel>> watch(String uid) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CustomerNotificationModel.fromMap(d.id, d.data())).toList());
  }

  /// How many of [uid]'s notifications are unread, live. Reads at most
  /// [UnreadBadge.queryLimit] documents: the badge shows `99+` past that.
  static Stream<int> unreadCount(String uid) {
    return _collection(uid).where('read', isEqualTo: false).limit(UnreadBadge.queryLimit).snapshots().map((snap) => snap.size);
  }

  /// Marks one notification read. Never throws.
  static Future<void> markRead(String uid, String id) async {
    if (uid.isEmpty || id.isEmpty) return;
    try {
      await _collection(uid).doc(id).update({'read': true});
    } catch (e) {
      log('notifications: mark read failed (${e.runtimeType})');
    }
  }

  /// Marks the notifications [ids] read in batched writes. Never throws.
  static Future<void> markAllShownRead(String uid, List<String> ids) async {
    if (uid.isEmpty || ids.isEmpty) return;
    for (int start = 0; start < ids.length; start += _batchSize) {
      final int end = (start + _batchSize).clamp(0, ids.length);
      final WriteBatch batch = FireStoreUtils.fireStore.batch();
      for (final String id in ids.sublist(start, end)) {
        if (id.isEmpty) continue;
        batch.update(_collection(uid).doc(id), {'read': true});
      }
      try {
        await batch.commit();
      } catch (e) {
        log('notifications: mark shown read failed (${e.runtimeType})');
      }
    }
  }

  /// Records a received push in the center when its sender did not (no
  /// `notificationId` in its data): admin-panel pushes and older sender
  /// builds. Called by every receive path (foreground, background, opened
  /// app); they all write the same document id
  /// ([CustomerNotificationRecord.fallbackId]), so it is stored once. A push
  /// with no text (data-only) is not a notification the customer saw and is
  /// not recorded. [waitForAuth]: the background isolate restores the
  /// signed-in user asynchronously. Never throws.
  static const Duration _writeTimeout = Duration(seconds: 10);

  static Future<void> recordPush(RemoteMessage message, {bool waitForAuth = false}) async {
    try {
      final Map<String, dynamic> data = message.data;
      if (!CustomerNotificationRecord.needsFallback(data)) return;
      final text = PushTap.displayText(title: message.notification?.title, body: message.notification?.body, data: data);
      if (text == null) return;

      String? uid = currentUid;
      if (uid == null && waitForAuth) {
        try {
          final User? user = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 5));
          final String id = user?.uid.trim() ?? '';
          uid = id.isEmpty ? null : id;
        } catch (_) {
          uid = null;
        }
      }
      if (uid == null) return;

      final String id = CustomerNotificationRecord.fallbackId(
        messageId: message.messageId,
        data: data,
        sentTime: message.sentTime,
        title: text.title,
        body: text.body,
      );
      final DocumentReference<Map<String, dynamic>> ref = _collection(uid).doc(id);
      // Already recorded (another handler, or a repeat delivery): keep it as
      // it is, `read: true` included.
      try {
        final snap = await ref.get().timeout(_writeTimeout);
        if (snap.exists) return;
      } catch (_) {
        // Offline and not cached: unknown whether it is stored (maybe read
        // already), so write nothing rather than reset `read`. A later
        // receive path (app opened, initial message) records it.
        return;
      }
      // Bounded: offline, the write stays queued and completes later, but the
      // background handler does not wait for the server.
      await ref
          .set(
            CustomerNotificationRecord.document(id: id, title: text.title, body: text.body, data: data, createdAt: FieldValue.serverTimestamp()),
            SetOptions(merge: true),
          )
          .timeout(_writeTimeout);
    } catch (e) {
      log('notifications: record push failed (${e.runtimeType})');
    }
  }
}
