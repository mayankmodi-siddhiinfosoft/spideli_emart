/// Orders placed for a later time ("scheduled orders"). Pure: no Firebase, no
/// Flutter, so every rule here is unit tested (test/scheduled_order_test.dart).
///
/// A scheduled order stays quiet until it is due: it is listed under
/// Scheduled with no Accept / Reject, nothing rings, and the customer app
/// sends the store no push. When it is due it moves to New (the in-app due
/// timer, or the push below) and the store is alerted: by the in-app ring,
/// and by the `scheduledOrderNotifier` Cloud Function's push
/// (`functions/`, type `scheduled_order_due`) on the `new_order` channel.
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

/// The push the `scheduledOrderNotifier` Cloud Function sends the store owner
/// when a scheduled order becomes due: `{type: "scheduled_order_due",
/// orderId}` with a `notification` (template `schedule_order`) on the
/// `new_order` channel.
class ScheduledOrderDuePush {
  ScheduledOrderDuePush._();

  /// `data.type` of the Cloud Function's push.
  static const String type = 'scheduled_order_due';

  /// The template (`dynamic_notification`) type of a scheduled order. Older
  /// customer builds sent it when the order was PLACED, so it does not prove
  /// that the order is due: it only makes the store split its tabs again.
  static const String templateType = 'schedule_order';

  static String _typeOf(Map<String, dynamic> data) => '${data['type'] ?? ''}'.trim();

  /// The order id of a scheduled-order push ([type] or [templateType]), or
  /// null for any other push or one without a usable order id. Never throws.
  static String? orderIdOf(Map<String, dynamic> data) {
    final String t = _typeOf(data);
    if (t != type && t != templateType) return null;
    final String orderId = '${data['orderId'] ?? ''}'.trim();
    if (orderId.isEmpty || orderId == 'null') return null;
    return orderId;
  }

  /// True only for the Cloud Function's push: the server decided the order
  /// is due, so it is New even if this phone's clock is a little behind.
  static bool isServerDue(Map<String, dynamic> data) => _typeOf(data) == type && orderIdOf(data) != null;
}
