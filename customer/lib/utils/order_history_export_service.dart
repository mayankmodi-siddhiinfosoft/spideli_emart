import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_order_details_controller.dart';
import 'package:customer/controllers/on_demand_order_details_controller.dart';
import 'package:customer/controllers/order_details_controller.dart';
import 'package:customer/controllers/rental_order_details_controller.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/customer_plan_service.dart';
import 'package:customer/utils/order_history_export.dart';
import 'package:customer/utils/order_history_pdf.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:customer/utils/region_service.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Loads the signed-in customer's orders of one history screen over an
/// [ExportPeriod], prices each one exactly as its detail screen / receipt
/// does, and turns them into the PDF statement.
///
/// Queries: the history screen's own query (same collection, `authorID` =
/// the customer, same section filter, `orderBy createdAt desc`) with a range
/// on `createdAt` added. A range on the field the query is already ordered by
/// is served by the composite index the history screen already uses, so no
/// new index is needed - and nothing outside the period is read.
class OrderHistoryExportService {
  OrderHistoryExportService._();

  // ---------------- entitlement ----------------

  /// The client rule: only customers with an ACTIVE order-history plan may
  /// export. Decided on the user document read NOW from the server path
  /// ([CustomerPlanService.currentUserData]), never on a cached copy, so a
  /// plan that expired while the screen was open cannot export. The same
  /// [CustomerPlanService.hasFullHistory] decision that unlocks the full
  /// history and the period picker.
  ///
  /// Throws when the user document cannot be read: the caller refuses the
  /// export (fails closed) rather than guess.
  static Future<bool> canExport() async => CustomerPlanService.hasFullHistory(await CustomerPlanService.currentUserData());

  // ---------------- loading ----------------

