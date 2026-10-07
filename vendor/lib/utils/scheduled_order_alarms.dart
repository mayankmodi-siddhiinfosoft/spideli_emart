import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/notification_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';
import 'package:vendor/utils/scheduled_order.dart';

/// The local alarm of a scheduled order: one notification on the loud
/// `new_order` channel at the order's due time, that rings even with the app
/// closed. Its id is [ScheduledOrderRule.notificationId] of the order id, so
/// setting it again replaces it and it fires once.
///
/// One alert per order at its due time, never two:
/// * App in the foreground (and the order in this store's live list): no
///   alarm. The order listener's timer moves the order to New at its time and
///   the in-app alert rings (`HomeController`). Alarms of listed orders are
///   cancelled whenever the app comes to the foreground.
/// * App in the background or closed: the alarm rings, and the in-app alert
///   stays quiet for that order while the app is not in the foreground
///   ([coversInBackground]). Opening the app later behaves like any order
///   waiting in New.
/// * An order the live list does not have (another of the owner's stores, or
///   the list is not running) keeps its alarm in every state: it is then the
///   only alert.
///
/// Alarms are set from the silent push (background handler, or foreground
/// `onMessage`) and from the order listener, and cancelled when the order
/// leaves `Order Placed` before its time.
class ScheduledOrderAlarms {
  ScheduledOrderAlarms._();

  /// Scheduled orders of the live list (this store), id -> due time.
  static final Map<String, DateTime> _listed = {};

  /// Scheduled orders known only from their push, id -> due time.
  static final Map<String, DateTime> _pushed = {};

  /// Alarms this run has set and not cancelled, id -> due time.
  static final Map<String, DateTime> _armed = {};

  /// Ended orders whose leftover alarm this run already cancelled.
  static final Set<String> _cleared = {};

  static AppLifecycleListener? _lifecycle;
  static bool? _wasForeground;
  static ({String? title, String? body})? _template;

  static const Duration _readTimeout = Duration(seconds: 6);

  static bool get isForeground => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Starts following the app's foreground state (main isolate, once).
  static void start() {
    _wasForeground ??= isForeground;
    _lifecycle ??= AppLifecycleListener(onStateChange: (_) => unawaited(_onForegroundChanged(isForeground)));
  }

  static Future<void> _onForegroundChanged(bool foreground) async {
    if (_wasForeground == foreground) return;
    _wasForeground = foreground;
    final DateTime now = DateTime.now();
    if (foreground) {
      // The in-app alert takes over the listed orders.
      for (final MapEntry<String, DateTime> e in _listed.entries.toList()) {
        if (e.value.isAfter(now)) await _cancel(e.key);
      }
      _armed.removeWhere((id, due) => !due.isAfter(now));
    } else {
      for (final MapEntry<String, DateTime> e in _listed.entries.toList()) {
        if (e.value.isAfter(now)) await _arm(e.key, e.value);
      }
    }
  }

  /// True while [orderId]'s alarm is set and the app is not in the
  /// foreground: the alarm is that order's alert, so the in-app alert must
  /// not ring for it as well.
  static bool coversInBackground(String? orderId) => orderId != null && !isForeground && _armed.containsKey(orderId);

  /// From the order listener (main isolate) after every change.
  /// [waiting]: this store's scheduled orders that are not due yet, id ->
  /// due time. [endedBeforeDue]: orders that left `Order Placed` while their
  /// due time is still ahead (accepted, rejected, cancelled early).
  static Future<void> syncListed({required Map<String, DateTime> waiting, required Set<String> endedBeforeDue}) async {
    // No longer waiting (due now, or not in this list any more): the alarm,
    // if any, stays as it is.
    _listed.removeWhere((id, _) => !waiting.containsKey(id));
    for (final String id in endedBeforeDue) {
      _listed.remove(id);
      _pushed.remove(id);
      if (_cleared.add(id)) await _cancel(id);
    }
    final bool foreground = isForeground;
    for (final MapEntry<String, DateTime> e in waiting.entries) {
      if (_listed[e.key] == e.value) continue;
      _listed[e.key] = e.value;
      _pushed.remove(e.key);
      // In the foreground this also clears an alarm the push set.
      if (foreground) {
        await _cancel(e.key);
      } else {
        await _arm(e.key, e.value);
      }
    }
  }

