import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_category.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/dispatch_navigation.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/dispatch_offer_service.dart';
import 'package:driver/services/parcel_dispatch_service.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/parcel_amounts.dart';
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

  /// Takes a parcel from the open search list through the shared dispatch
  /// service (D2), in a transaction: only while it is still `Order Placed`
  /// with no driver named, or `Driver Pending` for this driver. The
  /// `parcelDispatch` Cloud Function may have offered it to another driver
  /// since the list was read; taking it then stole that driver's offer. Known
  /// fields only (`Driver Accepted`, `driverId` / `driverID` / `driver`,
  /// `receiverPickupDateTime`) — the whole stale model used to be written
  /// back, over `rejectedByDrivers`, the cancellation fields and the
  /// server-owned SMS fields. Then the driver's record field-level
  /// (`inProgressOrderID` arrayUnion, `orderRequestData` arrayRemove), and
  /// the customer's `parcel_accepted` push.
  Future<void> acceptParcelBooking(ParcelOrderModel parcelBookingData) async {
    // A new parcel ('Order Placed' from the search) is only for a verified
    // driver who is online; the home screen hides the way here otherwise, and
    // this is the same rule where the write happens. Parcels already assigned
    // never come through here.
    final UserModel? me = Constant.userModel;
    final bool verified = !DocumentVerification.isPending(me);
    if (me == null || !verified) {
      ShowToastDialog.showToast("Document verification is pending. Please proceed to set up your document verification.".tr);
      return;
    }
    if (me.isActive != true) {
      ShowToastDialog.showToast("Switch to online mode to accept and deliver parcel orders.".tr);
      return;
    }
    final String? orderId = parcelBookingData.id;
    if (orderId == null || orderId.isEmpty) return;
    // The search screen, taken before the write: the incoming-order dialog
    // may open above it meanwhile, and Get.back() would pop that instead.
    final Route<dynamic>? searchRoute = DispatchNavigation.ownRoute();
    ShowToastDialog.showLoader("Accepting order...".tr);
    final DispatchResult result = await DispatchOfferService.accept(DispatchKind.parcel, orderId, me, fromOpenSearch: true);
    ShowToastDialog.closeLoader();
    switch (result.answer) {
      case OfferAnswer.done:
      case OfferAnswer.held:
        ShowToastDialog.showToast("Order accepted successfully".tr);
        DispatchNavigation.closeRoute(searchRoute, result: true);
      case OfferAnswer.gone:
        ShowToastDialog.showToast("This order is no longer available.".tr);
        parcelList.removeWhere((order) => order.id == orderId);
        update();
      case OfferAnswer.blocked:
      case OfferAnswer.failed:
        ShowToastDialog.showToast((result.message ?? "Failed to accept order. Please try again.").tr);
    }
  }

  /// The total the customer was charged ([ParcelAmounts]: platform fee and
  /// its taxes, the fixed tax and the receiver-SMS fee included) — what the
  /// driver collects on a cash parcel. Tolerant of missing fields.
  String calculateParcelTotalAmountBooking(ParcelOrderModel parcelBookingData) {
    final int digits = int.tryParse('${Constant.currencyModel?.decimalDigits}') ?? 2;
    return ParcelAmounts.of(parcelBookingData).totalText(digits);
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

    // Zone / date / destination are decided in memory as before; region and
    // carrier need a lookup, so the pass is a loop rather than a `where`.
    final List<ParcelOrderModel> result = [];
    final String me = driverModel.value.id ?? '';
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!_matchesSearchInput(data, date: date, destLat: destLat, destLng: destLng)) continue;

      // A parcel this driver already passed on is not offered again (the
      // dispatch Cloud Function excludes `rejectedByDrivers` the same way).
      if (DispatchOrderRules.rejectedBy(data, me)) continue;

      // Zone-bound (spec 9.1), scope-aware (admin spec §11/§12): a same-city
      // parcel keeps today's rule; an intercity / intercountry parcel is also
      // offered to drivers of the region it ENDS in.
      if (await ParcelDispatchService.isOutOfDriverRegion(data, driver: driverModel.value)) continue;

      // Carrier-bound dispatch (admin spec §11): an order carrying a
      // `carrierId` belongs to that company's own drivers. An order with no
      // carrier — and a carrier nothing is linked to — behaves as today.
      if (!await CarrierDispatchService.driverServesCarrier(data['carrierId']?.toString(), driverModel.value)) continue;

      result.add(ParcelOrderModel.fromJson(data));
    }

    return result;
  }

  /// The unchanged in-memory rules of the parcel search: the job must have a
  /// pickup date, touch the driver's zone at either end, fall on the searched
  /// day, and end near the searched destination when one was given.
  bool _matchesSearchInput(
    Map<String, dynamic> data, {
    required DateTime date,
    double? destLat,
    double? destLng,
  }) {
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
