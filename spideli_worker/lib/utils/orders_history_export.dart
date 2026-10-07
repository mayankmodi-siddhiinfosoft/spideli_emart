import 'package:intl/intl.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/currency_model.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/utils/booking_amount.dart';
import 'package:spideliworker/widgets/order_ui.dart' show shortBookingId;

/// Pure rules of the "Export PDF" of the worker's booking history: the
/// period, the rows, the totals per currency and the file name. No Firebase,
/// no widgets - unit tested in test/orders_history_export_test.dart.
///
/// The bookings exported are the ones the Jobs screen lists: the worker's
/// `provider_orders` (`workerId` == the worker) in the statuses of its three
/// tabs (Assigned, In progress, Completed).
class OrdersHistoryExport {
  OrdersHistoryExport._();

  /// Statuses of the Jobs tabs, in tab order (Assigned | In progress |
  /// Completed). Cancelled / rejected / placed bookings are not on that
  /// screen, so they are not exported either.
  static const List<String> statuses = [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED, ORDER_STATUS_ONGOING, ORDER_STATUS_COMPLETED];

  /// The statuses the Jobs screen actually shows to this worker: a worker
  /// whose documents are not approved ([canReceiveJobs] false) sees only the
  /// Completed tab - the Assigned and In progress tabs are hidden behind the
  /// verification card - so the export must not list active jobs either.
  static List<String> statusesFor({required bool canReceiveJobs}) => canReceiveJobs ? statuses : const [ORDER_STATUS_COMPLETED];

  /// Default period length, in days (today included).
  static const int defaultDays = 30;

  // ---------------- period ----------------

  /// Local midnight of [value]'s day.
  static DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

  /// The default period: the last [defaultDays] days, today included.
  static ExportPeriod defaultPeriod(DateTime now) {
    final DateTime today = day(now);
    return ExportPeriod(DateTime(today.year, today.month, today.day - (defaultDays - 1)), today);
  }

  /// The latest allowed end date for a period starting on [from]: one year
  /// minus one day later (e.g. 1 Jan 2025 -> 31 Dec 2025).
  static DateTime maxTo(DateTime from) {
    final DateTime start = day(from);
    return DateTime(start.year + 1, start.month, start.day - 1);
  }

  /// Validation message key (to be translated with `.tr`), or null when the
  /// period is valid. Dates are whole local days, both ends inclusive.
  static String? validate(DateTime? from, DateTime? to) {
    if (from == null || to == null) return msgChooseDates;
    final DateTime start = day(from);
    final DateTime end = day(to);
    if (end.isBefore(start)) return msgEndBeforeStart;
    if (end.isAfter(maxTo(start))) return msgTooLong;
    return null;
  }

  static const String msgChooseDates = 'Please choose a start and an end date.';
  static const String msgEndBeforeStart = 'The end date must be on or after the start date.';
  static const String msgTooLong = 'The period cannot be longer than one year.';

  // ---------------- file ----------------

  /// `orders_<from>_<to>.pdf`, dates as yyyy-MM-dd.
  static String fileName(ExportPeriod period) {
    final DateFormat f = DateFormat('yyyy-MM-dd');
    return 'orders_${f.format(period.from)}_${f.format(period.to)}.pdf';
  }

  // ---------------- rows and totals ----------------

  /// Is [createdAt] inside [period] (local days, both ends inclusive)?
  static bool inPeriod(DateTime createdAt, ExportPeriod period) => !createdAt.isBefore(period.start) && createdAt.isBefore(period.endExclusive);

  /// One row per booking, oldest first. The amount is the booking's "Total
  /// Amount" exactly as the booking details screen computes it
  /// ([BookingAmounts]), in the booking's own currency: [currencyFor] its
  /// `regionId` (RegionService.currencyForRegion), else [fallback] (the
  /// global currency, what amountShow uses when a booking has no region
  /// currency).
  static List<ExportRow> buildRows(
    List<OnProviderOrderModel> orders, {
    required CurrencyModel? Function(String? regionId) currencyFor,
    required CurrencyModel fallback,
  }) {
    final List<ExportRow> rows = [
      for (final OnProviderOrderModel order in orders)
        ExportRow(
          date: order.createdAt.toDate(),
          id: order.id,
          shortId: shortBookingId(order.id),
          service: order.provider.title ?? '',
          statusLabel: jobStatusLabel(order.status),
          amount: BookingAmounts.of(order).totalAmount,
          currency: currencyFor(order.regionId) ?? fallback,
        ),
    ];
    rows.sort((a, b) {
      final int byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return rows;
  }

  /// Identity of a currency for the totals: its code, else its symbol, else
  /// its id.
  static String currencyKey(CurrencyModel c) {
    if ((c.code ?? '').trim().isNotEmpty) return c.code!.trim();
    if ((c.symbol ?? '').trim().isNotEmpty) return c.symbol!.trim();
    return c.id ?? '';
  }

  /// Number of bookings and sum of their amounts per currency, in the order
  /// the currencies first appear in [rows]. Amounts in different currencies
  /// are never added together.
  static List<CurrencyTotal> totalsPerCurrency(List<ExportRow> rows) {
    final Map<String, CurrencyTotal> totals = {};
    for (final ExportRow row in rows) {
      final CurrencyTotal t = totals.putIfAbsent(currencyKey(row.currency), () => CurrencyTotal(row.currency));
      t.count++;
      t.total += row.amount;
    }
    return totals.values.toList();
  }

  /// [amountShow] in [currency]. The PDF's standard fonts only cover Latin-1,
  /// so a symbol outside it (e.g. "₹") is written as the currency code.
  static String money(double value, CurrencyModel currency) {
    final String shown = amountShow(currency: currency, amount: value.toString());
    final String symbol = currency.symbol ?? '';
    final String code = currency.code ?? '';
    if (!isLatin1(shown) && symbol.isNotEmpty && code.isNotEmpty) {
      return shown.replaceAll(symbol, code).trim();
    }
    return shown;
  }

  /// Can [s] be written with the PDF standard (Latin-1) fonts?
  static bool isLatin1(String s) => s.runes.every((r) => r <= 0xFF);
}

/// A period of whole local days, both ends inclusive.
class ExportPeriod {
  final DateTime from;
  final DateTime to;

  ExportPeriod(DateTime from, DateTime to)
      : from = OrdersHistoryExport.day(from),
        to = OrdersHistoryExport.day(to);

  /// First instant of the period (local midnight of [from]).
  DateTime get start => from;

  /// First instant after the period (local midnight after [to]).
  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);
}

class ExportRow {
  final DateTime date;
  final String id;
  final String shortId;
  final String service;

  /// Untranslated label of the Jobs chip ("Assigned", "In progress", ...).
  final String statusLabel;
  final double amount;
  final CurrencyModel currency;

  const ExportRow({
    required this.date,
    required this.id,
    required this.shortId,
    required this.service,
    required this.statusLabel,
    required this.amount,
    required this.currency,
  });
}

class CurrencyTotal {
  final CurrencyModel currency;
  int count = 0;
  double total = 0;

  CurrencyTotal(this.currency);
}
