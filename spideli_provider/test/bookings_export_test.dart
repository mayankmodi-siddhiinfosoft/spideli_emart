import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/lang/app_ar.dart';
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

    test('file name: status and period', () {
      final range = ExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7));
      expect(bookingsExportFileName(range, BookingStatusFilter.all.label), 'orders_all-statuses_2026-09-08_2026-10-07.pdf');
      expect(bookingsExportFileName(range, BookingStatusFilter.ongoing.label), 'orders_on-going_2026-09-08_2026-10-07.pdf');
      expect(bookingsExportFileName(range, BookingStatusFilter.cancelled.label), 'orders_cancelled-rejected_2026-09-08_2026-10-07.pdf');
    });
  });

  group('status filter', () {
    final range = ExportRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    const List<String> every = [
      ORDER_STATUS_PLACED,
      ORDER_STATUS_ACCEPTED,
      ORDER_STATUS_ASSIGNED,
      ORDER_STATUS_ONGOING,
      ORDER_STATUS_COMPLETED,
      ORDER_STATUS_REJECTED,
      ORDER_STATUS_CANCELLED,
    ];
    final orders = [
      for (int i = 0; i < every.length; i++) booking(id: 'b$i', createdAt: DateTime(2026, 9, 1 + i), status: every[i]),
      booking(id: 'unknown', createdAt: DateTime(2026, 9, 10), status: 'Order Something'),
      booking(id: 'out', createdAt: DateTime(2026, 10, 1), status: ORDER_STATUS_COMPLETED),
    ];
    List<String> ids(BookingStatusFilter f) => buildBookingExportRows(orders, range, currencyFor: currencyFor, status: f).map((r) => r.id).toList();

    test('choices: All statuses first, then the booking list groups', () {
      expect(BookingStatusFilter.values.map((f) => f.labelKey), ['All statuses', 'Pending', 'Accepted', 'On Going', 'Completed', 'Cancelled / Rejected']);
      expect(BookingStatusFilter.values.first, same(BookingStatusFilter.all));
      expect(BookingStatusFilter.all.isAll, isTrue);
      expect(BookingStatusFilter.completed.isAll, isFalse);
    });

    test('the groups cover every exported status exactly once', () {
      final grouped = [for (final f in BookingStatusFilter.values.skip(1)) ...f.statuses];
      expect(grouped.toSet(), exportedBookingStatuses.toSet());
      expect(grouped.length, exportedBookingStatuses.length);
      expect(BookingStatusFilter.all.statuses, exportedBookingStatuses);
    });

    test('all statuses: every booking-list status of the period, by default', () {
      expect(buildBookingExportRows(orders, range, currencyFor: currencyFor).map((r) => r.id), ['b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6']);
      expect(ids(BookingStatusFilter.all), ['b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6']);
    });

    test('one status group: only its bookings of the period', () {
      expect(ids(BookingStatusFilter.pending), ['b0']);
      expect(ids(BookingStatusFilter.accepted), ['b1', 'b2']);
      expect(ids(BookingStatusFilter.ongoing), ['b3']);
      expect(ids(BookingStatusFilter.completed), ['b4']);
      expect(ids(BookingStatusFilter.cancelled), ['b5', 'b6']);
    });

    test('row labels match the chosen group', () {
      for (final f in BookingStatusFilter.values.skip(1)) {
        for (final row in buildBookingExportRows(orders, range, currencyFor: currencyFor, status: f)) {
          expect(f.labelKey.contains(row.statusLabel), isTrue, reason: '${f.id}: ${row.statusLabel}');
        }
      }
    });

    test('file-name part: letters and digits of any script, "-" between', () {
      expect(fileNamePart('All statuses'), 'all-statuses');
      expect(fileNamePart('  Cancelled / Rejected  '), 'cancelled-rejected');
      expect(fileNamePart('a/b\\c:d*e?f"g<h>i|j'), 'a-b-c-d-e-f-g-h-i-j');
      expect(fileNamePart('../../etc'), 'etc');
      expect(fileNamePart('ملغى / مرفوض'), 'ملغى-مرفوض');
      expect(fileNamePart('مُسند'), 'مُسند');
      expect(fileNamePart(' / '), 'all');
    });

    test('empty message names the status, except for all statuses', () {
      expect(noBookingsMessage(BookingStatusFilter.all), 'No bookings in this period.');
      expect(noBookingsMessage(BookingStatusFilter.completed), 'No bookings with the status "Completed" in this period.');
    });

    group('translated', () {
      setUp(() {
        Get.addTranslations({'ar': lnAr});
        Get.locale = const Locale('ar');
      });
      tearDown(() {
        Get.locale = const Locale('en');
        Get.translations.clear();
      });

      test('labels, empty message and file name', () {
        expect(BookingStatusFilter.values.map((f) => f.label), ['كل الحالات', 'قيد الانتظار', 'مقبول', 'جارٍ', 'مكتمل', 'ملغى / مرفوض']);
        expect(noBookingsMessage(BookingStatusFilter.completed), 'لا توجد حجوزات بالحالة "مكتمل" في هذه الفترة.');
        expect(noBookingsMessage(BookingStatusFilter.all), 'لا توجد حجوزات في هذه الفترة.');
        expect(
          bookingsExportFileName(ExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7)), BookingStatusFilter.cancelled.label),
          'orders_ملغى-مرفوض_2026-09-08_2026-10-07.pdf',
        );
        // The PDF fonts cannot write Arabic: the status is printed in English.
        expect(BookingsHistoryPdf.pdfLabel(BookingStatusFilter.cancelled.labelKey), 'Cancelled / Rejected');
      });
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
    final bytes = BookingsHistoryPdf.build(range: range, rows: rows, status: BookingStatusFilter.completed, generatedAt: DateTime(2026, 7, 1));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    expect(doc.pages.count, greaterThan(1));
    final String text = PdfTextExtractor(doc).extractText();
    expect(text, contains('Booking history'));
    expect(text, contains('Status'));
    expect(text, contains('Completed'));
    expect(text, contains('01 Jan 2026 - 30 Jun 2026'));
    expect(text, contains('#ooking-0'));
    expect(text, contains('#king-179'));
    doc.dispose();
  });
}
