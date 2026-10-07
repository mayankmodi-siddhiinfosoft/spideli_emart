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

  /// Orders hidden by the free order-history limit (spec 18.9) ACROSS THE
  /// WHOLE HISTORY - one allowance for every tab, so there is one count and
  /// one notice (WEB spec 6, 28 Sep). 0 = the allowance hid nothing, and the
  /// notice must not appear.
  RxInt hiddenOrderCount = 0.obs;

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

  /// Newest orders the customer may see across the WHOLE history; null = all.
  int? _limit;

  /// The limit is on order HISTORY. Orders still being placed, prepared or
  /// delivered are always shown, however old, so a customer can always track
  /// and act on them.
  ///
  /// DEVIATION from WEB spec 6, kept deliberately and reported to the panel
  /// team: the spec hides everything past the allowance whatever its status.
  /// An in-progress order still counts against the allowance here - it is only
  /// never hidden.
  static const Set<String> activeStatuses = {
    Constant.orderPlaced,
    Constant.orderAccepted,
    Constant.driverPending,
    Constant.driverAccepted,
    Constant.driverRejected, // back to dispatch, still active
    Constant.orderShipped,
    Constant.orderInTransit,
  };

  /// The "In Progress" tab: everything [activeStatuses] holds once the store
  /// has accepted the order (so not "Order Placed").
  static final Set<String> inProgressStatuses = activeStatuses.difference({Constant.orderPlaced});

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
      renderOrders();
    }

    isLoading.value = false;
  }

  /// Chooses a period and redraws from what is already loaded (WEB spec 9).
  void setPeriod(HistoryPeriod value) {
    period.value = value;
    renderOrders();
  }

  /// Draws the tabs through ONE funnel (WEB spec 6, 28 Sep + WEB spec 9):
  ///
  ///   whole history -> free allowance -> chosen period -> this tab's statuses
  ///
  /// The allowance is worked out once, here, before any tab is built, so all
  /// five tabs are views of one decision rather than five. A tab may therefore
  /// come back empty while orders of that kind exist, because newer orders in
  /// other tabs used the allowance up - the rule, not a fault.
  void renderOrders() {
    // The free-limit notice is cleared before each redraw, or it would linger
    // after the customer narrowed to a period that was under the limit anyway.
    hiddenOrderCount.value = 0;

    // ONE whole-history decision, of any kind, before any tab exists.
    final FreeOrderAllowance<OrderModel> allowance = OrderHistoryLimit.applyFreeOrderAllowance(
      _fetched,
      _limit,
      (OrderModel o) => o.createdAt,
      keepAlways: (OrderModel o) => activeStatuses.contains(o.status),
    );
    hiddenOrderCount.value = allowance.hiddenCount;

    // The picker may only ever offer months of orders the customer may see, so
    // the months come from the allowance rather than from the whole query.
    availableMonths.value = OrderHistoryLimit.monthsOf(allowance.visible, (OrderModel o) => o.createdAt);
    // A month that no longer has orders (or a picker the customer is no longer
    // entitled to) falls back to the whole history.
    if (!canChoosePeriod.value) {
      period.value = const HistoryPeriod.all();
    } else if (period.value.mode == HistoryPeriodMode.month && !availableMonths.contains(period.value.month)) {
      period.value = const HistoryPeriod.all();
    }

    // WEB spec 9, in the same funnel and AFTER the allowance: the allowance
    // settles what the customer MAY see, the period narrows what they chose to
    // look at. The two can never disagree.
    final FreeOrderAllowance<OrderModel> visible = allowance.inPeriod(period.value);

    // Each tab only narrows the one allowance to its own statuses; nothing here
    // can reach past it.
    deliveredList.value = OrderHistoryLimit.limitOrderHistory(visible, (OrderModel o) => o.status == Constant.orderCompleted);
    cancelledList.value = OrderHistoryLimit.limitOrderHistory(visible, (OrderModel o) => o.status == Constant.orderCancelled);
    rejectedList.value = OrderHistoryLimit.limitOrderHistory(visible, (OrderModel o) => o.status == Constant.orderRejected);
    // Every live dispatch state: the store accepted it, a driver is being
    // offered it ("Driver Pending"), declined it so the next one is being
    // looked for ("Driver Rejected"), or accepted it ("Driver Accepted", until
    // deliveryDispatch moves it on to "Order Shipped").
    inProgressList.value = OrderHistoryLimit.limitOrderHistory(visible, (OrderModel o) => inProgressStatuses.contains(o.status));
    // "All" is exactly the allowance, so the tabs and the combined list can
    // never contradict each other.
    allList.value = visible.visible;
  }

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
