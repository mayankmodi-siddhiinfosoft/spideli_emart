import 'package:driver/utils/region_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:get/get.dart';

class RentalBookingSearchController extends GetxController {
  // Implementation of the controller

  RxBool isLoading = true.obs;

  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  @override
  void onInit() {
    driverModel.value = Constant.userModel!;
    if (driverModel.value.ownerId != null && driverModel.value.ownerId!.isNotEmpty) {
      getOwnerDetails(driverModel.value.ownerId!);
    }
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    await getRentalSearchBooking();
    isLoading.value = false;
    update();
  }

  Future<void> getOwnerDetails(String ownerId) async {
    ownerModel.value = await FireStoreUtils.getUserProfile(ownerId) ?? UserModel();
    update();
  }

  RxList<RentalOrderModel> rentalBookingData = <RentalOrderModel>[].obs;

  /// Driver passes on a booking request: a reason is mandatory (spec 9.1).
  /// Known-fields write: rejectedByDrivers + this driver's reason in driverRejections.
  Future<void> rejectBooking(RentalOrderModel order) async {
    if (order.id == null) return;
    final reason = await CancelReasonSheet.show(title: "Why are you rejecting this booking?".tr);
    if (reason == null) return;
    ShowToastDialog.showLoader("Rejecting booking...".tr);
    final ok = await FireStoreUtils.updateRentalFields(order.id!, {
      'rejectedByDrivers': FieldValue.arrayUnion([FireStoreUtils.getCurrentUid()]),
      ...reason.toFields(FireStoreUtils.getCurrentUid()),
    });
    ShowToastDialog.closeLoader();
    if (!ok) {
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }
    Get.back(result: true);
    ShowToastDialog.showToast("Booking rejected successfully".tr);
    getRentalSearchBooking();
  }

  /// Driver accepts a booking request. Known-fields write; stamps the driver's
  /// region when the booking has none (spec 18.12). A booking whose price
  /// proposal is still open must be answered first (spec 4.9).
  Future<void> acceptBooking(RentalOrderModel order) async {
    if (order.id == null) return;
    final proposalStatus = order.proposalStatus;
    if (proposalStatus == 'pending') {
      ShowToastDialog.showToast("Please answer the customer's price proposal first".tr);
      return;
    }
    if (proposalStatus == 'countered') {
      ShowToastDialog.showToast("Waiting for the customer to answer your counter-offer".tr);
      return;
    }
    ShowToastDialog.showLoader("Accepting booking...".tr);
    // Update section model for this order's section (multi-section support)
    final sid = order.sectionId;
    if (sid != null && sid.isNotEmpty) {
      await FireStoreUtils.getSectionBySectionId(sid).then((s) {
        if (s != null) Constant.sectionModels[sid] = s;
      });
    }
    final driver = Constant.userModel;
    final regionId = (order.regionId == null || order.regionId!.isEmpty) ? await RegionService.regionIdToStamp(driver) : null;
    final ok = await FireStoreUtils.updateRentalFields(order.id!, {
      'status': Constant.driverAccepted,
      'driverId': FireStoreUtils.getCurrentUid(),
      if (driver != null) 'driver': driver.toJson(),
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
    });
    ShowToastDialog.closeLoader();
    if (!ok) {
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }
    Get.back(result: true);
    ShowToastDialog.showToast("Booking accepted successfully".tr);
  }

  Future<void> getRentalSearchBooking() async {
    final lat = Constant.locationDataFinal?.latitude ?? driverModel.value.location?.latitude ?? 0.0;
    final lng = Constant.locationDataFinal?.longitude ?? driverModel.value.location?.longitude ?? 0.0;
    await searchParcelsOnce(srcLat: lat, srcLng: lng).then(
      (event) {
        rentalBookingData.value = event;
        update();
      },
    );
    isLoading.value = false;
  }

  Future<List<RentalOrderModel>> searchParcelsOnce({
    required double srcLat,
    required double srcLng,
  }) async {
    final driverSectionIds = driverModel.value.sectionIds ?? <String>[];

    // Collect all vehicle IDs the driver has across sections (for multi-section rental drivers)
    final Set<String> driverVehicleIds = {};
    if (driverModel.value.vehicleDetails != null) {
      for (final v in driverModel.value.vehicleDetails!.values) {
        final vid = v['vehicleId']?.toString();
        if (vid != null && vid.isNotEmpty) driverVehicleIds.add(vid);
      }
    }

    // Filter only by sectionId; vehicleId matching is done per-section client-side below
    final ref = FireStoreUtils.fireStore
        .collection(CollectionName.rentalOrders)
        .where("sectionId", whereIn: driverSectionIds.isEmpty ? ['__none__'] : driverSectionIds)
        .where('status', isEqualTo: "Order Placed");

    GeoFirePoint center = Geoflutterfire().point(latitude: srcLat, longitude: srcLng);

    // Fetch documents once
    final docs = await Geoflutterfire()
        .collection(collectionRef: ref)
        .within(
          center: center,
          radius: double.parse(Constant.rentalRadius),
          field: "sourcePoint",
          strictMode: true,
        )
        .first;

    final now = DateTime.now();

    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['bookingDateTime'] == null) return false;

      // ✅ Check zone match
      if (data['zoneId'] == null || data['zoneId'] != driverModel.value.zoneId) {
        return false;
      }

      // Zone-bound (spec 9.1): only requests of the driver's region.
      if (RegionService.isOutOfDriverRegion(data['regionId']?.toString(), driver: driverModel.value)) return false;

      // ✅ Per-section vehicle type match:
      // If driver has vehicleDetails, match the order's vehicleId against the
      // vehicle registered for THAT specific section.
      final orderSectionId = data['sectionId']?.toString();
      final orderVehicleId = data['vehicleId']?.toString();
      if (orderVehicleId != null && orderVehicleId.isNotEmpty) {
        if (driverModel.value.vehicleDetails != null && orderSectionId != null) {
          final sectionVehicle = driverModel.value.vehicleDetails![orderSectionId];
          if (sectionVehicle != null) {
            if (sectionVehicle['vehicleId']?.toString() != orderVehicleId) return false;
          } else if (!driverVehicleIds.contains(orderVehicleId)) {
            return false;
          }
        } else if (!driverVehicleIds.contains(orderVehicleId)) {
          return false;
        }
      }

      if (data['rejectedByDrivers'] != null) {
        List<dynamic> rejectedByDrivers = data['rejectedByDrivers'];
        if (rejectedByDrivers.contains(FireStoreUtils.getCurrentUid())) {
          return false;
        }
      }

      final Timestamp ts = data['bookingDateTime'];
      final orderDate = ts.toDate().toLocal();

      // ✅ Allow only today's or future bookings
      bool isToday = orderDate.year == now.year && orderDate.month == now.month && orderDate.day == now.day;

      return orderDate.isAfter(now) || isToday;
    }).toList();

    return filtered.map((e) => RentalOrderModel.fromJson(e.data()!)).toList();
  }
}
