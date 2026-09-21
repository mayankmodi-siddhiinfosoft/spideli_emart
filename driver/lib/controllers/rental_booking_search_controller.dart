import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
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
