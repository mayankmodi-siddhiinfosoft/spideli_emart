import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_order_details_controller.dart';
import 'package:driver/controllers/cab_order_list_controller.dart';
import 'package:driver/controllers/order_details_controller.dart';
import 'package:driver/controllers/owner_order_list_controller.dart';
import 'package:driver/controllers/parcel_order_details_controller.dart';
import 'package:driver/controllers/parcel_order_list_controller.dart';
import 'package:driver/controllers/rental_order_details_controller.dart';
import 'package:driver/controllers/rental_order_list_controller.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/order_history_export.dart';
import 'package:driver/utils/order_history_pdf.dart';
import 'package:driver/utils/region_service.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Whose history is exported.
sealed class OrderExportScope {
  const OrderExportScope();
}

/// One driver's own history: every order type the driver app lists (delivery
/// `vendor_orders.driverID`, cab `rides`, `parcel_orders`, `rental_orders`
/// by `driverId`), or only [types] (an owner looking at one driver's list for
/// one service).
class DriverExportScope extends OrderExportScope {
  final String driverId;
  final Set<OrderExportType> types;

  /// Adds the delivery charge / tip columns, as the delivery history card
  /// does for a driver who is not a store's own driver.
  final bool showEarnings;

  const DriverExportScope({required this.driverId, this.types = const {...OrderExportType.values}, this.showEarnings = false});
}

/// A company (owner) account: the fleet orders of the owner's order list, in
/// every section of the owner, for all drivers or only [driver].
class OwnerExportScope extends OrderExportScope {
  final UserModel? driver;

  const OwnerExportScope({this.driver});
}

/// Loads the orders of a period, builds the PDF and opens the share sheet.
class OrderHistoryExportService {
  OrderHistoryExportService._();

