import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_category.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
import 'package:intl/intl.dart';

class ParcelSearchController extends GetxController {
  // Implement parcel search logic here

  RxBool isLoading = true.obs;
  final Rx<TextEditingController> sourceTextEditController = TextEditingController().obs;
  final Rx<TextEditingController> destinationTextEditController = TextEditingController().obs;
  final Rx<TextEditingController> dateTimeTextEditController = TextEditingController().obs;

  // Journey
  final Rx<LatLng?> departureLatLong = Rx<LatLng?>(null);
  final Rx<LatLng?> destinationLatLong = Rx<LatLng?>(null);
  final Rx<latlong.LatLng?> departureLatLongOsm = Rx<latlong.LatLng?>(null);
  final Rx<latlong.LatLng?> destinationLatLongOsm = Rx<latlong.LatLng?>(null);

  Rx<DateTime> pickUpDateTime = DateTime.now().obs;
  RxList<ParcelOrderModel> parcelList = <ParcelOrderModel>[].obs;

  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  @override
  void onInit() {
    isLoading.value = false;
    driverModel.value = Constant.userModel!;
    if (driverModel.value.ownerId != null && driverModel.value.ownerId!.isNotEmpty) {
      getOwnerDetails(driverModel.value.ownerId!);
    }
    loadParcelCategories();
    super.onInit();
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  Future<void> getOwnerDetails(String ownerId) async {
    ownerModel.value = await FireStoreUtils.getUserProfile(ownerId) ?? UserModel();
    update();
  }

  void searchParcel() {
    searchParcelsOnce(
      srcLat: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value!.latitude : departureLatLong.value!.latitude,
      srcLng: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value!.longitude : departureLatLong.value!.longitude,
      destLat: Constant.selectedMapType == 'osm' ? destinationLatLongOsm.value?.latitude : destinationLatLong.value?.latitude,
      destLng: Constant.selectedMapType == 'osm' ? destinationLatLongOsm.value?.longitude : destinationLatLong.value?.longitude,
      date: pickUpDateTime.value, // required
    ).then(
      (event) {
        parcelList.value = event;
        update();
      },
    );
  }

  Future<void> acceptParcelBooking(ParcelOrderModel parcelBookingData) async {
    try {
      ShowToastDialog.showLoader("Accepting order...".tr);

      // Update section model to match this order's section (multi-section support)
      final sid = parcelBookingData.sectionId;
      if (sid != null && sid.isNotEmpty) {
        final s = await FireStoreUtils.getSectionBySectionId(sid);
        if (s != null) Constant.sectionModels[sid] = s;
      }
      parcelBookingData.status = Constant.driverAccepted;
      parcelBookingData.driver = Constant.userModel;
      parcelBookingData.driverId = Constant.userModel!.id;
      parcelBookingData.receiverPickupDateTime = Timestamp.fromDate(DateTime.now());

      final result = await FireStoreUtils.setParcelOrder(parcelBookingData);
      ShowToastDialog.closeLoader();

      if (result == true) {
        // Try to send FCM but don't fail the accept flow if it errors
        try {
          final fcmToken = parcelBookingData.author?.fcmToken;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            final payLoad = <String, dynamic>{"type": "parcel_order", "orderId": parcelBookingData.id};
            await SendNotification.sendFcmMessage(Constant.parcelAccepted, fcmToken, payLoad);
          }
        } catch (e) {
          // FCM failure should not block order acceptance
          print("FCM send failed: $e");
        }
        ShowToastDialog.showToast("Order accepted successfully".tr);
        Get.back(result: true);
      } else {
        ShowToastDialog.showToast("Failed to accept order. Please try again.".tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error accepting order: $e".tr);
      print("acceptParcelBooking error: $e");
    }
  }

  String calculateParcelTotalAmountBooking(ParcelOrderModel parcelBookingData) {
    String subTotal = parcelBookingData.subTotal.toString();
    String discount = parcelBookingData.discount ?? "0.0";
    String taxAmount = "0.0";
    for (var element in parcelBookingData.taxSetting!) {
      taxAmount = (double.parse(taxAmount) + Constant.calculateTax(amount: (double.parse(subTotal) - double.parse(discount)).toString(), taxModel: element))
          .toStringAsFixed(int.tryParse(Constant.currencyModel!.decimalDigits.toString()) ?? 2);
    }

    return ((double.parse(subTotal) - (double.parse(discount))) + double.parse(taxAmount)).toStringAsFixed(int.tryParse(Constant.currencyModel!.decimalDigits.toString()) ?? 2);
  }

  Future<List<ParcelOrderModel>> searchParcelsOnce({
    required double srcLat,
    required double srcLng,
    double? destLat,
    double? destLng,
    required DateTime date,
  }) async {
    final driverSectionIds = driverModel.value.sectionIds ?? <String>[];
    final ref = FireStoreUtils.fireStore
        .collection("parcel_orders")
        .where("sectionId", whereIn: driverSectionIds.isEmpty ? ['__none__'] : driverSectionIds)
        .where('status', isEqualTo: "Order Placed");

    GeoFirePoint center = Geoflutterfire().point(latitude: srcLat, longitude: srcLng);

    // Take first snapshot from the stream
    final docs = await Geoflutterfire()
        .collection(collectionRef: ref)
        .within(
          center: center,
          radius: double.parse(Constant.parcelRadius),
          field: "sourcePoint",
          strictMode: true,
        )
        .first;

    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderPickupDateTime'] == null) return false;

      final driverZoneId = driverModel.value.zoneId;

      // ✅ Check both sender and receiver zone
      final senderZoneId = data['senderZoneId'];
      final receiverZoneId = data['receiverZoneId'];

      if (senderZoneId == null && receiverZoneId == null) return false;

      // Match if driver zone equals either sender or receiver zone
      final zoneMatch = (senderZoneId == driverZoneId) || (receiverZoneId == driverZoneId);
      if (!zoneMatch) return false;

      // ✅ Date check
      final Timestamp ts = data['senderPickupDateTime'];
      final orderDate = ts.toDate().toLocal();
      final inputDate = date.toLocal();

      bool sameDay = orderDate.year == inputDate.year && orderDate.month == inputDate.month && orderDate.day == inputDate.day;

      if (!sameDay) return false;

      // ✅ Destination check
      if (destLat != null && destLng != null && data['receiverLatLong'] != null) {
        final rec = data['receiverLatLong'];
        double recLat = rec['latitude'];
        double recLng = rec['longitude'];

        double distance = Geoflutterfire().point(latitude: destLat, longitude: destLng).kmDistance(lat: recLat, lng: recLng);

        if (distance > double.parse(Constant.parcelRadius)) return false;
      }

      return true;
    }).toList();

    return filtered.map((e) => ParcelOrderModel.fromJson(e.data()!)).toList();
  }

  Future<void> pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: Get.context!,
      initialDate: pickUpDateTime.value,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date == null) return;
    pickUpDateTime.value = date;
    dateTimeTextEditController.value.text = DateFormat('dd-MMM-yyyy').format(date);
    update();
  }

  RxList<ParcelCategory> parcelCategory = <ParcelCategory>[].obs;


  void loadParcelCategories() async {
    final categories = await FireStoreUtils.getParcelServiceCategory();
    parcelCategory.value = categories;
  }

  ParcelCategory? getSelectedCategory(ParcelOrderModel parcelOrder) {
    try {
      return parcelCategory.firstWhere(
            (cat) => cat.title?.toLowerCase().trim() == parcelOrder.parcelType?.toLowerCase().trim(),
        orElse: () => ParcelCategory(),
      );
    } catch (e) {
      return null;
    }
  }
}
