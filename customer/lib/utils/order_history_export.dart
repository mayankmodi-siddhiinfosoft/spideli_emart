import 'package:customer/utils/booking_status_tabs.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/utils/order_receipt_pdf.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The pure rules of "export my order history as a PDF over a period": the
/// period, the table rows, the totals per currency and the file name. No
/// Firestore, no widgets - the loading lives in `order_history_export_service.dart`.

/// Which history screen the export was started from. Each history screen lists
/// one kind of order of the current section, and its export covers exactly
/// what that screen lists.
enum OrderHistoryKind {
  /// `vendor_orders` - food (multivendor) and e-commerce, "My Order".
  shopping,

  /// `rides` - cab and intercity rides, "Ride History".
  rides,

  /// `parcel_orders` - parcels and mail, "Parcel History".
  parcels,

  /// `rental_orders` - car rentals, "Rental History".
  rentals,

  /// `provider_orders` - on-demand service bookings, "Booking History".
  onDemand,
}

/// Why a chosen period cannot be exported.
enum ExportPeriodError { missing, endBeforeStart, tooLong }

/// A span of whole local days, both ends included.
class ExportPeriod {
  /// Local midnight of the first day.
  final DateTime from;

  /// Local midnight of the last day (included).
  final DateTime to;

  const ExportPeriod._(this.from, this.to);

  /// Days are taken in local time; the time of day is ignored. Call
  /// [validate] first: this constructor does not check the span.
  factory ExportPeriod(DateTime from, DateTime to) => ExportPeriod._(dayOf(from), dayOf(to));

  /// The default: the last 30 days, today included.
  factory ExportPeriod.lastDays(DateTime now, {int days = 30}) {
    final DateTime today = dayOf(now);
    return ExportPeriod._(DateTime(today.year, today.month, today.day - (days - 1)), today);
  }

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// First instant of the period (inclusive) - the `createdAt >=` bound.
  DateTime get start => from;

  /// Midnight after the last day (exclusive) - the `createdAt <` bound, so the
  /// whole of the last day counts.
  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);

  bool contains(DateTime? instant) => instant != null && !instant.isBefore(start) && instant.isBefore(endExclusive);

  /// The earliest first day allowed for a period ending on [to]: the same
  /// calendar day one year before. A year is the longest period.
  static DateTime earliestFrom(DateTime to) {
    final DateTime end = dayOf(to);
    return DateTime(end.year - 1, end.month, end.day);
  }

  /// Null when [from] .. [to] can be exported.
  static ExportPeriodError? validate(DateTime? from, DateTime? to) {
    if (from == null || to == null) return ExportPeriodError.missing;
    final DateTime a = dayOf(from);
    final DateTime b = dayOf(to);
    if (b.isBefore(a)) return ExportPeriodError.endBeforeStart;
    if (a.isBefore(earliestFrom(b))) return ExportPeriodError.tooLong;
    return null;
  }

  static String errorMessage(ExportPeriodError error) {
    switch (error) {
      case ExportPeriodError.missing:
        return "Please choose both dates.".tr;
      case ExportPeriodError.endBeforeStart:
        return "The end date must be on or after the start date.".tr;
      case ExportPeriodError.tooLong:
        return "The period cannot be longer than one year.".tr;
    }
  }

  static final DateFormat _fileDay = DateFormat('yyyy-MM-dd', 'en_US');

  /// `orders_2026-09-08_2026-10-07.pdf`.
  String get fileName => 'orders_${_fileDay.format(from)}_${_fileDay.format(to)}.pdf';

  @override
  bool operator ==(Object other) => other is ExportPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// One line of the exported table.
class OrderExportRow {
  final DateTime? createdAt;
  final String orderId;

  /// What was ordered: store and Delivery / TakeAway, ride type, service ...
  final String type;

  /// The order's raw status, as stored (translated when printed).
  final String status;

  /// The order total exactly as the order's own detail screen / receipt
  /// computes it; null when it could not be computed.
  final double? amount;

  /// The order's own currency (its region), null = the app default.
  final CurrencyModel? currency;

  /// Cancelled and rejected orders were never paid for: listed (greyed), but
  /// kept out of the totals. Set by the loader per history screen ([voided]),
  /// so the PDF agrees with the screen's own Cancelled tab; defaults to the
  /// receipts' rule ([OrderReceiptPdf.isVoidedStatus], WEB spec 8).
  final bool isVoided;

  OrderExportRow({required this.createdAt, required this.orderId, required this.type, required this.status, required this.amount, required this.currency, bool? voided})
    : isVoided = voided ?? OrderReceiptPdf.isVoidedStatus(status);
}

/// The total of one currency.
class CurrencyTotal {
  final CurrencyModel? currency;
  final double amount;
  final int orderCount;

  const CurrencyTotal(this.currency, this.amount, this.orderCount);
}

/// The summary printed above the table.
class OrderExportSummary {
  /// Every order in the period, voided ones included.
  final int orderCount;

  /// Cancelled / rejected orders, listed but not totalled.
  final int voidedCount;

  /// Orders whose amount could not be computed (shown as "-").
  final int missingAmountCount;

