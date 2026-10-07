import 'dart:async';
import 'dart:developer';

import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/service/customer_notification_service.dart';
import 'package:customer/utils/customer_notification_record.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:get/get.dart';

/// The Notification Center (`.claude/CUSTOMER-NOTIFICATIONS.md` §1, Customer
/// app UI): the signed-in customer's newest notifications, live. What is
/// shown unread is marked read right away (batched) but keeps its "new"
/// styling for the rest of this visit ([isNew]).
class NotificationCenterController extends GetxController {
  final RxList<CustomerNotificationModel> notifications = <CustomerNotificationModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;

  /// Ids that were unread when shown during this visit.
  final RxSet<String> newThisVisit = <String>{}.obs;

  String? _uid;
  StreamSubscription<List<CustomerNotificationModel>>? _subscription;

  bool get isSignedIn => _uid != null;

  @override
  void onInit() {
    super.onInit();
    _uid = CustomerNotificationService.currentUid;
    _listen();
  }

  void _listen() {
    final String? uid = _uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    _subscription?.cancel();
    hasError.value = false;
    _subscription = CustomerNotificationService.watch(uid).listen(
      (list) {
        notifications.assignAll(list);
        isLoading.value = false;
        hasError.value = false;
        final List<String> fresh = CustomerNotificationRecord.idsToMarkRead(list, newThisVisit);
        if (fresh.isNotEmpty) {
          newThisVisit.addAll(fresh);
          unawaited(CustomerNotificationService.markAllShownRead(uid, fresh));
        }
      },
      onError: (Object e) {
        log('notifications: list failed (${e.runtimeType})');
        isLoading.value = false;
        hasError.value = true;
      },
    );
  }

  /// Retry after an error.
  void retry() {
    isLoading.value = true;
    _listen();
  }

  /// Unread styling: unread, or unread when this visit showed it.
  bool isNew(CustomerNotificationModel n) => !n.read || newThisVisit.contains(n.id);

  /// Marks [n] read, then opens what it is about.
  Future<void> open(CustomerNotificationModel n) async {
    final String? uid = _uid;
    if (uid != null && !n.read) unawaited(CustomerNotificationService.markRead(uid, n.id));
    await NotificationService.openNotification(n);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
