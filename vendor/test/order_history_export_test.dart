import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/order_history_export.dart';
import 'package:vendor/utils/order_history_pdf.dart';

final CurrencyModel usd = CurrencyModel(code: 'USD', symbol: r'$', decimalDigits: 2, symbolAtRight: false);
final CurrencyModel eur = CurrencyModel(code: 'EUR', symbol: 'EUR', decimalDigits: 2, symbolAtRight: true);

OrderModel order(String id, DateTime? createdAt, {String status = Constant.orderCompleted, String? regionId, bool takeAway = false, DateTime? scheduleTime}) =>
    OrderModel(
      id: id,
      createdAt: createdAt == null ? null : Timestamp.fromDate(createdAt),
      status: status,
      takeAway: takeAway,
      scheduleTime: scheduleTime == null ? null : Timestamp.fromDate(scheduleTime),
    )..regionId = regionId;

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
      expect(OrderExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7)).fileName(), 'orders_2026-09-08_2026-10-07.pdf');
      expect(OrderExportRange(DateTime(2026, 1, 5), DateTime(2026, 1, 5)).fileName(), 'orders_2026-01-05_2026-01-05.pdf');
    });

    test('file name carries the status, sanitised', () {
      final OrderExportRange r = OrderExportRange(DateTime(2026, 9, 8), DateTime(2026, 10, 7));
      expect(r.fileName(status: 'Preparing'), 'orders_preparing_2026-09-08_2026-10-07.pdf');
      expect(r.fileName(status: 'All statuses'), 'orders_all-statuses_2026-09-08_2026-10-07.pdf');
      expect(r.fileName(status: ' En préparation / Prêtes! '), 'orders_en-préparation-prêtes_2026-09-08_2026-10-07.pdf');
      expect(r.fileName(status: '../a\\b:c*?"<>|'), 'orders_a-b-c_2026-09-08_2026-10-07.pdf');
      // Nothing usable: no status part.
      expect(r.fileName(status: ' /.. '), 'orders_2026-09-08_2026-10-07.pdf');
    });

    test('file name parts are length-limited and never end with a dash', () {
      expect(OrderExportRange.fileNamePart('a' * 60).length, 40);
      expect(OrderExportRange.fileNamePart('${'a' * 39} b'), 'a' * 39);
      expect(OrderExportRange.fileNamePart('Готовятся'), 'готовятся');
      expect(OrderExportRange.fileNamePart('准备中'), '准备中');
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

  group('status', () {
    final OrderExportRange range = OrderExportRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    final DateTime now = DateTime(2026, 9, 20, 12);
    final List<OrderModel> orders = [
      order('placed-now-00000001', DateTime(2026, 9, 20, 10), status: Constant.orderPlaced),
      order('placed-due-00000002', DateTime(2026, 9, 19), status: Constant.orderPlaced, scheduleTime: DateTime(2026, 9, 20, 11)),
      order('placed-later-000003', DateTime(2026, 9, 19), status: Constant.orderPlaced, scheduleTime: DateTime(2026, 9, 21, 9)),
      order('accepted-00000000004', DateTime(2026, 9, 2), status: Constant.orderAccepted),
      order('drv-pending-0000005', DateTime(2026, 9, 3), status: Constant.driverPending),
      order('drv-rejected-000006', DateTime(2026, 9, 4), status: Constant.driverRejected),
      order('drv-accepted-000007', DateTime(2026, 9, 5), status: Constant.driverAccepted),
      order('shipped-000000000008', DateTime(2026, 9, 6), status: Constant.orderShipped),
      order('in-transit-000000009', DateTime(2026, 9, 7), status: Constant.orderInTransit),
      order('completed-0000000010', DateTime(2026, 9, 8), status: Constant.orderCompleted),
      order('rejected-00000000011', DateTime(2026, 9, 9), status: Constant.orderRejected),
      order('cancelled-0000000012', DateTime(2026, 9, 10), status: Constant.orderCancelled),
      order('unknown-000000000013', DateTime(2026, 9, 11), status: 'Something Else'),
      order('outside-000000000014', DateTime(2026, 10, 2), status: Constant.orderCompleted), // after the period
    ];

    Future<List<String>> idsFor(OrderExportStatus status, {Duration lead = Duration.zero}) async {
      final List<OrderExportRow> rows = await OrderHistoryExport.buildRows(orders, range: range, amountOf: (_) => 1.0, currencyOf: (_) => usd, status: status, now: now, lead: lead);
      return rows.map((r) => r.orderId).toList();
    }

    test('the choices are All statuses then the home tabs, in order', () {
      expect(OrderExportStatus.values.first, OrderExportStatus.all);
      expect(OrderExportStatus.values.map((s) => s.labelKey), ['All statuses', 'New', 'Scheduled', 'Preparing', 'Ready', 'Completed', 'Rejected', 'Cancelled']);
    });

    test('groups use the home screen statuses', () {
      expect(OrderExportStatus.all.statuses, isEmpty);
      expect(OrderExportStatus.newOrders.statuses, [Constant.orderPlaced]);
      expect(OrderExportStatus.scheduled.statuses, [Constant.orderPlaced]);
      expect(OrderExportStatus.preparing.statuses, HomeController.preparingStatuses);
      expect(OrderExportStatus.ready.statuses, HomeController.readyStatuses);
      expect(OrderExportStatus.completed.statuses, [Constant.orderCompleted]);
      expect(OrderExportStatus.rejected.statuses, [Constant.orderRejected]);
      expect(OrderExportStatus.cancelled.statuses, [Constant.orderCancelled]);
    });

    test('all statuses keeps every order of the period, also an unknown status', () async {
      final List<String> ids = await idsFor(OrderExportStatus.all);
      expect(ids.length, 13);
      expect(ids, contains('unknown-000000000013'));
      expect(ids, isNot(contains('outside-000000000014')));
    });

    test('each status exports only its orders', () async {
      expect(await idsFor(OrderExportStatus.newOrders), unorderedEquals(['placed-now-00000001', 'placed-due-00000002']));
      expect(await idsFor(OrderExportStatus.scheduled), ['placed-later-000003']);
      expect(await idsFor(OrderExportStatus.preparing), ['accepted-00000000004', 'drv-pending-0000005', 'drv-rejected-000006', 'drv-accepted-000007']);
      expect(await idsFor(OrderExportStatus.ready), ['shipped-000000000008', 'in-transit-000000009']);
      expect(await idsFor(OrderExportStatus.completed), ['completed-0000000010']);
      expect(await idsFor(OrderExportStatus.rejected), ['rejected-00000000011']);
      expect(await idsFor(OrderExportStatus.cancelled), ['cancelled-0000000012']);
    });

    test('a scheduled order is New once its due time (minus the lead time) has come', () async {
      // Due at 21 Sep 09:00 - 22 h = 20 Sep 11:00, before "now".
      expect(await idsFor(OrderExportStatus.scheduled, lead: const Duration(hours: 22)), isEmpty);
      expect(await idsFor(OrderExportStatus.newOrders, lead: const Duration(hours: 22)), contains('placed-later-000003'));
      final OrderModel o = orders[2];
      expect(OrderExportStatus.scheduled.matches(o, now: now), isTrue);
      expect(OrderExportStatus.newOrders.matches(o, now: DateTime(2026, 9, 21, 9)), isTrue);
    });

    test('every status choice has a file name', () {
      for (final OrderExportStatus status in OrderExportStatus.values) {
        final String name = OrderHistoryPdf.fileName(range, status);
        expect(name, startsWith('orders_'));
        expect(name, endsWith('_2026-09-01_2026-09-30.pdf'));
        expect(name, isNot(contains(' ')));
      }
      expect(OrderHistoryPdf.fileName(range, OrderExportStatus.newOrders), 'orders_new_2026-09-01_2026-09-30.pdf');
    });

    test('the status label is translated when the PDF fonts can draw it', () {
      Get.addTranslations({
        'fr': {'Preparing': 'En préparation'},
        'ru': {'Preparing': 'Готовятся'},
      });
      Get.locale = const Locale('fr');
      expect(OrderHistoryPdf.statusText(OrderExportStatus.preparing), 'En préparation');
      expect(OrderHistoryPdf.fileName(range, OrderExportStatus.preparing), 'orders_en-préparation_2026-09-01_2026-09-30.pdf');
      Get.locale = const Locale('ru');
      expect(OrderHistoryPdf.statusText(OrderExportStatus.preparing), 'Preparing');
      expect(OrderHistoryPdf.fileName(range, OrderExportStatus.preparing), 'orders_preparing_2026-09-01_2026-09-30.pdf');
      Get.locale = null;
    });

    test('every status label and message is translated in every language', () {
      final Map<String, Map<String, String>> languages = {'ar': lnAr, 'de': deGR, 'en': enUS, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
      final List<String> keys = [
        for (final OrderExportStatus status in OrderExportStatus.values) status.labelKey,
        'Status',
        'Every order of the store created in the chosen period with the chosen status is included. The period can be up to one year.',
        'There is no order with the status @status between @from and @to. Choose another period or status to export.',
        'Orders in every status.',
        'Placed orders the store can accept or reject now.',
        'Placed orders waiting for their scheduled time.',
        'Includes: @statuses',
      ];
      for (final MapEntry<String, Map<String, String>> language in languages.entries) {
        for (final String key in keys) {
          expect(language.value[key], isNotNull, reason: '${language.key}: $key');
          for (final String param in RegExp(r'@\w+').allMatches(key).map((m) => m[0]!)) {
            expect(language.value[key], contains(param), reason: '${language.key}: $key');
          }
        }
      }
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
        status: OrderExportStatus.completed,
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