  /// Full flow after the period was picked: loader, load, PDF, share.
  static Future<void> export(OrderExportScope scope, ExportDateRange range) async {
    ShowToastDialog.showLoader("Please wait".tr);
    File? file;
    String? message;
    try {
      final List<OrderExportRow> rows = orderExportRowsInRange(await loadRows(scope, range), range);
      if (rows.isEmpty) {
        message = "No orders found for this period.";
      } else {
        file = await _save(scope, range, rows);
      }
    } catch (e, s) {
      log("Order history export failed: $e", stackTrace: s);
      message = "Could not create the PDF. Please try again.";
    }
    ShowToastDialog.closeLoader();
    if (message != null) {
      ShowToastDialog.showToast(message.tr);
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file!.path, mimeType: 'application/pdf')],
          subject: "${"Order history".tr} ${file.uri.pathSegments.last}",
        ),
      );
    } catch (e) {
      log("Order history share failed: $e");
      ShowToastDialog.showToast("Could not create the PDF. Please try again.".tr);
    }
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Rows of every order of [scope] created in [range] (createdAt).
  static Future<List<OrderExportRow>> loadRows(OrderExportScope scope, ExportDateRange range) async {
    switch (scope) {
      case DriverExportScope():
        return _driverRows(scope, range);
      case OwnerExportScope():
        return _ownerRows(scope, range);
    }
  }

  /// The queries of the driver's history screens (OrderListController,
  /// CabOrderListController, ParcelOrderListController,
  /// RentalOrderListController), bounded by the period.
  static Future<List<OrderExportRow>> _driverRows(DriverExportScope scope, ExportDateRange range) async {
    final String id = scope.driverId;
    final List<Future<List<OrderExportRow>>> loads = [
      if (scope.types.contains(OrderExportType.delivery))
        _query(CollectionName.vendorOrders, {'driverID': id}, range).then((docs) => _deliveryRows(_parse(docs, OrderModel.fromJson), showEarnings: scope.showEarnings)),
      if (scope.types.contains(OrderExportType.cab))
        _query(CollectionName.ridesBooking, {'driverId': id}, range).then((docs) {
          final CabOrderListController shown = CabOrderListController()..cabOrder.assignAll(_parse(docs, CabOrderModel.fromJson));
          return _cabRows([for (final tab in shown.tabTitles) ...shown.getOrdersForTab(tab)]);
        }),
      if (scope.types.contains(OrderExportType.parcel))
        _query(CollectionName.parcelOrders, {'driverId': id}, range).then((docs) {
          final ParcelOrderListController shown = ParcelOrderListController()..parcelOrder.assignAll(_parse(docs, ParcelOrderModel.fromJson));
          return _parcelRows([for (final tab in shown.tabTitles) ...shown.getOrdersForTab(tab)]);
        }),
      if (scope.types.contains(OrderExportType.rental))
        _query(CollectionName.rentalOrders, {'driverId': id}, range).then((docs) {
          final RentalOrderListController shown = RentalOrderListController()..rentalOrders.assignAll(_parse(docs, RentalOrderModel.fromJson));
          return _rentalRows([for (final tab in shown.tabTitles) ...shown.getOrdersForTab(tab)]);
        }),
    ];
    return (await Future.wait(loads)).expand((rows) => rows).toList();
  }

  /// The owner order list (OwnerOrderListController.fetchOrdersForSection):
  /// per owner section, the section's collection for each of its drivers, with
  /// the list's status tabs.
  static Future<List<OrderExportRow>> _ownerRows(OwnerExportScope scope, ExportDateRange range) async {
    final List<String> ownerSectionIds = Constant.userModel?.sectionIds ?? [];
    final List<SectionModel> sections = (await FireStoreUtils.getAllActiveSections()).where((s) => s.id != null && ownerSectionIds.contains(s.id)).toList();
    final List<UserModel> drivers = scope.driver != null ? [scope.driver!] : await FireStoreUtils.getOwnerDriver();
    final OwnerOrderListController shown = OwnerOrderListController();

    final List<OrderExportRow> rows = [];
    for (final SectionModel section in sections) {
      final String sectionId = section.id!;
      final List<String> driverIds =
          drivers.where((d) => d.sectionIds?.contains(sectionId) == true).map((d) => d.id ?? '').where((id) => id.isNotEmpty).toList();
      final String name = section.name ?? Constant.sectionNameFromId(sectionId);
      for (final String did in driverIds) {
        switch (section.serviceTypeFlag) {
          case 'cab-service':
            shown.cabOrders.assignAll(_parse(await _query(CollectionName.ridesBooking, {'driverId': did, 'sectionId': sectionId}, range), CabOrderModel.fromJson));
            rows.addAll(_cabRows([for (final tab in shown.cabTabTitles) ...shown.getCabOrdersForTab(tab)], sectionName: name));
            break;
          case 'parcel_delivery':
            shown.parcelOrders.assignAll(_parse(await _query(CollectionName.parcelOrders, {'driverId': did, 'sectionId': sectionId}, range), ParcelOrderModel.fromJson));
            rows.addAll(_parcelRows([for (final tab in shown.parcelTabTitles) ...shown.getParcelOrdersForTab(tab)], sectionName: name));
            break;
          case 'rental-service':
            shown.rentalOrders.assignAll(_parse(await _query(CollectionName.rentalOrders, {'driverId': did, 'sectionId': sectionId}, range), RentalOrderModel.fromJson));
            rows.addAll(_rentalRows([for (final tab in shown.rentalTabTitles) ...shown.getRentalOrdersForTab(tab)], sectionName: name));
            break;
          case 'delivery-service':
            shown.vendorOrders.assignAll(_parse(await _query(CollectionName.vendorOrders, {'driverID': did, 'section_id': sectionId}, range), OrderModel.fromJson));
            rows.addAll(await _deliveryRows([for (final tab in shown.vendorTabTitles) ...shown.getVendorOrdersForTab(tab)], showEarnings: false, sectionName: name));
            break;
          default:
            // Sections the owner list does not show (e.g. e-commerce).
            break;
        }
      }
    }
    return rows;
  }

  /// The history query (equality on the owner fields, newest first) with a
  /// createdAt range: it uses the same composite index as the list. Should
  /// that index be missing on this project, falls back to the equality alone
  /// (no composite index needed) and the period is applied in code.
  static Future<List<Map<String, dynamic>>> _query(String collection, Map<String, String> equals, ExportDateRange range) async {
    Query<Map<String, dynamic>> base = FireStoreUtils.fireStore.collection(collection);
    equals.forEach((field, value) => base = base.where(field, isEqualTo: value));
    try {
      final snapshot = await base
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('createdAt', isLessThan: Timestamp.fromDate(range.endExclusive))
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      log("Order export: index missing on $collection, filtering the period in code");
      final snapshot = await base.get();
      return snapshot.docs.map((d) => d.data()).where((data) {
        final createdAt = data['createdAt'];
        return createdAt is Timestamp && range.contains(createdAt.toDate());
      }).toList();
    }
  }

  static List<T> _parse<T>(List<Map<String, dynamic>> docs, T Function(Map<String, dynamic>) fromJson) {
    final List<T> result = [];
    for (final data in docs) {
      try {
        result.add(fromJson(data));
      } catch (e) {
        log("Order export: skipped unreadable order ${data['id']}: $e");
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Rows. Each amount is the total of the order's details screen, computed by
  // that screen's own controller (nothing recalculated here). A controller
  // that cannot price a record gives "-" instead of a number.
  // ---------------------------------------------------------------------------

  static DateTime _date(Timestamp? createdAt) => createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Delivery: "To Pay" of OrderDetailsScreen (OrderDetailsController.calculatePrice);
  /// delivery charge and tip as the history card shows them.
  static Future<List<OrderExportRow>> _deliveryRows(List<OrderModel> orders, {required bool showEarnings, String? sectionName}) async {
    final List<OrderExportRow> rows = [];
    for (final OrderModel order in orders) {
      rows.add(OrderExportRow(
        type: OrderExportType.delivery,
        orderId: order.id ?? '',
        createdAt: _date(order.createdAt),
        status: order.status ?? '',
        section: sectionName ?? Constant.sectionNameFromId(order.sectionId),
        amount: await deliveryTotal(order),
        deliveryCharge: showEarnings ? double.tryParse(order.deliveryCharge ?? '') : null,
        tip: double.tryParse(order.tipAmount ?? ''),
        currency: RegionService.currencyForRecord(order.regionId),
      ));
    }
    return rows;
  }

  static List<OrderExportRow> _cabRows(List<CabOrderModel> orders, {String? sectionName}) => [
        for (final CabOrderModel order in orders)
          OrderExportRow(
            type: OrderExportType.cab,
            orderId: order.id ?? '',
            createdAt: _date(order.createdAt),
            status: order.status ?? '',
            section: sectionName ?? Constant.sectionNameFromId(order.sectionId),
            amount: cabTotal(order),
            currency: RegionService.currencyForRecord(order.regionId),
          ),
      ];

  static List<OrderExportRow> _parcelRows(List<ParcelOrderModel> orders, {String? sectionName}) => [
        for (final ParcelOrderModel order in orders)
          OrderExportRow(
            type: OrderExportType.parcel,
            orderId: order.id ?? '',
            createdAt: _date(order.createdAt),
            status: order.status ?? '',
            section: sectionName ?? Constant.sectionNameFromId(order.sectionId),
            amount: parcelTotal(order),
            currency: RegionService.currencyForRecord(order.regionId),
          ),
      ];

  static List<OrderExportRow> _rentalRows(List<RentalOrderModel> orders, {String? sectionName}) => [
        for (final RentalOrderModel order in orders)
          OrderExportRow(
            type: OrderExportType.rental,
            orderId: order.id ?? '',
            createdAt: _date(order.createdAt),
            status: order.status ?? '',
            section: sectionName ?? Constant.sectionNameFromId(order.sectionId),
            amount: rentalTotal(order),
            currency: RegionService.currencyForRecord(order.regionId),
          ),
      ];

  /// OrderDetailsScreen "To Pay".
  static Future<double?> deliveryTotal(OrderModel order) async {
    final OrderDetailsController c = OrderDetailsController();
    c.orderModel.value = order;
    try {
      await c.calculatePrice();
      return c.totalAmount.value;
    } catch (e) {
      log("Order export: delivery ${order.id} not priced: $e");
      return null;
    }
  }

  /// CabOrderDetails "Order Total".
  static double? cabTotal(CabOrderModel order) {
    final CabOrderDetailsController c = CabOrderDetailsController();
    c.cabOrder.value = order;
    try {
      c.calculateTotalAmount();
      return c.totalAmount.value;
    } catch (e) {
      log("Order export: ride ${order.id} not priced: $e");
      return null;
    }
  }

  /// ParcelOrderDetails "Order Total".
  static double? parcelTotal(ParcelOrderModel order) {
    final ParcelOrderDetailsController c = ParcelOrderDetailsController();
    c.parcelOrder.value = order;
    try {
      c.calculateTotalAmount();
      return c.totalAmount.value;
    } catch (e) {
      log("Order export: parcel ${order.id} not priced: $e");
      return null;
    }
  }

  /// RentalOrderDetailsScreen "Order Total".
  static double? rentalTotal(RentalOrderModel order) {
    final RentalOrderDetailsController c = RentalOrderDetailsController();
    c.order.value = order;
    try {
      c.computeTotalAmount();
      return c.totalAmount.value;
    } catch (e) {
      log("Order export: rental ${order.id} not priced: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static String _label(String key) => pdfLabel(key, (k) => k.tr, enUS);

  static OrderHistoryPdfLabels labels() => OrderHistoryPdfLabels(
        title: _label("Order history"),
        period: _label("Period"),
        generatedOn: _label("Generated on"),
        summary: _label("Summary"),
        numberOfOrders: _label("Number of orders"),
        totalAmount: _label("Total amount"),
        dateTime: _label("Date & time"),
        orderId: _label("Order ID"),
        type: _label("Type"),
        status: _label("Status"),
        deliveryCharge: _label("Delivery Charge"),
        tips: _label("Tips"),
        amount: _label("Amount"),
        page: _label("Page"),
        types: {for (final t in OrderExportType.values) t: _label(orderExportTypeKey(t))},
        statusLabel: (status) => status.isEmpty ? '-' : _label(status),
      );

  /// App, then whose orders: the driver, or the company (and the driver when
  /// the owner exports one driver's orders).
  static Future<List<String>> _headerLines(OrderExportScope scope) async {
    final UserModel? me = Constant.userModel;
    final String company = (me?.companyName ?? '').trim();
    final String myName = (me?.fullName() ?? '').trim();
    final List<String> lines = ['spideli - ${_label("Driver")}'];
    switch (scope) {
      case DriverExportScope(:final driverId):
        if (driverId == me?.id) {
          lines.add(myName);
        } else {
          // An owner exporting one of their drivers.
          lines.add(company.isNotEmpty ? company : myName);
          final UserModel? driver = await FireStoreUtils.getUserProfile(driverId);
          lines.add('${_label("Driver")}: ${driver?.fullName() ?? driverId}');
        }
      case OwnerExportScope(:final driver):
        lines.add(company.isNotEmpty ? company : myName);
        if (driver != null) lines.add('${_label("Driver")}: ${driver.fullName()}');
    }
    return lines;
  }

  static Future<File> _save(OrderExportScope scope, ExportDateRange range, List<OrderExportRow> rows) async {
    final bool showEarnings = scope is DriverExportScope && scope.showEarnings && rows.any((r) => r.type == OrderExportType.delivery);
    final List<int> bytes = OrderHistoryPdf.build(
      labels: labels(),
      headerLines: await _headerLines(scope),
      range: range,
      generatedAt: DateTime.now(),
      rows: rows,
      showEarnings: showEarnings,
    );
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/${orderExportFileName(range)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