  static Query<Map<String, dynamic>> _historyQuery(String collection, String sectionField, ExportPeriod period) {
    return FireStoreUtils.fireStore
        .collection(collection)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where(sectionField, isEqualTo: Constant.sectionConstantModel?.id)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(period.start))
        .where('createdAt', isLessThan: Timestamp.fromDate(period.endExclusive))
        .orderBy('createdAt', descending: true);
  }

  /// Parses each document on its own: one malformed order is skipped (and
  /// logged) instead of losing the whole export.
  static Future<List<T>> _load<T>(Query<Map<String, dynamic>> query, T Function(Map<String, dynamic>) parse) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    final List<T> list = [];
    for (final doc in snap.docs) {
      try {
        list.add(parse(doc.data()));
      } catch (e) {
        log("OrderHistoryExport: order ${doc.id} skipped: $e");
      }
    }
    return list;
  }

  /// The rows of [kind] in [period], oldest first.
  static Future<List<OrderExportRow>> loadRows(OrderHistoryKind kind, ExportPeriod period) async {
    await RegionService.ensureLoaded();
    final List<OrderExportRow> rows;
    switch (kind) {
      case OrderHistoryKind.shopping:
        // FireStoreUtils.getAllOrder: vendor_orders, authorID + section_id.
        final orders = await _load(_historyQuery(CollectionName.vendorOrders, 'section_id', period), OrderModel.fromJson);
        rows = _shoppingRows(orders);
      case OrderHistoryKind.rides:
        // FireStoreUtils.getCabDriverOrders: rides, authorID + sectionId.
        final orders = await _load(_historyQuery(CollectionName.rides, 'sectionId', period), CabOrderModel.fromJson);
        rows = _rideRows(orders);
      case OrderHistoryKind.parcels:
        // FireStoreUtils.listenParcelOrders: parcel_orders, authorID + sectionId.
        final orders = await _load(_historyQuery(CollectionName.parcelOrders, 'sectionId', period), ParcelOrderModel.fromJson);
        rows = _parcelRows(orders);
      case OrderHistoryKind.rentals:
        // FireStoreUtils.getRentalOrders: rental_orders, authorID + sectionId.
        final orders = await _load(_historyQuery(CollectionName.rentalOrders, 'sectionId', period), RentalOrderModel.fromJson);
        rows = _rentalRows(orders, await _rentalDrivers(orders));
      case OrderHistoryKind.onDemand:
        // FireStoreUtils.getProviderOrdersStream: provider_orders, authorID + sectionId.
        final orders = await _load(_historyQuery(CollectionName.providerOrders, 'sectionId', period), OnProviderOrderModel.fromJson);
        rows = _onDemandRows(orders);
    }
    // The query is bounded already; this only guards a createdAt stored in
    // an unexpected shape.
    return OrderHistoryExport.sortRows(rows.where((r) => period.contains(r.createdAt)).toList());
  }

  /// Runs one of the detail controllers' own total calculations. The
  /// controllers only assign `totalAmount` at the very end, so NaN left in it
  /// means the calculation failed for this order.
  static double? _total(RxDouble total, void Function() calculate) {
    total.value = double.nan;
    try {
      calculate();
    } catch (e) {
      log("OrderHistoryExport: total not computed: $e");
      return null;
    }
    return total.value.isNaN ? null : total.value;
  }

  /// vendor_orders: [OrderDetailsController.calculatePrice], the total of the
  /// order detail screen and of its receipt. The controller is never
  /// registered with GetX, so its onInit (arguments, live listener) never runs.
  static List<OrderExportRow> _shoppingRows(List<OrderModel> orders) {
    final OrderDetailsController c = OrderDetailsController();
    return [
      for (final OrderModel o in orders)
        OrderExportRow(
          createdAt: o.createdAt?.toDate(),
          orderId: o.id ?? '',
          type: [
            OrderHistoryExport.printable(o.vendor?.title ?? '', ''),
            o.takeAway == true ? OrderHistoryExport.label('TakeAway') : OrderHistoryExport.label('Delivery'),
          ].where((s) => s.trim().isNotEmpty).join(' - '),
          status: o.status ?? '',
          voided: OrderHistoryExport.isVoided(OrderHistoryKind.shopping, o.status),
          amount: _total(c.totalAmount, () {
            c.orderModel.value = o;
            // calculatePrice is declared async but awaits nothing: it has
            // finished when it returns. A failure lands in the returned
            // future (totalAmount then stays NaN -> "-").
            c.calculatePrice().catchError((Object e) => log("OrderHistoryExport: order ${o.id} total not computed: $e"));
          }),
          currency: RegionService.currencyForRecord(o.regionId),
        ),
    ];
  }

  /// rides: [CabOrderDetailsController.calculateTotalAmount] (city and
  /// intercity), as the ride detail screen and the ride receipt.
  static List<OrderExportRow> _rideRows(List<CabOrderModel> orders) {
    final CabOrderDetailsController c = CabOrderDetailsController();
    return [
      for (final CabOrderModel o in orders)
        OrderExportRow(
          createdAt: o.createdAt?.toDate(),
          orderId: o.id ?? '',
          type: o.rideType == 'intercity' ? OrderHistoryExport.label('Intercity ride') : OrderHistoryExport.label('Ride'),
          status: o.status ?? '',
          voided: OrderHistoryExport.isVoided(OrderHistoryKind.rides, o.status),
          amount: _total(c.totalAmount, () {
            c.cabOrder.value = o;
            c.calculateTotalAmount();
          }),
          currency: RegionService.currencyForRecord(o.regionId),
        ),
    ];
  }

  /// parcel_orders: [ParcelAmounts.of] - "computed exactly as the parcel
  /// screens do", the parcel receipt's total - in the currency the parcel
  /// detail screen shows its total in.
  static List<OrderExportRow> _parcelRows(List<ParcelOrderModel> orders) {
    return [
      for (final ParcelOrderModel o in orders)
        OrderExportRow(
          createdAt: o.createdAt?.toDate(),
          orderId: o.id ?? '',
          type: o.shipmentType == ParcelShipping.mail ? OrderHistoryExport.label('Mail') : OrderHistoryExport.label('Parcel'),
          status: o.status ?? '',
          voided: OrderHistoryExport.isVoided(OrderHistoryKind.parcels, o.status),
          amount: _parcelTotal(o),
          currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: o.regionId, zoneId: o.senderZoneId)),
        ),
    ];
  }

  static double? _parcelTotal(ParcelOrderModel o) {
    try {
      return ParcelAmounts.of(o).total;
    } catch (e) {
      log("OrderHistoryExport: parcel ${o.id} total not computed: $e");
      return null;
    }
  }

  /// The drivers of the rentals that have no `regionId` of their own, read
  /// once each: the rental detail screen prices such a booking in its
  /// driver's region ([RentalOrderDetailsController.bookingRegionId]). A
  /// driver that cannot be read is left out (zone / global currency).
  static Future<Map<String, UserModel>> _rentalDrivers(List<RentalOrderModel> orders) async {
    final Set<String> ids = {
      for (final RentalOrderModel o in orders)
        if ((o.regionId ?? '').isEmpty && (o.driverId ?? '').trim().isNotEmpty) o.driverId!.trim(),
    };
    final Map<String, UserModel> drivers = {};
    await Future.wait(ids.map((id) async {
      try {
        final UserModel? driver = await FireStoreUtils.getUserProfile(id);
        if (driver != null) drivers[id] = driver;
      } catch (e) {
        log("OrderHistoryExport: driver $id not read: $e");
      }
    }));
    return drivers;
  }

  /// Whether [RentalOrderDetailsController.calculateTotalAmount] would fail on
  /// [o]. It catches its own error and shows it as a toast, which would pop
  /// over the export's loader once per such booking - so the export does not
  /// call it then, and the row shows "-" (as the failed calculation would).
  static bool rentalTotalWouldFail(RentalOrderModel o) {
    if (o.endTime != null && o.startTime == null) return true;
    if (o.startKitoMetersReading != null && o.endKitoMetersReading != null) {
      final double startKm = double.tryParse(o.startKitoMetersReading.toString()) ?? 0.0;
      final double endKm = double.tryParse(o.endKitoMetersReading.toString()) ?? 0.0;
      if (endKm > startKm && double.tryParse(o.rentalPackageModel?.includedDistance ?? '') == null) return true;
    }
    final double? platformFee = double.tryParse(o.platformFee ?? '0.0');
    if (platformFee == null) return true;
    bool badTax(TaxModel t) => t.enable == true && double.tryParse(t.tax.toString()) == null;
    if ((o.taxSetting ?? []).any(badTax)) return true;
    if (platformFee > 0 && (o.platformTax ?? []).any(badTax)) return true;
    return false;
  }

  /// rental_orders: [RentalOrderDetailsController.calculateTotalAmount] and
  /// its booking currency (own region, else the driver's, else the zone's),
  /// as the rental detail screen and receipt.
  static List<OrderExportRow> _rentalRows(List<RentalOrderModel> orders, Map<String, UserModel> drivers) {
    final RentalOrderDetailsController c = RentalOrderDetailsController();
    final List<OrderExportRow> rows = [];
    for (final RentalOrderModel o in orders) {
      c.order.value = o;
      c.driverUser.value = drivers[o.driverId?.trim()];
      rows.add(
        OrderExportRow(
          createdAt: o.createdAt?.toDate(),
          orderId: o.id ?? '',
          type: OrderHistoryExport.label('Rental'),
          status: o.status ?? '',
          voided: OrderHistoryExport.isVoided(OrderHistoryKind.rentals, o.status),
          amount: rentalTotalWouldFail(o) ? null : _total(c.totalAmount, c.calculateTotalAmount),
          currency: c.bookingCurrency,
        ),
      );
    }
    return rows;
  }

  /// provider_orders: [OnDemandOrderDetailsController.calculatePrice] with the
  /// booking's own discount (as its getData sets it), plus the provider's
  /// extra charges - the "Total paid" of the booking receipt.
  static List<OrderExportRow> _onDemandRows(List<OnProviderOrderModel> orders) {
    final OnDemandOrderDetailsController c = OnDemandOrderDetailsController();
    try {
      return [
        for (final OnProviderOrderModel o in orders)
          OrderExportRow(
            createdAt: o.createdAt.toDate(),
            orderId: o.id,
            type: OrderHistoryExport.printable(o.provider.title ?? '', OrderHistoryExport.label('Booking')),
            status: o.status,
            voided: OrderHistoryExport.isVoided(OrderHistoryKind.onDemand, o.status),
            amount: () {
              final double? total = _total(c.totalAmount, () {
                c.onProviderOrder.value = o;
                c.discountType.value = o.discountType ?? '';
                c.discountLabel.value = o.discountLabel ?? '';
                c.calculatePrice();
              });
              if (total == null) return null;
              return total + (double.tryParse(o.extraCharges ?? '') ?? 0);
            }(),
            currency: RegionService.currencyForRecord(o.regionId),
          ),
      ];
    } finally {
      c.couponTextController.value.dispose();
    }
  }

  // ---------------- PDF ----------------

  static String _historyTitle(OrderHistoryKind kind) {
    switch (kind) {
      case OrderHistoryKind.shopping:
        return OrderHistoryExport.label('Order History');
      case OrderHistoryKind.rides:
        return OrderHistoryExport.label('Ride History');
      case OrderHistoryKind.parcels:
        return OrderHistoryExport.label('Parcel History');
      case OrderHistoryKind.rentals:
        return OrderHistoryExport.label('Rental History');
      case OrderHistoryKind.onDemand:
        return OrderHistoryExport.label('Booking History');
    }
  }

  /// Builds the PDF of [rows] and writes it to the temporary directory as
  /// `orders_<from>_<to>.pdf`.
  static Future<File> writePdf(OrderHistoryKind kind, ExportPeriod period, List<OrderExportRow> rows) async {
    final String app = OrderHistoryExport.label('spideli');
    final OrderHistoryPdfHeader header = OrderHistoryPdfHeader(
      appName: app.capitalizeFirst ?? app,
      customerName: Constant.userModel?.fullName() ?? '',
      title: _historyTitle(kind),
      serviceName: OrderHistoryExport.printable(Constant.sectionConstantModel?.name ?? '', ''),
      period: period,
      generatedAt: DateTime.now(),
    );
    final List<int> bytes = OrderHistoryPdf.build(header, rows, OrderHistoryExport.summarize(rows));
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/${period.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// The share sheet, from which the customer saves or sends the PDF.
  static Future<void> share(File file, ExportPeriod period) async {
    final String title = "Order history".tr;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: '$title ${period.fileName}'),
    );
  }
}
