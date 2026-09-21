import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
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

  @override
  void onClose() {
    _driverSub?.cancel();
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
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
      if (cached != null && (cached.latitude ?? 0) != 0) {
        lat = cached.latitude!;
        lng = cached.longitude!;
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
    try {
      await AudioPlayerService.playSound(false);
      ShowToastDialog.showLoader("Please wait".tr);

      driverModel.value.inProgressOrderID ??= [];
      driverModel.value.inProgressOrderID!.add(currentOrder.value.id);
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.updateUser(driverModel.value);

      currentOrder.value.status = Constant.driverAccepted;
      currentOrder.value.driverId = driverModel.value.id;
      currentOrder.value.driver = driverModel.value;
      await FireStoreUtils.setCabOrder(currentOrder.value);

      ShowToastDialog.closeLoader();

      await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.value.author?.fcmToken ?? "", {});
    } catch (e, s) {
      ShowToastDialog.closeLoader();
      debugPrint("Error in acceptOrder: $e");
      debugPrintStack(stackTrace: s);
      ShowToastDialog.showToast("Something went wrong. Please try again.");
    }
  }

  Future<void> rejectOrder() async {
    try {
      await AudioPlayerService.playSound(false);

      // 1️⃣ Immediately update local state (UI)
      currentOrder.value.status = Constant.driverRejected;

      currentOrder.value.rejectedByDrivers ??= [];
      if (!currentOrder.value.rejectedByDrivers!.contains(driverModel.value.id)) {
        currentOrder.value.rejectedByDrivers!.add(driverModel.value.id);
      }

      // Immediately update UI so bottom sheet hides right away
      currentOrder.refresh();

      // 2️⃣ Update driver local state right away
      driverModel.value.orderCabRequestData = null;
      driverModel.value.inProgressOrderID = [];
      await FireStoreUtils.updateUser(driverModel.value);

      // 3️⃣ Close bottom sheet immediately (don’t wait for Firestore)
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      } else if (Constant.singleOrderReceive == false) {
        Get.back();
      }

      // 4️⃣ Clear map immediately
      await clearMap();

      // 5️⃣ Update Firestore in background (no UI wait)
      unawaited(FireStoreUtils.setCabOrder(currentOrder.value));

      // 6️⃣ Reset local current order after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        currentOrder.value = CabOrderModel();
      });
    } catch (e, s) {
      print("rejectOrder() error: $e\n$s");
    }
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
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      await updateCabWalletAmount(currentOrder.value);

      await FireStoreUtils.getFirestOrderOrNOtCabService(currentOrder.value).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateReferralAmountCabService(currentOrder.value);
        }
      });

      currentOrder.value.status = Constant.orderCompleted;
      driverModel.value.inProgressOrderID = [];
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.setCabOrder(currentOrder.value);
      await FireStoreUtils.updateUser(driverModel.value);

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
      await _orderDocSub?.cancel();
      await _orderQuerySub?.cancel();

      final inProgress = driverModel.value.inProgressOrderID;
      if (inProgress != null && inProgress.isNotEmpty) {
        final String id = inProgress.first.toString();
        _orderDocSub = FireStoreUtils.fireStore.collection(CollectionName.ridesBooking).doc(id).snapshots().listen((docSnap) => _handleOrderDoc(docSnap, id));
        return;
      }

      final pendingRequest = driverModel.value.orderCabRequestData;
      if (pendingRequest != null) {
        final id = pendingRequest.id?.toString();
        if (id != null && id.isNotEmpty) {
          // Immediately show the order from cached data so the accept/reject
          // sheet appears without waiting for the Firestore snapshot.
          if (currentOrder.value.id == null) {
            currentOrder.value = pendingRequest;
            await changeData();
            update();
          }
          _orderDocSub = FireStoreUtils.fireStore.collection(CollectionName.ridesBooking).doc(id).snapshots().listen((docSnap) => _handleOrderDoc(docSnap, id));
          return;
        }
      }

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
          currentOrder.value = CabOrderModel.fromJson(data);
          await changeData();
          if (currentOrder.value.status == Constant.orderCompleted) {
            driverModel.value.inProgressOrderID = [];
            await FireStoreUtils.updateUser(driverModel.value);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
            update();
            return;
          } else if (currentOrder.value.status == Constant.orderRejected || currentOrder.value.status == Constant.orderCancelled) {
            driverModel.value.inProgressOrderID = [];
            driverModel.value.orderCabRequestData = null;
            await FireStoreUtils.updateUser(driverModel.value);
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
        currentOrder.value = CabOrderModel.fromJson(data);
        await changeData();
        if (currentOrder.value.status == Constant.orderCompleted) {
          driverModel.value.inProgressOrderID = [];
          await FireStoreUtils.updateUser(driverModel.value);
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
    // Play alert sound for both "Order Placed" and "Driver Pending" — both need accept/reject
    if (currentOrder.value.status == Constant.driverPending || currentOrder.value.status == Constant.orderPlaced) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  Future<void> _subscribeDriver() async {
    _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((event) => _onDriverSnapshot(event));

    if (Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty) {
      FireStoreUtils.fireStore.collection(CollectionName.users).doc(Constant.userModel!.ownerId).snapshots().listen(
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