  /// The silent push, received with the app in the foreground.
  static Future<void> handleForegroundPush(Map<String, dynamic> data) async {
    final ScheduledOrderPush? push = ScheduledOrderPush.parse(data);
    if (push == null) {
      log("scheduled-order push without a usable orderId / scheduleAt");
      return;
    }
    // The live list has it: the in-app alert handles it.
    if (_listed.containsKey(push.orderId)) return;
    final DateTime due = ScheduledOrderRule.dueAt(push.scheduleAt, lead: Constant.scheduleLeadTime)!;
    // Already due: it is a new order now (listed under New, and rung).
    if (!due.isAfter(DateTime.now())) return;
    _pushed[push.orderId] = due;
    await _arm(push.orderId, due);
  }

  /// The silent push, received with the app in the background or closed
  /// (FCM background handler; on Android its own isolate, with Firebase
  /// started by the handler). Reads the order (still waiting? its time) and
  /// the admin's lead time, then sets the alarm - or, when the order is
  /// already due, alerts now. Never throws.
  static Future<void> handleBackgroundPush(Map<String, dynamic> data) async {
    final ScheduledOrderPush? push = ScheduledOrderPush.parse(data);
    if (push == null) {
      log("scheduled-order push without a usable orderId / scheduleAt");
      return;
    }
    try {
      final bool firestore = await _ensureFirestore();
      final Future<({String? status, DateTime? scheduleTime})> orderRead = firestore ? _readOrder(push.orderId) : Future.value((status: null, scheduleTime: null));
      final Future<Duration> leadRead = firestore ? _readLeadTime() : Future.value(Constant.scheduleLeadTime);
      final ({String? status, DateTime? scheduleTime}) order = await orderRead;
      final Duration lead = await leadRead;
      if (order.status != null && order.status != ScheduledOrderRule.orderPlaced) {
        // Accepted, rejected or cancelled meanwhile.
        await _cancel(push.orderId);
        return;
      }
      final DateTime due = ScheduledOrderRule.dueAt(order.scheduleTime ?? push.scheduleAt, lead: lead)!;
      if (due.isAfter(DateTime.now())) {
        _pushed[push.orderId] = due;
        await _arm(push.orderId, due);
      } else {
        await _showNow(push.orderId);
      }
    } catch (e) {
      log("scheduled-order push handling failed: $e");
    }
  }

  /// Sign-out: every pending scheduled-order alarm goes.
  static Future<void> cancelAll() async {
    try {
      await NotificationService.ensureLocalReady();
      final List<PendingNotificationRequest> pending = await NotificationService.plugin.pendingNotificationRequests();
      for (final PendingNotificationRequest request in pending) {
        if ((request.payload ?? '').contains('"${ScheduledOrderPush.templateType}"')) {
          await NotificationService.plugin.cancel(id: request.id);
        }
      }
    } catch (e) {
      log("cancelling scheduled-order alarms failed: $e");
    }
    _listed.clear();
    _pushed.clear();
    _armed.clear();
    _cleared.clear();
    _template = null;
  }

  // ── Alarm ──

