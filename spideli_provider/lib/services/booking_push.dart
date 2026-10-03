// On-demand booking pushes (.claude/ONDEMAND-NOTIFICATIONS.md): which pushes a
// provider action sends, their data payload, and where a tapped booking push
// leads. Pure: no Flutter, no Firebase, so it is unit tested
// (test/booking_push_test.dart). The sending lives in booking_notifier.dart,
// the tap routing in notification_service.dart.
import 'package:spideliprovider/services/push_message.dart';

/// Booking statuses (the same strings as ORDER_STATUS_* in constants.dart,
/// repeated here so this file stays free of Flutter imports).
class BookingStatus {
  static const String placed = 'Order Placed';
  static const String accepted = 'Order Accepted';
  static const String assigned = 'Order Assigned';
  static const String ongoing = 'Order Ongoing';
  static const String completed = 'Order Completed';
  static const String rejected = 'Order Rejected';
  static const String cancelled = 'Order Cancelled';
}

/// The `event` codes of the contract.
class BookingEvent {
  // Sent by this app.
  static const String providerAccepted = 'provider_accepted';
  static const String providerRejected = 'provider_rejected';
  static const String workerAssigned = 'worker_assigned';
  static const String workerAssignedCustomer = 'worker_assigned_customer';
  static const String workerUnassigned = 'worker_unassigned';
  static const String serviceInTransit = 'service_intransit';
  static const String stopTime = 'stop_time';
  static const String serviceCharges = 'service_charges';
  static const String serviceCompleted = 'service_completed';

  /// Contract #14: "Assign to Myself" (Accepted -> Assigned, no worker).
  static const String providerSelfAssigned = 'provider_self_assigned';

  // Received by this app (sent by the customer and worker apps).
  static const String bookingPlaced = 'booking_placed';
  static const String bookingCancelledByCustomer = 'booking_cancelled_by_customer';
  static const String workerAccepted = 'worker_accepted';
  static const String workerRejected = 'worker_rejected';

  /// Every event code of an on-demand booking push.
  static const Set<String> all = <String>{
    providerAccepted,
    providerRejected,
    workerAssigned,
    workerAssignedCustomer,
    workerUnassigned,
    serviceInTransit,
    stopTime,
    serviceCharges,
    serviceCompleted,
    providerSelfAssigned,
    bookingPlaced,
    bookingCancelledByCustomer,
    workerAccepted,
    workerRejected,
    // Template names other apps may use as `type` for a booking push.
    'service_cancelled',
  };
}

/// The `dynamic_notification` templates (looked up by `type`; `subject` is
/// the title, `message` the body) the provider's booking pushes are sent
/// with. Every push's text comes from its template: none is written here.
class BookingTemplate {
  static const String providerAccepted = 'provider_accepted';
  static const String providerRejected = 'provider_rejected';

  /// The decline / cancel, to the worker who was assigned.
  static const String providerRejectedWorker = 'provider_rejected_worker';
  static const String providerSelfAssigned = 'provider_self_assigned';
  static const String workerAssigned = 'worker_assigned';

  /// To the customer: a worker assigned to a booking that had none.
  static const String workerAssignedCustomer = 'worker_assigned_customer';

  /// To the customer: the booking's worker replaced by another.
  static const String workerChangedCustomer = 'worker_changed_customer';

  /// To the previous worker of a reassigned booking.
  static const String workerUnassigned = 'worker_unassigned';
  static const String serviceInTransit = 'service_intransit';
  static const String stopTime = 'stop_time';
  static const String serviceCharges = 'service_charges';
  static const String serviceCompleted = 'service_completed';
}

/// The routing key every on-demand booking push carries in `type`.
const String bookingPushType = 'provider_order';

/// What the provider did to a booking.
enum ProviderBookingAction {
  accept,
  reject,

  /// "Assign to Myself": the provider does the job, no worker.
  assignSelf,

  /// Assign a worker, or reassign the booking to another worker.
  assignWorker,
  start,
  stopTime,
  extraCharges,
  complete,
}

/// What is known about the booking when the push is sent (after the write).
class BookingPushFacts {
  final String orderId;

  /// The status after the action.
  final String status;
  final String serviceId;
  final String serviceName;

  /// The customer (`provider_orders.authorID`) and the token copied on the
  /// booking, used only when `users/{customerId}` cannot be read.
  final String customerId;
  final String customerToken;
  final String providerId;

  /// The worker on the booking after the action ('' for none).
  final String workerId;

