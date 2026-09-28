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
  /// Newest orders visible ACROSS THE WHOLE HISTORY - of any kind, whichever
  /// tab they would sit in; null = every order (WEB spec 6, 28 Sep).
  final int? limit;

  /// Whether the period picker (WEB spec 9) is offered. Entitled customers
  /// only: offering it under the free allowance would let the customer step
  /// through the whole history [limit] orders at a time.
  final bool canChoosePeriod;

  const OrderHistoryAccess({required this.limit, required this.canChoosePeriod});

  /// Full history: no limit, picker offered.
  static const OrderHistoryAccess full = OrderHistoryAccess(limit: null, canChoosePeriod: true);
}

/// The single whole-history decision of WEB spec 6, taken once per render
/// before any tab is built. Every tab of the order screen is a view of this
/// one object, so the tabs can never disagree about what the customer may see.
class FreeOrderAllowance<T> {
  /// What the customer may see, newest first.
  final List<T> visible;

  /// How many orders the allowance ACTUALLY hid. `0` means nothing was hidden
  /// and the "see older orders" notice must not appear - eight orders under an
  /// allowance of eight hide nothing; the ninth is what hides one.
  final int hiddenCount;

  final Timestamp? Function(T) _createdAt;

  const FreeOrderAllowance._(this.visible, this.hiddenCount, this._createdAt);

  /// Whether the allowance hid anything, i.e. whether the notice is due.
  bool get hidSomething => hiddenCount > 0;

  /// The period picker of WEB spec 9, applied **in the same funnel and after
  /// the allowance** - the allowance settles what the customer may see, the
  /// period only narrows what they chose to look at. Applying it the other way
  /// round would let a customer on the free allowance step through their whole
  /// history a period at a time, which defeats WEB spec 6.
  ///
  /// [hiddenCount] is carried through unchanged: the notice reports what the
  /// allowance hid, never what the customer's own choice of period left out.
  FreeOrderAllowance<T> inPeriod(HistoryPeriod period) =>
      period.isAll ? this : FreeOrderAllowance<T>._(visible.where((T item) => period.contains(_createdAt(item))).toList(), hiddenCount, _createdAt);
}

/// Free order-history limit (spec 7.7 / 18.9 / 18.10; WEB spec 6).
///
/// `settings/OrderHistory { isLimitEnabled, freeOrderLimit }`; a missing
/// document means `{ true, 5 }`. Customers with an active customer plan
/// (`subscription_plan.planFor == "customer"`, not expired,
/// `features.fullOrderHistory == true`) see everything.
///
/// The limit is applied **ACROSS THE WHOLE HISTORY** (client decision, 28 Sep,
/// replacing the per-tab rule of 24 Sep): the customer sees their most recent
/// [OrderHistoryAccess.limit] orders of any kind and everything older is
/// hidden, whichever tab it would appear in. The allowance is worked out once
/// per render by [OrderHistoryLimit.applyFreeOrderAllowance], before any tab is
/// built, and [OrderHistoryLimit.limitOrderHistory] then only narrows a tab to
/// its own statuses *within* what the allowance permits. **A tab can therefore
/// be empty while orders of that kind exist**, because newer orders in other
/// tabs used the allowance up - that is the rule, not a fault.
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

  /// [items] newest first by [createdAt]. Ties - and items with no usable
  /// timestamp, which sort last - keep the order the query returned them in,
  /// so a render never reshuffles the list it drew a moment ago.
  static List<T> newestFirst<T>(List<T> items, Timestamp? Function(T) createdAt) {
    final List<MapEntry<int, T>> indexed = [for (int i = 0; i < items.length; i++) MapEntry(i, items[i])];
    indexed.sort((a, b) {
      final Timestamp? ta = createdAt(a.value);
      final Timestamp? tb = createdAt(b.value);
      if (ta == null && tb == null) return a.key.compareTo(b.key);
      if (ta == null) return 1;
      if (tb == null) return -1;
      final int byDate = tb.compareTo(ta);
      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  /// **The one decision of WEB spec 6**, taken once per render before any tab
  /// is built: the newest [limit] of [items] across the WHOLE history, of any
  /// kind. `null` [limit] means the customer is entitled to everything.
  ///
  /// [keepAlways] is the app's one safeguard (not in the web spec, reported to
  /// the panel team): an order matching it is never hidden however old, so a
  /// customer tracking a live delivery cannot lose sight of it. It still
  /// *counts* against the allowance like any other order - the deviation is
  /// only that it is shown rather than hidden.
  ///
  /// [FreeOrderAllowance.hiddenCount] is what the allowance actually hid, so
  /// the "see older orders" notice appears on the ninth order rather than
  /// merely on having eight.
  static FreeOrderAllowance<T> applyFreeOrderAllowance<T>(
    List<T> items,
    int? limit,
    Timestamp? Function(T) createdAt, {
    bool Function(T)? keepAlways,
  }) {
    final List<T> sorted = newestFirst(items, createdAt);
    if (limit == null || sorted.length <= limit) return FreeOrderAllowance<T>._(sorted, 0, createdAt);
    final List<T> allowed = sorted.take(limit).toList();
    final List<T> older = sorted.skip(limit).toList();
    final List<T> kept = keepAlways == null ? const [] : older.where(keepAlways).toList();
    final List<T> visible = kept.isEmpty ? allowed : newestFirst([...allowed, ...kept], createdAt);
    return FreeOrderAllowance<T>._(visible, older.length - kept.length, createdAt);
  }

  /// Narrows one tab to its own statuses **within what the allowance permits**.
  /// It never reaches past [allowance]; a tab that comes back empty while
  /// orders of that kind exist is the whole-history rule doing its job.
  static List<T> limitOrderHistory<T>(FreeOrderAllowance<T> allowance, bool Function(T) matches) =>
      allowance.visible.where(matches).toList();

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

/// "See older orders" prompt shown under a limited history. There is exactly
/// ONE of these - the allowance is one whole-history decision, so it sits above
/// the tabs where the customer meets it on whichever tab they are on, including
/// a tab the allowance left empty (WEB spec 6, 28 Sep).
///
/// It appears only when the allowance actually hid something. Opens "My plan"
/// where the customer can buy the full-history plan (spec 4.6); when they
/// come back, [onReturn] reloads the history so a new plan shows everything.
class OlderOrdersPrompt extends StatelessWidget {
  final int hiddenCount;
  final bool isDark;
  final VoidCallback? onReturn;

  /// Defaults to the in-list spacing; the order screen sits it above the tabs
  /// and supplies its own.
  final EdgeInsetsGeometry? margin;

  const OlderOrdersPrompt({super.key, required this.hiddenCount, required this.isDark, this.onReturn, this.margin});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return DsCard.tinted(
      margin: margin ?? const EdgeInsets.only(bottom: DsSpace.md),
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
