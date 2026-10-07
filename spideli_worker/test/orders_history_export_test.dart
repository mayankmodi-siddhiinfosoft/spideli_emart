import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/currency_model.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/model/provider_service_model.dart';
import 'package:spideliworker/model/tax_model.dart';
import 'package:spideliworker/utils/booking_amount.dart';
import 'package:spideliworker/utils/orders_history_export.dart';
import 'package:spideliworker/utils/orders_history_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final CurrencyModel usd = CurrencyModel(code: 'USD', symbol: r'$', decimal: 2, id: 'usd');
  final CurrencyModel xaf = CurrencyModel(code: 'XAF', symbol: 'FCFA', decimal: 0, id: 'xaf', symbolatright: true);
  final CurrencyModel inr = CurrencyModel(code: 'INR', symbol: '₹', decimal: 2, id: 'inr');

  OnProviderOrderModel booking({
    String id = 'booking-0001',
    DateTime? createdAt,
    String price = '100',
    String disPrice = '0',
    double quantity = 1,
    String status = ORDER_STATUS_COMPLETED,
    String? regionId,
    String? discountType,
    String? discountLabel,
    List<TaxModel>? taxes,
    String title = 'Deep cleaning',
  }) =>
      OnProviderOrderModel(
        id: id,
        status: status,
        createdAt: Timestamp.fromDate(createdAt ?? DateTime(2026, 10, 1, 9, 30)),
        provider: ProviderServiceModel(title: title, price: price, disPrice: disPrice),
        quantity: quantity,
        regionId: regionId,
        discountType: discountType,
        discountLabel: discountLabel,
        taxModel: taxes,
      );

  group('period', () {
    test('default: the last 30 days, today included', () {
      final ExportPeriod p = OrdersHistoryExport.defaultPeriod(DateTime(2026, 10, 7, 15, 45));
      expect(p.from, DateTime(2026, 9, 8));
      expect(p.to, DateTime(2026, 10, 7));
      expect(p.endExclusive.difference(p.start).inDays, 30);
      expect(OrdersHistoryExport.validate(p.from, p.to), isNull);
    });

    test('whole local days, both ends inclusive', () {
      final ExportPeriod p = ExportPeriod(DateTime(2026, 3, 1, 18), DateTime(2026, 3, 31, 7));
      expect(p.start, DateTime(2026, 3, 1));
      expect(p.endExclusive, DateTime(2026, 4, 1));
      expect(OrdersHistoryExport.inPeriod(DateTime(2026, 3, 1), p), isTrue);
      expect(OrdersHistoryExport.inPeriod(DateTime(2026, 3, 31, 23, 59, 59), p), isTrue);
      expect(OrdersHistoryExport.inPeriod(DateTime(2026, 2, 28, 23, 59, 59), p), isFalse);
      expect(OrdersHistoryExport.inPeriod(DateTime(2026, 4, 1), p), isFalse);
    });

    test('a single day is a valid period', () {
      expect(OrdersHistoryExport.validate(DateTime(2026, 5, 5, 10), DateTime(2026, 5, 5, 8)), isNull);
    });

    test('both dates are required', () {
      expect(OrdersHistoryExport.validate(null, DateTime(2026, 5, 5)), OrdersHistoryExport.msgChooseDates);
      expect(OrdersHistoryExport.validate(DateTime(2026, 5, 5), null), OrdersHistoryExport.msgChooseDates);
    });

    test('the end date cannot be before the start date', () {
      expect(OrdersHistoryExport.validate(DateTime(2026, 5, 5), DateTime(2026, 5, 4)), OrdersHistoryExport.msgEndBeforeStart);
    });

    test('at most one year', () {
      expect(OrdersHistoryExport.validate(DateTime(2025, 1, 1), DateTime(2025, 12, 31)), isNull);
      expect(OrdersHistoryExport.validate(DateTime(2025, 1, 1), DateTime(2026, 1, 1)), OrdersHistoryExport.msgTooLong);
      expect(OrdersHistoryExport.validate(DateTime(2025, 10, 7), DateTime(2026, 10, 6)), isNull);
      expect(OrdersHistoryExport.validate(DateTime(2025, 10, 7), DateTime(2026, 10, 7)), OrdersHistoryExport.msgTooLong);
    });

    test('one year from 29 February ends on 28 February', () {
      expect(OrdersHistoryExport.maxTo(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
      expect(OrdersHistoryExport.validate(DateTime(2024, 2, 29), DateTime(2025, 2, 28)), isNull);
      expect(OrdersHistoryExport.validate(DateTime(2024, 2, 29), DateTime(2025, 3, 1)), OrdersHistoryExport.msgTooLong);
    });
  });

  test('file name: orders_<from>_<to>.pdf', () {
    expect(OrdersHistoryExport.fileName(ExportPeriod(DateTime(2026, 9, 8, 13), DateTime(2026, 10, 7))), 'orders_2026-09-08_2026-10-07.pdf');
  });

  test('exports the statuses of the Jobs tabs only', () {
    expect(OrdersHistoryExport.statuses, [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED, ORDER_STATUS_ONGOING, ORDER_STATUS_COMPLETED]);
  });

  test('a worker whose documents are not approved exports only completed jobs, as the Jobs screen shows', () {
    expect(OrdersHistoryExport.statusesFor(canReceiveJobs: true), OrdersHistoryExport.statuses);
    expect(OrdersHistoryExport.statusesFor(canReceiveJobs: false), [ORDER_STATUS_COMPLETED]);
  });

  group('amount (booking details "Total Amount")', () {
    test('discounted price when set, else price, times quantity', () {
      expect(BookingAmounts.of(booking(price: '100', disPrice: '0', quantity: 2)).totalAmount, 200);
      expect(BookingAmounts.of(booking(price: '100', disPrice: '', quantity: 2)).totalAmount, 200);
      expect(BookingAmounts.of(booking(price: '100', disPrice: '80', quantity: 2)).totalAmount, 160);
    });

    test('discount then taxes on the subtotal (percentage and fixed, enabled only)', () {
      final BookingAmounts a = BookingAmounts.of(booking(
        price: '100',
        quantity: 2,
        discountType: 'Percentage',
        discountLabel: '10',
        taxes: [
          TaxModel(enable: true, type: 'percentage', tax: '10'),
          TaxModel(enable: true, type: 'fix', tax: '5'),
          TaxModel(enable: false, type: 'fix', tax: '1000'),
        ],
      ));
      expect(a.price, 200);
      expect(a.discount, 20);
      expect(a.subTotal, 180);
      expect(a.totalAmount, 180 + 18 + 5);
    });

    test('flat discount', () {
      expect(BookingAmounts.of(booking(price: '50', discountType: 'Fix', discountLabel: '15')).totalAmount, 35);
    });
  });

  test('status label as on the Jobs chip', () {
    expect(jobStatusLabel(ORDER_STATUS_ASSIGNED), 'Assigned');
    expect(jobStatusLabel(ORDER_STATUS_ACCEPTED), 'Assigned');
    expect(jobStatusLabel(ORDER_STATUS_ONGOING), 'In progress');
    expect(jobStatusLabel(ORDER_STATUS_COMPLETED), 'Completed');
    expect(jobStatusLabel(ORDER_STATUS_PLACED), 'Pending');
  });

  group('rows and totals', () {
    final Map<String, CurrencyModel> byRegion = {'cm': xaf};
    CurrencyModel? currencyFor(String? regionId) => byRegion[regionId];

    final List<OnProviderOrderModel> orders = [
      booking(id: 'zzzzzzzz-late-0003', createdAt: DateTime(2026, 10, 3, 8), price: '20', status: ORDER_STATUS_ONGOING),
      booking(id: 'aaaaaaaa-early-0001', createdAt: DateTime(2026, 10, 1, 8), price: '5000', regionId: 'cm'),
      booking(id: 'mmmmmmmm-mid-0002', createdAt: DateTime(2026, 10, 2, 8), price: '10', quantity: 3, status: ORDER_STATUS_ASSIGNED, regionId: 'unknown'),
      booking(id: 'bbbbbbbb-xaf-0004', createdAt: DateTime(2026, 10, 4, 8), price: '2500', regionId: 'cm'),
    ];

    test('one row per booking, oldest first, amount and currency of the booking', () {
      final List<ExportRow> rows = OrdersHistoryExport.buildRows(orders, currencyFor: currencyFor, fallback: usd);
      expect(rows.map((r) => r.id), ['aaaaaaaa-early-0001', 'mmmmmmmm-mid-0002', 'zzzzzzzz-late-0003', 'bbbbbbbb-xaf-0004']);
      expect(rows.map((r) => r.amount), [5000, 30, 20, 2500]);
      expect(rows.map((r) => r.currency.code), ['XAF', 'USD', 'USD', 'XAF']);
      expect(rows.map((r) => r.statusLabel), ['Completed', 'Assigned', 'In progress', 'Completed']);
      expect(rows.first.shortId, '#rly-0001');
      expect(rows.first.service, 'Deep cleaning');
    });

    test('totals per currency, never added across currencies', () {
      final List<CurrencyTotal> totals = OrdersHistoryExport.totalsPerCurrency(OrdersHistoryExport.buildRows(orders, currencyFor: currencyFor, fallback: usd));
      expect(totals.length, 2);
      expect(OrdersHistoryExport.currencyKey(totals[0].currency), 'XAF');
      expect(totals[0].count, 2);
      expect(totals[0].total, 7500);
      expect(OrdersHistoryExport.currencyKey(totals[1].currency), 'USD');
      expect(totals[1].count, 2);
      expect(totals[1].total, 50);
    });

    test('no rows, no totals', () {
      expect(OrdersHistoryExport.totalsPerCurrency(const []), isEmpty);
    });
  });

  group('money', () {
    test('formatted as amountShow (symbol side, decimals)', () {
      expect(OrdersHistoryExport.money(12.5, usd), r'$ 12.50');
      expect(OrdersHistoryExport.money(7500, xaf), '7500 FCFA');
    });

    test('a symbol the PDF fonts cannot write becomes the currency code', () {
      expect(OrdersHistoryExport.money(99, inr), 'INR 99.00');
    });
  });

  test('PDF: summary and a table that paginates with its header on every page', () {
    final List<OnProviderOrderModel> many = [
      for (int i = 0; i < 120; i++) booking(id: 'booking-${i.toString().padLeft(6, '0')}', createdAt: DateTime(2026, 9, 1).add(Duration(hours: i * 5)), price: '${10 + i}'),
    ];
    final ExportPeriod period = ExportPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    final List<int> bytes = OrdersHistoryPdf.build(OrdersHistoryPdfData(
      appName: 'spideli Worker',
      ownerName: 'Jane Worker',
      period: period,
      generatedAt: DateTime(2026, 10, 7, 10),
      rows: OrdersHistoryExport.buildRows(many, currencyFor: (_) => null, fallback: usd),
    ));
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    expect(doc.pages.count, greaterThan(1));
    final PdfTextExtractor extractor = PdfTextExtractor(doc);
    final String first = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
    expect(first, contains('Booking history'));
    expect(first, contains('Jane Worker'));
    expect(first, contains('01 Sep 2026 - 30 Sep 2026'));
    expect(first, contains('120'));
    // 10 + 11 + ... + 129 = 8340
    expect(first, contains(r'$ 8340.00'));
    final String last = extractor.extractText(startPageIndex: doc.pages.count - 1, endPageIndex: doc.pages.count - 1);
    expect(last, contains('Date & Time'));
    expect(last, contains('booking-000119'.substring(6)));
    doc.dispose();
  });
}
