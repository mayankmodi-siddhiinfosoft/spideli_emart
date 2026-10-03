import 'dart:async';
import 'dart:developer';

import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/services/booking_push.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/send_notification.dart';

/// The one place a provider action on an on-demand booking notifies the other
/// parties (.claude/ONDEMAND-NOTIFICATIONS.md). The booking list, the booking
/// details screen, the worker list and the extra-charges dialog all call
/// [notify] after their Firestore write; the plan of who gets what is
/// [planProviderBookingPushes].
///
/// Never throws and never blocks the action: callers fire it with
/// `unawaited(...)`, each push is sent independently, a failure is logged.
class BookingNotifier {
  static final BookingPushDeduper _deduper = BookingPushDeduper();

  /// The facts of [order] as written, for [planProviderBookingPushes].
  static BookingPushFacts factsOf(OnProviderOrderModel order, {String previousWorkerId = '', String workerToken = ''}) {
    String providerId = order.provider.author ?? '';
    if (providerId.trim().isEmpty) providerId = MyAppState.currentUser?.id ?? FireStoreUtils.getCurrentUid();
    final String customerId = order.authorID.trim().isNotEmpty ? order.authorID : order.author.id;
    return BookingPushFacts(
      orderId: order.id,
      status: order.status,
      serviceId: order.provider.id ?? '',
      serviceName: order.provider.title ?? '',
      customerId: customerId,
      customerToken: order.author.fcmToken,
      providerId: providerId,
      workerId: order.workerId ?? '',
      workerToken: workerToken,
      previousWorkerId: previousWorkerId,
    );
  }

  /// Sends the pushes of [action] on [order] (already written). For
  /// [ProviderBookingAction.assignWorker], [previousWorkerId] is the worker
  /// before the change and [workerToken] the new worker's token from the list.
  static Future<void> notify(ProviderBookingAction action, OnProviderOrderModel order, {String previousWorkerId = '', String workerToken = ''}) async {
    try {
      final List<BookingPush> pushes = planProviderBookingPushes(action, factsOf(order, previousWorkerId: previousWorkerId, workerToken: workerToken));
      await Future.wait(pushes.map(_sendOne));
    } catch (e) {
      log("Booking pushes for '${action.name}' not sent: $e");
    }
  }

  static Future<void> _sendOne(BookingPush push) async {
    if (!_deduper.claim(push.dedupeKey)) {
      log("Booking push ${push.event} skipped: already sent for this action.");
      return;
    }
    try {
      // The title and body are the template's (`dynamic_notification`).
      final bool sent = await SendNotification.sendFcmMessage(
        push.template,
        push.fallbackToken,
        push.data,
        recipientId: push.recipientId,
        recipient: push.recipient,
      );
      if (!sent) {
        // Not accepted by FCM: a retry of the action may send it again.
        _deduper.release(push.dedupeKey);
        log("Booking push ${push.event} to the ${push.recipient.name} not delivered.");
      }
    } catch (e) {
      _deduper.release(push.dedupeKey);
      log("Booking push ${push.event} failed: $e");
    }
  }
}
