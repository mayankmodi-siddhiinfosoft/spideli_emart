import 'dart:convert';

/// Orders placed for a later time ("scheduled orders"). Pure: no Firebase, no
/// Flutter, so every rule here is unit tested (test/scheduled_order_test.dart).
///
/// A scheduled order stays quiet until it is due: it is listed under
/// Scheduled with no Accept / Reject, nothing rings, and the customer app
/// sends the store only a silent data push (`type: scheduled_order`). When it
/// is due it moves to New and alerts the store once - in the app when the app
/// is open, otherwise with a local notification set for that time.
///
/// "Due" is the scheduled time minus the admin's lead time
/// (`settings/scheduleOrderNotification` `notifyTime` + `timeUnit`, the same
/// setting the Accept button already waited for; 0 by default, i.e. exactly
/// at the scheduled time).
class ScheduledOrderRule {
  ScheduledOrderRule._();

  /// `Constant.orderPlaced`: the only status a scheduled order waits in.
  static const String orderPlaced = 'Order Placed';

  /// How far past "now" a due time must be for the order still to count as
  /// scheduled. 0: an order is actionable from its due time on.
  static const Duration grace = Duration.zero;

  /// The admin's lead time: [notifyTime] (a number, also as a string) in
  /// [timeUnit] `minute` / `hour` / `day`. Same reading as
  /// `Constant.checkScheduleTime`, which this replaces: a missing or
  /// unreadable number is 0, an unknown unit is one minute. Never negative.
  static Duration leadTime(Object? notifyTime, Object? timeUnit) {
    final int value = int.tryParse('${notifyTime ?? ''}'.trim()) ?? 0;
    final Duration lead;
    switch ('${timeUnit ?? ''}'.trim()) {
      case 'minute':
        lead = Duration(minutes: value);
        break;
      case 'hour':
        lead = Duration(hours: value);
        break;
      case 'day':
        lead = Duration(days: value);
        break;
      default:
        lead = const Duration(minutes: 1);
    }
    return lead.isNegative ? Duration.zero : lead;
  }

  /// When the store can (and should) act on an order scheduled for
  /// [scheduleTime]; null for an order with no scheduled time.
  static DateTime? dueAt(DateTime? scheduleTime, {Duration lead = Duration.zero}) => scheduleTime?.subtract(lead);

  /// True while an order waits for its time: still `Order Placed`, and its
  /// due time is after [now] (+ [grace]). Such an order is not new yet: no
  /// Accept / Reject, no ring.
  static bool isScheduledFuture({required String? status, required DateTime? scheduleTime, required DateTime now, Duration lead = Duration.zero}) {
    if (status != orderPlaced) return false;
    final DateTime? due = dueAt(scheduleTime, lead: lead);
    return due != null && due.isAfter(now.add(grace));
  }

  /// Splits the `Order Placed` orders of [orders] into the ones the store can
  /// act on now ([ScheduledSplit.actionable], the New tab, which rings) and
  /// the ones still waiting for their time ([ScheduledSplit.scheduled],
  /// soonest first). Orders in any other status are in neither list.
  static ScheduledSplit<T> split<T>(
    Iterable<T> orders, {
    required String? Function(T order) status,
    required DateTime? Function(T order) scheduleTime,
    required DateTime now,
    Duration lead = Duration.zero,
  }) {
    final List<T> actionable = [];
    final List<(T, DateTime)> scheduled = [];
    for (final T order in orders) {
      if (status(order) != orderPlaced) continue;
      final DateTime? time = scheduleTime(order);
      if (isScheduledFuture(status: orderPlaced, scheduleTime: time, now: now, lead: lead)) {
        scheduled.add((order, dueAt(time, lead: lead)!));
      } else {
        actionable.add(order);
      }
    }
    scheduled.sort((a, b) => a.$2.compareTo(b.$2));
    return ScheduledSplit<T>(actionable: actionable, scheduled: [for (final s in scheduled) s.$1], nextDueAt: scheduled.isEmpty ? null : scheduled.first.$2);
  }

  /// Local notification id of an order's alarm: the same for the same order
  /// id in every run and every isolate (FNV-1a, 31 bits, never 0), so
  /// scheduling it again replaces the pending one and it fires once.
  /// `String.hashCode` is not guaranteed to be stable across runs.
  static int notificationId(String orderId) {
    int hash = 0x811c9dc5;
    for (final int unit in utf8.encode(orderId)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final int id = hash & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}

/// [ScheduledOrderRule.split]'s result.
class ScheduledSplit<T> {
  final List<T> actionable;
  final List<T> scheduled;

  /// The soonest due time among [scheduled] (when the lists must be split
  /// again), or null when nothing is scheduled.
  final DateTime? nextDueAt;

  const ScheduledSplit({required this.actionable, required this.scheduled, required this.nextDueAt});
}

/// The silent push the customer app sends the store owner for a scheduled
/// order: `{type: "scheduled_order", orderId, scheduleAt: "<epoch ms>"}`.
class ScheduledOrderPush {
  final String orderId;

  /// The order's scheduled time (not the due time: the store applies its
  /// lead time itself).
  final DateTime scheduleAt;

  const ScheduledOrderPush({required this.orderId, required this.scheduleAt});

  static const String type = 'scheduled_order';

  /// The template (`dynamic_notification`) whose text the alarm shows.
  static const String templateType = 'schedule_order';

  /// The local notification's payload. Its `type` is the template type,
  /// which a tap routes to the store's orders (`NotificationRouting`).
  static String payloadFor(String orderId) => jsonEncode({'type': templateType, 'orderId': orderId});

  /// True when [data] is a scheduled-order push (whatever else it carries).
  static bool isScheduledOrder(Map<String, dynamic> data) => '${data['type'] ?? ''}'.trim() == type;

  /// The push in [data], or null when it is not one or is unusable (no
  /// order id, no readable time). Never throws.
  static ScheduledOrderPush? parse(Map<String, dynamic> data) {
    if (!isScheduledOrder(data)) return null;
    final String orderId = '${data['orderId'] ?? ''}'.trim();
    final int? ms = int.tryParse('${data['scheduleAt'] ?? ''}'.trim());
    if (orderId.isEmpty || orderId == 'null' || ms == null || ms <= 0) return null;
    return ScheduledOrderPush(orderId: orderId, scheduleAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
  }
}
