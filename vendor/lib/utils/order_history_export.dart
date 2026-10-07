import 'dart:async';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/order_model.dart';

/// Pure parts of "Export PDF" of the store's order history: the period
/// rules, the table rows and the summary. No Firestore and no UI here, so
/// all of it is unit tested (test/order_history_export_test.dart).

/// Why a period cannot be exported.
enum OrderExportRangeError { missingDates, endBeforeStart, tooLong }

/// A period of whole local days, both ends included.
class OrderExportRange {
  /// First day (local midnight).
  final DateTime from;

  /// Last day, included (local midnight).
  final DateTime to;

  OrderExportRange(DateTime from, DateTime to) : from = _day(from), to = _day(to);

  /// The default period: the last [days] days, today included.
  factory OrderExportRange.lastDays(DateTime now, {int days = 30}) {
    final DateTime today = _day(now);
    return OrderExportRange(DateTime(today.year, today.month, today.day - (days - 1)), today);
  }

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  /// Null when [from] .. [to] can be exported: both set, [to] on or after
  /// [from], and no longer than one year ([to] before the same calendar day
  /// one year after [from]: 8 Oct 2025 - 7 Oct 2026 is allowed, 7 Oct 2025 -
  /// 7 Oct 2026 is not).
  static OrderExportRangeError? check(DateTime? from, DateTime? to) {
    if (from == null || to == null) return OrderExportRangeError.missingDates;
    final DateTime start = _day(from);
    final DateTime end = _day(to);
    if (end.isBefore(start)) return OrderExportRangeError.endBeforeStart;
    if (!end.isBefore(DateTime(start.year + 1, start.month, start.day))) return OrderExportRangeError.tooLong;
    return null;
  }

  /// The message shown for [error] (translation key).
  static String messageOf(OrderExportRangeError error) => switch (error) {
    OrderExportRangeError.missingDates => "Please choose the first and the last day of the period.",
    OrderExportRangeError.endBeforeStart => "The end date must be on or after the start date.",
    OrderExportRangeError.tooLong => "The period cannot be longer than one year.",
  };

  /// Inclusive lower bound of `createdAt` (local midnight of [from]).
  DateTime get start => from;

  /// Exclusive upper bound of `createdAt`: local midnight after [to].
  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);

  /// True when [time] falls inside the period.
  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(endExclusive);

  /// Number of days in the period, both ends included (DST safe).
  int get dayCount => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays + 1;

  /// `orders_2026-09-08_2026-10-07.pdf`.
  String get fileName => 'orders_${ymd(from)}_${ymd(to)}.pdf';

  /// `2026-09-08`, always in Western digits whatever the app language.
  static String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// `08/09/2026`.
  static String dmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year.toString().padLeft(4, '0')}';

  /// `08/09/2026 14:05`.
  static String dmyHm(DateTime d) => '${dmy(d)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) => other is OrderExportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// One line of the exported table.
class OrderExportRow {
  final String orderId;
  final DateTime createdAt;
  final bool takeAway;

  /// Raw status, as stored (translated when printed, like the order card).
  final String status;

  /// The order's total, or null when it could not be computed.
  final double? amount;

  /// The currency the order was charged in.
  final CurrencyModel? currency;

  const OrderExportRow({required this.orderId, required this.createdAt, required this.takeAway, required this.status, required this.amount, required this.currency});

  /// Short id as the order card shows it ([Constant.orderId]), safe for a
  /// short id.
  String get shortId => orderId.length >= 10 ? Constant.orderId(orderId: orderId) : '#$orderId';

  /// Cancelled and rejected orders are listed but not added to the totals.
  bool get countsInTotal => !OrderExportSummary.excludedStatuses.contains(status);

  /// Groups the totals: one total per currency.
  String get currencyKey => currencyKeyOf(currency);

  static String currencyKeyOf(CurrencyModel? currency) {
    final String code = (currency?.code ?? '').trim();
    if (code.isNotEmpty) return code.toUpperCase();
    return (currency?.symbol ?? '').trim();
  }
}

/// The sum of one currency's orders.
class OrderExportCurrencyTotal {
  final String key;
  final CurrencyModel? currency;
  final double amount;
  final int orders;

  const OrderExportCurrencyTotal({required this.key, required this.currency, required this.amount, required this.orders});
}

/// Header figures of the export.
class OrderExportSummary {
  /// Statuses listed in the table but left out of the totals.
  static const Set<String> excludedStatuses = {Constant.orderCancelled, Constant.orderRejected};

  /// Every order in the period.
  final int orderCount;

  /// Cancelled or rejected (not in the totals).
  final int excludedCount;

  /// Orders whose total could not be computed (shown as "-", not in the totals).
  final int unpricedCount;

  /// One total per currency, in the order the currencies first appear.
  final List<OrderExportCurrencyTotal> totals;

  const OrderExportSummary({required this.orderCount, required this.excludedCount, required this.unpricedCount, required this.totals});

