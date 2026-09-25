import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/screen_ui/subscriptions/my_plan_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// What the customer is allowed to see of their own order history: the free
/// limit of WEB spec 6 and the period picker of WEB spec 9, read together so
/// the two can never disagree.
class OrderHistoryAccess {
  /// Newest orders visible PER TAB; null = every order.
  final int? limit;

  /// Whether the period picker (WEB spec 9) is offered. Entitled customers
  /// only: offering it under the free allowance would let the customer step
  /// through the whole history [limit] orders at a time.
  final bool canChoosePeriod;

  const OrderHistoryAccess({required this.limit, required this.canChoosePeriod});

  /// Full history: no limit, picker offered.
  static const OrderHistoryAccess full = OrderHistoryAccess(limit: null, canChoosePeriod: true);
}

/// Free order-history limit (spec 7.7 / 18.9 / 18.10; WEB spec 6).
///
/// `settings/OrderHistory { isLimitEnabled, freeOrderLimit }`; a missing
/// document means `{ true, 5 }`. Customers with an active customer plan
/// (`subscription_plan.planFor == "customer"`, not expired,
/// `features.fullOrderHistory == true`) see everything.
///
/// The limit is applied **PER TAB** - each tab of the order screen shows its
/// own newest [OrderHistoryAccess.limit] orders. Capping the combined list
/// leaves tabs empty, which reads as a fault rather than a limit (client
/// decision, 24 Sep; WEB spec 6).
///
/// SCOPE: use this ONLY in the customer's own order-history screens. It must
/// never move into FireStoreUtils or any shared data layer.
class OrderHistoryLimit {
  OrderHistoryLimit._();

  static const int defaultFreeOrderLimit = 5;

  /// How many of the newest orders the customer may see; null = all.
  static Future<int?> visibleCount() async => (await access()).limit;