  /// The new worker's token from the list it was picked from (fallback only).
  final String workerToken;

  /// The worker on the booking before a reassignment ('' for none).
  final String previousWorkerId;

  const BookingPushFacts({
    required this.orderId,
    required this.status,
    this.serviceId = '',
    this.serviceName = '',
    this.customerId = '',
    this.customerToken = '',
    this.providerId = '',
    this.workerId = '',
    this.workerToken = '',
    this.previousWorkerId = '',
  });
}

/// One push to one recipient.
class BookingPush {
  final String event;
  final PushApp recipient;

  /// The recipient's uid: their current token is read from their record.
  final String recipientId;

  /// The token copy to use only when the record cannot be read.
  final String fallbackToken;

  /// The `dynamic_notification` template ([BookingTemplate]) that gives the
  /// push its title and body.
  final String template;

  /// The data block (strings only, no empty values).
  final Map<String, String> data;

  const BookingPush({
    required this.event,
    required this.recipient,
    required this.recipientId,
    required this.fallbackToken,
    required this.template,
    required this.data,
  });

  /// Same booking, event, status and recipient: the same push.
  String get dedupeKey => '${data['orderId'] ?? ''}|$event|${data['status'] ?? ''}|${recipient.name}|$recipientId';

  @override
  String toString() => 'BookingPush($event -> ${recipient.name} $recipientId, template $template)';
}