  /// Each amount is rounded to its currency's decimals before it is added, so
  /// the total matches the sum of the amounts printed in the table.
  factory OrderExportSummary.of(List<OrderExportRow> rows) {
    final Map<String, double> sums = {};
    final Map<String, int> counts = {};
    final Map<String, CurrencyModel?> currencies = {};
    int excluded = 0;
    int unpriced = 0;
    for (final OrderExportRow row in rows) {
      if (!row.countsInTotal) {
        excluded++;
        continue;
      }
      final double? amount = row.amount;
      if (amount == null) {
        unpriced++;
        continue;
      }
      final String key = row.currencyKey;
      currencies.putIfAbsent(key, () => row.currency);
      sums[key] = (sums[key] ?? 0) + roundTo(amount, row.currency?.decimalDigits ?? Constant.currencyModel?.decimalDigits ?? 2);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return OrderExportSummary(
      orderCount: rows.length,
      excludedCount: excluded,
      unpricedCount: unpriced,
      totals: [
        for (final String key in sums.keys)
          OrderExportCurrencyTotal(key: key, currency: currencies[key], amount: roundTo(sums[key]!, currencies[key]?.decimalDigits ?? Constant.currencyModel?.decimalDigits ?? 2), orders: counts[key]!),
      ],
    );
  }

  /// Rounds the way the table prints ([Constant.amountShow] uses
  /// `toStringAsFixed`), so a total always equals the sum of its printed rows.
  static double roundTo(double value, int decimals) {
    if (!value.isFinite) return value;
    return double.parse(value.toStringAsFixed(decimals.clamp(0, 20)));
  }
}

/// Turns loaded orders into table rows.
class OrderHistoryExport {
  OrderHistoryExport._();

  /// The order's total exactly as the order card shows it ("Total Amount",
  /// `home_screen.dart` newOrderWidget / acceptedWidget /
  /// completedAndRejectedWidget): the card's own formula, step for step, and
  /// only the fields it reads - so a field the card does not need (delivery
  /// charge, tip, platform fee, a packaging charge with packaging off) can
  /// never leave the PDF without an amount the card still shows. Null
  /// (logged) when the order is too malformed to price - the card could not
  /// show it either.
  static double? storeTotalOf(OrderModel order) {
    try {
      double subTotal = 0.0;
      double specialDiscountAmount = 0.0;
      double productTaxAmount = 0.0;
      double orderTaxAmount = 0.0;
      double packagingTaxAmount = 0.0;

      for (var element in order.products!) {
        final double price = element.unitPrice;
        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());
        subTotal += (price * qty) + (extras * qty);
      }

      final double couponAmount = double.parse(order.discount.toString());
      if (order.specialDiscount != null && order.specialDiscount!['special_discount'] != null) {
        specialDiscountAmount = double.parse(order.specialDiscount!['special_discount'].toString());
      }
      final double totalDiscount = couponAmount + specialDiscountAmount;

      double discountRatio = 0.0;
      if (subTotal > 0 && totalDiscount > 0) {
        discountRatio = totalDiscount / subTotal;
      }

      if (order.taxScope == "product") {
        for (var element in order.products!) {
          final double price = element.unitPrice;
          final double qty = double.parse(element.quantity.toString());
          final double extras = double.parse(element.extrasPrice.toString());
          final double itemAmount = (price * qty) + (extras * qty);
          final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);
          for (var taxElement in element.taxSetting!) {
            if (taxElement.type == "fix") {
              productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
            } else {
              productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
            }
          }
        }
      }

      if (order.taxScope == "order") {
        for (var taxElement in order.taxSetting ?? []) {
          orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
        }
      }

      final double packagingCharge = order.packagingChargeEnable == true ? double.parse(order.vendor!.packagingCharge.toString()) : 0.0;
      if (packagingCharge > 0) {
        for (var taxElement in order.packagingTax ?? []) {
          packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
        }
      }

      final double totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;
      return (subTotal - totalDiscount) + totalTaxAmount + packagingCharge;
    } catch (e) {
      log("Order ${order.id} could not be priced for the export: $e");
      return null;
    }
  }

  /// Rows of [orders] created inside [range], oldest first, one per order id.
  /// Orders without a creation time are left out (they cannot be placed in a
  /// period, and the range query never returns them).
  static Future<List<OrderExportRow>> buildRows(
    List<OrderModel> orders, {
    required OrderExportRange range,
    required FutureOr<double?> Function(OrderModel order) amountOf,
    required CurrencyModel? Function(String? regionId) currencyOf,
  }) async {
    final Set<String> seen = {};
    final List<OrderExportRow> rows = [];
    for (final OrderModel order in orders) {
      final DateTime? createdAt = order.createdAt?.toDate();
      if (createdAt == null || !range.contains(createdAt)) continue;
      final String id = order.id ?? '';
      if (id.isNotEmpty && !seen.add(id)) continue;
      rows.add(
        OrderExportRow(
          orderId: id,
          createdAt: createdAt,
          takeAway: order.takeAway == true,
          status: order.status ?? '',
          amount: await amountOf(order),
          currency: currencyOf(order.regionId),
        ),
      );
    }
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows;
  }

  /// Label of the order type, as the receipt words it.
  static String typeLabel(OrderExportRow row) => row.takeAway ? 'Takeaway'.tr : 'Deliver to door'.tr;
}
