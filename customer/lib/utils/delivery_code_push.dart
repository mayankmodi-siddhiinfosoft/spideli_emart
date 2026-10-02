import 'dart:async';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/order_details_controller.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/order_list_screen/order_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// The `delivery_otp` push (POD-OTP-CONTRACT): "Your order has arrived — open
/// the app for your delivery code". The payload carries the order id only
/// (`{type: delivery_otp, orderId}`), never the code: tapping it opens that
/// order's details screen, whose code card reads `order_pod/{orderId}`.
abstract final class DeliveryCodePush {
  static const String type = 'delivery_otp';

  /// A tap that launched the app, held until the splash has routed.
  static String? _pending;
  static bool _appReady = false;

  /// The order id from a push payload, or null.
  static String? orderIdOf(Map<String, dynamic> data) {
    for (final key in const ['orderId', 'order_id', 'orderID']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return null;
  }

  /// A tap on the notification. On a cold start ([coldStart]) the order is
  /// opened once the splash has finished routing ([markAppReady]).
  static Future<void> handleTap(Map<String, dynamic> data, {bool coldStart = false}) async {
    final String? orderId = orderIdOf(data);
    if (orderId == null) return;
    if (coldStart && !_appReady) {
      _pending = orderId;
      return;
    }
    await open(orderId);
  }

  /// Called by the splash once the signed-in customer reached the app.
  static void markAppReady() {
    _appReady = true;
    final String? pending = _pending;
    _pending = null;
    if (pending != null) unawaited(open(pending));
  }

  /// Opens the details screen of the signed-in customer's order [orderId].
  static Future<void> open(String orderId) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Already on this order's details: its code card is live.
    if (Get.isRegistered<OrderDetailsController>()) {
      if (Get.find<OrderDetailsController>().orderModel.value.id == orderId) return;
      // A details screen of another order is open; its controller is shared
      // by type, so close it before opening this one.
      Get.until((route) => route.isFirst);
      for (int i = 0; i < 20 && Get.isRegistered<OrderDetailsController>(); i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (Get.isRegistered<OrderDetailsController>()) return;
    }

    OrderModel? order;
    SectionModel? section;
    final SectionModel? previousSection = Constant.sectionConstantModel;
    ShowToastDialog.showLoader('Please wait...'.tr);
    try {
      order = await FireStoreUtils.getOrderByOrderId(orderId);
      // Only the customer's own order.
      if (order == null || order.authorID != uid) return;
      // The details screen reads the active section (store vs restaurant,
      // e-commerce courier block); a tap from outside it brings its own.
      final String sectionId = (order.sectionId ?? '').trim();
      if (sectionId.isNotEmpty && previousSection?.id != sectionId) {
        final snap = await FireStoreUtils.fireStore.collection(CollectionName.sections).doc(sectionId).get();
        if (snap.data() != null) section = SectionModel.fromJson(snap.data()!);
      }
    } catch (_) {
      return;
    } finally {
      ShowToastDialog.closeLoader();
    }
    if (section == null && previousSection == null) return;

    if (section != null) Constant.sectionConstantModel = section;
    await Get.to(const OrderDetailsScreen(), arguments: {'orderModel': order});
    if (section != null) Constant.sectionConstantModel = previousSection;
  }
}