  /// One read of `settings/OrderHistory` + the user document, answering both
  /// the free limit (WEB spec 6) and whether the period picker is offered
  /// (WEB spec 9).
  ///
  /// The picker **fails open**: a customer is never shut out of their own
  /// orders because a lookup errored. The limit keeps failing to the
  /// documented default, as it always has.
  static Future<OrderHistoryAccess> access() async {
    try {
      final db = FireStoreUtils.fireStore;
      final results = await Future.wait([
        db.collection(CollectionName.settings).doc('OrderHistory').get(),
        db.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).get(),
      ]);
      if (hasFullHistory(results[1].data())) return OrderHistoryAccess.full;
      final settings = results[0].data();
      if (settings == null) return const OrderHistoryAccess(limit: defaultFreeOrderLimit, canChoosePeriod: false);
      // Nobody is limited: the picker cannot defeat a limit that is off.
      if (settings['isLimitEnabled'] == false) return OrderHistoryAccess.full;
      final dynamic raw = settings['freeOrderLimit'];
      final int? limit = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      if (limit == null || limit < 0) return const OrderHistoryAccess(limit: defaultFreeOrderLimit, canChoosePeriod: false);
      return OrderHistoryAccess(limit: limit, canChoosePeriod: false);
    } catch (e) {
      log("OrderHistoryLimit: $e");
      // Could not read the setting: apply the documented default, and offer
      // the picker rather than shut the customer out (WEB spec 9).
      return const OrderHistoryAccess(limit: defaultFreeOrderLimit, canChoosePeriod: true);
    }
  }

  /// `hasFullHistory(customer)` from spec 18.10, on the raw user document so a
  /// customer plan snapshot of any shape is read tolerantly.
  static bool hasFullHistory(Map<String, dynamic>? user) {
    final dynamic plan = user?['subscription_plan'];
    if (plan is! Map || plan['planFor'] != 'customer') return false; // a vendor plan never counts
    final dynamic expiry = user?['subscriptionExpiryDate'];
    if (expiry is Timestamp && expiry.toDate().isBefore(DateTime.now())) return false;
    final dynamic features = plan['features'];
    return features is Map && features['fullOrderHistory'] == true;
  }

  /// The newest [limit] items of [items] (sorted newest first by [createdAt]).
  static List<T> newest<T>(List<T> items, int? limit, Timestamp? Function(T) createdAt) {
    if (limit == null || items.length <= limit) return items;
    final sorted = [...items]..sort((a, b) {
      final ta = createdAt(a);
      final tb = createdAt(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return sorted.take(limit).toList();
  }

  /// The months [items] actually have orders in, newest first - an empty month
  /// can never be offered (WEB spec 9). Each entry is the first day of that
  /// month at midnight; items without a usable `createdAt` contribute none.
  static List<DateTime> monthsOf<T>(List<T> items, Timestamp? Function(T) createdAt) {
    final Set<int> seen = {};
    final List<DateTime> months = [];
    for (final item in items) {
      final DateTime? date = createdAt(item)?.toDate();
      if (date == null) continue;
      final int key = date.year * 100 + date.month;
      if (seen.add(key)) months.add(DateTime(date.year, date.month));
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }
}

/// Which period of their history the customer chose to look at (WEB spec 9).
enum HistoryPeriodMode { all, month, range }

/// A period of order history. Entirely client side: it narrows orders that
/// are already in memory, never a new query.
///
/// An order with **no usable `createdAt` is kept, not dropped** - hiding a
/// customer's own order because its timestamp is odd reads as lost data.
class HistoryPeriod {
  final HistoryPeriodMode mode;

  /// First day of the chosen month, for [HistoryPeriodMode.month].
  final DateTime? month;

  /// Inclusive span ends, for [HistoryPeriodMode.range]. Either end alone is
  /// valid ("since March", "up to March").
  final DateTime? from;
  final DateTime? to;

  const HistoryPeriod._(this.mode, {this.month, this.from, this.to});

  /// The default: everything the query returned.
  const HistoryPeriod.all() : this._(HistoryPeriodMode.all);

  /// One month, given any day inside it.
  HistoryPeriod.month(DateTime day) : this._(HistoryPeriodMode.month, month: DateTime(day.year, day.month));

  /// A span with both ends inclusive; a span with neither end is "all time".
  factory HistoryPeriod.range({DateTime? from, DateTime? to}) {
    if (from == null && to == null) return const HistoryPeriod.all();
    DateTime? start = from == null ? null : DateTime(from.year, from.month, from.day);
    DateTime? end = to == null ? null : DateTime(to.year, to.month, to.day);
    // A span typed back to front still means the days between the two.
    if (start != null && end != null && end.isBefore(start)) {
      final DateTime swap = start;
      start = end;
      end = swap;
    }
    return HistoryPeriod._(HistoryPeriodMode.range, from: start, to: end);
  }

  bool get isAll => mode == HistoryPeriodMode.all;

  /// Whether an order created at [createdAt] falls in this period. A missing
  /// or unreadable timestamp is always kept.
  bool contains(Timestamp? createdAt) {
    if (mode == HistoryPeriodMode.all) return true;
    final DateTime? date = createdAt?.toDate();
    if (date == null) return true;
    if (mode == HistoryPeriodMode.month) {
      final DateTime? m = month;
      return m != null && date.year == m.year && date.month == m.month;
    }
    if (from != null && date.isBefore(from!)) return false;
    // Inclusive: the whole of the last day counts.
    if (to != null && !date.isBefore(to!.add(const Duration(days: 1)))) return false;
    return true;
  }

  /// Short label for the picker button.
  String label() {
    switch (mode) {
      case HistoryPeriodMode.all:
        return "All time".tr;
      case HistoryPeriodMode.month:
        return month == null ? "All time".tr : monthLabel(month!);
      case HistoryPeriodMode.range:
        final String a = from == null ? '' : _day(from!);
        final String b = to == null ? '' : _day(to!);
        if (a.isEmpty && b.isEmpty) return "All time".tr;
        if (a.isEmpty) return "${"Up to".tr} $b";
        if (b.isEmpty) return "${"Since".tr} $a";
        return "$a - $b";
    }
  }

  /// "September 2026". The month name comes from the device locale.
  static String monthLabel(DateTime month) => DateFormat.yMMMM().format(month);

  /// "Sep 24, 2026".
  static String dayLabel(DateTime day) => DateFormat.yMMMd().format(day);

  static String _day(DateTime day) => dayLabel(day);

  @override
  bool operator ==(Object other) =>
      other is HistoryPeriod && other.mode == mode && other.month == month && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(mode, month, from, to);
}

/// "See older orders" prompt shown under a limited history. Opens "My plan"
/// where the customer can buy the full-history plan (spec 4.6); when they
/// come back, [onReturn] reloads the history so a new plan shows everything.
class OlderOrdersPrompt extends StatelessWidget {
  final int hiddenCount;
  final bool isDark;
  final VoidCallback? onReturn;

  const OlderOrdersPrompt({super.key, required this.hiddenCount, required this.isDark, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return DsCard.tinted(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: Icons.history_toggle_off_rounded, tone: DsTone.brand, size: 40),
              const DsGap(DsSpace.md),
              Expanded(child: Text("See older orders".tr, style: DsTypography.titleSm.copyWith(color: c.textPrimary))),
            ],
          ),
          const DsGap(DsSpace.sm),
          Text(
            "${"Older orders hidden:".tr} $hiddenCount. ${"Subscribe to a monthly or annual plan to view your complete order history.".tr}",
            style: DsTypography.bodySm.copyWith(color: c.textSecondary),
          ),
          const DsGap(DsSpace.md),
          DsButton.primary(
            label: "See plans".tr,
            icon: Icons.workspace_premium_outlined,
            expand: true,
            onPressed: () async {
              await Get.to(() => const MyPlanScreen());
              onReturn?.call();
            },
          ),
        ],
      ),
    );
  }
}
