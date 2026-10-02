import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as location;

class CabHomeController extends GetxController {
  RxBool isLoading = true.obs;
  flutterMap.MapController osmMapController = flutterMap.MapController();
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;

  /// Default driver icon loaded from local asset — shown when no section icon is available.
  BitmapDescriptor? _defaultDriverIcon;

  /// Cached section-specific icon so we don't re-download on every GPS update.
  String? _cachedIconUrl;
  BitmapDescriptor? _cachedSectionIcon;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderQuerySub;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  /// Live statuses of every id in `inProgressOrderID`, so the ride on screen
  /// is the first one this driver can actually work — not simply
  /// `inProgressOrderID.first`. That array is shared with delivery (the
  /// assignment watcher adopts both into it) and can hold a finished,
  /// reassigned or `Driver Rejected` ride; any of those in first place hid
  /// the ride that was really assigned.
  late final OrdersByIdWatch<CabOrderModel> _ridesWatch = OrdersByIdWatch<CabOrderModel>(
    collection: CollectionName.ridesBooking,
    parse: CabOrderModel.fromJson,
    idOf: (ride) => ride.id,
    onChange: (rides, fromServer) {
      _rides = rides;
      getCurrentOrder();
    },
  );
  Map<String, CabOrderModel> _rides = const {};

  /// The ride id [_orderDocSub] is listening to; re-subscribed only when it
  /// changes (it used to be cancelled and re-opened on every user snapshot,
  /// with awaits in between, so two snapshots could leave an old listener
  /// running that kept writing an earlier ride into [currentOrder]).
  String? _listeningRideId;

  static const List<String> _finishedRideStatuses = [
    Constant.orderCompleted,
    Constant.orderCancelled,
    Constant.orderRejected,
    Constant.driverRejected,
  ];

  bool _rideIsMine(CabOrderModel ride) {
    if (_finishedRideStatuses.contains(ride.status)) return false;
    final String driverId = (ride.driverId ?? '').toString().trim();
    return driverId.isEmpty || driverId == driverModel.value.id;
  }

  /// Verified documents (or auto-verify) and online: the only state in which
  /// a NEW ride request is surfaced, rung or accepted. A ride assigned to
  /// this driver is never gated by it.
  bool get canTakeNewWork {
    final UserModel me = driverModel.value;
    final bool verified = !(me.isDocumentVerify == false && me.isAutoVerify == false);
    return verified && me.isActive == true;
  }

  /// A ride that names this driver, or that `inProgressOrderID` holds:
  /// assigned work, not an offer.
  bool isAssignedToMe(CabOrderModel ride) {
    final String? uid = driverModel.value.id;
    final String driverId = (ride.driverId ?? '').toString().trim();
    if (uid != null && driverId.isNotEmpty && driverId == uid) return true;
    return ride.id != null && (driverModel.value.inProgressOrderID ?? const []).contains(ride.id);
  }

  bool _isPending(CabOrderModel ride) => ride.status == Constant.driverPending || ride.status == Constant.orderPlaced;

  /// A pending ride this driver may be shown with Accept / Reject: one
  /// assigned to them, or a new request while [canTakeNewWork].
  bool _offerable(CabOrderModel ride) => isAssignedToMe(ride) || canTakeNewWork;

  /// The accept / reject card. Reads [currentOrder] and [driverModel]
  /// synchronously, so it can drive an Obx.
  bool get showRequestSheet {
    final CabOrderModel order = currentOrder.value;
    return order.id != null && _isPending(order) && _offerable(order);
  }

  void _listenToRide(String id) {
    if (_listeningRideId == id && _orderDocSub != null) return;
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
    _orderQuerySub = null;
    _listeningRideId = id;
    _orderDocSub = FireStoreUtils.fireStore.collection(CollectionName.ridesBooking).doc(id).snapshots().listen((docSnap) => _handleOrderDoc(docSnap, id));
  }

  void _stopRide() {
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
    _orderDocSub = null;
    _orderQuerySub = null;
    _listeningRideId = null;
  }

  /// Drops one finished / reassigned ride from `inProgressOrderID` — and
  /// nothing else. This used to write `inProgressOrderID = []` with the whole
  /// user document, which also wiped delivery orders held in the same array.
  Future<void> _releaseRide(String id, {bool clearRequest = false}) async {
    final String? uid = driverModel.value.id;
    driverModel.value.inProgressOrderID?.remove(id);
    if (uid == null) return;
    final bool request = clearRequest && driverModel.value.orderCabRequestData?.id == id;
    if (request) driverModel.value.orderCabRequestData = null;
    await FireStoreUtils.updateUserFields(uid, {
      'inProgressOrderID': FieldValue.arrayRemove([id]),
      if (request) 'ordercabRequestData': FieldValue.delete(),
    });
  }

  @override
  void onClose() {
    _driverSub?.cancel();
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
    _ridesWatch.cancel();
    super.onClose();
  }

  SectionModel? get _activeSectionModel {
    final sid = (currentOrder.value.sectionId?.isNotEmpty == true)
        ? currentOrder.value.sectionId
        : (driverModel.value.orderCabRequestData?.sectionId?.isNotEmpty == true)
            ? driverModel.value.orderCabRequestData!.sectionId
            : driverModel.value.sectionIds?.isNotEmpty == true
                ? driverModel.value.sectionIds!.first
                : null;
    return Constant.sectionModelFor(sid);
  }

