import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/payment_model/flutter_wave_model.dart';
import 'package:vendor/models/payment_model/paypal_model.dart';
import 'package:vendor/models/payment_model/razorpay_model.dart';
import 'package:vendor/models/payment_model/stripe_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/models/withdraw_method_model.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';

/// Period for the Earnings / Commissions summaries.
enum WalletPeriod { today, week, month }

/// One completed order on the Commissions tab. The money comes from
/// [FireStoreUtils.vendorOrderCredit], the same helper that credits the store.
class OrderCommissionRow {
  final OrderModel order;
  final double subTotal;
  final double commissionAmount;
  final double commissionPercent;
  final bool commissionApplied;
  final double taxAmount;

  /// What the store was credited for the order: base price + tax.
  final double storeReceived;

  /// True when [storeReceived] is the amount actually credited (from the
  /// order's wallet rows); false when it is an estimate from the formula,
  /// e.g. the credit row is outside the current date filter.
  final bool storeReceivedFromCredit;

  OrderCommissionRow({
    required this.order,
    required this.subTotal,
    required this.commissionAmount,
    required this.commissionPercent,
    required this.commissionApplied,
    required this.taxAmount,
    required this.storeReceived,
    this.storeReceivedFromCredit = false,
  });
}

class WalletController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> amountTextFieldController = TextEditingController().obs;
  Rx<TextEditingController> noteTextFieldController = TextEditingController().obs;

  Rx<UserModel> userModel = UserModel().obs;

  /// The store being viewed. Its `wallet_amount` is what can be withdrawn.
  Rx<VendorModel> vendorModel = VendorModel().obs;

  /// Withdrawable balance: the current store's own balance, not the owner's
  /// account total (which spans every store the owner has).
  num get storeBalance => vendorModel.value.storeWalletAmount ?? 0;

  /// The current store's wallet rows (Earnings tab, header totals, statement).
  /// `wallet` rows are keyed on the owner, who may own several stores, so the
  /// owner's rows are narrowed to this store - see [_rowsForStore].
  RxList<WalletTransactionModel> walletTransactionList = <WalletTransactionModel>[].obs;

  /// Ids of rows whose store can't be determined (no order, subscription or
  /// payout to tie them to). They show on every store, labelled "Account".
  RxSet<String> accountRowIds = <String>{}.obs;

  bool isAccountRow(WalletTransactionModel row) => row.id != null && accountRowIds.contains(row.id);

  RxList<WithdrawalModel> withdrawalList = <WithdrawalModel>[].obs;

  /// Completed orders of this store with their commission breakdown.
  RxList<OrderCommissionRow> commissionList = <OrderCommissionRow>[].obs;

  /// orderId -> the order's regionId, for order-based wallet rows.
  RxMap<String, String> orderRegionIds = <String, String>{}.obs;

  Rx<WalletPeriod> selectedPeriod = WalletPeriod.today.obs;

  /// Whether the Earnings list is narrowed by the date-range filter.
  bool _isFiltered = false;

  String get currentVendorId => (userModel.value.vendorID ?? '').isNotEmpty ? userModel.value.vendorID! : (Constant.userModel?.vendorID ?? '');

  /// Order-based rows keep the currency the order was charged in; other rows
  /// (subscriptions, payouts) use the store's currency (null = default).
  CurrencyModel? currencyForTransaction(WalletTransactionModel transaction) {
    final orderId = transaction.orderId;
    if (orderId == null || orderId.isEmpty) return null;
    return RegionService.currencyForOrder(orderRegionIds[orderId]);
  }

  CurrencyModel? currencyForOrder(OrderModel order) => RegionService.currencyForOrder(order.regionId);

  Future<void> loadOrderRegions() async {
    final ids = walletTransactionList.map((e) => e.orderId ?? '').where((e) => e.isNotEmpty && !orderRegionIds.containsKey(e));
    if (ids.isEmpty) return;
    await RegionService.ensureLoaded();
    orderRegionIds.addAll(await RegionService.orderRegionIds(ids));
  }

  RxInt selectedTabIndex = 0.obs;
  RxInt selectedValue = 0.obs;

  Rx<WithdrawMethodModel> withdrawMethodModel = WithdrawMethodModel().obs;

  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;
  Rx<PayPalModel> paypalDataModel = PayPalModel().obs;
  Rx<StripeModel> stripeSettingData = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveSettingData = FlutterWaveModel().obs;

  @override
  void onInit() {
    getWalletTransaction(false);

    super.onInit();
  }

  /// Short order label; tolerant of ids shorter than [Constant.orderId] expects.
  static String orderLabel(String? orderId) {
    final id = orderId ?? '';
    if (id.isEmpty || id == 'null') return '-';
    return id.length >= 10 ? Constant.orderId(orderId: id) : '#$id';
  }

  Future<void> createAndSavePdf() async {
    // Create a new PDF document
    final PdfDocument document = PdfDocument();

    // Add a page to the document
    final PdfPage page = document.pages.add();

    // Create a PDF grid (table)
    final PdfGrid grid = PdfGrid();

    // Add columns to the grid
    grid.columns.add(count: 4);

    // Add headers to the grid
    grid.headers.add(1);
    final PdfGridRow header = grid.headers[0];
    header.cells[0].value = 'Description';
    header.cells[1].value = 'Order Id';
    header.cells[2].value = 'Amount';
    header.cells[3].value = 'Date';

    // Add rows to the grid - this store's rows only.
    PdfGridRow row = grid.rows.add();
    for (var element in walletTransactionList) {
      row.cells[0].value = isAccountRow(element) ? '${element.note} (Account)' : element.note.toString();
      row.cells[1].value = orderLabel(element.orderId);
      final amount = Constant.amountShow(amount: element.amount.toString(), currency: currencyForTransaction(element));
      row.cells[2].value = element.isTopup ? amount : '-$amount';
      row.cells[3].value = element.date == null ? '' : Constant.timestampToDateTime(element.date!);
      row = grid.rows.add();
    }

    // Draw the grid on the page
    grid.draw(page: page, bounds: const Rect.fromLTWH(0, 0, 0, 0));

    // Save the document
    final List<int> bytes = document.saveSync();

    // Dispose of the document
    document.dispose();

    // Get the application directory
    final Directory downloadsDirectory = Directory('/storage/emulated/0/Download');
    final String path = '${downloadsDirectory.path}/statement.pdf';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    ShowToastDialog.showToast("Statement downloaded in download folder".tr);
    debugPrint('PDF saved at: $path');
  }

  RxDouble orderAmount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;

  Rx<DateTime> startDate = DateTime.now().subtract(const Duration(days: 1)).obs;
  Rx<DateTime> endDate = DateTime.now().obs;

  /// Pull to refresh: reloads everything, keeping the current date filter.
  Future<void> refreshAll() => getWalletTransaction(_isFiltered);

  Future<void> getWalletTransaction(bool isFilter) async {
    _isFiltered = isFilter;

    // The store first: every list below is narrowed to it.
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
      }
    });
    await loadStore();

    final List<WalletTransactionModel> ownerRows =
        (isFilter
            ? await FireStoreUtils.getFilterWalletTransaction(
                Timestamp.fromDate(DateTime(startDate.value.year, startDate.value.month, startDate.value.day, 00, 00)),
                Timestamp.fromDate(DateTime(endDate.value.year, endDate.value.month, endDate.value.day, 23, 59)),
              )
            : await FireStoreUtils.getWalletTransaction()) ??
        [];

    await FireStoreUtils.getWithdrawHistory().then((value) {
      if (value != null) {
        withdrawalList.value = value;
      }
    });

    final List<OrderModel> storeOrders = await _getStoreOrders();
    for (final order in storeOrders) {
      if ((order.id ?? '').isNotEmpty && (order.regionId ?? '').isNotEmpty) {
        orderRegionIds[order.id!] = order.regionId!;
      }
    }

    walletTransactionList.value = await _rowsForStore(ownerRows, storeOrders);
    _computeHeaderTotals();
    _buildCommissions(storeOrders);

    await loadOrderRegions();
    await getPaymentMethod();
    isLoading.value = false;
  }

  void _computeHeaderTotals() {
    taxAmount.value = 0;
    orderAmount.value = 0;
    for (var element in walletTransactionList) {
      if (element.orderId != null) {
        if (element.paymentMethod == "tax") {
          if (element.isTopup == false) {
            taxAmount.value -= double.parse(element.amount.toString());
          } else {
            taxAmount.value += double.parse(element.amount.toString());
          }
        } else {
          if (element.isTopup == false) {
            orderAmount.value -= double.parse(element.amount.toString());
          } else {
            orderAmount.value += double.parse(element.amount.toString());
          }
        }
      }
    }
  }

  /// All orders of the current store, newest first (same query and index as
  /// the Home screen's order list).
  Future<List<OrderModel>> _getStoreOrders() async {
    final vendorId = currentVendorId;
    if (vendorId.isEmpty) return [];
    final List<OrderModel> orders = [];
    try {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).where('vendorID', isEqualTo: vendorId).orderBy('createdAt', descending: true).get();
      for (final doc in snap.docs) {
        try {
          orders.add(OrderModel.fromJson(doc.data()));
        } catch (e) {
          debugPrint('WalletController: skipping unreadable order ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('WalletController: store orders failed: $e');
    }
    return orders;
  }

  /// docId -> `vendorID` for docs of [collection], looked up in chunks of 30.
  /// Docs that don't exist are absent from the result.
  Future<Map<String, String>> _vendorIdsByDocId(String collection, Iterable<String> docIds) async {
    final Map<String, String> result = {};
    final ids = docIds.where((e) => e.isNotEmpty && e != 'null').toSet().toList();
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snap = await FireStoreUtils.fireStore.collection(collection).where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          result[doc.id] = doc.data()['vendorID']?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('WalletController: $collection lookup failed: $e');
      }
    }
    return result;
  }

  /// Narrows the owner's `wallet` rows to the current store:
  /// - order rows: kept when the order is this store's;
  /// - subscription rows: by the `subscription_history` doc's `vendorID`;
  /// - other rows: by a `payouts` doc with the row's id (its `vendorID`).
  /// Rows tied to another store are dropped. Rows whose store can't be
  /// determined are kept and marked as account-level, so nothing silently
  /// disappears.
  Future<List<WalletTransactionModel>> _rowsForStore(List<WalletTransactionModel> rows, List<OrderModel> storeOrders) async {
    final vendorId = currentVendorId;
    final storeOrderIds = storeOrders.map((e) => e.id ?? '').where((e) => e.isNotEmpty).toSet();
    final storePayoutIds = withdrawalList.map((e) => e.id ?? '').where((e) => e.isNotEmpty).toSet();

    bool has(String? v) => v != null && v.isNotEmpty && v != 'null';

    final unknownOrderIds = rows.where((r) => has(r.orderId) && !storeOrderIds.contains(r.orderId)).map((r) => r.orderId!);
    final subscriptionIds = rows.where((r) => !has(r.orderId) && r.subscriptionId.isNotEmpty).map((r) => r.subscriptionId);
    final otherRowIds = rows.where((r) => !has(r.orderId) && r.subscriptionId.isEmpty && has(r.id) && !storePayoutIds.contains(r.id)).map((r) => r.id!);

    final orderVendors = await _vendorIdsByDocId(CollectionName.vendorOrders, unknownOrderIds);
    final subscriptionVendors = await _vendorIdsByDocId(CollectionName.subscriptionHistory, subscriptionIds);
    final payoutVendors = await _vendorIdsByDocId(CollectionName.payouts, otherRowIds);

    final Set<String> account = {};
    final List<WalletTransactionModel> result = [];

    // null = undetermined, true = this store, false = another store.
    bool? belongs(String? ownerVendorId) {
      if (ownerVendorId == null || ownerVendorId.isEmpty) return null;
      return ownerVendorId == vendorId;
    }

    for (final row in rows) {
      bool? mine;
      if (has(row.orderId)) {
        mine = storeOrderIds.contains(row.orderId) ? true : belongs(orderVendors[row.orderId]);
      } else if (row.subscriptionId.isNotEmpty) {
        mine = belongs(subscriptionVendors[row.subscriptionId]);
      } else if (has(row.id)) {
        mine = storePayoutIds.contains(row.id) ? true : belongs(payoutVendors[row.id]);
      }
      if (mine == false) continue;
      if (mine == null && has(row.id)) account.add(row.id!);
      result.add(row);
    }
    accountRowIds
      ..clear()
      ..addAll(account);
    return result;
  }

  void _buildCommissions(List<OrderModel> storeOrders) {
    // What each order actually credited the store, net of reversals, from its
    // vendor rows - so the tab shows real money, not a recomputation that
    // follows today's commission setting.
    final Map<String, double> credited = {};
    for (final row in walletTransactionList) {
      if (row.transactionUser != 'vendor' || (row.orderId ?? '').isEmpty) continue;
      if (row.paymentMethod != 'Wallet' && row.paymentMethod != 'tax') continue;
      credited[row.orderId!] = (credited[row.orderId!] ?? 0) + (row.isTopup ? row.amount : -row.amount);
    }
    final List<OrderCommissionRow> rows = [];
    for (final order in storeOrders) {
      if (order.status != Constant.orderCompleted) continue;
      try {
        final credit = FireStoreUtils.vendorOrderCredit(order);
        rows.add(
          OrderCommissionRow(
            order: order,
            subTotal: credit.subTotal,
            commissionAmount: credit.commissionAmount,
            commissionPercent: credit.adminCommissionPercent,
            commissionApplied: credit.commissionApplied,
            taxAmount: credit.totalTaxAmount,
            storeReceived: credited[order.id] ?? (credit.basePrice + credit.totalTaxAmount),
            storeReceivedFromCredit: credited.containsKey(order.id),
          ),
        );
      } catch (e) {
        debugPrint('WalletController: commission for order ${order.id} failed: $e');
      }
    }
    commissionList.value = rows;
  }

  // ---------------- Period summaries ----------------

  DateTime get periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (selectedPeriod.value) {
      case WalletPeriod.today:
        return today;
      case WalletPeriod.week:
        return today.subtract(Duration(days: today.weekday - DateTime.monday));
      case WalletPeriod.month:
        return DateTime(now.year, now.month);
    }
  }

  bool _inPeriod(Timestamp? ts) => ts != null && !ts.toDate().isBefore(periodStart);

  /// Net order earnings (order amount + tax, less reversals) in the period.
  double get periodEarnings {
    double total = 0;
    for (final row in walletTransactionList) {
      if ((row.orderId ?? '').isEmpty || !_inPeriod(row.date)) continue;
      total += row.isTopup ? row.amount : -row.amount;
    }
    return total;
  }

  int get periodEarningsCount => walletTransactionList.where((r) => (r.orderId ?? '').isNotEmpty && r.paymentMethod != 'tax' && r.isTopup && _inPeriod(r.date)).length;

  List<OrderCommissionRow> get periodCommissionRows => commissionList.where((r) => _inPeriod(r.order.createdAt)).toList();

  double get periodCommission => periodCommissionRows.fold(0.0, (total, r) => total + r.commissionAmount);

  /// The currency the period's orders share, or null (store default) when mixed.
  CurrencyModel? get periodCommissionCurrency {
    final regions = periodCommissionRows.map((r) => r.order.regionId ?? '').toSet();
    return regions.length == 1 ? RegionService.currencyForOrder(regions.first.isEmpty ? null : regions.first) : null;
  }

  CurrencyModel? get periodEarningsCurrency {
    final regions = walletTransactionList.where((r) => (r.orderId ?? '').isNotEmpty && _inPeriod(r.date)).map((r) => orderRegionIds[r.orderId] ?? '').toSet();
    return regions.length == 1 ? RegionService.currencyForOrder(regions.first.isEmpty ? null : regions.first) : null;
  }

  Future<void> loadStore() async {
    final vendorId = userModel.value.vendorID;
    if (vendorId == null || vendorId.isEmpty) return;
    final vendor = await FireStoreUtils.getVendorById(vendorId);
    if (vendor != null) {
      vendorModel.value = vendor;
    }
  }

  Future<void> getPaymentMethod() async {
    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("razorpaySettings").get().then((user) {
      try {
        razorPayModel.value = RazorPayModel.fromJson(user.data() ?? {});
      } catch (e) {
        debugPrint('FireStoreUtils.getUserByID failed to parse user object ${user.id}');
      }
    });

    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("paypalSettings").get().then((paypalData) {
      try {
        paypalDataModel.value = PayPalModel.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("stripeSettings").get().then((paypalData) {
      try {
        stripeSettingData.value = StripeModel.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("flutterWave").get().then((paypalData) {
      try {
        flutterWaveSettingData.value = FlutterWaveModel.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.getWithdrawMethod().then((value) {
      if (value != null) {
        withdrawMethodModel.value = value;
      }
    });
  }
}
