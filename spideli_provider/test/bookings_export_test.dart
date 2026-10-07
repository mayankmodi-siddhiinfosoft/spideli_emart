import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/utils/booking_receipt_pdf.dart';
import 'package:spideliprovider/utils/bookings_export.dart';
import 'package:spideliprovider/utils/bookings_history_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Booking history "Export PDF": period rules, rows, totals per currency,
/// file name.
void main() {
  final CurrencyModel xaf = CurrencyModel(code: 'XAF', symbol: 'FCFA', decimal: 0, symbolatright: true);
  final CurrencyModel eur = CurrencyModel(code: 'EUR', symbol: '€', decimal: 2);
  CurrencyModel? currencyFor(String? regionId) => regionId == 'eu' ? eur : xaf;

  OnProviderOrderModel booking({
    String id = 'booking-0001',
    required DateTime createdAt,
    String status = ORDER_STATUS_COMPLETED,
    String price = '100',
    String disPrice = '',
    double quantity = 1,
    String discountType = '',
    String discountLabel = '0',
    String extraCharges = '',
    List<Map<String, dynamic>> taxes = const [],
    String? regionId,
    String priceUnit = 'Fixed',
  }) {
    return OnProviderOrderModel.fromJson({
      'id': id,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'quantity': quantity,
      'discountType': discountType,
      'discountLabel': discountLabel,
      'extraCharges': extraCharges,
      'taxSetting': taxes,
      'regionId': regionId,
      'provider': {'title': 'Plumbing', 'price': price, 'disPrice': disPrice, 'priceUnit': priceUnit, 'author': 'p1'},
    });
  }

  group('ExportRange', () {
    test('defaults to the last 30 days, today included', () {
      final r = ExportRange.lastDays(DateTime(2026, 10, 7, 15, 30));
      expect(r.from, DateTime(2026, 9, 8));
      expect(r.to, DateTime(2026, 10, 7));
      expect(r.endExclusive.difference(r.start).inDays, 30);
      expect(r.validate(), isNull);
    });

    test('whole local days, both ends included', () {
      final r = ExportRange(DateTime(2026, 3, 1, 18), DateTime(2026, 3, 31, 9));
      expect(r.start, DateTime(2026, 3, 1));
      expect(r.endExclusive, DateTime(2026, 4, 1));
      expect(r.contains(DateTime(2026, 3, 1)), isTrue);
      expect(r.contains(DateTime(2026, 3, 31, 23, 59, 59, 999)), isTrue);
      expect(r.contains(DateTime(2026, 2, 28, 23, 59, 59)), isFalse);
      expect(r.contains(DateTime(2026, 4, 1)), isFalse);
    });

    test('a single day is a valid period', () {
      expect(ExportRange(DateTime(2026, 5, 5), DateTime(2026, 5, 5)).validate(), isNull);
    });

    test('to before from is refused', () {
      expect(ExportRange(DateTime(2026, 5, 5), DateTime(2026, 5, 4)).validate(), ExportRangeError.toBeforeFrom);
    });

    test('at most one year', () {
      expect(ExportRange(DateTime(2025, 10, 8), DateTime(2026, 10, 7)).validate(), isNull);
      expect(ExportRange(DateTime(2025, 10, 7), DateTime(2026, 10, 7)).validate(), ExportRangeError.tooLong);
      expect(ExportRange(DateTime(2024, 1, 1), DateTime(2026, 1, 1)).validate(), ExportRangeError.tooLong);
      // From Feb 29: the year ends on Feb 28.
      expect(ExportRange(DateTime(2024, 2, 29), DateTime(2025, 2, 28)).validate(), isNull);
      expect(ExportRange(DateTime(2024, 2, 29), DateTime(2025, 3, 1)).validate(), ExportRangeError.tooLong);
    });

    test('file name', () {
      expect(ExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7)).fileName, 'orders_2026-09-08_2026-10-07.pdf');
    });
  });

  group('rows', () {
    final range = ExportRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

    test('keeps the period only, oldest first', () {
      final rows = buildBookingExportRows([
        booking(id: 'b', createdAt: DateTime(2026, 9, 20, 10)),
        booking(id: 'out-before', createdAt: DateTime(2026, 8, 31, 23, 59)),
        booking(id: 'a', createdAt: DateTime(2026, 9, 1, 0, 0)),
        booking(id: 'out-after', createdAt: DateTime(2026, 10, 1)),
        booking(id: 'c', createdAt: DateTime(2026, 9, 30, 23, 59)),
      ], range, currencyFor: currencyFor);
      expect(rows.map((r) => r.id), ['a', 'b', 'c']);
    });

    test('amount is the booking details total (BookingTotals.grandTotal)', () {
      final order = booking(
        createdAt: DateTime(2026, 9, 2),
        price: '200',
        disPrice: '150',
        quantity: 2,
        discountType: 'Percentage',
        discountLabel: '10',
        extraCharges: '25',
        taxes: [
          {'title': 'VAT', 'tax': '10', 'type': 'percentage', 'enable': true},
          {'title': 'Fee', 'tax': '5', 'type': 'fix', 'enable': true},
          {'title': 'Off', 'tax': '50', 'type': 'fix', 'enable': false},
        ],
      );
      // 150 x 2 = 300; -10% = 270; +10% VAT 27 + fee 5 = 302; + extra 25 = 327.
      final rows = buildBookingExportRows([order], range, currencyFor: currencyFor);
      expect(rows.single.amount, closeTo(327, 1e-9));
      expect(rows.single.amount, BookingTotals.of(order).grandTotal);
    });

    test('fixed discount, no discounted price, no extras', () {
      final rows = buildBookingExportRows([booking(createdAt: DateTime(2026, 9, 2), price: '80', disPrice: '0', discountLabel: '15')], range, currencyFor: currencyFor);
      expect(rows.single.amount, 65);
    });

    test('short id, service, status label, currency', () {
      final rows = buildBookingExportRows(
        [booking(id: 'ABCDEFGHIJKL', createdAt: DateTime(2026, 9, 3), status: ORDER_STATUS_ASSIGNED, regionId: 'eu', priceUnit: 'Hourly')],
        range,
        currencyFor: currencyFor,
      );
      final row = rows.single;
      expect(row.shortId, '#EFGHIJKL');
      expect(row.service, 'Plumbing');
      expect(row.hourly, isTrue);
      expect(row.statusLabel, 'Accepted');
      expect(row.currency, same(eur));
    });

    test('status labels follow the booking list chips', () {
      expect(bookingStatusLabel(ORDER_STATUS_PLACED), 'Pending');
      expect(bookingStatusLabel(ORDER_STATUS_ACCEPTED), 'Accepted');
      expect(bookingStatusLabel(ORDER_STATUS_ONGOING), 'On Going');
      expect(bookingStatusLabel(ORDER_STATUS_COMPLETED), 'Completed');
      expect(bookingStatusLabel(ORDER_STATUS_REJECTED), 'Rejected');
      expect(bookingStatusLabel(ORDER_STATUS_CANCELLED), 'Cancelled');
      expect(exportedBookingStatuses.length, 7);
    });
  });

  group('totals per currency', () {
    final range = ExportRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

    test('one total per currency, counts and sums', () {
      final rows = buildBookingExportRows([
        booking(id: '1', createdAt: DateTime(2026, 9, 1), price: '1000'),
        booking(id: '2', createdAt: DateTime(2026, 9, 2), price: '10.25', regionId: 'eu'),
        booking(id: '3', createdAt: DateTime(2026, 9, 3), price: '2500'),
        booking(id: '4', createdAt: DateTime(2026, 9, 4), price: '4.10', regionId: 'eu'),
      ], range, currencyFor: currencyFor);
      final totals = totalsPerCurrency(rows);
      expect(totals.map((t) => t.key), ['XAF', 'EUR']);
      expect(totals[0].count, 2);
      expect(totals[0].amount, 3500);
      expect(totals[1].count, 2);
      expect(totals[1].amount, closeTo(14.35, 1e-9));
    });

    test('a total is the sum of the printed (rounded) amounts', () {
      final rows = buildBookingExportRows([
        booking(id: '1', createdAt: DateTime(2026, 9, 1), price: '100.4'),
        booking(id: '2', createdAt: DateTime(2026, 9, 2), price: '100.4'),
      ], range, currencyFor: currencyFor);
      // XAF has 0 decimals: 100 + 100, not round(200.8) = 201.
      expect(totalsPerCurrency(rows).single.amount, 200);
    });

    test('no rows, no totals', () {
      expect(totalsPerCurrency(const []), isEmpty);
    });
  });

  test('PDF builds and paginates a long table', () {
    final range = ExportRange(DateTime(2026, 1, 1), DateTime(2026, 6, 30));
    final orders = [
      for (int i = 0; i < 180; i++) booking(id: 'booking-$i', createdAt: DateTime(2026, 1, 1).add(Duration(hours: i * 20)), regionId: i.isEven ? 'eu' : null),
    ];
    final rows = buildBookingExportRows(orders, range, currencyFor: currencyFor);
    final bytes = BookingsHistoryPdf.build(range: range, rows: rows, generatedAt: DateTime(2026, 7, 1));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    expect(doc.pages.count, greaterThan(1));
    final String text = PdfTextExtractor(doc).extractText();
    expect(text, contains('Booking history'));
    expect(text, contains('#ooking-0'));
    expect(text, contains('#king-179'));
    doc.dispose();
  });
}