  Future<void> getData() async {
    _subscribeDriver();
    _initDeviceLocation();
    _loadDefaultIcon();
    isLoading.value = false;
  }

  Future<void> _loadDefaultIcon() async {
    _defaultDriverIcon = await _bitmapDescriptorFromAsset('assets/images/ic_cab.png', width: 120);
  }

  /// Returns the driver icon for Google Maps.
  /// Uses the active section's network icon if available (cached), otherwise the default asset icon.
  Future<BitmapDescriptor> _getDriverIcon() async {
    final iconUrl = _activeSectionModel?.markerIcon;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      if (iconUrl != _cachedIconUrl || _cachedSectionIcon == null) {
        _cachedIconUrl = iconUrl;
        _cachedSectionIcon = await _bitmapDescriptorFromUrl(iconUrl, width: 120);
      }
      return _cachedSectionIcon!;
    }
    return _defaultDriverIcon ?? BitmapDescriptor.defaultMarker;
  }

  /// Returns the driver marker child widget for OSM.
  /// Shows asset icon immediately; section network icon only when a valid URL exists.
  Widget _driverMarkerWidget() {
    final iconUrl = _activeSectionModel?.markerIcon;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        width: 45,
        height: 45,
        fit: BoxFit.contain,
        placeholder: (_, __) => Image.asset('assets/images/ic_cab.png', width: 45, height: 45),
        errorWidget: (_, __, ___) => Image.asset('assets/images/ic_cab.png', width: 45, height: 45),
      );
    }
    return Image.asset('assets/images/ic_cab.png', width: 45, height: 45);
  }

  /// Fetches device GPS immediately — works offline.
  Future<void> _initDeviceLocation() async {
    try {
      double lat = 0.0, lng = 0.0;

      final cached = Constant.locationDataFinal;
      if (cached != null && cached.latitude != 0) {
        lat = cached.latitude;
        lng = cached.longitude;
      } else {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }

      current.value = location.LatLng(lat, lng);

      try {
        osmMapController.move(location.LatLng(lat, lng), 16);
      } catch (_) {}

      try {
        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: 16),
          ),
        );
      } catch (_) {}
    } catch (e) {
      log('CabHomeController._initDeviceLocation error: $e');
    }
  }

  Rx<CabOrderModel> currentOrder = CabOrderModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  Future<void> acceptOrder() async {
    final CabOrderModel accepted = currentOrder.value;
    final String? id = accepted.id;
    final String? uid = driverModel.value.id;
    if (id == null || uid == null) return;
    // A new request needs a verified driver who is online; a ride already
    // assigned to this driver is always accepted.
    if (!_offerable(accepted)) {
      final bool verified = !(driverModel.value.isDocumentVerify == false && driverModel.value.isAutoVerify == false);
      ShowToastDialog.showToast(verified
          ? "Go online to get requests".tr
          : "Document verification is pending. Please proceed to set up your document verification.".tr);
      return;
    }
    try {
      await AudioPlayerService.playSound(false);
      ShowToastDialog.showLoader("Please wait".tr);

      // Field-level: this ride joins `inProgressOrderID` and the request is
      // cleared. The whole user document was written from this controller's
      // copy, which rolled back any assignment or offer (a delivery order in
      // the same array included) that landed since the last snapshot.
      driverModel.value.inProgressOrderID ??= [];
      if (!driverModel.value.inProgressOrderID!.contains(id)) driverModel.value.inProgressOrderID!.add(id);
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.updateUserFields(uid, {
        'inProgressOrderID': FieldValue.arrayUnion([id]),
        'ordercabRequestData': FieldValue.delete(),
      });

      // The ride's own snapshot may have replaced [currentOrder] with a fresher
      // copy of the same ride meanwhile; that one is written. Never another ride.
      final CabOrderModel order = currentOrder.value.id == id ? currentOrder.value : accepted;
      order.status = Constant.driverAccepted;
      order.driverId = uid;
      order.driver = driverModel.value;
      // Spec 18.12: a ride carries the assigned driver's region.
      if (order.regionId == null || order.regionId!.isEmpty) {
        order.regionId = await RegionService.regionIdToStamp(driverModel.value);
      }
      await FireStoreUtils.setCabOrder(order);

      ShowToastDialog.closeLoader();

      await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, order.author?.fcmToken ?? "", {});
    } catch (e, s) {
      ShowToastDialog.closeLoader();
      debugPrint("Error in acceptOrder: $e");
      debugPrintStack(stackTrace: s);
      ShowToastDialog.showToast("Something went wrong. Please try again.");
    }
  }

  /// Driver rejects a pending ride request. A reason is mandatory (spec 9.1);
  /// [reason] is null only for the automatic out-of-region decline, which
  /// passes the declined request as [ride] and is [silent].
  ///
  /// The user document gets field-level writes only: the request cleared and
  /// this ride id dropped from `inProgressOrderID` ([_releaseRide]). It used
  /// to write the whole user with `inProgressOrderID = []`, which also wiped
  /// a delivery order held in the same array (a delivery + cab driver keeps
  /// both modules alive) and rolled back any write since the last snapshot.
  Future<void> rejectOrder({CancelReasonResult? reason, bool silent = false, CabOrderModel? ride}) async {
    final CabOrderModel order = ride ?? currentOrder.value;
    final String? rideId = order.id;
    if (rideId == null) return;
    final String? uid = driverModel.value.id;
    // Only a request on screen touches the screen, the map and the shared
    // alert sound. An automatic decline of a request never shown leaves them
    // alone: on the Delivery tab that sound may be a delivery offer ringing.
    final bool onScreen = currentOrder.value.id == rideId;
    try {
      if (onScreen) {
        await AudioPlayerService.playSound(false);

        // 1️⃣ Immediately update local state (UI)
        currentOrder.value.status = Constant.driverRejected;
        currentOrder.value.rejectedByDrivers ??= [];
        if (uid != null && !currentOrder.value.rejectedByDrivers!.contains(uid)) {
          currentOrder.value.rejectedByDrivers!.add(uid);
        }

        // Immediately update UI so bottom sheet hides right away
        currentOrder.refresh();
      }

      // 2️⃣ This request and this ride id only.
      await _releaseRide(rideId, clearRequest: true);

      // 3️⃣ Close bottom sheet immediately (don’t wait for Firestore)
      if (!silent) {
        if (Get.isBottomSheetOpen ?? false) {
          Get.back();
        } else if (Constant.singleOrderReceive == false) {
          Get.back();
        }
      }

      // 4️⃣ Clear map immediately
      if (onScreen) await clearMap();

      // 5️⃣ Update Firestore in background (no UI wait)
      // Only the fields this rejection changes. Writing the cached ride back
      // (the pending-request copy can be stale) overwrote rejectedByDrivers and
      // lost other drivers' rejections, so they were offered the ride again.
      unawaited(FireStoreUtils.updateRideFields(rideId, {
        'status': Constant.driverRejected,
        if (uid != null) 'rejectedByDrivers': FieldValue.arrayUnion([uid]),
        if (reason != null) ...reason.toFields(uid),
      }));

      // 6️⃣ Reset local current order after short delay (unless another ride
      // has taken the screen meanwhile).
      if (onScreen) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (currentOrder.value.id == rideId) currentOrder.value = CabOrderModel();
        });
      }
    } catch (e, s) {
      print("rejectOrder() error: $e\n$s");
    }
  }

  /// Asks for the mandatory reason, then rejects the pending request.
  Future<void> rejectWithReason() async {
    final reason = await CancelReasonSheet.show(title: "Why are you rejecting this ride?".tr);
    if (reason == null) return;
    await rejectOrder(reason: reason);
  }

  /// Driver cancels a ride he already accepted (before pickup). The ride goes
  /// back to dispatch exactly like a rejected request (status "Driver
  /// Rejected", driver added to rejectedByDrivers, driver cleared) so the
  /// customer is re-matched instead of losing the booking; the reason is
  /// recorded with cancelledBy "driver".
  Future<void> cancelAcceptedRide() async {
    final order = currentOrder.value;
    if (order.id == null) return;
    final reason = await CancelReasonSheet.show(title: "Why are you cancelling this ride?".tr);
    if (reason == null) return;
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      await AudioPlayerService.playSound(false);
      final uid = driverModel.value.id;
      await FireStoreUtils.updateRideFields(order.id!, {
        'status': Constant.driverRejected,
        if (uid != null) 'rejectedByDrivers': FieldValue.arrayUnion([uid]),
        'driverId': null,
        'driver': FieldValue.delete(),
        ...reason.toFields(uid, afterAccept: true),
      });
      // This ride id (and its request) only, field-level: the whole user
      // document rolled back concurrent assignments and offers.
      await _releaseRide(order.id!, clearRequest: true);
      currentOrder.value = CabOrderModel();
      await clearMap();
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride cancelled".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("cancelAcceptedRide error: $e");
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
    }
  }

  /// Marks stop [index] of [CabOrderModel.orderedStops] as reached (spec 4.8
  /// step 5). Stops are completed in sequence.
  Future<void> markStopReached(int index) async {
    final order = currentOrder.value;
    if (order.id == null || order.stops == null) return;
    final ordered = order.orderedStops;
    if (index < 0 || index >= ordered.length) return;
    for (int i = 0; i < index; i++) {
      if (ordered[i]['reached'] != true) {
        ShowToastDialog.showToast("Please complete the previous stop first".tr);
        return;
      }
    }
    ShowToastDialog.showLoader("Please wait".tr);
    final target = ordered[index];
    // Rewrite the array in the document's own order, touching only `reached`
    // and `reachedAt` of the target stop.
    final updated = order.stops!.map((stop) {
      final copy = Map<String, dynamic>.from(stop);
      if (identical(stop, target)) {
        copy['reached'] = true;
        copy['reachedAt'] = Timestamp.now();
      }
      return copy;
    }).toList();
    final ok = await FireStoreUtils.updateRideFields(order.id!, {'stops': updated});
    ShowToastDialog.closeLoader();
    if (ok) {
      currentOrder.value.stops = updated;
      currentOrder.refresh();
    } else {
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
    }
  }

  /// Zone-bound dispatch (spec 9.1): a request from another region is declined
  /// automatically so dispatch moves on to a driver of that region.
  final Set<String> _declinedOutOfRegion = {};

  /// An offer from another region. A ride assigned to this driver (named, or
  /// held in `inProgressOrderID`) is not an offer and is never declined.
  bool _isOutOfRegionRequest(CabOrderModel order) {
    return _isPending(order) && !isAssignedToMe(order) && RegionService.isOutOfDriverRegion(order.regionId, driver: driverModel.value);
  }

  /// Declines that request with field-level writes only (the request, this
  /// ride id, the ride's rejection fields). It is not put on screen first, so
  /// whatever else the driver is doing — a delivery held in the same
  /// `inProgressOrderID`, its ringing offer — is left untouched.
  Future<void> _declineOutOfRegion(CabOrderModel order) async {
    final id = order.id;
    if (id == null || !_declinedOutOfRegion.add(id)) return;
    log("Declining ride $id: region ${order.regionId} is not the driver's region");
    await rejectOrder(silent: true, ride: order);
  }

  bool get shouldShowOrderSheet {
    final status = currentOrder.value.status;
    // orderPlaced & driverPending = waiting for accept/reject → don't show ride actions card
    return currentOrder.value.id != null &&
        ![
          Constant.orderPlaced,
          Constant.driverPending,
          Constant.driverRejected,
          Constant.orderCompleted,
          Constant.orderCancelled,
        ].contains(status);
  }

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    if (Constant.selectedMapType != 'osm') {
      markers.clear();
      polyLines.clear();
    } else {
      osmMarkers.clear();
      routePoints.clear();
    }
    update();
  }

  Future<void> onRideStatus() async {
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    currentOrder.value.status = Constant.orderInTransit;
    await FireStoreUtils.setCabOrder(currentOrder.value);
    ShowToastDialog.closeLoader();
    Get.back();
  }

  Future<void> completeRide() async {
    final CabOrderModel completed = currentOrder.value;
    final String? id = completed.id;
    if (id == null) return;
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      await updateCabWalletAmount(completed);

      await FireStoreUtils.getFirestOrderOrNOtCabService(completed).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateReferralAmountCabService(completed);
        }
      });

      // The ride's snapshot may have replaced [currentOrder] with a fresher
      // copy of the same ride meanwhile; that one is written. Never another ride.
      final CabOrderModel order = currentOrder.value.id == id ? currentOrder.value : completed;
      order.status = Constant.orderCompleted;
      await FireStoreUtils.setCabOrder(order);
      // This ride id (and its request) only, field-level. `inProgressOrderID
      // = []` with the whole user document also wiped a delivery order held
      // in the same array, and rolled back concurrent assignments and offers.
      await _releaseRide(id, clearRequest: true);

      ShowToastDialog.closeLoader();
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("Error in completeRide(): $e");
    }
  }

  Future<void> updateCabWalletAmount(CabOrderModel orderModel) async {
    try {
      double totalTax = 0.0;
      double discount = 0.0;
      double subTotal = 0.0;
      double adminComm = 0.0;
      double totalAmount = 0.0;

      subTotal = double.tryParse(orderModel.subTotal ?? '0.0') ?? 0.0;
      discount = double.tryParse(orderModel.discount ?? '0.0') ?? 0.0;

      if (orderModel.taxSetting != null) {
        for (var element in orderModel.taxSetting!) {
          totalTax += Constant.calculateTax(amount: subTotal.toString(), taxModel: element);
        }
      }

      if ((orderModel.adminCommission ?? '').isNotEmpty) {
        adminComm = Constant.calculateAdminCommission(
            amount: (subTotal - discount).toString(), adminCommissionType: orderModel.adminCommissionType.toString(), adminCommission: orderModel.adminCommission ?? '0');
      }
      totalAmount = (subTotal + totalTax) - discount;

      final ownerId = orderModel.driver?.ownerId;
      final userIdForWallet = (ownerId != null && ownerId.isNotEmpty) ? ownerId : FireStoreUtils.getCurrentUid();

      if (orderModel.paymentMethod.toString() != PaymentGateway.cod.name) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: totalAmount,
            date: Timestamp.now(),
            paymentMethod: orderModel.paymentMethod ?? '',
            transactionUser: "driver",
            userId: userIdForWallet,
            isTopup: true,
            orderId: orderModel.id,
            note: "Booking amount credited",
            paymentStatus: "success");

        final setTx = await FireStoreUtils.setWalletTransaction(transactionModel);
        if (setTx == true) {
          await FireStoreUtils.updateUserWallet(amount: totalAmount.toString(), userId: userIdForWallet);
        }
      }

      WalletTransactionModel adminTx = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: adminComm,
          date: Timestamp.now(),
          paymentMethod: orderModel.paymentMethod ?? '',
          transactionUser: "driver",
          userId: userIdForWallet,
          isTopup: false,
          orderId: orderModel.id,
          note: "Admin commission deducted",
          paymentStatus: "success");

      final setAdmin = await FireStoreUtils.setWalletTransaction(adminTx);
      if (setAdmin == true) {
        await FireStoreUtils.updateUserWallet(amount: "-${adminComm.toString()}", userId: userIdForWallet);
      }
    } catch (e) {
      log("Error in updateCabWalletAmount(): $e");
    }
  }

  Future<void> getCurrentOrder() async {
    try {
      final List<dynamic> inProgress = driverModel.value.inProgressOrderID ?? const [];
      _ridesWatch.watch(inProgress);
      if (inProgress.isNotEmpty) {
        // Until the statuses are known, keep whatever is on screen.
        if (!_ridesWatch.loaded) return;
        String? id;
        final CabOrderModel? current = _listeningRideId == null ? null : _rides[_listeningRideId];
        if (current != null && inProgress.contains(_listeningRideId) && _rideIsMine(current)) {
          id = _listeningRideId;
        } else {
          for (final dynamic raw in inProgress) {
            final CabOrderModel? ride = _rides[raw.toString()];
            if (ride != null && _rideIsMine(ride)) {
              id = raw.toString();
              break;
            }
          }
        }
        if (id != null) {
          _listenToRide(id);
          return;
        }
        // No ride in progress (the ids are delivery orders, or finished):
        // fall through to a pending request, as when the array is empty.
      }

      final pendingRequest = driverModel.value.orderCabRequestData;
      if (pendingRequest != null) {
        final id = pendingRequest.id?.toString();
        if (id != null && id.isNotEmpty) {
          if (_isOutOfRegionRequest(pendingRequest)) {
            // Declined without being shown; then on as if there were none.
            await _declineOutOfRegion(pendingRequest);
          } else if (_offerable(pendingRequest)) {
            // Immediately show the order from cached data so the accept/reject
            // sheet appears without waiting for the Firestore snapshot.
            final bool show = currentOrder.value.id == null;
            _listenToRide(id);
            if (show) {
              currentOrder.value = pendingRequest;
              await changeData();
              update();
            }
            return;
          }
          // Not offerable (unverified or offline): a new request is not
          // surfaced at all — no card, no route, no alert sound.
        }
      }

      _stopRide();
      if (currentOrder.value.id == null) return;
      currentOrder.value = CabOrderModel();
      await clearMap();
      await AudioPlayerService.playSound(false);
      update();
    } catch (e) {
      log("getCurrentOrder() error: $e");
    }
  }

  Future<void> _handleOrderDoc(DocumentSnapshot<Map<String, dynamic>> docSnap, String id) async {
    try {
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          final incoming = CabOrderModel.fromJson(data);
          if (_listeningRideId != id) return; // a listener being replaced
          if (_isOutOfRegionRequest(incoming)) {
            _stopRide();
            await _declineOutOfRegion(incoming);
            return;
          }
          // A new request this driver may not take (unverified, or gone
          // offline) is taken off the screen; an assigned ride never is.
          if (_isPending(incoming) && !_offerable(incoming)) {
            _stopRide();
            if (currentOrder.value.id == id) {
              currentOrder.value = CabOrderModel();
              await clearMap();
            }
            update();
            return;
          }
          // Handed to another driver, or sent back to dispatch: not this
          // driver's ride any more, and never shown with live actions.
          final String otherDriver = (incoming.driverId ?? '').toString().trim();
          final bool reassigned = otherDriver.isNotEmpty && otherDriver != driverModel.value.id;
          if (reassigned || (incoming.status == Constant.driverRejected && (driverModel.value.inProgressOrderID ?? const []).contains(id))) {
            _stopRide();
            await _releaseRide(id);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
            update();
            return;
          }
          currentOrder.value = incoming;
          await changeData();
          if (currentOrder.value.status == Constant.orderCompleted) {
            _stopRide();
            await _releaseRide(id);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
            update();
            return;
          } else if (currentOrder.value.status == Constant.orderRejected || currentOrder.value.status == Constant.orderCancelled) {
            _stopRide();
            await _releaseRide(id, clearRequest: true);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
            update();
            return;
          }
          update();
          return;
        }
      }
      if (_listeningRideId != id) return;
      _orderQuerySub?.cancel();
      _orderQuerySub = FireStoreUtils.fireStore.collection(CollectionName.ridesBooking).where('id', isEqualTo: id).limit(1).snapshots().listen((qSnap) => _handleOrderQuery(qSnap));
    } catch (e) {
      log("Error listening to order doc: $e");
    }
  }

  Future<void> _handleOrderQuery(QuerySnapshot<Map<String, dynamic>> qSnap) async {
    try {
      if (qSnap.docs.isNotEmpty) {
        final doc = qSnap.docs.first;
        final data = doc.data();
        final CabOrderModel incoming = CabOrderModel.fromJson(data);
        // Same rule as the doc listener: a new request this driver may not
        // take is not shown.
        if (_isPending(incoming) && !_offerable(incoming)) {
          if (currentOrder.value.id == incoming.id) {
            currentOrder.value = CabOrderModel();
            await clearMap();
          }
          update();
          return;
        }
        currentOrder.value = incoming;
        await changeData();
        if (currentOrder.value.status == Constant.orderCompleted) {
          final String? id = currentOrder.value.id;
          _stopRide();
          if (id != null) await _releaseRide(id);
          currentOrder.value = CabOrderModel();
          await clearMap();
          await AudioPlayerService.playSound(false);
          update();
          return;
        }
        update();
        return;
      } else {
        currentOrder.value = CabOrderModel();
        await AudioPlayerService.playSound(false);
        update();
      }
    } catch (e) {
      log("Error parsing order from query fallback: $e");
    }
  }

  RxBool isChange = false.obs;

  Future<void> changeData() async {
    if (Constant.mapType == "inappmap") {
      if (Constant.selectedMapType == "osm") {
        await getOSMPolyline();
      } else {
        await getGooglePolyline();
      }
    }
    // Play alert sound for both "Order Placed" and "Driver Pending" — both need
    // accept/reject — when the card is actually shown (see [showRequestSheet]).
    if (showRequestSheet) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  Future<void> _subscribeDriver() async {
    _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((event) => _onDriverSnapshot(event));

    // An independent driver has no owner, and `Constant.userModel` itself
    // can still be null on a cold start — the `!` threw here and took the
    // whole subscribe step (including the driver listener below it in the
    // other modules) down with it.
    final String ownerId = Constant.userModel?.ownerId ?? '';
    if (ownerId.isNotEmpty) {
      FireStoreUtils.fireStore.collection(CollectionName.users).doc(ownerId).snapshots().listen(
        (event) async {
          if (event.exists) {
            ownerModel.value = UserModel.fromJson(event.data()!);
          }
        },
      );
    }
  }

  Future<void> _onDriverSnapshot(DocumentSnapshot<Map<String, dynamic>> event) async {
    try {
      if (event.exists && event.data() != null) {
        driverModel.value = UserModel.fromJson(event.data()!);
        _updateCurrentLocationMarkers();
        if (driverModel.value.id != null) {
          await getCurrentOrder();
          await changeData();
          // For multi-section drivers: use active order's sectionId when available.
          // currentOrder may not be populated yet (async listener), so also check
          // orderCabRequestData.sectionId (the pending push from customer side).
          final activeSectionId = (currentOrder.value.sectionId?.isNotEmpty == true)
              ? currentOrder.value.sectionId
              : (driverModel.value.orderCabRequestData?.sectionId?.isNotEmpty == true)
                  ? driverModel.value.orderCabRequestData!.sectionId
                  : driverModel.value.sectionIds?.isNotEmpty == true
                      ? driverModel.value.sectionIds!.first
                      : null;
          // Preload all registered sections into cache; also ensure active section is loaded
          for (final sid in driverModel.value.sectionIds ?? <String>[]) {
            if (!Constant.sectionModels.containsKey(sid)) {
              FireStoreUtils.getSectionBySectionId(sid).then((sectionValue) {
                if (sectionValue != null) Constant.sectionModels[sid] = sectionValue;
              });
            }
          }
          // Active order/request section may differ — ensure it's cached too
          if (activeSectionId != null &&
              activeSectionId.isNotEmpty &&
              !Constant.sectionModels.containsKey(activeSectionId)) {
            await FireStoreUtils.getSectionBySectionId(activeSectionId).then((sectionValue) {
              if (sectionValue != null) Constant.sectionModels[activeSectionId] = sectionValue;
            });
          }
          update();
        }
      }
    } catch (e) {
      log("getDriver() listener error: $e");
    }
  }

  void _updateCurrentLocationMarkers() async {
    try {
      final loc = driverModel.value.location;
      final latLng = _safeLatLngFromLocation(loc);

      // Update reactive current location
      current.value = location.LatLng(latLng.latitude, latLng.longitude);

      // --- OSM Section ---
      try {
        setOsmMapMarker();

        if (latLng.latitude != 0.0 || latLng.longitude != 0.0) {
          osmMapController.move(location.LatLng(latLng.latitude, latLng.longitude), 16);
        }
      } catch (e) {
        log("OSM map move ignored (controller not ready): $e");
      }

      // --- GOOGLE MAP Section ---
      try {
        final driverIcon = await _getDriverIcon();

        // Remove old driver marker
        markers.remove("Driver");

        // Create new Google Marker
        markers["Driver"] = Marker(
          markerId: const MarkerId("Driver"),
          infoWindow: const InfoWindow(title: "Driver"),
          position: LatLng(current.value.latitude, current.value.longitude),
          icon: driverIcon,
          rotation: _safeRotation(),
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );

        // Animate camera to current driver location
        if (mapController != null && !(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(current.value.latitude, current.value.longitude),
                zoom: 16,
                bearing: _safeRotation(),
              ),
            ),
          );
        }
      } catch (e) {
        log("Google map update ignored (controller not ready): $e");
      }

      update();

      log('_updateCurrentLocationMarkers: lat=${latLng.latitude}, lng=${latLng.longitude}, '
          'osmMarkers=${osmMarkers.length}, googleMarkers=${markers.length}');
    } catch (e) {
      log("_updateCurrentLocationMarkers error: $e");
    }
  }

  GoogleMapController? mapController;

  Rx<PolylinePoints> polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey).obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxMap<String, Marker> markers = <String, Marker>{}.obs;

  LatLng _safeLatLngFromLocation(dynamic loc) {
    final lat = (loc?.latitude is num) ? loc.latitude.toDouble() : 0.0;
    final lng = (loc?.longitude is num) ? loc.longitude.toDouble() : 0.0;
    return LatLng(lat, lng);
  }

  double _safeRotation() {
    return double.tryParse(driverModel.value.rotation.toString()) ?? 0.0;
  }

  Future<void> getGooglePolyline() async {
    try {
      if (currentOrder.value.id == null) return;

      final driverLatLng = _safeLatLngFromLocation(driverModel.value.location);

      // Check order status
      if (currentOrder.value.status != Constant.driverPending) {
        // Case 1: Driver Accepted or Order Shipped → Driver → Pickup
        if (currentOrder.value.status == Constant.driverAccepted || currentOrder.value.status == Constant.orderShipped) {
          final sourceLatLng = _safeLatLngFromLocation(currentOrder.value.sourceLocation);

          await _drawGoogleRoute(
            origin: driverLatLng,
            destination: sourceLatLng,
            addDriver: true,
            addSource: true,
            addDestination: false,
          );

          animateToSource();
        }

        // Case 2: Order In Transit → Driver → Destination
        else if (currentOrder.value.status == Constant.orderInTransit) {
          final destLatLng = _safeLatLngFromLocation(currentOrder.value.destinationLocation);

          await _drawGoogleRoute(
            origin: driverLatLng,
            destination: destLatLng,
            addDriver: true,
            addSource: false,
            addDestination: true,
          );

          animateToSource();
        }
      }

      // Case 3: Before driver assigned → Source → Destination
      else {
        final sourceLatLng = _safeLatLngFromLocation(currentOrder.value.sourceLocation);
        final destLatLng = _safeLatLngFromLocation(currentOrder.value.destinationLocation);

        await _drawGoogleRoute(
          origin: sourceLatLng,
          destination: destLatLng,
          addDriver: false,
          addSource: true,
          addDestination: true,
        );

        animateToSource();
      }
    } catch (e, s) {
      log('getGooglePolyline() error: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  Future<void> _drawGoogleRoute({
    required LatLng origin,
    required LatLng destination,
    bool addDriver = true,
    bool addSource = true,
    bool addDestination = true,
  }) async {
    try {
      if ((origin.latitude == 0.0 && origin.longitude == 0.0) || (destination.latitude == 0.0 && destination.longitude == 0.0)) return;

      // Get route points from Google Directions API
      final result = await polylinePoints.value.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) {
        log('Google route not found');
        return;
      }

      final List<LatLng> polylineCoordinates = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      // Draw polyline
      addPolyLine(polylineCoordinates);

      // --- Update markers (same style as OSM) ---
      await _updateGoogleMarkers(
        driverLatLng: addDriver ? origin : null,
        sourceLatLng: addSource ? _safeLatLngFromLocation(currentOrder.value.sourceLocation) : null,
        destinationLatLng: addDestination ? _safeLatLngFromLocation(currentOrder.value.destinationLocation) : null,
      );
    } catch (e) {
      log('_drawGoogleRoute error: $e');
    }
  }

  Future<void> _updateGoogleMarkers({
    LatLng? driverLatLng,
    LatLng? sourceLatLng,
    LatLng? destinationLatLng,
  }) async {
    final Map<String, Marker> newMarkers = {};

    // Driver Marker
    if (driverLatLng != null) {
      final driverIcon = await _getDriverIcon();
      newMarkers['Driver'] = Marker(
        markerId: const MarkerId('Driver'),
        position: driverLatLng,
        rotation: _safeRotation(),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: driverIcon,
      );
    }

    // Source Marker
    if (sourceLatLng != null) {
      final srcIcon = await _bitmapDescriptorFromAsset(
        'assets/images/location_black3x.png',
        width: 100,
      );
      newMarkers['Source'] = Marker(
        markerId: const MarkerId('Source'),
        position: sourceLatLng,
        icon: srcIcon,
      );
    }

    // Destination Marker
    if (destinationLatLng != null) {
      final dstIcon = await _bitmapDescriptorFromAsset(
        'assets/images/location_orange3x.png',
        width: 100,
      );
      newMarkers['Destination'] = Marker(
        markerId: const MarkerId('Destination'),
        position: destinationLatLng,
        icon: dstIcon,
      );
    }

    // Apply all markers
    // ✅ Apply all markers to your RxMap<String, Marker>
    markers
      ..clear()
      ..addAll(newMarkers);

    update();
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromUrl(String url, {int width = 100}) async {
    try {
      final Uint8List bytes = await Constant().getBytesFromUrl(url, width: width);
      return BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      log('Error loading network icon: $e');
      return BitmapDescriptor.defaultMarker;
    }
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(String asset, {int width = 100}) async {
    try {
      final Uint8List bytes = await Constant().getBytesFromAsset(asset, width);
      return BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      log('Error loading asset icon: $e');
      return BitmapDescriptor.defaultMarker;
    }
  }

  void addPolyLine(List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isEmpty) {
      // nothing to draw, but ensure markers updated
      update();
      return;
    }

    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppThemeData.primary300,
      points: polylineCoordinates,
      width: 8,
      geodesic: true,
    );
    polyLines[id] = polyline;
    update();
    updateCameraLocation(polylineCoordinates.first);
  }

  Future<void> updateCameraLocation([LatLng? source]) async {
    try {
      if (mapController == null || source == null) return;
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: source,
            zoom: currentOrder.value.id == null || currentOrder.value.status == Constant.driverPending ? 16 : 20,
            bearing: _safeRotation(),
          ),
        ),
      );
    } catch (e) {
      log("updateCameraLocation error: $e");
    }
  }

  void animateToSource() {
    double lat = 0.0;
    double lng = 0.0;
    final loc = driverModel.value.location;
    if (loc != null) {
      // Use string parsing to avoid nullable-toDouble issues and handle numbers/strings.
      lat = double.tryParse('${loc.latitude}') ?? 0.0;
      lng = double.tryParse('${loc.longitude}') ?? 0.0;
    }
    _updateCurrentLocationMarkers();
    osmMapController.move(location.LatLng(lat, lng), 16);
  }

  Rx<location.LatLng> source = location.LatLng(21.1702, 72.8311).obs; // Start (e.g., Surat)
  Rx<location.LatLng> current = location.LatLng(21.1800, 72.8400).obs; // Moving marker
  Rx<location.LatLng> destination = location.LatLng(21.2000, 72.8600).obs; // Destination

  void setOsmMapMarker() {
    final List<flutterMap.Marker> mk = [];

    // Add driver/current marker only when we have a valid location
    if (!(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
      mk.add(flutterMap.Marker(
        point: current.value,
        width: 45,
        height: 45,
        rotate: true,
        child: _driverMarkerWidget(),
      ));
    }

    // Add source marker if we have a valid source location (or an active order with non-zero coords)
    final hasSource = currentOrder.value.sourceLocation != null &&
        !(currentOrder.value.sourceLocation?.latitude == null || currentOrder.value.sourceLocation?.longitude == null) &&
        !(currentOrder.value.sourceLocation?.latitude == 0.0 && currentOrder.value.sourceLocation?.longitude == 0.0);
    if (hasSource) {
      source.value = location.LatLng(currentOrder.value.sourceLocation!.latitude ?? 0.0, currentOrder.value.sourceLocation!.longitude ?? 0.0);
      mk.add(flutterMap.Marker(
        point: source.value,
        width: 40,
        height: 40,
        child: Image.asset('assets/images/location_black3x.png'),
      ));
    }

    // Add destination marker if valid
    final hasDest = currentOrder.value.destinationLocation != null &&
        !(currentOrder.value.destinationLocation?.latitude == null || currentOrder.value.destinationLocation?.longitude == null) &&
        !(currentOrder.value.destinationLocation?.latitude == 0.0 && currentOrder.value.destinationLocation?.longitude == 0.0);
    if (hasDest) {
      destination.value = location.LatLng(currentOrder.value.destinationLocation!.latitude ?? 0.0, currentOrder.value.destinationLocation!.longitude ?? 0.0);
      mk.add(flutterMap.Marker(
        point: destination.value,
        width: 40,
        height: 40,
        child: Image.asset('assets/images/location_orange3x.png'),
      ));
    }

    osmMarkers.value = mk;
  }

  Future<void> getOSMPolyline() async {
    try {
      if (currentOrder.value.id == null) return;

      if (currentOrder.value.status != Constant.driverPending) {
        if (currentOrder.value.status == Constant.driverAccepted || currentOrder.value.status == Constant.orderShipped) {
          final lat = (driverModel.value.location?.latitude as num?)?.toDouble() ?? 0.0;
          final lng = (driverModel.value.location?.longitude as num?)?.toDouble() ?? 0.0;
          current.value = location.LatLng(lat, lng);
          source.value = location.LatLng(
            currentOrder.value.sourceLocation?.latitude ?? 0.0,
            currentOrder.value.sourceLocation?.longitude ?? 0.0,
          );
          animateToSource();
          await fetchRoute(current.value, source.value);
          setOsmMapMarker();
        } else if (currentOrder.value.status == Constant.orderInTransit) {
          final lat = (driverModel.value.location?.latitude as num?)?.toDouble() ?? 0.0;
          final lng = (driverModel.value.location?.longitude as num?)?.toDouble() ?? 0.0;
          current.value = location.LatLng(lat, lng);
          destination.value = location.LatLng(
            currentOrder.value.destinationLocation?.latitude ?? 0.0,
            currentOrder.value.destinationLocation?.longitude ?? 0.0,
          );
          await fetchRoute(current.value, destination.value);
          setOsmMapMarker();
          animateToSource();
        }
      } else {
        current.value = location.LatLng(currentOrder.value.sourceLocation?.latitude ?? 0.0, currentOrder.value.sourceLocation?.longitude ?? 0.0);
        destination.value = location.LatLng(currentOrder.value.destinationLocation?.latitude ?? 0.0, currentOrder.value.destinationLocation?.longitude ?? 0.0);
        await fetchRoute(current.value, destination.value);
        setOsmMapMarker();
        animateToSource();
      }
    } catch (e) {
      log('getOSMPolyline error: $e');
    }
  }

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;

  Future<void> fetchRoute(location.LatLng source, location.LatLng destination) async {
    try {
      // ensure valid coords
      final bothZero = source.latitude == 0.0 && source.longitude == 0.0 && destination.latitude == 0.0 && destination.longitude == 0.0;
      if (bothZero) {
        routePoints.clear();
        return;
      }

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded != null && decoded['routes'] != null && decoded['routes'] is List && (decoded['routes'] as List).isNotEmpty && decoded['routes'][0]['geometry'] != null) {
          final geometry = decoded['routes'][0]['geometry']['coordinates'];
          routePoints.clear();
          for (var coord in geometry) {
            if (coord is List && coord.length >= 2) {
              final lon = coord[0];
              final lat = coord[1];
              if (lat is num && lon is num) {
                routePoints.add(location.LatLng(lat.toDouble(), lon.toDouble()));
              }
            }
          }
          return;
        }
        routePoints.clear();
      } else {
        log("Failed to get route: ${response.statusCode} ${response.body}");
        routePoints.clear();
      }
    } catch (e) {
      log("fetchRoute error: $e");
      routePoints.clear();
    }
  }
}
