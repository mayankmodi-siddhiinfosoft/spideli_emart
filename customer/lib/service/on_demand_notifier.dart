import 'dart:developer';

import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/worker_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/on_demand_push.dart';

/// Sends the customer's on-demand booking pushes
/// (`.claude/ONDEMAND-NOTIFICATIONS.md`) to the provider and, when one is
/// assigned, the worker. Always called after the booking's Firestore write;
/// never throws and never blocks the action: callers do not await it.
///
/// The recipient's CURRENT token is read: the provider from
/// `users/{order.provider.author}`, the worker from
/// `providers_workers/{order.workerId}` (bookings carry no copy of either).
abstract final class OnDemandNotifier {
  /// [1] A new booking: the provider, template `booking_placed`.
  static Future<void> bookingPlaced(OnProviderOrderModel order) {
    return _send(order, event: OnDemandPush.bookingPlaced, toWorker: false);
  }

  /// [2] The customer cancelled: the provider and the assigned worker,
  /// template `service_cancelled`.
  static Future<void> bookingCancelled(OnProviderOrderModel order) {
    return _send(order, event: OnDemandPush.bookingCancelledByCustomer, toWorker: true);
  }

  /// [14] An hourly booking paid from its details screen ("Pay Now"): the
  /// provider and the assigned worker, template `booking_paid`.
  static Future<void> bookingPaid(OnProviderOrderModel order) {
    return _send(order, event: OnDemandPush.bookingPaid, toWorker: true);
  }

  /// [14] Extra charges paid: the provider and the assigned worker, template
  /// `extra_charges_paid`.
  static Future<void> extraChargesPaid(OnProviderOrderModel order) {
    return _send(order, event: OnDemandPush.extraChargesPaid, toWorker: true);
  }

  /// The contract payload of [order] for [event].
  static Map<String, String> payloadFor(OnProviderOrderModel order, String event) {
    return OnDemandPush.payload(
      event: event,
      orderId: order.id,
      status: order.status,
      serviceId: order.provider.id,
      serviceName: order.provider.title,
      customerId: order.authorID,
      providerId: order.provider.author,
      workerId: order.workerId,
    );
  }

  /// One push to the provider and, with [toWorker] and an assigned worker,
  /// one to the worker, with the title and body of the Firestore template of
  /// [event] ([OnDemandPush.templateFor], `dynamic_notification`); no text is
  /// written in the app.
  static Future<void> _send(OnProviderOrderModel order, {required String event, required bool toWorker}) async {
    final String? template = OnDemandPush.templateFor[event];
    if (template == null) {
      log('push "$event" not sent: no template for it');
      return;
    }
    if (order.id.trim().isEmpty) {
      log('push "$event" not sent: the booking has no id');
      return;
    }
    // Everything is read from [order] before the first await: callers do not
    // wait, and may change the model afterwards.
    final Map<String, String> payload = payloadFor(order, event);
    final String providerId = order.provider.author?.trim() ?? '';
    final String workerId = order.workerId?.trim() ?? '';

    Future<void> deliver(String token, PushRecipient recipient) async {
      final bool sent = await SendNotification.sendFcmMessage(template, token, payload, recipient: recipient);
      if (!sent) log('push "$event" to the ${recipient.name} was not delivered');
    }

    try {
      final UserModel? provider = providerId.isEmpty ? null : await FireStoreUtils.getUserProfile(providerId);
      if (provider == null) {
        log('push "$event" not sent: no provider account');
      } else {
        await deliver(provider.fcmToken ?? '', PushRecipient.provider);
      }
    } catch (e) {
      log('push "$event" to the provider failed (${e.runtimeType})');
    }

    if (!toWorker || workerId.isEmpty) return;
    try {
      final WorkerModel? worker = await FireStoreUtils.getWorker(workerId);
      if (worker == null) {
        log('push "$event" not sent: no worker account');
      } else {
        await deliver(worker.fcmToken, PushRecipient.worker);
      }
    } catch (e) {
      log('push "$event" to the worker failed (${e.runtimeType})');
    }
  }
}