String _clean(String? value) {
  final String text = (value ?? '').trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

/// The contract data block of a booking push: strings only, empty values
/// dropped (never "null").
Map<String, String> bookingPushData(String event, BookingPushFacts facts, {bool withPreviousWorker = false}) {
  final Map<String, String> data = <String, String>{
    'type': bookingPushType,
    'event': event,
    'orderId': _clean(facts.orderId),
    'status': _clean(facts.status),
    'serviceId': _clean(facts.serviceId),
    'serviceName': _clean(facts.serviceName),
    'customerId': _clean(facts.customerId),
    'providerId': _clean(facts.providerId),
    'workerId': _clean(facts.workerId),
    if (withPreviousWorker) 'previousWorkerId': _clean(facts.previousWorkerId),
    'senderRole': 'provider',
  };
  data.removeWhere((String _, String value) => value.isEmpty);
  return data;
}

/// The pushes [action] sends: one per recipient (contract events 3-11, 14).
/// Empty when the booking has no id, or when nothing changed (the same worker
/// picked again).
List<BookingPush> planProviderBookingPushes(ProviderBookingAction action, BookingPushFacts facts) {
  if (_clean(facts.orderId).isEmpty) return const <BookingPush>[];
  final String customerId = _clean(facts.customerId);
  final String customerToken = _clean(facts.customerToken);
  final String workerId = _clean(facts.workerId);
  final String previousWorkerId = _clean(facts.previousWorkerId);
  final bool hasCustomer = customerId.isNotEmpty || isUsableFcmToken(customerToken);
  final List<BookingPush> pushes = <BookingPush>[];

  void toCustomer(String event, String template) {
    if (!hasCustomer) return;
    pushes.add(BookingPush(
      event: event,
      recipient: PushApp.customer,
      recipientId: customerId,
      fallbackToken: customerToken,
      template: template,
      data: bookingPushData(event, facts),
    ));
  }

  void toWorker(String id, String token, String event, String template, {bool withPreviousWorker = false}) {
    if (id.isEmpty) return;
    pushes.add(BookingPush(
      event: event,
      recipient: PushApp.worker,
      recipientId: id,
      fallbackToken: token,
      template: template,
      data: bookingPushData(event, facts, withPreviousWorker: withPreviousWorker),
    ));
  }

  switch (action) {
    case ProviderBookingAction.accept:
      toCustomer(BookingEvent.providerAccepted, BookingTemplate.providerAccepted);
      break;
    case ProviderBookingAction.reject:
      toCustomer(BookingEvent.providerRejected, BookingTemplate.providerRejected);
      // The customer's template is worded for the customer: the worker's own.
      toWorker(workerId, '', BookingEvent.providerRejected, BookingTemplate.providerRejectedWorker);
      break;
    case ProviderBookingAction.assignSelf:
      toCustomer(BookingEvent.providerSelfAssigned, BookingTemplate.providerSelfAssigned);
      break;
    case ProviderBookingAction.assignWorker:
      if (workerId.isEmpty || workerId == previousWorkerId) break;
      final bool reassigned = previousWorkerId.isNotEmpty;
      toWorker(workerId, _clean(facts.workerToken), BookingEvent.workerAssigned, BookingTemplate.workerAssigned);
      toWorker(previousWorkerId, '', BookingEvent.workerUnassigned, BookingTemplate.workerUnassigned, withPreviousWorker: true);
      toCustomer(BookingEvent.workerAssignedCustomer, reassigned ? BookingTemplate.workerChangedCustomer : BookingTemplate.workerAssignedCustomer);
      break;
    case ProviderBookingAction.start:
      toCustomer(BookingEvent.serviceInTransit, BookingTemplate.serviceInTransit);
      break;
    case ProviderBookingAction.stopTime:
      toCustomer(BookingEvent.stopTime, BookingTemplate.stopTime);
      break;
    case ProviderBookingAction.extraCharges:
      toCustomer(BookingEvent.serviceCharges, BookingTemplate.serviceCharges);
      break;
    case ProviderBookingAction.complete:
      toCustomer(BookingEvent.serviceCompleted, BookingTemplate.serviceCompleted);
      break;
  }
  return pushes;
}

/// Drops a push identical to one sent moments ago (a double tap, or two
/// handlers reacting to the same action), so each recipient gets one push per
/// action. A later identical push (a worker reassigned back) is sent again.
class BookingPushDeduper {
  final Duration window;
  final DateTime Function() _now;
  final Map<String, DateTime> _sent = <String, DateTime>{};

  BookingPushDeduper({this.window = const Duration(seconds: 30), DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// True the first time [key] is seen within [window]; records it.
  bool claim(String key) {
    final DateTime now = _now();
    _sent.removeWhere((String _, DateTime at) => now.difference(at) >= window);
    if (_sent.containsKey(key)) return false;
    _sent[key] = now;
    return true;
  }

  /// Forgets [key] so a send that failed before reaching FCM can be retried.
  void release(String key) => _sent.remove(key);
}

// -----------------------------------------------------------------------------
// Taps
// -----------------------------------------------------------------------------

/// The screen a tapped push opens in this app.
enum ProviderTapKind { bookingDetails, bookingList, orderChat, providerChat, adminChat, none }

class ProviderTapTarget {
  final ProviderTapKind kind;

  /// The booking ('' when there is none).
  final String orderId;

  const ProviderTapTarget(this.kind, [this.orderId = '']);

  @override
  bool operator ==(Object other) => other is ProviderTapTarget && other.kind == kind && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(kind, orderId);

  @override
  String toString() => 'ProviderTapTarget(${kind.name}${orderId.isEmpty ? '' : ', $orderId'})';
}

/// Whether [data] is an on-demand booking push: `type` provider_order (or an
/// event code used as the type by an older sender), or a known `event`.
bool isBookingPush(Map<dynamic, dynamic>? data) {
  final String type = pushDataString(data, 'type');
  if (type == bookingPushType || BookingEvent.all.contains(type)) return true;
  return type.isEmpty && BookingEvent.all.contains(pushDataString(data, 'event'));
}

/// A Firestore document id that can be opened: not empty, no path separator
/// (`.doc('a/b')` addresses another collection, or throws).
bool isOpenableOrderId(String id) {
  final String t = id.trim();
  return t.isNotEmpty && !t.contains('/') && t != '.' && t != '..' && t.length <= 1500;
}

/// Where a tap on a push with [data] leads. Never throws.
ProviderTapTarget providerTapTarget(Map<dynamic, dynamic>? data) {
  if (data == null || data.isEmpty) return const ProviderTapTarget(ProviderTapKind.none);
  final String type = pushDataString(data, 'type');
  final String orderId = pushDataString(data, 'orderId');
  if (isBookingPush(data)) {
    return isOpenableOrderId(orderId) ? ProviderTapTarget(ProviderTapKind.bookingDetails, orderId) : const ProviderTapTarget(ProviderTapKind.bookingList);
  }
  switch (type) {
    case 'orderChat':
      return orderId.isEmpty || pushDataString(data, 'senderId').isEmpty
          ? const ProviderTapTarget(ProviderTapKind.none)
          : ProviderTapTarget(ProviderTapKind.orderChat, orderId);
    case 'provider_chat':
      return orderId.isEmpty ? const ProviderTapTarget(ProviderTapKind.none) : ProviderTapTarget(ProviderTapKind.providerChat, orderId);
    case 'admin_chat':
    case 'admin':
      return const ProviderTapTarget(ProviderTapKind.adminChat);
    default:
      return const ProviderTapTarget(ProviderTapKind.none);
  }
}
