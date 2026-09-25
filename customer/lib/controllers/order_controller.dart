import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';
import '../utils/order_history_limit.dart';
import '../utils/wholesale_pricing.dart';
import 'package:customer/models/vendor_model.dart';

class OrderController extends GetxController {
  RxList<OrderModel> allList = <OrderModel>[].obs;
  RxList<OrderModel> inProgressList = <OrderModel>[].obs;
  RxList<OrderModel> deliveredList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledList = <OrderModel>[].obs;

  RxBool isLoading = true.obs;

  /// Orders hidden by the free order-history limit (spec 18.9), PER TAB -
  /// each tab caps its own history, so a tab is never left empty by another
  /// tab's orders (WEB spec 6). 0 = nothing hidden in that tab.
  RxInt hiddenOrderCount = 0.obs;
  RxInt hiddenDeliveredCount = 0.obs;
  RxInt hiddenCancelledCount = 0.obs;
  RxInt hiddenRejectedCount = 0.obs;

  /// WEB spec 9 - the period picker, offered to entitled customers only.
  RxBool canChoosePeriod = false.obs;

  /// The chosen period. Narrows orders that are already in memory: changing
  /// it never returns to the server.
  Rx<HistoryPeriod> period = const HistoryPeriod.all().obs;

  /// Months the customer actually has orders in, newest first. An empty month
  /// can never be chosen.
  RxList<DateTime> availableMonths = <DateTime>[].obs;

  /// Everything the query returned, before the period and the free limit.
  final List<OrderModel> _fetched = [];

  /// Newest orders each tab may show; null = all.
  int? _limit;

  /// The limit is on order HISTORY. Orders still being placed, prepared or
  /// delivered are always shown, however old, so a customer can always track
  /// and act on them.
  static const Set<String> activeStatuses = {
    Constant.orderPlaced,
    Constant.orderAccepted,
    Constant.driverPending,
    Constant.driverAccepted,
    Constant.driverRejected, // back to dispatch, still active
    Constant.orderShipped,
    Constant.orderInTransit,
  };

  @override
  void onInit() {
    // TODO: implement onInit
    getOrder();
    super.onInit();
  }

  /// Fetches the history once, then draws it. The period picker calls
  /// [renderOrders] instead, so choosing a period costs no read.
  Future<void> getOrder() async {
    if (Constant.userModel != null) {
      // The free limit applies HERE, in the customer's own history screen,
      // never in FireStoreUtils (the store app / panels must see everything).
      final OrderHistoryAccess access = await OrderHistoryLimit.access();
      _limit = access.limit;
      canChoosePeriod.value = access.canChoosePeriod;
      final List<OrderModel> value = await FireStoreUtils.getAllOrder();
      _fetched
        ..clear()
        ..addAll(value);
      availableMonths.value = OrderHistoryLimit.monthsOf(_fetched, (OrderModel o) => o.createdAt);
      // A month that no longer has orders (or a picker the customer is no
      // longer entitled to) falls back to the whole history.
      if (!canChoosePeriod.value) {
        period.value = const HistoryPeriod.all();
      } else if (period.value.mode == HistoryPeriodMode.month && !availableMonths.contains(period.value.month)) {
        period.value = const HistoryPeriod.all();
      }
      renderOrders();
    }

    isLoading.value = false;
  }

  /// Chooses a period and redraws from what is already loaded (WEB spec 9).
  void setPeriod(HistoryPeriod value) {
    period.value = value;
    renderOrders();
  }

  /// Splits the loaded orders into the tabs, applying the period first and the
  /// free limit PER TAB afterwards - the same funnel, so the two can never
  /// disagree about which orders a customer may see.
  void renderOrders() {
    // The free-limit notice is cleared before each redraw, or it would linger
    // after the customer narrowed to a period that was under the limit anyway.
    hiddenOrderCount.value = 0;
    hiddenDeliveredCount.value = 0;
    hiddenCancelledCount.value = 0;
    hiddenRejectedCount.value = 0;

    final HistoryPeriod chosen = period.value;
    final List<OrderModel> inPeriod = _fetched.where((o) => chosen.contains(o.createdAt)).toList();

    final List<OrderModel> active = inPeriod.where((o) => activeStatuses.contains(o.status)).toList();
    final List<OrderModel> finished = inPeriod.where((o) => !activeStatuses.contains(o.status)).toList();

    final List<OrderModel> delivered = finished.where((o) => o.status == Constant.orderCompleted).toList();
    final List<OrderModel> cancelled = finished.where((o) => o.status == Constant.orderCancelled).toList();
    final List<OrderModel> rejected = finished.where((o) => o.status == Constant.orderRejected).toList();
    // Anything finished that none of the three tabs claims (older or custom
    // statuses) still belongs in "All", capped like its own tab.
    final List<OrderModel> other = finished
        .where((o) => o.status != Constant.orderCompleted && o.status != Constant.orderCancelled && o.status != Constant.orderRejected)
        .toList();

    final List<OrderModel> visibleDelivered = _cap(delivered);
    final List<OrderModel> visibleCancelled = _cap(cancelled);
    final List<OrderModel> visibleRejected = _cap(rejected);
    final List<OrderModel> visibleOther = _cap(other);

    hiddenDeliveredCount.value = delivered.length - visibleDelivered.length;
    hiddenCancelledCount.value = cancelled.length - visibleCancelled.length;
    hiddenRejectedCount.value = rejected.length - visibleRejected.length;

    deliveredList.value = _newestFirst(visibleDelivered);
    cancelledList.value = _newestFirst(visibleCancelled);
    rejectedList.value = _newestFirst(visibleRejected);
    inProgressList.value = _newestFirst(
      active
          .where((p0) => p0.status == Constant.orderAccepted || p0.status == Constant.driverPending || p0.status == Constant.orderShipped || p0.status == Constant.orderInTransit)
          .toList(),
    );

    // "All" is exactly what the other tabs show, so the tabs and the combined
    // list can never contradict each other.
    final List<OrderModel> all = [...active, ...visibleDelivered, ...visibleCancelled, ...visibleRejected, ...visibleOther];
    hiddenOrderCount.value = finished.length - (visibleDelivered.length + visibleCancelled.length + visibleRejected.length + visibleOther.length);
    allList.value = _newestFirst(all);
  }

  List<OrderModel> _cap(List<OrderModel> orders) => OrderHistoryLimit.newest(orders, _limit, (OrderModel o) => o.createdAt);

  List<OrderModel> _newestFirst(List<OrderModel> orders) =>
      [...orders]..sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));

  final CartProvider cartProvider = CartProvider();

  /// Reorder: the past order line carries the price that was charged (maybe
  /// wholesale), so retail prices and tiers are refreshed from the product.
  Future<void> addToCart({required CartProductModel cartProductModel, VendorModel? vendor}) async {
    final CartProductModel? line = await WholesalePricing.reorderLine(cartProductModel, vendor: vendor);
    if (line == null) {
      ShowToastDialog.showToast("This item can't be reordered right now. Please add it from the store.".tr);
      return;
    }
    await cartProvider.addToCart(Get.context!, line, line.quantity!);
    update();
  }
}
