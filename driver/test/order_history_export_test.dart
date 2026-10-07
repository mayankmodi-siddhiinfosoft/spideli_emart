import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/models/currency_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/services/order_history_export_service.dart';
import 'package:driver/utils/order_history_export.dart';
import 'package:driver/utils/order_history_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Order-history PDF export: period rules, rows, per-currency totals, file
/// name, labels and the generated document.
void main() {
  final CurrencyModel eur = CurrencyModel(code: 'EUR', symbol: '€', symbolAtRight: true, decimalDigits: 2);
  final CurrencyModel usd = CurrencyModel(code: 'USD', symbol: '\$', symbolAtRight: false, decimalDigits: 2);
  final CurrencyModel inr = CurrencyModel(code: 'INR', symbol: '₹', symbolAtRight: false, decimalDigits: 2);

  OrderExportRow row(String id, DateTime at, {double? amount = 10, CurrencyModel? currency, OrderExportType type = OrderExportType.delivery, double? charge, double? tip}) =>
      OrderExportRow(type: type, orderId: id, createdAt: at, status: 'Order Completed', amount: amount, deliveryCharge: charge, tip: tip, currency: currency ?? eur);

  group('ExportDateRange', () {
    test('defaults to the last 30 days, today included', () {
      final range = ExportDateRange.lastDays(DateTime(2026, 10, 7, 15, 42));
      expect(range.from, DateTime(2026, 9, 8));
      expect(range.to, DateTime(2026, 10, 7));
      expect(range.to.difference(range.from).inDays + 1, 30);
      expect(range.isValid, isTrue);
    });

    test('drops the time of day', () {
      final range = ExportDateRange(DateTime(2026, 1, 5, 23, 59), DateTime(2026, 1, 6, 0, 1));
      expect(range.from, DateTime(2026, 1, 5));
      expect(range.to, DateTime(2026, 1, 6));
    });

    test('end before start is refused, same day is allowed', () {
      expect(ExportDateRange(DateTime(2026, 3, 2), DateTime(2026, 3, 1)).error, ExportDateRange.endBeforeStartError);
      expect(ExportDateRange(DateTime(2026, 3, 2), DateTime(2026, 3, 2)).error, isNull);
    });

    test('at most one year', () {
      expect(ExportDateRange(DateTime(2025, 1, 1), DateTime(2025, 12, 31)).error, isNull);
      expect(ExportDateRange(DateTime(2025, 1, 1), DateTime(2026, 1, 1)).error, ExportDateRange.tooLongError);
      expect(ExportDateRange(DateTime(2025, 3, 15), DateTime(2026, 3, 14)).error, isNull);
      expect(ExportDateRange(DateTime(2025, 3, 15), DateTime(2026, 3, 15)).error, ExportDateRange.tooLongError);
      // A 29 February start ends on 28 February.
      expect(ExportDateRange(DateTime(2024, 2, 29), DateTime(2025, 2, 28)).error, isNull);
      expect(ExportDateRange(DateTime(2024, 2, 29), DateTime(2025, 3, 1)).error, ExportDateRange.tooLongError);
    });

    test('query bounds are local midnights, end exclusive', () {
      final range = ExportDateRange(DateTime(2026, 2, 27), DateTime(2026, 2, 28));
      expect(range.start, DateTime(2026, 2, 27));
      expect(range.endExclusive, DateTime(2026, 3, 1));
    });

    test('both days are inclusive', () {
      final range = ExportDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));
      expect(range.contains(DateTime(2026, 5, 1)), isTrue);
      expect(range.contains(DateTime(2026, 5, 31, 23, 59, 59)), isTrue);
      expect(range.contains(DateTime(2026, 4, 30, 23, 59, 59)), isFalse);
      expect(range.contains(DateTime(2026, 6, 1)), isFalse);
    });
  });

  group('file name', () {
    test('orders_<from>_<to>.pdf', () {
      expect(orderExportFileName(ExportDateRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7))), 'orders_2026-09-08_2026-10-07.pdf');
    });
  });

  group('rows', () {
    final range = ExportDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));

    test('keeps the period only, oldest first, each order once', () {
      final rows = orderExportRowsInRange([
        row('b', DateTime(2026, 5, 20)),
        row('out', DateTime(2026, 6, 1)),
        row('a', DateTime(2026, 5, 2)),
        row('b', DateTime(2026, 5, 20)),
        row('before', DateTime(2026, 4, 30, 23)),
      ], range);
      expect(rows.map((r) => r.orderId), ['a', 'b']);
    });

    test('the same id in two order types is two orders', () {
      final rows = orderExportRowsInRange([
        row('x', DateTime(2026, 5, 3)),
        row('x', DateTime(2026, 5, 4), type: OrderExportType.cab),
      ], range);
      expect(rows.length, 2);
    });

    test('short order id', () {
      expect(shortOrderId('Abc123'), '#Abc123');
      expect(shortOrderId('8f3a1c2d-77aa-4b1e-9e0f-1234ABCD'), '#1234ABCD');
      expect(shortOrderId(null), '-');
    });
  });

  group('summary', () {
    test('totals per currency, unpriced orders counted but not summed', () {
      final summary = OrderExportSummary.of([
        row('1', DateTime(2026, 5, 1), amount: 10.5, charge: 2, tip: 1),
        row('2', DateTime(2026, 5, 2), amount: 4.25, currency: usd),
        row('3', DateTime(2026, 5, 3), amount: 3, charge: 1.5),
        row('4', DateTime(2026, 5, 4), amount: null),
      ]);
      expect(summary.orderCount, 4);
      expect(summary.perCurrency.map((t) => currencyKey(t.currency)), ['EUR', 'USD']);
      final euro = summary.perCurrency.first;
      expect(euro.orders, 3);
      expect(euro.amount, closeTo(13.5, 1e-9));
      expect(euro.deliveryCharge, closeTo(3.5, 1e-9));
      expect(euro.tips, closeTo(1, 1e-9));
      expect(euro.unpriced, 1);
      expect(summary.perCurrency.last.amount, closeTo(4.25, 1e-9));
    });

    test('a currency without code is keyed by its symbol', () {
      expect(currencyKey(CurrencyModel(symbol: 'Fr')), 'Fr');
      expect(currencyKey(null), '');
    });
  });

  group('amount', () {
    test('a delivery order is priced by the order details controller ("To Pay")', () async {
      final order = OrderModel(
        id: 'o1',
        paymentMethod: 'cod',
        isFreeDelivery: false,
        takeAway: false,
        deliveryCharge: '5',
        tipAmount: '2',
        discount: 1,
        products: [CartProductModel(price: '10', discountPrice: '0', quantity: 2, extrasPrice: '0')],
      );
      // (10 x 2 - 1) + 5 + 2, no taxes, no packaging, no platform fee.
      expect(await OrderHistoryExportService.deliveryTotal(order), closeTo(26, 1e-9));
    });

    test('a prepaid delivery is the driver payout', () async {
      final order = OrderModel(
        id: 'o2',
        paymentMethod: 'stripe',
        deliveryCharge: '5',
        tipAmount: '2',
        discount: 0,
        products: [CartProductModel(price: '10', discountPrice: '0', quantity: 1, extrasPrice: '0')],
      );
      expect(await OrderHistoryExportService.deliveryTotal(order), closeTo(7, 1e-9));
    });

    test('an order the controller cannot price has no amount', () async {
      expect(await OrderHistoryExportService.deliveryTotal(OrderModel(id: 'broken')), isNull);
    });
  });

  group('labels', () {
    String Function(String) translator(Map<String, String> map) => (k) => map[k] ?? k;

    test('Latin translations are used, others fall back to English', () {
      expect(pdfLabel('Order history', translator(trFR), enUS), 'Historique des commandes');
      expect(pdfLabel('Order history', translator(lnAr), enUS), 'Order history');
      expect(pdfLabel('Unknown key', translator(lnAr), enUS), 'Unknown key');
    });

    test('every export label exists in every language file', () {
      const keys = [
        'Export PDF', 'Export order history', 'Choose a period of up to one year.', 'Start date', 'End date', //
        ExportDateRange.endBeforeStartError, ExportDateRange.tooLongError, 'No orders found for this period.',
        'Could not create the PDF. Please try again.', 'Order history', 'Period', 'Generated on', 'Summary', 'Number of orders',
        'Total amount', 'Date & time', 'Order ID', 'Type', 'Status', 'Delivery Charge', 'Tips', 'Amount', 'Page', 'Driver',
        'Please wait', 'Delivery', 'Cab', 'Parcel', 'Rental',
      ];
      final files = {'en': enUS, 'fr': trFR, 'ar': lnAr, 'de': deGR, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH, 'ja': jaJP, 'hi': hiIN};
      for (final entry in files.entries) {
        for (final key in keys) {
          expect(entry.value.containsKey(key), isTrue, reason: '${entry.key}: $key');
        }
      }
      for (final t in OrderExportType.values) {
        expect(enUS.containsKey(orderExportTypeKey(t)), isTrue);
      }
    });
  });

  group('PDF', () {
    OrderHistoryPdfLabels labels() => OrderHistoryPdfLabels(
          title: 'Order history',
          period: 'Period',
          generatedOn: 'Generated on',
          summary: 'Summary',
          numberOfOrders: 'Number of orders',
          totalAmount: 'Total amount',
          dateTime: 'Date & time',
          orderId: 'Order ID',
          type: 'Type',
          status: 'Status',
          deliveryCharge: 'Delivery Charge',
          tips: 'Tips',
          amount: 'Amount',
          page: 'Page',
          types: {for (final t in OrderExportType.values) t: orderExportTypeKey(t)},
          statusLabel: (s) => s,
        );

    test('a long period paginates into a valid document', () {
      final range = ExportDateRange(DateTime(2026, 1, 1), DateTime(2026, 6, 30));
      final rows = [for (int i = 0; i < 180; i++) row('order-$i', DateTime(2026, 1, 1).add(Duration(days: i)), charge: 2, tip: i.isEven ? 1 : null)];
      final bytes = OrderHistoryPdf.build(
        labels: labels(),
        headerLines: ['spideli - Driver', 'Jane Doe'],
        range: range,
        generatedAt: DateTime(2026, 7, 1, 9),
        rows: rows,
        showEarnings: true,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final document = PdfDocument(inputBytes: bytes);
      expect(document.pages.count, greaterThan(2));
      final text = PdfTextExtractor(document).extractText();
      expect(text, contains('Order history'));
      expect(text, contains('#order-0'));
      expect(text, contains('#order-179'));
      document.dispose();
    });

    test('a symbol the font cannot draw is written as the currency code', () {
      // The standard PDF fonts draw neither the rupee nor the euro sign.
      expect(OrderHistoryPdf.money(12.5, inr), 'INR 12.50');
      expect(OrderHistoryPdf.money(12.5, eur), '12.50 EUR');
      expect(OrderHistoryPdf.money(12.5, usd), '\$ 12.50');
    });
  });
}
