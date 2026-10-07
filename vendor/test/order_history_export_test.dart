import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/order_history_export.dart';
import 'package:vendor/utils/order_history_pdf.dart';

final CurrencyModel usd = CurrencyModel(code: 'USD', symbol: r'$', decimalDigits: 2, symbolAtRight: false);
final CurrencyModel eur = CurrencyModel(code: 'EUR', symbol: 'EUR', decimalDigits: 2, symbolAtRight: true);

OrderModel order(String id, DateTime? createdAt, {String status = Constant.orderCompleted, String? regionId, bool takeAway = false}) =>
    OrderModel(id: id, createdAt: createdAt == null ? null : Timestamp.fromDate(createdAt), status: status, takeAway: takeAway)..regionId = regionId;

OrderExportRow row(String id, double? amount, {CurrencyModel? currency, String status = Constant.orderCompleted, DateTime? at}) =>
    OrderExportRow(orderId: id, createdAt: at ?? DateTime(2026, 10, 1), takeAway: false, status: status, amount: amount, currency: currency);

void main() {
  setUp(() {
    Constant.currencyModel = usd;
  });

  group('period rules', () {
    test('the default period is the last 30 days, today included', () {
      final OrderExportRange r = OrderExportRange.lastDays(DateTime(2026, 10, 7, 15, 30));
      expect(r.from, DateTime(2026, 9, 8));
      expect(r.to, DateTime(2026, 10, 7));
      expect(r.dayCount, 30);
      expect(OrderExportRange.check(r.from, r.to), isNull);
    });

    test('the default period crosses month and year boundaries', () {
      final OrderExportRange r = OrderExportRange.lastDays(DateTime(2026, 1, 10));
      expect(r.from, DateTime(2025, 12, 12));
      expect(r.to, DateTime(2026, 1, 10));
    });

    test('both dates are required and the end is on or after the start', () {
      expect(OrderExportRange.check(null, DateTime(2026, 1, 1)), OrderExportRangeError.missingDates);
      expect(OrderExportRange.check(DateTime(2026, 1, 1), null), OrderExportRangeError.missingDates);
      expect(OrderExportRange.check(DateTime(2026, 1, 2), DateTime(2026, 1, 1)), OrderExportRangeError.endBeforeStart);
      // Same day (times are ignored).
      expect(OrderExportRange.check(DateTime(2026, 1, 1, 18), DateTime(2026, 1, 1, 9)), isNull);
    });

    test('a period may be up to one year long', () {
      expect(OrderExportRange.check(DateTime(2025, 10, 8), DateTime(2026, 10, 7)), isNull);
      expect(OrderExportRange.check(DateTime(2025, 10, 7), DateTime(2026, 10, 7)), OrderExportRangeError.tooLong);
      expect(OrderExportRange.check(DateTime(2024, 1, 1), DateTime(2026, 1, 1)), OrderExportRangeError.tooLong);
      // From 29 Feb: the year ends on 28 Feb (29 Feb 2025 does not exist).
      expect(OrderExportRange.check(DateTime(2024, 2, 29), DateTime(2025, 2, 28)), isNull);
      expect(OrderExportRange.check(DateTime(2024, 2, 29), DateTime(2025, 3, 1)), OrderExportRangeError.tooLong);
      expect(OrderExportRange(DateTime(2025, 10, 8), DateTime(2026, 10, 7)).dayCount, 365);
    });

    test('every error has a message', () {
      for (final OrderExportRangeError e in OrderExportRangeError.values) {
        expect(OrderExportRange.messageOf(e), isNotEmpty);
      }
    });

    test('bounds are local day boundaries, both days included', () {
      final OrderExportRange r = OrderExportRange(DateTime(2026, 9, 1, 13), DateTime(2026, 9, 30, 8));
      expect(r.start, DateTime(2026, 9, 1));
      expect(r.endExclusive, DateTime(2026, 10, 1));
      expect(r.contains(DateTime(2026, 9, 1)), isTrue);
      expect(r.contains(DateTime(2026, 9, 30, 23, 59, 59, 999)), isTrue);
      expect(r.contains(DateTime(2026, 10, 1)), isFalse);
      expect(r.contains(DateTime(2026, 8, 31, 23, 59, 59, 999)), isFalse);
    });

    test('day count is not thrown off by a clock change', () {
      expect(OrderExportRange(DateTime(2026, 3, 1), DateTime(2026, 3, 31)).dayCount, 31);
      expect(OrderExportRange(DateTime(2026, 10, 1), DateTime(2026, 11, 30)).dayCount, 61);
    });

    test('file name carries the period', () {
      expect(OrderExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7)).fileName, 'orders_2026-09-08_2026-10-07.pdf');
      expect(OrderExportRange(DateTime(2026, 1, 5), DateTime(2026, 1, 5)).fileName, 'orders_2026-01-05_2026-01-05.pdf');
    });
  });

  group('rows', () {
    final OrderExportRange range = OrderExportRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

    test('only orders created in the period, once each, oldest first', () async {
      final List<OrderModel> orders = [
        order('order-c-0000000003', DateTime(2026, 9, 30, 23, 59), regionId: 'eu'),
        order('order-a-0000000001', DateTime(2026, 9, 1, 0, 0), takeAway: true),
        order('order-b-0000000002', DateTime(2026, 9, 15, 12)),
        order('order-b-0000000002', DateTime(2026, 9, 15, 12)), // duplicate
        order('order-x-0000000009', DateTime(2026, 10, 1)), // after
        order('order-y-0000000008', DateTime(2026, 8, 31, 23, 59)), // before
        order('order-z-0000000007', null), // no creation time
      ];
      final List<OrderExportRow> rows = await OrderHistoryExport.buildRows(
        orders,
        range: range,
        amountOf: (o) => o.id == 'order-b-0000000002' ? null : 10.0,
        currencyOf: (regionId) => regionId == 'eu' ? eur : usd,
      );
      expect(rows.map((r) => r.orderId), ['order-a-0000000001', 'order-b-0000000002', 'order-c-0000000003']);
      expect(rows[0].takeAway, isTrue);
      expect(rows[1].amount, isNull);
      expect(rows[2].currency, same(eur));
      expect(rows[0].shortId, Constant.orderId(orderId: 'order-a-0000000001'));
    });

    test('a short order id does not throw', () {
      expect(row('abc', 1).shortId, '#abc');
    });

    test('the amount is the order card total', () {
      final OrderModel o = OrderModel(
        id: 'priced-order-0001',
        status: Constant.orderCompleted,
        products: [
          CartProductModel.fromJson({'price': '10', 'discountPrice': '0', 'quantity': 2, 'extras_price': '1'}),
        ],
        discount: 2,
        deliveryCharge: '5',
        tipAmount: '1',
        platformFee: '0',
        taxScope: 'order',
        taxSetting: [TaxModel.fromJson({'enable': true, 'type': 'percentage', 'tax': '10', 'title': 'VAT'})],
        packagingChargeEnable: false,
        takeAway: true,
      );
      // (2 x 10 + 2 x 1) - 2 discount = 20, + 10 % order tax = 22. Delivery
      // and tip are not part of the store total, as on the order card.
      expect(OrderHistoryExport.storeTotalOf(o), closeTo(22, 1e-9));
    });

    test('fields the card total does not read never drop the amount', () {
      final OrderModel o = OrderModel(
        id: 'odd-fields-0001',
        status: Constant.orderCompleted,
        products: [
          CartProductModel.fromJson({'price': '10', 'discountPrice': '0', 'quantity': 1, 'extras_price': '0'}),
        ],
        discount: 0,
        deliveryCharge: 'abc',
        tipAmount: '',
        platformFee: 'x',
        taxScope: 'order',
        packagingChargeEnable: false,
        vendor: VendorModel(packagingCharge: ''),
      );
      expect(OrderHistoryExport.storeTotalOf(o), closeTo(10, 1e-9));
    });

    test('an order that cannot be priced gives no amount instead of failing the export', () {
      expect(OrderHistoryExport.storeTotalOf(OrderModel(id: 'broken')), isNull);
    });
  });

  group('summary', () {
    test('totals per currency, without cancelled, rejected or unpriced orders', () {
      final OrderExportSummary s = OrderExportSummary.of([
        row('1', 10.005, currency: usd),
        row('2', 5.5, currency: eur),
        row('3', 2.25, currency: usd),
        row('4', 100, currency: usd, status: Constant.orderCancelled),
        row('5', 100, currency: eur, status: Constant.orderRejected),
        row('6', null, currency: usd),
      ]);
      expect(s.orderCount, 6);
      expect(s.excludedCount, 2);
      expect(s.unpricedCount, 1);
      expect(s.totals.map((t) => t.key), ['USD', 'EUR']);
      // 10.005 is printed as 10.01: the total adds the printed amounts.
      expect(s.totals[0].amount, closeTo(12.26, 1e-9));
      expect(s.totals[0].orders, 2);
      expect(s.totals[1].amount, closeTo(5.5, 1e-9));
      expect(s.totals[1].orders, 1);
    });

    test('currencies are grouped by code, falling back to the symbol', () {
      expect(OrderExportRow.currencyKeyOf(CurrencyModel(code: 'usd', symbol: r'$')), 'USD');
      expect(OrderExportRow.currencyKeyOf(CurrencyModel(code: '', symbol: 'Fr')), 'Fr');
      expect(OrderExportRow.currencyKeyOf(null), '');
    });

    test('no countable order gives no total', () {
      final OrderExportSummary s = OrderExportSummary.of([row('1', 3, status: Constant.orderCancelled)]);
      expect(s.totals, isEmpty);
      expect(s.orderCount, 1);
    });

    test('rounding follows the currency decimals', () {
      expect(OrderExportSummary.roundTo(1.005, 0), 1);
      expect(OrderExportSummary.roundTo(1.236, 2), 1.24);
      expect(OrderExportSummary.roundTo(1.2364, 3), 1.236);
      // Same rounding as the printed row (toStringAsFixed): 1.115 is stored
      // just under 1.115 and prints "1.11", so it is totalled as 1.11.
      expect(OrderExportSummary.roundTo(1.115, 2), double.parse(1.115.toStringAsFixed(2)));
    });
  });

  group('pdf', () {
    tearDown(() => Get.locale = null);

    test('a long period paginates into a valid multi-page PDF', () {
      final OrderExportRange range = OrderExportRange(DateTime(2026, 1, 1), DateTime(2026, 6, 30));
      final List<OrderExportRow> rows = [
        for (int i = 0; i < 180; i++)
          row('order-${i.toString().padLeft(14, '0')}', i * 1.5, currency: i.isEven ? usd : eur, at: DateTime(2026, 1, 1).add(Duration(hours: i * 12)), status: i % 10 == 0 ? Constant.orderCancelled : Constant.orderCompleted),
      ];
      final List<int> bytes = OrderHistoryPdf.build(
        range: range,
        rows: rows,
        summary: OrderExportSummary.of(rows),
        appName: 'spideli Store',
        storeName: 'Test Store',
        generatedAt: DateTime(2026, 7, 1, 9),
      );
      final String head = latin1.decode(bytes.take(5).toList());
      expect(head, '%PDF-');
      // Several pages for 180 rows.
      final int pages = RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(bytes)).length;
      expect(pages, greaterThan(2));
    });

    test('labels the standard PDF fonts cannot draw fall back to English', () {
      Get.addTranslations({
        'fr': {'Status': 'Statut'},
        'ar': {'Status': 'الحالة'},
      });
      Get.locale = const Locale('fr');
      expect(OrderHistoryPdf.label('Status'), 'Statut');
      Get.locale = const Locale('ar');
      expect(OrderHistoryPdf.label('Status'), 'Status');
      expect(OrderHistoryPdf.labelParams('@count days', {'count': '3'}), '3 days');
      expect(OrderHistoryPdf.safe('Café م'), 'Café ?');
    });
  });
}
