import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/cab_order_list_controller.dart';
import 'package:driver/controllers/owner_order_list_controller.dart';
import 'package:driver/controllers/parcel_order_list_controller.dart';
import 'package:driver/controllers/rental_order_list_controller.dart';
import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/models/currency_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/services/order_history_export_service.dart';
import 'package:driver/utils/order_history_export.dart';
import 'package:driver/utils/order_history_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Order-history PDF export: period rules, rows, per-currency totals, file
/// name, labels and the generated document.
void main() {
  final CurrencyModel eur = CurrencyModel(code: 'EUR', symbol: '€', symbolAtRight: true, decimalDigits: 2);
  final CurrencyModel usd = CurrencyModel(code: 'USD', symbol: '\$', symbolAtRight: false, decimalDigits: 2);
  final CurrencyModel inr = CurrencyModel(code: 'INR', symbol: '₹', symbolAtRight: false, decimalDigits: 2);

  OrderExportRow row(String id, DateTime at,
          {double? amount = 10, CurrencyModel? currency, OrderExportType type = OrderExportType.delivery, double? charge, double? tip, String status = 'Order Completed'}) =>
      OrderExportRow(type: type, orderId: id, createdAt: at, status: status, amount: amount, deliveryCharge: charge, tip: tip, currency: currency ?? eur);

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

    test('a status filter is in the name, made safe for a file', () {
      final range = ExportDateRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7));
      expect(orderExportFileName(range, statusLabel: 'Order Cancelled'), 'orders_order-cancelled_2026-09-08_2026-10-07.pdf');
      expect(orderExportFileName(range, statusLabel: 'Commande annulée'), 'orders_commande-annulee_2026-09-08_2026-10-07.pdf');
      expect(orderExportFileName(range, statusLabel: ''), 'orders_2026-09-08_2026-10-07.pdf');
      expect(orderExportFileName(range, statusLabel: null), 'orders_2026-09-08_2026-10-07.pdf');
      // Nothing usable left: no status part rather than an empty one.
      expect(orderExportFileName(range, statusLabel: 'Заказ отменён'), 'orders_2026-09-08_2026-10-07.pdf');
    });

    test('file-name part', () {
      expect(fileNamePart('  On Going  '), 'on-going');
      expect(fileNamePart('../a/b\\c:d*e?"f"<g>|h'), 'a-b-c-d-e-f-g-h');
      expect(fileNamePart('Concluídos / Terminés'), 'concluidos-termines');
      expect(fileNamePart('Straße & Œuvre'), 'strasse-oeuvre');
      expect(fileNamePart('Order  -- Shipped!'), 'order-shipped');
      expect(fileNamePart('进行中'), '');
    });
  });

  group('status filter', () {
    test('choices: all statuses first, then each tab and its statuses', () {
      expect(OrderExportStatusFilter.choices.map((f) => f.key), [
        'All statuses',
        'On Going', 'Order Placed', 'Order Accepted', 'Driver Pending', 'Driver Accepted', 'Order Shipped', 'In Transit', 'Driver Rejected', //
        'Completed',
        'Cancelled', 'Order Rejected', 'Order Cancelled',
      ]);
      expect(OrderExportStatusFilter.choices.first, OrderExportStatusFilter.all);
      expect(OrderExportStatusFilter.choices.where((f) => f.isGroup).map((f) => f.key), ['On Going', 'Completed', 'Cancelled']);
      expect(OrderExportStatusFilter.choices.toSet().length, OrderExportStatusFilter.choices.length);
    });

    test('the statuses are the app constants', () {
      expect(
        {for (final f in OrderExportStatusFilter.choices.where((f) => f.isGroup)) ...f.statuses},
        {
          Constant.orderPlaced, Constant.orderAccepted, Constant.driverPending, Constant.driverAccepted, Constant.orderShipped, //
          Constant.orderInTransit, Constant.driverRejected, Constant.orderCompleted, Constant.orderRejected, Constant.orderCancelled,
        },
      );
    });

    test('all statuses keeps everything, a tab its statuses, a status itself', () {
      expect(OrderExportStatusFilter.all.isAll, isTrue);
      expect(OrderExportStatusFilter.all.matches('Quote Requested'), isTrue);
      expect(OrderExportStatusFilter.all.matches(''), isTrue);
      expect(OrderExportStatusFilter.onGoing.matches('In Transit'), isTrue);
      expect(OrderExportStatusFilter.onGoing.matches('Order Completed'), isFalse);
      expect(OrderExportStatusFilter.completedTab.matches('Order Completed'), isTrue);
      expect(OrderExportStatusFilter.cancelledTab.matches('Order Rejected'), isTrue);
      expect(OrderExportStatusFilter.cancelledTab.matches(' Order Cancelled '), isTrue);
      expect(OrderExportStatusFilter.cancelledTab.matches('Order Completed'), isFalse);
      final shipped = OrderExportStatusFilter.choices.firstWhere((f) => f.key == 'Order Shipped');
      expect(shipped.isGroup, isFalse);
      expect(shipped.isAll, isFalse);
      expect(shipped.matches('Order Shipped'), isTrue);
      expect(shipped.matches('In Transit'), isFalse);
    });

    test('the tabs are those of the order lists', () {
      // Every status the history screens put in a tab, in the export's tab
      // of the same meaning (parcel "In Transit" / "Delivered" are the
      // "On Going" / "Completed" tabs of the other services).
      Set<String> statusesIn<T>(List<T> Function(String tab) forTab, String tab, String? Function(T) status) => forTab(tab).map((o) => status(o)!).toSet();
      final all = [for (final f in OrderExportStatusFilter.choices.where((f) => f.isGroup)) ...f.statuses];

      final cab = CabOrderListController()..cabOrder.assignAll([for (final s in all) CabOrderModel(id: s, status: s)]);
      final parcel = ParcelOrderListController()..parcelOrder.assignAll([for (final s in all) ParcelOrderModel(id: s, status: s, driverId: 'd1')]);
      final rental = RentalOrderListController()..rentalOrders.assignAll([for (final s in all) RentalOrderModel(id: s, status: s)]);
      final owner = OwnerOrderListController()..vendorOrders.assignAll([for (final s in all) OrderModel(id: s, status: s)]);

      // A driver's own lists never hold "Driver Rejected" (the dispatch
      // clears the driver), the owner's parcel "Pending" tab does.
      final onGoing = OrderExportStatusFilter.onGoing.statuses.difference({Constant.driverRejected});
      expect(statusesIn(cab.getOrdersForTab, 'On Going', (o) => o.status), onGoing);
      expect(statusesIn(cab.getOrdersForTab, 'Completed', (o) => o.status), OrderExportStatusFilter.completedTab.statuses);
      expect(statusesIn(cab.getOrdersForTab, 'Cancelled', (o) => o.status), OrderExportStatusFilter.cancelledTab.statuses);
      expect(statusesIn(parcel.getOrdersForTab, 'In Transit', (o) => o.status), onGoing);
      expect(statusesIn(parcel.getOrdersForTab, 'Delivered', (o) => o.status), OrderExportStatusFilter.completedTab.statuses);
      expect(statusesIn(parcel.getOrdersForTab, 'Cancelled', (o) => o.status), OrderExportStatusFilter.cancelledTab.statuses);
      expect(statusesIn(rental.getOrdersForTab, 'On Going', (o) => o.status), onGoing);
      expect(statusesIn(rental.getOrdersForTab, 'Completed', (o) => o.status), OrderExportStatusFilter.completedTab.statuses);
      expect(statusesIn(rental.getOrdersForTab, 'Cancelled', (o) => o.status), OrderExportStatusFilter.cancelledTab.statuses);
      expect(statusesIn(owner.getVendorOrdersForTab, 'On Going', (o) => o.status), onGoing);
      expect(statusesIn(owner.getVendorOrdersForTab, 'Completed', (o) => o.status), OrderExportStatusFilter.completedTab.statuses);
      expect(statusesIn(owner.getVendorOrdersForTab, 'Cancelled', (o) => o.status), OrderExportStatusFilter.cancelledTab.statuses);

      // Owner parcels: "Pending" (handed back by a driver), "Assigned" and
      // "In Transit" all fall in "On Going".
      owner.parcelOrders.assignAll([
        ParcelOrderModel(id: 'p1', status: 'Driver Rejected'),
        ParcelOrderModel(id: 'p2', status: 'Order Placed'),
        ParcelOrderModel(id: 'p3', status: 'Driver Pending', driverId: 'd1'),
        ParcelOrderModel(id: 'p4', status: 'Order Shipped', driverId: 'd1'),
      ]);
      for (final tab in ['Pending', 'Assigned', 'In Transit']) {
        for (final o in owner.getParcelOrdersForTab(tab)) {
          expect(OrderExportStatusFilter.onGoing.matches(o.status!), isTrue, reason: '$tab: ${o.status}');
        }
      }
      expect(owner.getParcelOrdersForTab('Pending').map((o) => o.id), containsAll(['p1', 'p2']));
    });

    test('rows of the period and of the status only', () {
      final range = ExportDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));
      final rows = [
        row('done', DateTime(2026, 5, 2)),
        row('cancelled', DateTime(2026, 5, 3), status: 'Order Cancelled'),
        row('rejected', DateTime(2026, 5, 4), status: 'Order Rejected', type: OrderExportType.cab),
        row('moving', DateTime(2026, 5, 5), status: 'In Transit', type: OrderExportType.parcel),
        row('old-cancelled', DateTime(2026, 4, 3), status: 'Order Cancelled'),
      ];
      expect(orderExportRowsInRange(rows, range).map((r) => r.orderId), ['done', 'cancelled', 'rejected', 'moving']);
      expect(orderExportRowsInRange(rows, range, status: OrderExportStatusFilter.all).length, 4);
      expect(orderExportRowsInRange(rows, range, status: OrderExportStatusFilter.cancelledTab).map((r) => r.orderId), ['cancelled', 'rejected']);
      expect(orderExportRowsInRange(rows, range, status: OrderExportStatusFilter.completedTab).map((r) => r.orderId), ['done']);
      expect(orderExportRowsInRange(rows, range, status: OrderExportStatusFilter.onGoing).map((r) => r.orderId), ['moving']);
      final rejected = OrderExportStatusFilter.choices.firstWhere((f) => f.key == 'Order Rejected');
      expect(orderExportRowsInRange(rows, range, status: rejected).map((r) => r.orderId), ['rejected']);
      final placed = OrderExportStatusFilter.choices.firstWhere((f) => f.key == 'Order Placed');
      expect(orderExportRowsInRange(rows, range, status: placed), isEmpty);
    });

    test('empty export message names the status', () {
      expect(OrderHistoryExportService.emptyMessage(OrderExportStatusFilter.all), 'No orders found for this period.');
      expect(OrderHistoryExportService.emptyMessage(OrderExportStatusFilter.cancelledTab), 'No orders with the status "Cancelled" found for this period.');
    });

    test('status label of the PDF and file name', () {
      expect(OrderHistoryExportService.statusFilterLabel(OrderExportStatusFilter.all), 'All statuses');
      expect(OrderHistoryExportService.statusFilterLabel(OrderExportStatusFilter.onGoing), 'On Going');
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
      final keys = [
        'Export PDF', 'Export order history', 'Choose a period of up to one year.', 'Start date', 'End date', //
        ExportDateRange.endBeforeStartError, ExportDateRange.tooLongError, 'No orders found for this period.',
        'Could not create the PDF. Please try again.', 'Order history', 'Period', 'Generated on', 'Summary', 'Number of orders',
        'Total amount', 'Date & time', 'Order ID', 'Type', 'Status', 'Delivery Charge', 'Tips', 'Amount', 'Page', 'Driver',
        'Please wait', 'Delivery', 'Cab', 'Parcel', 'Rental', OrderHistoryExportService.noOrdersWithStatusKey,
        for (final f in OrderExportStatusFilter.choices) f.key,
      ];
      final files = {'en': enUS, 'fr': trFR, 'ar': lnAr, 'de': deGR, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH, 'ja': jaJP, 'hi': hiIN};
      for (final entry in files.entries) {
        for (final key in keys) {
          expect(entry.value.containsKey(key), isTrue, reason: '${entry.key}: $key');
        }
        // The status placeholder survives translation.
        expect(entry.value[OrderHistoryExportService.noOrdersWithStatusKey], contains('@status'), reason: entry.key);
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

    test('the chosen status is printed under the period', () {
      final range = ExportDateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      final bytes = OrderHistoryPdf.build(
        labels: labels(),
        headerLines: ['spideli - Driver'],
        range: range,
        statusFilter: 'Cancelled',
        generatedAt: DateTime(2026, 2, 1, 9),
        rows: [row('c1', DateTime(2026, 1, 5), status: 'Order Cancelled')],
        showEarnings: false,
      );
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      expect(text, contains('01 Jan 2026 - 31 Jan 2026'));
      expect(text, contains('Status'));
      expect(text, contains('Cancelled'));
      expect(text, contains('Order Cancelled'));
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
