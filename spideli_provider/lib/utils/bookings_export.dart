// Pure parts of the "Export PDF" of the booking history: the date-range rules,
// the rows (one per booking) and the totals per currency, and the file name.
// No Firestore, no PDF and no widgets here, so all of it is unit-tested.

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/utils/booking_receipt_pdf.dart';
import 'package:spideliprovider/widgets/order_ui.dart';

/// Every status the five booking-list tabs show (New Booking, Today,
/// Upcoming, Completed, Cancelled). A booking in any other status appears in
/// no tab, so it is not exported either.
const List<String> exportedBookingStatuses = [
  ORDER_STATUS_PLACED,
  ORDER_STATUS_ACCEPTED,
  ORDER_STATUS_ASSIGNED,
  ORDER_STATUS_ONGOING,
  ORDER_STATUS_COMPLETED,
  ORDER_STATUS_REJECTED,
  ORDER_STATUS_CANCELLED,
];

/// Why a chosen period cannot be exported.
enum ExportRangeError { toBeforeFrom, tooLong }

/// A period of whole local days, both ends included.
class ExportRange {
  /// First day (time of day ignored).
  final DateTime from;

  /// Last day, included (time of day ignored).
  final DateTime to;

  ExportRange(DateTime from, DateTime to)
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  /// Default period: the last [days] days, today included.
  factory ExportRange.lastDays(DateTime now, {int days = 30}) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    return ExportRange(DateTime(today.year, today.month, today.day - (days - 1)), today);
  }

  /// Start of [from] (local midnight), included.
  DateTime get start => from;

  /// Start of the day after [to] (local midnight), excluded. Calendar
  /// arithmetic, so a DST change inside the period moves nothing.
  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);

  /// The first day that is too late for [to]: one year after [from].
  DateTime get maxEndExclusive => DateTime(from.year + 1, from.month, from.day);

  /// Null when the period can be exported.
  ExportRangeError? validate() {
    if (to.isBefore(from)) return ExportRangeError.toBeforeFrom;
    if (!to.isBefore(maxEndExclusive)) return ExportRangeError.tooLong;
    return null;
  }

  bool contains(DateTime moment) => !moment.isBefore(start) && moment.isBefore(endExclusive);

  /// Translated message of [error] (en/ar keys in lib/lang).
  static String message(ExportRangeError error) => switch (error) {
        ExportRangeError.toBeforeFrom => 'The end date must be on or after the start date.'.tr,
        ExportRangeError.tooLong => 'The period cannot be longer than one year.'.tr,
      };

  /// `orders_<from>_<to>.pdf`, dates as yyyy-MM-dd.
  String get fileName {
    final DateFormat f = DateFormat('yyyy-MM-dd');
    return 'orders_${f.format(from)}_${f.format(to)}.pdf';
  }
}

/// The status label the booking list shows on its chips (`_statusChip`),
/// with "Completed" (the tab name) for a completed booking.
String bookingStatusLabel(String status) {
  switch (status) {
    case ORDER_STATUS_PLACED:
      return 'Pending'.tr;
    case ORDER_STATUS_ACCEPTED:
    case ORDER_STATUS_ASSIGNED:
      return 'Accepted'.tr;
    case ORDER_STATUS_ONGOING:
      return 'On Going'.tr;
    case ORDER_STATUS_COMPLETED:
      return 'Completed'.tr;
    case ORDER_STATUS_REJECTED:
      return 'Rejected'.tr;
    case ORDER_STATUS_CANCELLED:
      return 'Cancelled'.tr;
    default:
      return status.tr;
  }
}

/// One line of the exported table.
class BookingExportRow {
  final DateTime createdAt;
  final String id;
  final String shortId;
  final String service;
  final bool hourly;
  final String status;
  final String statusLabel;

  /// The booking total as the booking details screen shows it
  /// ([BookingTotals.grandTotal]: price x quantity - discount + taxes + extra charges).
  final double amount;
  final CurrencyModel? currency;

  const BookingExportRow({
    required this.createdAt,
    required this.id,
    required this.shortId,
    required this.service,
    required this.hourly,
    required this.status,
    required this.statusLabel,
    required this.amount,
    required this.currency,
  });

  String get currencyKey => currencyKeyOf(currency);
}

/// Sum of one currency's bookings.
class CurrencyTotal {
  final String key;
  final CurrencyModel? currency;
  final int count;
  final double amount;

  const CurrencyTotal(this.key, this.currency, this.count, this.amount);
}

/// Groups amounts by currency code (symbol when a currency has no code).
String currencyKeyOf(CurrencyModel? currency) {
  final String code = (currency?.code ?? '').trim();
  if (code.isNotEmpty) return code.toUpperCase();
  return (currency?.symbol ?? '').trim();
}

/// Rows of [orders] created inside [range], oldest first. [currencyFor]
/// resolves a booking's currency (the app passes
/// `RegionService.currencyForBooking`); a test passes its own.
List<BookingExportRow> buildBookingExportRows(
  Iterable<OnProviderOrderModel> orders,
  ExportRange range, {
  required CurrencyModel? Function(String? regionId) currencyFor,
}) {
  final List<BookingExportRow> rows = [];
  for (final OnProviderOrderModel order in orders) {
    final DateTime created = order.createdAt.toDate();
    if (!range.contains(created)) continue;
    rows.add(BookingExportRow(
      createdAt: created,
      id: order.id,
      shortId: shortBookingId(order.id),
      service: (order.provider.title ?? '').trim(),
      hourly: order.provider.priceUnit != null && order.provider.priceUnit != 'Fixed',
      status: order.status,
      statusLabel: bookingStatusLabel(order.status),
      amount: BookingTotals.of(order).grandTotal,
      currency: currencyFor(order.regionId),
    ));
  }
  rows.sort((a, b) {
    final int byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  return rows;
}

/// Totals per currency, in the order each currency first appears. Each row
/// is rounded to its currency's decimals first, so a total is exactly the sum
/// of the amounts printed above it.
List<CurrencyTotal> totalsPerCurrency(Iterable<BookingExportRow> rows) {
  final Map<String, CurrencyTotal> totals = {};
  for (final BookingExportRow row in rows) {
    final String key = row.currencyKey;
    final CurrencyTotal? current = totals[key];
    final double rounded = roundToCurrency(row.amount, row.currency);
    totals[key] = CurrencyTotal(
      key,
      current?.currency ?? row.currency,
      (current?.count ?? 0) + 1,
      roundToCurrency((current?.amount ?? 0) + rounded, row.currency),
    );
  }
  return totals.values.toList();
}

/// [value] rounded like [amountShow] prints it (the currency's decimals,
/// 2 when unknown).
double roundToCurrency(double value, CurrencyModel? currency) {
  final int decimals = currency?.decimal ?? 2;
  return double.parse(value.toStringAsFixed(decimals < 0 ? 0 : decimals));
}
