import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/rental_package_model.dart';
import 'package:customer/utils/order_history_export.dart';
import 'package:customer/utils/order_history_export_service.dart';
import 'package:customer/utils/order_history_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// "Export my order history as a PDF over a period": the period rules, the
/// rows, the totals per currency, the file name and the PDF itself.
void main() {
  final CurrencyModel usd = CurrencyModel(id: 'usd', code: 'USD', symbol: r'$', decimal: 2);
  final CurrencyModel eur = CurrencyModel(id: 'eur', code: 'EUR', symbol: 'EUR', decimal: 2, symbolatright: true);
  final CurrencyModel xof = CurrencyModel(id: 'xof', code: 'XOF', symbol: 'F CFA', decimal: 0, symbolatright: true);

  OrderExportRow row(DateTime? at, double? amount, CurrencyModel? currency, {String status = 'Order Completed', String id = 'abcdefghijkl'}) =>
      OrderExportRow(createdAt: at, orderId: id, type: 'Ride', status: status, amount: amount, currency: currency);

  group('ExportPeriod', () {
    test('defaults to the last 30 days, today included', () {
      final ExportPeriod p = ExportPeriod.lastDays(DateTime(2026, 10, 7, 15, 42));
      expect(p.from, DateTime(2026, 9, 8));
      expect(p.to, DateTime(2026, 10, 7));
      expect(p.to.difference(p.from).inDays + 1, 30);
      expect(ExportPeriod.validate(p.from, p.to), isNull);
    });

    test('works on local days: the time of day is ignored, both ends are included', () {
      final ExportPeriod p = ExportPeriod(DateTime(2026, 9, 1, 18, 30), DateTime(2026, 9, 30, 6));
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.endExclusive, DateTime(2026, 10, 1));
      expect(p.contains(DateTime(2026, 9, 1)), isTrue);
      expect(p.contains(DateTime(2026, 9, 30, 23, 59, 59, 999)), isTrue);
      expect(p.contains(DateTime(2026, 10, 1)), isFalse);
      expect(p.contains(DateTime(2026, 8, 31, 23, 59, 59)), isFalse);
      expect(p.contains(null), isFalse);
    });

    test('a single day is a valid period', () {
      expect(ExportPeriod.validate(DateTime(2026, 10, 7, 9), DateTime(2026, 10, 7, 8)), isNull);
      final ExportPeriod p = ExportPeriod(DateTime(2026, 10, 7), DateTime(2026, 10, 7));
      expect(p.contains(DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(p.contains(DateTime(2026, 10, 8)), isFalse);
    });

    test('both dates are required', () {
      expect(ExportPeriod.validate(null, DateTime(2026, 10, 7)), ExportPeriodError.missing);
      expect(ExportPeriod.validate(DateTime(2026, 10, 7), null), ExportPeriodError.missing);
    });

    test('the end may not be before the start', () {
      expect(ExportPeriod.validate(DateTime(2026, 10, 7), DateTime(2026, 10, 6)), ExportPeriodError.endBeforeStart);
    });

    test('a year at most', () {
      expect(ExportPeriod.validate(DateTime(2025, 10, 7), DateTime(2026, 10, 7)), isNull);
      expect(ExportPeriod.validate(DateTime(2025, 10, 6), DateTime(2026, 10, 7)), ExportPeriodError.tooLong);
      expect(ExportPeriod.validate(DateTime(2020, 1, 1), DateTime(2026, 10, 7)), ExportPeriodError.tooLong);
      // From a leap day: one year back is 1 March of the year before.
      expect(ExportPeriod.validate(DateTime(2023, 3, 1), DateTime(2024, 2, 29)), isNull);
      expect(ExportPeriod.validate(DateTime(2023, 2, 28), DateTime(2024, 2, 29)), ExportPeriodError.tooLong);
    });

    test('every error has a message', () {
      for (final ExportPeriodError e in ExportPeriodError.values) {
        expect(ExportPeriod.errorMessage(e), isNotEmpty);
      }
    });

    test('file name is orders_<from>_<to>.pdf', () {
      expect(ExportPeriod(DateTime(2026, 9, 8), DateTime(2026, 10, 7)).fileName, 'orders_2026-09-08_2026-10-07.pdf');
      expect(ExportPeriod(DateTime(2026, 1, 2, 23), DateTime(2026, 1, 2, 1)).fileName, 'orders_2026-01-02_2026-01-02.pdf');
    });
  });

  group('rows and totals', () {
    test('totals are kept per currency, in the order the currencies first appear', () {
      final OrderExportSummary s = OrderHistoryExport.summarize([
        row(DateTime(2026, 9, 1), 10.5, eur),
        row(DateTime(2026, 9, 2), 4.25, usd),
        row(DateTime(2026, 9, 3), 1.5, eur),
        row(DateTime(2026, 9, 4), 2000, xof),
      ]);
      expect(s.orderCount, 4);
      expect(s.totals.map((t) => t.currency?.code), ['EUR', 'USD', 'XOF']);
      expect(s.totals[0].amount, closeTo(12.0, 1e-9));
      expect(s.totals[0].orderCount, 2);
      expect(s.totals[1].amount, closeTo(4.25, 1e-9));
      expect(s.totals[2].amount, 2000);
    });

    test('cancelled and rejected orders are listed but not totalled; Driver Rejected still counts', () {
      final OrderExportSummary s = OrderHistoryExport.summarize([
        row(DateTime(2026, 9, 1), 10, usd),
        row(DateTime(2026, 9, 2), 99, usd, status: 'Order Cancelled'),
        row(DateTime(2026, 9, 3), 99, usd, status: 'Order Rejected'),
        row(DateTime(2026, 9, 4), 5, usd, status: 'Driver Rejected'),
      ]);
      expect(s.orderCount, 4);
      expect(s.voidedCount, 2);
      expect(s.totals.single.amount, 15);
      expect(s.totals.single.orderCount, 2);
    });

    test('booking histories void what their Cancelled tab lists; a dispatched Driver Rejected is back with dispatch, never voided; My Order keeps the receipt rule', () {
      for (final OrderHistoryKind kind in [OrderHistoryKind.rides, OrderHistoryKind.parcels, OrderHistoryKind.rentals, OrderHistoryKind.onDemand]) {
        // provider_orders are not dispatched: their Booking History files
        // "Driver Rejected" under Cancelled, and the PDF follows it.
        expect(OrderHistoryExport.isVoided(kind, 'Driver Rejected'), kind == OrderHistoryKind.onDemand, reason: '$kind');
        expect(OrderHistoryExport.isVoided(kind, 'Driver Pending'), isFalse, reason: '$kind');
        expect(OrderHistoryExport.isVoided(kind, 'Order Cancelled'), isTrue, reason: '$kind');
        expect(OrderHistoryExport.isVoided(kind, 'Order Rejected'), isTrue, reason: '$kind');
        expect(OrderHistoryExport.isVoided(kind, 'Order Completed'), isFalse, reason: '$kind');
        expect(OrderHistoryExport.isVoided(kind, null), isFalse, reason: '$kind');
      }
      expect(OrderHistoryExport.isVoided(OrderHistoryKind.shopping, 'Driver Rejected'), isFalse);
      expect(OrderHistoryExport.isVoided(OrderHistoryKind.shopping, 'Order Rejected'), isTrue);

      expect(OrderHistoryExport.bookingCancelledStatuses, {'Order Rejected', 'Order Cancelled'});
      expect(OrderHistoryExport.onDemandCancelledStatuses, {'Order Rejected', 'Order Cancelled', 'Driver Rejected'});

      // A Driver Rejected ride, parcel or rental is waiting for the next
      // driver: it is totalled like any live booking.
      final OrderExportSummary s = OrderHistoryExport.summarize([
        row(DateTime(2026, 9, 1), 10, usd),
        for (final OrderHistoryKind kind in [OrderHistoryKind.rides, OrderHistoryKind.parcels, OrderHistoryKind.rentals])
          OrderExportRow(createdAt: DateTime(2026, 9, 2), orderId: '$kind', type: 'Booking', status: 'Driver Rejected', amount: 7, currency: usd, voided: OrderHistoryExport.isVoided(kind, 'Driver Rejected')),
      ]);
      expect(s.voidedCount, 0);
      expect(s.totals.single.amount, 31);
    });

    test('two currency documents of the same currency share one total line', () {
      final OrderExportSummary s = OrderHistoryExport.summarize([
        row(DateTime(2026, 9, 1), 1, CurrencyModel(id: 'eur-fr', code: 'EUR', symbol: 'EUR', decimal: 2, symbolatright: true)),
        row(DateTime(2026, 9, 2), 2, CurrencyModel(id: 'eur-be', code: 'EUR', symbol: 'EUR', decimal: 2, symbolatright: true)),
        row(DateTime(2026, 9, 3), 4, usd),
      ]);
      expect(s.totals.map((t) => t.currency?.code), ['EUR', 'USD']);
      expect(s.totals[0].amount, 3);
      expect(s.totals[0].orderCount, 2);
    });

    test('a rental whose total cannot be computed is skipped before the controller (no error toast)', () {
      RentalOrderModel rental({Timestamp? start, Timestamp? end, String? startKm, String? endKm, String? included = '10', String? platformFee}) => RentalOrderModel(
        startTime: start,
        endTime: end,
        startKitoMetersReading: startKm,
        endKitoMetersReading: endKm,
        rentalPackageModel: RentalPackageModel(includedDistance: included),
        platformFee: platformFee,
      );
      final Timestamp t = Timestamp.fromDate(DateTime(2026, 9, 1));
      expect(OrderHistoryExportService.rentalTotalWouldFail(rental(start: t, end: t, startKm: '0', endKm: '50')), isFalse);
      expect(OrderHistoryExportService.rentalTotalWouldFail(rental(end: t)), isTrue);
      expect(OrderHistoryExportService.rentalTotalWouldFail(rental(startKm: '0', endKm: '50', included: null)), isTrue);
      expect(OrderHistoryExportService.rentalTotalWouldFail(rental(startKm: '50', endKm: '50', included: null)), isFalse);
      expect(OrderHistoryExportService.rentalTotalWouldFail(rental(platformFee: 'abc')), isTrue);
    });

    test('an order whose amount could not be computed is counted, not totalled', () {
      final OrderExportSummary s = OrderHistoryExport.summarize([row(DateTime(2026, 9, 1), null, usd), row(DateTime(2026, 9, 2), double.nan, usd), row(DateTime(2026, 9, 3), 3, usd)]);
      expect(s.orderCount, 3);
      expect(s.missingAmountCount, 2);
      expect(s.totals.single.amount, 3);
    });

    test('a currency without an id is told apart by code and symbol', () {
      final OrderExportSummary s = OrderHistoryExport.summarize([
        row(DateTime(2026, 9, 1), 1, CurrencyModel(code: 'USD', symbol: r'$')),
        row(DateTime(2026, 9, 2), 2, CurrencyModel(code: 'USD', symbol: r'$')),
        row(DateTime(2026, 9, 3), 4, null),
      ]);
      expect(s.totals.length, 2);
      expect(s.totals[0].amount, 3);
      expect(s.totals[1].currency, isNull);
      expect(s.totals[1].amount, 4);
    });

    test('no orders: no totals', () {
      final OrderExportSummary s = OrderHistoryExport.summarize(const []);
      expect(s.orderCount, 0);
      expect(s.totals, isEmpty);
    });

    test('rows read oldest first; undated rows last; ties keep their order', () {
      final List<OrderExportRow> sorted = OrderHistoryExport.sortRows([
        row(DateTime(2026, 9, 3), 1, usd, id: 'c'),
        row(null, 1, usd, id: 'x'),
        row(DateTime(2026, 9, 1), 1, usd, id: 'a'),
        row(DateTime(2026, 9, 3), 1, usd, id: 'd'),
      ]);
      expect(sorted.map((r) => r.orderId), ['a', 'c', 'd', 'x']);
    });

    test('order ids are shortened to their last 8 characters', () {
      expect(OrderHistoryExport.shortId('abcdefghijkl'), '#efghijkl');
      expect(OrderHistoryExport.shortId('abc'), '#abc');
      expect(OrderHistoryExport.shortId('  '), '-');
    });

    test('amounts use the order currency as the app shows them', () {
      expect(OrderHistoryExport.money(12.5, usd), r'$ 12.50');
      expect(OrderHistoryExport.money(12.5, eur), '12.50 EUR');
      expect(OrderHistoryExport.money(2000.4, xof), '2000 F CFA');
      expect(OrderHistoryExport.money(null, usd), '-');
      // A symbol the PDF font cannot draw is written as the currency code.
      expect(OrderHistoryExport.money(3, CurrencyModel(id: 'inr', code: 'INR', symbol: '₹', decimal: 2)), 'INR 3.00');
    });

    test('labels the PDF font cannot draw fall back to the English text', () {
      expect(OrderHistoryExport.printable('Statut', 'Status'), 'Statut');
      expect(OrderHistoryExport.printable('الحالة', 'Status'), 'Status');
    });
  });

  group('PDF', () {
    final OrderHistoryPdfHeader header = OrderHistoryPdfHeader(
      appName: 'Spideli',
      customerName: 'Jane Doe',
      title: 'Ride History',
      serviceName: 'Cab',
      period: ExportPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
      statusLabel: 'All statuses',
      generatedAt: DateTime(2026, 10, 7, 10, 30),
    );

    test('a long period paginates onto several pages', () {
      final List<OrderExportRow> rows = [
        for (int i = 0; i < 150; i++) row(DateTime(2026, 9, 1 + i % 30, 10, i % 60), 10.0 + i, i.isEven ? usd : eur, status: i % 10 == 0 ? 'Order Cancelled' : 'Order Completed', id: 'order-$i-xyz'),
      ];
      final List<int> bytes = OrderHistoryPdf.build(header, rows, OrderHistoryExport.summarize(rows));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final PdfDocument doc = PdfDocument(inputBytes: bytes);
      expect(doc.pages.count, greaterThan(1));
      doc.dispose();
    });

    test('one order fits one page; non-Latin text does not break the build', () {
      final List<OrderExportRow> rows = [OrderExportRow(createdAt: DateTime(2026, 9, 2), orderId: 'abc', type: 'متجر - Delivery', status: 'Order Placed', amount: 5, currency: usd)];
      final List<int> bytes = OrderHistoryPdf.build(header, rows, OrderHistoryExport.summarize(rows));
      final PdfDocument doc = PdfDocument(inputBytes: bytes);
      expect(doc.pages.count, 1);
      doc.dispose();
    });

    test('the header names the period and the chosen status', () {
      final List<OrderExportRow> rows = [row(DateTime(2026, 9, 2), 5, usd, status: 'Driver Accepted')];
      final OrderHistoryPdfHeader onGoing = OrderHistoryPdfHeader(
        appName: 'Spideli',
        customerName: 'Jane Doe',
        title: 'Ride History',
        serviceName: 'Cab',
        period: ExportPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        statusLabel: const ExportStatusFilter.group('On Going', {'Driver Accepted'}).printLabel,
        generatedAt: DateTime(2026, 10, 7, 10, 30),
      );
      final PdfDocument doc = PdfDocument(inputBytes: OrderHistoryPdf.build(onGoing, rows, OrderHistoryExport.summarize(rows)));
      final String text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      expect(text, contains('Status'));
      expect(text, contains('On Going'));
      expect(text, contains('Sep 01, 2026 - Sep 30, 2026'));
    });
  });

  group('status filter', () {
    OrderExportRow at(String status, {String id = 'o'}) => row(DateTime(2026, 9, 1), 1, usd, status: status, id: id);
    List<String> labels(List<ExportStatusFilter> options) => options.map((o) => o.labelKey).toList();

    test('each history screen offers its own tabs, in its order', () {
      expect(labels(OrderHistoryExport.statusGroups(OrderHistoryKind.shopping)), ['In Progress', 'Delivered', 'Cancelled', 'Rejected']);
      expect(labels(OrderHistoryExport.statusGroups(OrderHistoryKind.rides)), ['New', 'On Going', 'Completed', 'Cancelled']);
      expect(labels(OrderHistoryExport.statusGroups(OrderHistoryKind.parcels)), ['New', 'In Transit', 'Delivered', 'Cancelled']);
      expect(labels(OrderHistoryExport.statusGroups(OrderHistoryKind.rentals)), ['New', 'On Going', 'Completed', 'Cancelled']);
      expect(labels(OrderHistoryExport.statusGroups(OrderHistoryKind.onDemand)), ['Placed', 'Completed', 'Cancelled']);

      Set<String> of(OrderHistoryKind kind, String label) => OrderHistoryExport.statusGroups(kind).firstWhere((g) => g.labelKey == label).statuses!;
      // The tabs keep their own grouping: a dispatched "Driver Rejected" is
      // still New, an on-demand one is Cancelled.
      expect(of(OrderHistoryKind.rides, 'New'), containsAll(['Order Placed', 'Driver Pending', 'Driver Rejected']));
      expect(of(OrderHistoryKind.rides, 'Cancelled'), {'Order Rejected', 'Order Cancelled'});
      expect(of(OrderHistoryKind.parcels, 'New'), contains('Quote Requested'));
      expect(of(OrderHistoryKind.parcels, 'In Transit'), containsAll(['Order Accepted', 'Driver Accepted', 'Order Shipped', 'In Transit']));
      expect(of(OrderHistoryKind.rentals, 'New'), contains('Order Accepted'));
      expect(of(OrderHistoryKind.onDemand, 'Placed'), {'Order Placed', 'Order Accepted', 'Order Assigned', 'Order Ongoing', 'In Transit'});
      expect(of(OrderHistoryKind.onDemand, 'Cancelled'), {'Order Rejected', 'Order Cancelled', 'Driver Rejected'});
      expect(of(OrderHistoryKind.shopping, 'In Progress'), isNot(contains('Order Placed')));
      expect(of(OrderHistoryKind.shopping, 'Delivered'), {'Order Completed'});
    });

    test('"All statuses" first, then only the tabs that have orders, then statuses no tab lists', () {
      final List<OrderExportRow> rows = [at('Order Completed'), at('Order Placed'), at('Order Rejected'), at('Driver Accepted'), at('  ')];
      final List<ExportStatusFilter> options = OrderHistoryExport.statusOptions(OrderHistoryKind.shopping, rows);
      expect(options.first, ExportStatusFilter.all);
      // My Order shows "Order Placed" under All only: it is offered on its own.
      expect(labels(options), ['All statuses', 'In Progress', 'Delivered', 'Rejected', 'Order Placed']);

      expect(labels(OrderHistoryExport.statusOptions(OrderHistoryKind.rides, [at('Driver Rejected'), at('Order Cancelled')])), ['All statuses', 'New', 'Cancelled']);
      expect(labels(OrderHistoryExport.statusOptions(OrderHistoryKind.onDemand, [at('Order Ongoing')])), ['All statuses', 'Placed']);
      expect(labels(OrderHistoryExport.statusOptions(OrderHistoryKind.parcels, const [])), ['All statuses']);
      // Not loaded: every tab of the screen.
      expect(labels(OrderHistoryExport.statusOptions(OrderHistoryKind.parcels, null)), ['All statuses', 'New', 'In Transit', 'Delivered', 'Cancelled']);
    });

    test('a status keeps only its orders; "All statuses" keeps every order', () {
      final List<OrderExportRow> rows = [
        at('Order Placed', id: 'a'),
        at('Driver Accepted', id: 'b'),
        at('Order Completed', id: 'c'),
        at(' In Transit ', id: 'd'),
        at('Order Cancelled', id: 'e'),
        at('', id: 'f'),
      ];
      List<String> ids(ExportStatusFilter f) => OrderHistoryExport.filterByStatus(rows, f).map((r) => r.orderId).toList();
      expect(ids(ExportStatusFilter.all), ['a', 'b', 'c', 'd', 'e', 'f']);
      final List<ExportStatusFilter> rides = OrderHistoryExport.statusGroups(OrderHistoryKind.rides);
      expect(ids(rides[0]), ['a']);
      expect(ids(rides[1]), ['b', 'd']);
      expect(ids(rides[2]), ['c']);
      expect(ids(rides[3]), ['e']);
      expect(ids(const ExportStatusFilter.group('Order Rejected', {'Order Rejected'})), isEmpty);
      // Every option offered for the rows exports at least one of them.
      for (final ExportStatusFilter o in OrderHistoryExport.statusOptions(OrderHistoryKind.rides, rows)) {
        expect(ids(o), isNotEmpty, reason: o.labelKey);
      }
      // The input list is never changed.
      expect(rows.length, 6);
    });

    test('filters compare by label and statuses', () {
      expect(const ExportStatusFilter.group('New', {'a', 'b'}), const ExportStatusFilter.group('New', {'b', 'a'}));
      expect(const ExportStatusFilter.group('New', {'a'}) == const ExportStatusFilter.group('New', {'b'}), isFalse);
      expect(ExportStatusFilter.all.isAll, isTrue);
      expect(const ExportStatusFilter.group('New', {'a'}).isAll, isFalse);
    });

    test('file names carry the status and the period, sanitised', () {
      final ExportPeriod p = ExportPeriod(DateTime(2026, 9, 8), DateTime(2026, 10, 7));
      expect(OrderHistoryExport.fileName(p, ExportStatusFilter.all), 'orders_all-statuses_2026-09-08_2026-10-07.pdf');
      expect(OrderHistoryExport.fileName(p, OrderHistoryExport.statusGroups(OrderHistoryKind.rides)[1]), 'orders_on-going_2026-09-08_2026-10-07.pdf');
      expect(OrderHistoryExport.fileName(p, const ExportStatusFilter.group('Order Placed', {'Order Placed'})), 'orders_order-placed_2026-09-08_2026-10-07.pdf');
      expect(OrderHistoryExport.fileNamePart('Annulée / Rejetée'), 'annulée-rejetée');
      expect(OrderHistoryExport.fileNamePart('../a\\b:c*?"<>|'), 'a-b-c');
      expect(OrderHistoryExport.fileNamePart(' -- '), 'status');
      expect(OrderHistoryExport.fileNamePart('x' * 60).length, 40);
      expect(OrderHistoryExport.fileNamePart('${'a' * 39} b'), 'a' * 39);
    });

    test('the empty-period message names the status', () {
      expect(OrderHistoryExport.noOrdersMessage(ExportStatusFilter.all), 'You have no orders in this period.');
      expect(OrderHistoryExport.noOrdersMessage(const ExportStatusFilter.group('Completed', {'Order Completed'})), 'You have no orders with the status Completed in this period.');
    });
  });

  group('subscription gate', () {
    final Future<Map<String, dynamic>?> Function() original = OrderHistoryExportService.readUserData;
    tearDown(() => OrderHistoryExportService.readUserData = original);

    Map<String, dynamic> user({String planFor = 'customer', bool fullHistory = true, DateTime? expires}) => {
      'subscription_plan': {
        'planFor': planFor,
        'features': {'fullOrderHistory': fullHistory},
      },
      if (expires != null) 'subscriptionExpiryDate': Timestamp.fromDate(expires),
    };

    final ExportPeriod period = ExportPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    final List<OrderExportRow> rows = [row(DateTime(2026, 9, 2), 5, usd)];

    test('customers without an active order history plan are refused at every step', () async {
      final List<Map<String, dynamic>?> nonSubscribers = [
        null,
        <String, dynamic>{},
        user(fullHistory: false),
        user(planFor: 'vendor'),
        user(expires: DateTime.now().subtract(const Duration(days: 1))),
      ];
      for (final Map<String, dynamic>? doc in nonSubscribers) {
        OrderHistoryExportService.readUserData = () async => doc;
        expect(await OrderHistoryExportService.canExport(), isFalse, reason: '$doc');
        await expectLater(OrderHistoryExportService.ensureEntitled(), throwsA(isA<OrderHistoryExportLocked>()), reason: '$doc');
        for (final OrderHistoryKind kind in OrderHistoryKind.values) {
          await expectLater(OrderHistoryExportService.loadRows(kind, period), throwsA(isA<OrderHistoryExportLocked>()), reason: '$kind $doc');
          // Even with rows in hand (from the sheet) and for one status only.
          await expectLater(
            OrderHistoryExportService.exportPdf(kind, OrderHistoryExportRequest(period: period, status: OrderHistoryExport.statusGroups(kind).first, rows: rows)),
            throwsA(isA<OrderHistoryExportLocked>()),
            reason: '$kind $doc',
          );
          await expectLater(OrderHistoryExportService.writePdf(kind, period, ExportStatusFilter.all, rows), throwsA(isA<OrderHistoryExportLocked>()), reason: '$kind $doc');
        }
      }
    });

    test('an unreadable plan refuses the export (fails closed)', () async {
      OrderHistoryExportService.readUserData = () async => throw StateError('offline');
      await expectLater(OrderHistoryExportService.canExport(), throwsStateError);
      await expectLater(OrderHistoryExportService.exportPdf(OrderHistoryKind.rides, OrderHistoryExportRequest(period: period, rows: rows)), throwsStateError);
    });

    test('customers with an active order history plan may export', () async {
      OrderHistoryExportService.readUserData = () async => user(expires: DateTime.now().add(const Duration(days: 30)));
      expect(await OrderHistoryExportService.canExport(), isTrue);
      OrderHistoryExportService.readUserData = () async => user();
      expect(await OrderHistoryExportService.canExport(), isTrue);
      await OrderHistoryExportService.ensureEntitled();
      // Nothing of that status in the period: nothing is written.
      expect(
        await OrderHistoryExportService.exportPdf(OrderHistoryKind.rides, OrderHistoryExportRequest(period: period, status: const ExportStatusFilter.group('Cancelled', {'Order Cancelled'}), rows: rows)),
        isNull,
      );
    });
  });

  test('every export label is translated in every language', () {
    const keys = <String>[
      'Export PDF',
      'Export PDF (subscription required)',
      'Your orders of the chosen period, as a PDF you can save or send.',
      'From',
      'To',
      'Both days are included. A period can be up to one year.',
      'Please choose both dates.',
      'The end date must be on or after the start date.',
      'The period cannot be longer than one year.',
      'Subscription required',
      'Exporting your order history as a PDF needs an active order history subscription.',
      'See plans',
      'Close',
      'Could not check your subscription. Please try again.',
      'Preparing your PDF...',
      'You have no orders in this period.',
      'Could not create the document. Please try again.',
      'Order history',
      'Order History',
      'Ride History',
      'Parcel History',
      'Rental History',
      'Booking History',
      'Customer',
      'Period',
      'Generated on',
      'Summary',
      'Number of orders',
      'Total',
      'Cancelled or rejected orders are listed but not included in the totals:',
      'Orders whose amount could not be read (shown as -):',
      'Date & time',
      'Order',
      'Type',
      'Status',
      'Amount',
      'Page',
      'Ride',
      'Intercity ride',
      'Parcel',
      'Mail',
      'Rental',
      'Booking',
      'Delivery',
      'TakeAway',
      'All statuses',
      'Placed',
      'Checking your orders in this period...',
      'You have no orders with the status @status in this period.',
      'New',
      'On Going',
      'In Progress',
      'In Transit',
      'Delivered',
      'Completed',
      'Cancelled',
      'Rejected',
    ];
    for (final MapEntry<String, Map<String, String>> lang in const {'en_US': enUS, 'ar_AR': arAR}.entries) {
      final List<String> missing = keys.where((k) => (lang.value[k] ?? '').trim().isEmpty).toList();
      expect(missing, isEmpty, reason: lang.key);
    }
  });
}
