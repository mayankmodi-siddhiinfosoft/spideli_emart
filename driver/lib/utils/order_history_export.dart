import 'package:driver/models/currency_model.dart';
import 'package:intl/intl.dart';

/// Pure parts of the order-history PDF export: the period rules, the rows,
/// the per-currency summary and the file name. No Firestore, no widgets, so
/// they are unit tested (test/order_history_export_test.dart).

/// The period the driver picked: two calendar days, both inclusive, read in
/// the phone's local time.
class ExportDateRange {
  /// First day (only the date part is used).
  final DateTime from;

  /// Last day, inclusive (only the date part is used).
  final DateTime to;

  ExportDateRange(DateTime from, DateTime to)
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  /// Default period: the last 30 days, today included.
  factory ExportDateRange.lastDays(DateTime now, {int days = 30}) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    return ExportDateRange(DateTime(today.year, today.month, today.day - (days - 1)), today);
  }

  /// Local midnight that opens the period (inclusive bound of the query).
  DateTime get start => DateTime(from.year, from.month, from.day);

  /// Local midnight after the last day (exclusive bound of the query).
  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);

  /// Latest allowed last day for [from]: one calendar year, minus a day
  /// (1 Jan 2025 -> 31 Dec 2025).
  static DateTime maxTo(DateTime from) => DateTime(from.year + 1, from.month, from.day - 1);

  /// Untranslated error key, or null when the period can be exported.
  String? get error {
    if (to.isBefore(from)) return endBeforeStartError;
    if (to.isAfter(maxTo(from))) return tooLongError;
    return null;
  }

  bool get isValid => error == null;

  /// Whether [moment] falls inside the period (local day boundaries).
  bool contains(DateTime moment) {
    final DateTime local = moment.toLocal();
    return !local.isBefore(start) && local.isBefore(endExclusive);
  }

  static const String endBeforeStartError = 'The end date must be on or after the start date.';
  static const String tooLongError = 'The period cannot be longer than one year.';

  @override
  bool operator ==(Object other) => other is ExportDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// `orders_<from>_<to>.pdf`, ISO dates so the files sort by period.
String orderExportFileName(ExportDateRange range) {
  final DateFormat f = DateFormat('yyyy-MM-dd');
  return 'orders_${f.format(range.from)}_${f.format(range.to)}.pdf';
}

/// The order types the driver app lists in its history.
enum OrderExportType { delivery, cab, parcel, rental }

/// Untranslated label of each order type (the keys the app already uses).
String orderExportTypeKey(OrderExportType type) => switch (type) {
      OrderExportType.delivery => 'Delivery',
      OrderExportType.cab => 'Cab',
      OrderExportType.parcel => 'Parcel',
      OrderExportType.rental => 'Rental',
    };

/// Short form of an order id for the table: the last 8 characters, the full
/// id when it is already short.
String shortOrderId(String? id) {
  final String value = (id ?? '').trim();
  if (value.isEmpty) return '-';
  return '#${value.length <= 10 ? value : value.substring(value.length - 8)}';
}

/// One line of the PDF table.
class OrderExportRow {
  final OrderExportType type;
  final String orderId;
  final DateTime createdAt;
  final String status;

  /// Section name, as the history cards show it next to the order.
  final String section;

  /// The total the order's details screen shows ("To Pay" / "Order Total"),
  /// computed by that screen's controller; null when it could not be priced.
  final double? amount;

  /// Delivery orders only, when the history card shows them (the driver's
  /// delivery charge and the customer's tip).
  final double? deliveryCharge;
  final double? tip;
  final CurrencyModel? currency;

  const OrderExportRow({
    required this.type,
    required this.orderId,
    required this.createdAt,
    required this.status,
    this.section = '',
    required this.amount,
    this.deliveryCharge,
    this.tip,
    required this.currency,
  });
}

/// Rows of the period only, oldest first; one row per order id (an order
/// found twice, e.g. by two queries, is kept once).
List<OrderExportRow> orderExportRowsInRange(Iterable<OrderExportRow> rows, ExportDateRange range) {
  final Map<String, OrderExportRow> byId = {};
  final List<OrderExportRow> withoutId = [];
  for (final OrderExportRow row in rows) {
    if (!range.contains(row.createdAt)) continue;
    if (row.orderId.isEmpty) {
      withoutId.add(row);
    } else {
      byId.putIfAbsent('${row.type.name}/${row.orderId}', () => row);
    }
  }
  final List<OrderExportRow> result = [...byId.values, ...withoutId];
  result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return result;
}

/// Identifies a currency in the summary: its code, else its symbol.
String currencyKey(CurrencyModel? currency) {
  final String code = (currency?.code ?? '').trim();
  if (code.isNotEmpty) return code;
  return (currency?.symbol ?? '').trim();
}

/// Totals of one currency.
class CurrencyTotals {
  final CurrencyModel? currency;
  int orders = 0;
  double amount = 0;
  double deliveryCharge = 0;
  double tips = 0;

  /// Orders whose amount could not be computed (shown as "-").
  int unpriced = 0;

  CurrencyTotals(this.currency);
}

/// Header figures of the PDF.
class OrderExportSummary {
  final int orderCount;

  /// In order of first appearance.
  final List<CurrencyTotals> perCurrency;

  const OrderExportSummary(this.orderCount, this.perCurrency);

  factory OrderExportSummary.of(List<OrderExportRow> rows) {
    final Map<String, CurrencyTotals> totals = {};
    for (final OrderExportRow row in rows) {
      final CurrencyTotals t = totals.putIfAbsent(currencyKey(row.currency), () => CurrencyTotals(row.currency));
      t.orders++;
      if (row.amount == null) {
        t.unpriced++;
      } else {
        t.amount += row.amount!;
      }
      t.deliveryCharge += row.deliveryCharge ?? 0;
      t.tips += row.tip ?? 0;
    }
    return OrderExportSummary(rows.length, totals.values.toList());
  }
}

/// The standard PDF fonts only encode Latin-1.
bool isLatin1(String s) => s.codeUnits.every((u) => u <= 0xFF);

/// A PDF label: the app's translation when the PDF font can draw it, else the
/// English text (Arabic, Russian, Hindi, Chinese and Japanese translations
/// would only print as "?").
String pdfLabel(String key, String Function(String) translate, Map<String, String> english) {
  final String translated = translate(key);
  if (isLatin1(translated)) return translated;
  return english[key] ?? key;
}