  static Future<void> _arm(String orderId, DateTime dueAt) async {
    if (!dueAt.isAfter(DateTime.now())) return;
    try {
      await NotificationService.ensureLocalReady();
      final ({String? title, String? body}) text = await _templateText();
      final AndroidScheduleMode mode = await _scheduleMode();
      await NotificationService.plugin.zonedSchedule(
        id: ScheduledOrderRule.notificationId(orderId),
        title: text.title,
        body: text.body,
        // UTC from the epoch: an absolute instant, no time-zone database.
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, dueAt.millisecondsSinceEpoch),
        notificationDetails: NotificationService.orderAlertDetails(),
        androidScheduleMode: mode,
        payload: ScheduledOrderPush.payloadFor(orderId),
      );
      _armed[orderId] = dueAt;
      log("scheduled-order alarm set for ${dueAt.toUtc().toIso8601String()} (${mode.name})");
    } catch (e) {
      log("setting the scheduled-order alarm failed: $e");
    }
  }

  static Future<void> _cancel(String orderId) async {
    _armed.remove(orderId);
    try {
      await NotificationService.ensureLocalReady();
      await NotificationService.plugin.cancel(id: ScheduledOrderRule.notificationId(orderId));
    } catch (e) {
      log("cancelling the scheduled-order alarm failed: $e");
    }
  }

  /// The order is already due: the alert, now (same id as its alarm).
  static Future<void> _showNow(String orderId) async {
    try {
      await NotificationService.ensureLocalReady();
      final ({String? title, String? body}) text = await _templateText();
      await NotificationService.plugin.show(
        id: ScheduledOrderRule.notificationId(orderId),
        title: text.title,
        body: text.body,
        notificationDetails: NotificationService.orderAlertDetails(),
        payload: ScheduledOrderPush.payloadFor(orderId),
      );
    } catch (e) {
      log("showing the scheduled-order alert failed: $e");
    }
  }

  /// Exact (to the minute, even in Doze) when the user allows exact alarms;
  /// otherwise inexact, which Android may delay (in Doze by several minutes).
  /// iOS ignores it.
  static Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final bool? exact = await NotificationService.plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications();
      return exact == true ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  // ── Firestore ──

  /// The alarm's text: the `dynamic_notification` template of type
  /// `schedule_order` (subject, message). There is no text in the app: when
  /// the template is missing or unreadable the alarm still rings, without
  /// text, and the reason is logged.
  static Future<({String? title, String? body})> _templateText() async {
    final ({String? title, String? body})? cached = _template;
    if (cached != null) return cached;
    try {
      if (!await _ensureFirestore()) return (title: null, body: null);
      final QuerySnapshot<Map<String, dynamic>> snapshot = await FireStoreUtils.fireStore
          .collection(CollectionName.dynamicNotification)
          .where('type', isEqualTo: ScheduledOrderPush.templateType)
          .limit(1)
          .get()
          .timeout(_readTimeout);
      if (snapshot.docs.isEmpty) {
        log("no dynamic_notification template '${ScheduledOrderPush.templateType}': the scheduled-order alarm has no text");
        return (title: null, body: null);
      }
      final NotificationModel template = NotificationModel.fromJson(snapshot.docs.first.data());
      return _template = (title: template.subject, body: template.message);
    } catch (e) {
      log("reading the '${ScheduledOrderPush.templateType}' template failed: $e");
      return (title: null, body: null);
    }
  }

  /// Firestore in this isolate, signed in (the background isolate restores
  /// the session itself). False when it cannot be used.
  static Future<bool> _ensureFirestore() async {
    try {
      if (!FireStoreUtils.isReady) {
        if (Firebase.apps.isEmpty) return false;
        FireStoreUtils.instance.initForEnv(Firebase.app());
      }
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null).timeout(const Duration(seconds: 4));
      }
      return true;
    } catch (e) {
      log("Firestore not usable for the scheduled-order push: $e");
      return FireStoreUtils.isReady && FirebaseAuth.instance.currentUser != null;
    }
  }

  static Future<({String? status, DateTime? scheduleTime})> _readOrder(String orderId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderId).get().timeout(_readTimeout);
      final Map<String, dynamic>? data = doc.data();
      if (data == null) return (status: null, scheduleTime: null);
      final Object? time = data['scheduleTime'];
      return (status: data['status']?.toString(), scheduleTime: time is Timestamp ? time.toDate() : null);
    } catch (e) {
      log("reading the scheduled order failed: $e");
      return (status: null, scheduleTime: null);
    }
  }

  static Future<Duration> _readLeadTime() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('scheduleOrderNotification').get().timeout(_readTimeout);
      final Map<String, dynamic>? data = doc.data();
      if (data == null) return Constant.scheduleLeadTime;
      return ScheduledOrderRule.leadTime(data['notifyTime'], data['timeUnit']);
    } catch (e) {
      log("reading the scheduled-order lead time failed: $e");
      return Constant.scheduleLeadTime;
    }
  }
}
