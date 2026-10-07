import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/dine_in_booking_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_order_details.dart';
import 'package:customer/screen_ui/multi_vendor_service/dine_in_booking/dine_in_booking_details.dart';
import 'package:customer/screen_ui/parcel_service/parcel_order_details.dart';
import 'package:customer/screen_ui/rental_service/rental_order_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/delivery_code_push.dart';
import 'package:customer/utils/on_demand_booking_opener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// Opens the details of the order a Notification Center row is about, in
/// whichever collection it lives (food / e-commerce order, ride, parcel,
/// rental, on-demand booking, table booking). Only the signed-in customer's own order;
/// anything else (not found, someone else's, unknown kind) leaves the
/// customer where they are. Never throws.
abstract final class OrderNotificationOpener {
  static const Duration _timeout = Duration(seconds: 15);

  /// Whether the order document [data] belongs to [uid] (`authorID`).
  static bool isOwn(Map<String, dynamic>? data, String? uid) {
    final String author = data?['authorID']?.toString().trim() ?? '';
    final String me = uid?.trim() ?? '';
    return author.isNotEmpty && author == me;
  }

  /// The table booking [id] (`booked_table/{id}`) tagged with its
  /// collection, or null (missing, failed, timed out).
  static Future<Map<String, dynamic>?> _dineInBooking(String id) async {
    try {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.bookedTable).doc(id).get().timeout(_timeout);
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return null;
      return {...data, 'collection_name': CollectionName.bookedTable};
    } catch (e) {
      log('notifications: booking lookup failed (${e.runtimeType})');
      return null;
    }
  }

  static Future<void> open(String orderId) async {
    final String id = orderId.trim();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (id.isEmpty || id.contains('/') || uid == null) return;
    try {
      Map<String, dynamic>? data;
      ShowToastDialog.showLoader('Please wait...'.tr);
      try {
        final dynamic found = await FireStoreUtils.getOrderByIdFromAllCollections(id).timeout(_timeout);
        if (found is Map<String, dynamic>) data = found;
        // A table booking (`dinein_accepted` / `dinein_canceled`, category
        // booking) lives in booked_table, keyed by its id.
        data ??= await _dineInBooking(id);
      } catch (e) {
        log('notifications: order lookup failed (${e.runtimeType})');
      } finally {
        ShowToastDialog.closeLoader();
      }
      if (data == null || !isOwn(data, uid)) return;

      switch (data['collection_name']) {
        case CollectionName.vendorOrders:
          // Brings the order's section along (store vs restaurant details).
          await DeliveryCodePush.open(id);
        case CollectionName.providerOrders:
          await OnDemandBookingOpener.open(id);
        case CollectionName.rides:
          await Get.to(() => const CabOrderDetails(), arguments: {'cabOrderModel': CabOrderModel.fromJson(data)});
        case CollectionName.parcelOrders:
          await Get.to(() => const ParcelOrderDetails(), arguments: ParcelOrderModel.fromJson(data));
        case CollectionName.rentalOrders:
          await Get.to(() => const RentalOrderDetailsScreen(), arguments: RentalOrderModel.fromJson(data));
        case CollectionName.bookedTable:
          await Get.to(() => const DineInBookingDetails(), arguments: {'bookingModel': DineInBookingModel.fromJson(data)});
      }
    } catch (e) {
      log('notifications: open order failed (${e.runtimeType})');
    }
  }
}
