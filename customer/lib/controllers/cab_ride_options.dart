import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One intermediate stop chosen while booking a CabCar ride.
class RideStop {
  final String address;
  final double lat;
  final double lng;

  const RideStop({required this.address, required this.lat, required this.lng});
}

/// CabCar booking options shared by the city cab ([CabBookingController]) and
/// intercity ([IntercityHomeController]) flows (spec 4.8 / 7.10, APP-CONTRACT):
/// stops A, B, … between pickup and destination, passengers, instructions,
/// "written communication only" and "ride for someone else".
///
/// Nothing here changes a booking unless the customer uses it: with no stops
/// the route and fare are exactly today's.
mixin CabRideOptions on GetxController {
  static const int maxStops = 10;

  final RxList<RideStop> stops = <RideStop>[].obs;

  final RxInt adults = 1.obs;
  final RxInt children = 0.obs;

  final TextEditingController instructionsController = TextEditingController();
  final RxBool writtenCommunicationOnly = false.obs;

  final RxBool rideForSomeoneElse = false.obs;
  final TextEditingController riderNameController = TextEditingController();
  final TextEditingController riderPhoneController = TextEditingController();
  final TextEditingController riderCountryCodeController = TextEditingController();
  final TextEditingController riderCountryISOCodeController = TextEditingController();
  final TextEditingController riderEmailController = TextEditingController();

  /// Recalculates the route (and so the distance / fare) through the stops.
  void onStopsChanged();

  void addStop(String address, double lat, double lng) {
    if (stops.length >= maxStops) return;
    stops.add(RideStop(address: address, lat: lat, lng: lng));
    onStopsChanged();
  }

  void removeStop(int index) {
    if (index < 0 || index >= stops.length) return;
    stops.removeAt(index);
    onStopsChanged();
  }

  /// Moves the stop at [index] by [delta] (-1 = earlier, +1 = later).
  void moveStop(int index, int delta) {
    final target = index + delta;
    if (index < 0 || index >= stops.length || target < 0 || target >= stops.length) return;
    final stop = stops.removeAt(index);
    stops.insert(target, stop);
    onStopsChanged();
  }

  /// "A", "B", … for the stop at [index].
  static String stopLabel(int index) => String.fromCharCode(65 + (index % 26));

  /// Google Directions `waypoints` value for the stops, in order (empty when none).
  String get googleWaypointsParam => stops.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(stops.map((s) => '${s.lat},${s.lng}').join('|'))}';

  void incrementAdults() => adults.value++;

  void decrementAdults() {
    if (adults.value > 1) adults.value--;
  }

  void incrementChildren() => children.value++;

  void decrementChildren() {
    if (children.value > 0) children.value--;
  }

  String get riderPhone {
    final phone = riderPhoneController.text.trim();
    if (phone.isEmpty) return '';
    final code = riderCountryCodeController.text.trim();
    return code.isEmpty ? phone : '$code $phone';
  }

  /// Null when the options are valid, else a message for the customer.
  String? validateRideOptions() {
    if (adults.value < 1) return "At least one adult passenger is required".tr;
    if (rideForSomeoneElse.value) {
      if (riderNameController.text.trim().isEmpty) return "Please enter the rider's name".tr;
      if (riderPhoneController.text.trim().isEmpty) return "Please enter the rider's phone number".tr;
      final email = riderEmailController.text.trim();
      if (email.isNotEmpty && !GetUtils.isEmail(email)) return "Please enter a valid email for the rider".tr;
    }
    return null;
  }

  /// Copies the customer-owned options onto a new ride.
  void applyRideOptions(CabOrderModel order) {
    order.passengers = {'adults': adults.value, 'children': children.value};
    final instructions = instructionsController.text.trim();
    order.instructions = instructions.isEmpty ? null : instructions;
    order.writtenCommunicationOnly = writtenCommunicationOnly.value ? true : null;
    order.rideFor =
        rideForSomeoneElse.value ? {'name': riderNameController.text.trim(), 'phone': riderPhone, 'email': riderEmailController.text.trim()} : null;
    order.stops = stopsForOrder();
  }

  /// The contract's `stops` array, or null when there are none.
  List<Map<String, dynamic>>? stopsForOrder() {
    if (stops.isEmpty) return null;
    return List.generate(stops.length, (i) => {'address': stops[i].address, 'lat': stops[i].lat, 'lng': stops[i].lng, 'order': i, 'reached': false, 'reachedAt': null});
  }

  void resetRideOptions() {
    stops.clear();
    adults.value = 1;
    children.value = 0;
    instructionsController.clear();
    writtenCommunicationOnly.value = false;
    rideForSomeoneElse.value = false;
    riderNameController.clear();
    riderPhoneController.clear();
    riderEmailController.clear();
  }

  @override
  void onClose() {
    instructionsController.dispose();
    riderNameController.dispose();
    riderPhoneController.dispose();
    riderCountryCodeController.dispose();
    riderCountryISOCodeController.dispose();
    riderEmailController.dispose();
    super.onClose();
  }
}

/// Customer cancellation of a ride that is still waiting for a driver
/// (spec 4.8 step 6). Field update only (contract lesson 2), inside a
/// transaction that re-reads the ride so a driver acceptance that just landed
/// is not overwritten.
class CabRideCancellation {
  CabRideCancellation._();

  /// Statuses in which the customer may still cancel from the booking screen.
  static bool isCancellable(String? status, String? driverId) =>
      status == Constant.orderPlaced ||
      status == Constant.driverPending ||
      status == Constant.driverRejected ||
      (status == Constant.orderAccepted && (driverId == null || driverId.isEmpty));

  /// Returns null on success, else a message for the customer.
  static Future<String?> cancel(String rideId, Map<String, dynamic> reasonFields) async {
    final ref = FireStoreUtils.fireStore.collection(CollectionName.rides).doc(rideId);
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return "Ride not found".tr;
        if (!isCancellable(data['status']?.toString(), data['driverId']?.toString())) {
          return "A driver has already accepted this ride".tr;
        }
        tx.update(ref, {'status': Constant.orderRejected, ...reasonFields});
        return null;
      });
    } catch (e) {
      log("CabRideCancellation failed: $e");
      return "Failed to cancel ride".tr;
    }
  }
}
