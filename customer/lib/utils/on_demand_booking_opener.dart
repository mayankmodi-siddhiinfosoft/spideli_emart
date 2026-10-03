import 'dart:async';
import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/on_demand_dashboard_controller.dart';
import 'package:customer/controllers/on_demand_order_details_controller.dart';
import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/screen_ui/on_demand_service/my_booking_on_demand_screen.dart';
import 'package:customer/screen_ui/on_demand_service/on_demand_order_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/on_demand_push.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// Opens what a tapped on-demand booking push is about
/// (`.claude/ONDEMAND-NOTIFICATIONS.md`, Tap behaviour): the booking details
/// screen of its `orderId`, or the bookings list when the id is missing, the
/// booking cannot be read, or it is not the signed-in customer's. Pushed on
/// top of whatever is open. Never throws.
abstract final class OnDemandBookingOpener {
  static const Duration _timeout = Duration(seconds: 15);
  static const String _onDemandFlag = 'ondemand-service';

  /// Opens the booking [orderId] (null: the bookings list).
  static Future<void> open(String? orderId) async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (orderId != null && _refreshIfOpen(orderId)) return;

      OnProviderOrderModel? order;
      SectionModel? section;
      ShowToastDialog.showLoader('Please wait...'.tr);
      try {
        if (orderId != null) {
          order = await FireStoreUtils.getProviderOrderById(orderId).timeout(_timeout);
          if (order != null && !OnDemandPush.isOwnBooking(orderAuthorId: order.authorID, uid: uid)) order = null;
        }
        // The on-demand screens read the active section (booking list query,
        // the dashboard a payment returns to); a tap from outside brings its own.
        section = await _sectionFor(order?.sectionId).timeout(_timeout);
      } catch (e) {
        log('push: on-demand booking lookup failed (${e.runtimeType})');
      } finally {
        ShowToastDialog.closeLoader();
      }

      if (order != null) {
        await _withSection(section, () => Get.to(() => OnDemandOrderDetailsScreen(tag: _tag(order!.id)), arguments: order));
        return;
      }
      // No usable booking: the list, which needs an on-demand section.
      if (section == null) return;
      await _withSection(section, () => Get.to(() => const MyBookingOnDemandScreen(showBack: true)));
    } catch (e) {
      log('push: on-demand booking open failed (${e.runtimeType})');
    }
  }

  static String _tag(String orderId) => 'push_$orderId';

  /// Already showing [orderId] (opened from a push, or from the list):
  /// reloads it instead of stacking a second copy.
  static bool _refreshIfOpen(String orderId) {
    final String tag = _tag(orderId);
    if (Get.isRegistered<OnDemandOrderDetailsController>(tag: tag)) {
      unawaited(Get.find<OnDemandOrderDetailsController>(tag: tag).getData());
      return true;
    }
    if (Get.isRegistered<OnDemandOrderDetailsController>()) {
      final OnDemandOrderDetailsController controller = Get.find<OnDemandOrderDetailsController>();
      if (controller.onProviderOrder.value?.id == orderId) {
        unawaited(controller.getData());
        return true;
      }
    }
    return false;
  }

  /// The section to open the booking in: the active one when it is an
  /// on-demand section (or the booking's own), else the booking's section,
  /// else the first active on-demand section.
  static Future<SectionModel?> _sectionFor(String? sectionId) async {
    final SectionModel? current = Constant.sectionConstantModel;
    final String id = sectionId?.trim() ?? '';
    if (current != null && (id.isEmpty ? current.serviceTypeFlag == _onDemandFlag : current.id == id)) return current;
    if (id.isNotEmpty) {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.sections).doc(id).get();
      final Map<String, dynamic>? data = snap.data();
      if (data != null) return SectionModel.fromJson(data);
    }
    final query = await FireStoreUtils.fireStore
        .collection(CollectionName.sections)
        .where('serviceTypeFlag', isEqualTo: _onDemandFlag)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return SectionModel.fromJson(query.docs.first.data());
  }

  /// Runs [open] with [section] active, then puts the previous one back —
  /// unless the customer ended up in the on-demand dashboard (a payment from
  /// the details screen returns there), which needs it.
  static Future<void> _withSection(SectionModel? section, Future<dynamic>? Function() open) async {
    final SectionModel? previous = Constant.sectionConstantModel;
    final bool swap = section != null && section.id != previous?.id;
    if (swap) Constant.sectionConstantModel = section;
    try {
      await open();
    } finally {
      if (swap && previous != null && !Get.isRegistered<OnDemandDashboardController>()) {
        Constant.sectionConstantModel = previous;
      }
    }
  }
}