  /// One entry per currency, in the order the currencies first appear.
  final List<CurrencyTotal> totals;

  const OrderExportSummary({required this.orderCount, required this.voidedCount, required this.missingAmountCount, required this.totals});
}

class OrderHistoryExport {
  OrderHistoryExport._();

  /// Oldest first: a statement reads in the order things happened. Orders
  /// without a date go last; ties keep their incoming order.
  static List<OrderExportRow> sortRows(List<OrderExportRow> rows) {
    final List<MapEntry<int, OrderExportRow>> indexed = [for (int i = 0; i < rows.length; i++) MapEntry(i, rows[i])];
    indexed.sort((a, b) {
      final DateTime? da = a.value.createdAt;
      final DateTime? db = b.value.createdAt;
      if (da == null && db == null) return a.key.compareTo(b.key);
      if (da == null) return 1;
      if (db == null) return -1;
      final int byDate = da.compareTo(db);
      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  /// The statuses the Ride, Parcel and Rental history screens file under
  /// their Cancelled tab ([BookingStatusTabs.cancelled]). "Driver Rejected"
  /// is not one: it sends the booking back to the dispatch Cloud Function,
  /// which offers it to the next driver, so it is still a live booking and is
  /// totalled. "My Order" (shopping) keeps the receipts' rule instead.
  static const Set<String> bookingCancelledStatuses = BookingStatusTabs.cancelled;

  /// The statuses the on-demand "Booking History" files under its Cancelled
  /// tab. `provider_orders` are not dispatched by the Cloud Functions, so a
  /// "Driver Rejected" there is not waiting for another driver: it stays
  /// voided, as that screen lists it.
  static const Set<String> onDemandCancelledStatuses = {Constant.orderRejected, Constant.orderCancelled, Constant.driverRejected};

  /// Whether an order of [kind] with [status] is listed as cancelled by its
  /// history screen - and so left out of the PDF totals.
  static bool isVoided(OrderHistoryKind kind, String? status) {
    switch (kind) {
      case OrderHistoryKind.shopping:
        return OrderReceiptPdf.isVoidedStatus(status);
      case OrderHistoryKind.onDemand:
        return onDemandCancelledStatuses.contains(status);
      case OrderHistoryKind.rides:
      case OrderHistoryKind.parcels:
      case OrderHistoryKind.rentals:
        return bookingCancelledStatuses.contains(status);
    }
  }

  /// Totals are grouped by how the currency prints (code, symbol, decimals,
  /// symbol side), so two regions with separate documents of the same
  /// currency share one "Total (EUR)" line instead of printing it twice.
  static String currencyKey(CurrencyModel? c) {
    if (c == null) return '';
    return '${c.code}|${c.symbol}|${c.decimal}|${c.symbolatright}';
  }

  /// Number of orders and totals per currency. Voided orders and orders
  /// without an amount are counted but never added to a total.
  static OrderExportSummary summarize(List<OrderExportRow> rows) {
    final Map<String, CurrencyModel?> currencies = {};
    final Map<String, double> sums = {};
    final Map<String, int> counts = {};
    int voided = 0;
    int missing = 0;
    for (final OrderExportRow row in rows) {
      if (row.isVoided) {
        voided++;
        continue;
      }
      final double? amount = row.amount;
      if (amount == null || amount.isNaN) {
        missing++;
        continue;
      }
      final String key = currencyKey(row.currency);
      currencies.putIfAbsent(key, () => row.currency);
      sums[key] = (sums[key] ?? 0) + amount;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return OrderExportSummary(
      orderCount: rows.length,
      voidedCount: voided,
      missingAmountCount: missing,
      totals: [for (final key in currencies.keys) CurrencyTotal(currencies[key], sums[key]!, counts[key]!)],
    );
  }

  /// The last 8 characters of an order id, "#"-prefixed - enough to find the
  /// order again in the app.
  static String shortId(String id) {
    final String trimmed = id.trim();
    if (trimmed.isEmpty) return '-';
    return '#${trimmed.length <= 8 ? trimmed : trimmed.substring(trimmed.length - 8)}';
  }

  /// The standard PDF fonts only encode Latin-1. [preferred] when it can be
  /// printed, else [fallback] (the English source of the translation).
  static bool isPrintable(String s) => s.runes.every((r) => r <= 0xFF);

  static String printable(String preferred, String fallback) => isPrintable(preferred) ? preferred : fallback;

  /// A translated label for the PDF: the translation when the PDF font can
  /// draw it, else the English key (Arabic does not render with the PDF's
  /// standard fonts).
  static String label(String key) => printable(key.tr, key);

  /// An amount in [currency] as the app shows it ([Constant.amountShow], via
  /// the receipts' Latin-1-safe formatter). "-" when there is no amount.
  static String money(double? amount, CurrencyModel? currency) {
    if (amount == null || amount.isNaN) return '-';
    final CurrencyModel? c = currency ?? Constant.currencyModel;
    if (c == null) return amount.toStringAsFixed(2);
    return OrderReceiptPdf.pdfMoney(amount, c);
  }
}
