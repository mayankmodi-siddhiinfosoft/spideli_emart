import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  /// `Constant.userModel!` threw in the field initialiser — i.e. before
  /// `onInit`, so GetX could not even construct this controller — whenever the
  /// global had not been populated yet (cold start straight onto the
  /// dashboard). The live user document arrives from [getDriver] anyway.
  Rx<UserModel> driverModel = (Constant.userModel ?? UserModel()).obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  /// The orders behind [newOrder] and [activeOrder], live. The cards used to
  /// be `FutureBuilder(getOrderById)` created inside build: every
  /// `users/{me}` snapshot (one per location update) cleared both lists and
  /// rebuilt them, every card dropped back to a skeleton while it re-read its
  /// order, and a tap on Accept / Reject or on an active order mostly landed on
  /// a skeleton that does nothing.
  final RxMap<String, OrderModel> orders = <String, OrderModel>{}.obs;
  final RxBool ordersLoaded = false.obs;
  late final VendorOrdersWatch _ordersWatch = VendorOrdersWatch(_onOrdersChanged);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  @override
  void onInit() {
    // TODO: implement onInt
    getDriver();
    super.onInit();
  }

  @override
  void onClose() {
    _driverSub?.cancel();
    _ordersWatch.cancel();
    super.onClose();
  }

  bool _ordersFromServer = false;

  void _onOrdersChanged(Map<String, OrderModel> found, bool fromServer) {
    orders.assignAll(found);
    ordersLoaded.value = true;
    _ordersFromServer = fromServer;
    final String? uid = driverModel.value.id;
    if (fromServer && uid != null) {
      AssignedDeliveryOrders.pruneStale(uid, driverModel.value.inProgressOrderID, found);
    }
    _syncOffers();
  }

  /// A freelance driver whose documents are not verified (and who is not
  /// auto-verified). They keep their assigned (Active) jobs but are offered
  /// nothing new: no "New" tab, no alert, and [acceptOrder] refuses.
  static bool documentsPending(UserModel driver) =>
      driver.vendorID?.isEmpty == true && driver.isDocumentVerify == false && driver.isAutoVerify == false;

  /// Who gets the "New" tab: a freelance driver who may take offers.
  static bool canTakeOffers(UserModel driver) => driver.vendorID?.isEmpty == true && !documentsPending(driver);

  static bool _outOfRegionOffer(OrderModel order, UserModel driver) =>
      !AssignedDeliveryOrders.isNamedFor(order, driver.id) && RegionService.isOutOfDriverRegion(order.regionId, driver: driver);

  /// The "New" tab: the ids of [requests] (`orderRequestData`) that are still
  /// offers this driver may answer ([AssignedDeliveryOrders.isOfferFor]: the
  /// order is `Driver Pending`, names nobody else, and was not rejected by
  /// them) and are in their region. Nothing removes an id from a driver's
  /// requests when the order moves on, so the raw list offered Accept /
  /// Reject on cancelled orders and on jobs held by another driver. An id
  /// whose order has not loaded yet is kept (a skeleton card) until it does.
  static List<dynamic> offersToShow({
    required List<dynamic> requests,
    required Map<String, OrderModel> orders,
    required bool ordersLoaded,
    required UserModel driver,
  }) {
    return requests.where((id) {
      final OrderModel? order = orders[id.toString()];
      if (order == null) return !ordersLoaded;
      return AssignedDeliveryOrders.isOfferFor(order, driver.id) && !_outOfRegionOffer(order, driver);
    }).toList();
  }

  /// Declines out-of-region offers and rings only for offers the "New" tab
  /// actually shows (it rang on every user snapshot for any id in the list).
  Future<void> _syncOffers() async {
    final UserModel driver = driverModel.value;
    final String? uid = driver.id;
    // Zone-bound (spec 9.1): an offer from another region is not offered;
    // it is declined so dispatch moves on. Only on server data: a stale
    // cached copy must not reject an order that has since moved on.
    if (uid != null && _ordersFromServer) {
      for (final dynamic id in newOrder) {
        final OrderModel? order = orders[id.toString()];
        if (order != null && order.id != null && AssignedDeliveryOrders.isOfferFor(order, uid) && _outOfRegionOffer(order, driver)) {
          FireStoreUtils.declineOutOfRegionVendorOrder(order.id!, uid);
        }
      }
    }
    final List<dynamic> offers = offersToShow(requests: newOrder, orders: orders, ordersLoaded: ordersLoaded.value, driver: driver);
    if (canTakeOffers(driver) && offers.any((id) => orders.containsKey(id.toString()))) {
      await AudioPlayerService.playSound(true);
    } else if (ordersLoaded.value || newOrder.isEmpty) {
      await AudioPlayerService.playSound(false);
    }
  }

  /// The id is still in the driver's (latest) arrays: an offer withdrawn
  /// while its card was on screen, or while the reason sheet was open, is
  /// not answered.
  static bool _holds(UserModel driver, String orderId) =>
      (driver.orderRequestData ?? const []).contains(orderId) || (driver.inProgressOrderID ?? const []).contains(orderId);

  final Set<String> _answering = {};

  static bool _sameIds(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  Future<void> getDriver() async {
    _driverSub?.cancel();
    _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = driverModel.value;
          final List<dynamic> requests = List<dynamic>.from(driverModel.value.orderRequestData ?? const []);
          final List<dynamic> inProgress = List<dynamic>.from(driverModel.value.inProgressOrderID ?? const []);
          // Only touched when the ids really changed (see [orders]).
          if (!_sameIds(newOrder, requests)) newOrder.assignAll(requests);
          if (!_sameIds(activeOrder, inProgress)) activeOrder.assignAll(inProgress);
          _ordersWatch.watch([...inProgress, ...requests]);
          await _syncOffers();
        }
        isLoading.value = false;
      },
      onError: (Object e) {
        log("HomeScreenMultipleOrderController.getDriver failed: $e");
        isLoading.value = false;
      },
    );
  }

  /// Accepts one of the offers in the list, after a re-check of the live
  /// order ([AssignedDeliveryOrders.acceptOffer]): a cancelled order, or one
  /// another driver holds, is refused with a message and leaves the list.
  /// The order and the driver's arrays are written field by field; the whole
  /// user document is no longer written back from this screen's copy.
  Future<void> acceptOrder(OrderModel offer) async {
    final String? orderId = offer.id;
    final UserModel driver = driverModel.value;
    if (orderId == null || driver.id == null || _answering.contains(orderId)) return;
    if (documentsPending(driver)) {
      ShowToastDialog.showToast("Document Verification in Pending".tr);
      return;
    }
    if (!_holds(driver, orderId)) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return;
    }
    _answering.add(orderId);
    try {
      await AudioPlayerService.playSound(false);
      ShowToastDialog.showLoader("Please wait".tr);
      final result = await AssignedDeliveryOrders.acceptOffer(orderId, driver);
      ShowToastDialog.closeLoader();
      switch (result.answer) {
        case OfferAnswer.done:
          final OrderModel notified = result.order ?? offer;
          // Customer and store, each on its app's channel, by their live tokens.
          await SendNotification.notifyOrderAccepted(notified);
        case OfferAnswer.held:
          break;
        case OfferAnswer.gone:
          ShowToastDialog.showToast("This order is no longer available.".tr);
        case OfferAnswer.failed:
          ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      }
    } finally {
      _answering.remove(orderId);
    }
  }

  /// Driver passes on one of the offers in the list. A reason is mandatory
  /// and nothing changes until one is given. The order goes back to dispatch
  /// (status "Driver Rejected", this driver in `rejectedByDrivers`) and the
  /// reason is appended to `driverRejections` — in a transaction that first
  /// re-checks the live order ([AssignedDeliveryOrders.rejectOffer]), so a
  /// cancelled order or another driver's job is never sent back to dispatch.
  Future<void> rejectOrder(OrderModel offer) async {
    final String? orderId = offer.id;
    final String? driverId = driverModel.value.id;
    if (orderId == null || driverId == null || _answering.contains(orderId)) return;
    final reason = await CancelReasonSheet.show(title: "Why are you rejecting this order?".tr);
    if (reason == null) return;
    // The driver's record as it is NOW, after the sheet.
    if (!_holds(driverModel.value, orderId)) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return;
    }
    _answering.add(orderId);
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      await AudioPlayerService.playSound(false);
      final OfferAnswer answer = await AssignedDeliveryOrders.rejectOffer(orderId, driverId, reason.toFields(driverId));
      ShowToastDialog.closeLoader();
      if (answer == OfferAnswer.failed) {
        ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      } else if (answer == OfferAnswer.gone) {
        ShowToastDialog.showToast("This order is no longer available.".tr);
      }
    } finally {
      _answering.remove(orderId);
    }
  }
}
