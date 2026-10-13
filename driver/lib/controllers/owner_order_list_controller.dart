import 'dart:async';

import 'package:get/get.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/carrier_parcel_service.dart';
import 'package:driver/services/driver_document_status_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import '../models/cab_order_model.dart';
import '../models/order_model.dart';
import '../models/parcel_order_model.dart';
import '../models/rental_order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:intl/intl.dart';

class OwnerOrderListController extends GetxController {
  // Loading flags
  RxBool isLoading = true.obs;
  RxBool isLoadingOrders = false.obs;

  // ── Sections (replaces service list) ────────────────────────────────────
  RxList<SectionModel> ownerSections = <SectionModel>[].obs;
  Rx<SectionModel?> selectedSection = Rx<SectionModel?>(null);

  /// Convenience: serviceTypeFlag of the currently selected section.
  String get selectedServiceFlag =>
      selectedSection.value?.serviceTypeFlag ?? '';

  // ── Driver list ─────────────────────────────────────────────────────────
  RxList<UserModel> driverList = <UserModel>[].obs;
  Rx<UserModel?> selectedDriver = Rx<UserModel?>(null);

  // ── Cab Orders ──────────────────────────────────────────────────────────
  RxList<CabOrderModel> cabOrders = <CabOrderModel>[].obs;
  RxString cabSelectedTab = 'On Going'.obs;
  final List<String> cabTabTitles = ["On Going", "Completed", "Cancelled"];

  // ── Parcel Orders ───────────────────────────────────────────────────────
  RxList<ParcelOrderModel> parcelOrders = <ParcelOrderModel>[].obs;
  RxString parcelSelectedTab = 'All'.obs;
  final List<String> parcelTabTitles = ["All", "Pending", "Assigned", "In Transit", "Delivered", "Cancelled"];

  // ── Rental Orders ───────────────────────────────────────────────────────
  RxList<RentalOrderModel> rentalOrders = <RentalOrderModel>[].obs;
  RxString rentalSelectedTab = 'On Going'.obs;
  final List<String> rentalTabTitles = ["On Going", "Completed", "Cancelled"];

  // ── Vendor (Delivery) Orders ────────────────────────────────────────────
  RxList<OrderModel> vendorOrders = <OrderModel>[].obs;
  RxString vendorSelectedTab = 'On Going'.obs;
  final List<String> vendorTabTitles = ["On Going", "Completed", "Cancelled"];

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  // ── Initial data ────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    try {
      // Load owner sections and driver list in parallel.
      await Future.wait([
        FireStoreUtils.getAllActiveSections().then((allSections) {
          final ownerSectionIds = Constant.userModel?.sectionIds ?? [];
          final bool hasCarrier = (Constant.userModel?.carrierId ?? '').isNotEmpty;
          ownerSections.value = allSections.where((s) {
            if (s.id == null) return false;
            if (ownerSectionIds.contains(s.id)) return true;
            final flag = s.serviceTypeFlag;
            final isParcel = flag == 'parcel_delivery' || flag == 'parcel-service' || flag == 'parcel';
            if (isParcel && (hasCarrier || Constant.userModel?.serviceTypes?.contains('parcel_delivery') == true)) {
              return true;
            }
            return false;
          }).toList();
        }),
        FireStoreUtils.getOwnerDriver().then((drivers) {
          driverList.value = drivers;
          // The assign sheet marks / sorts drivers by the status computed
          // from their documents (not the flag alone).
          unawaited(DriverDocumentStatusService.refreshAll(drivers).then((_) => driverList.refresh()));
        }),
      ]);

      // Auto-select first section.
      if (ownerSections.isNotEmpty) {
        selectedSection.value = ownerSections.first;
        await fetchOrdersForSection();
      }
    } catch (e) {
      ShowToastDialog.showToast("Error loading data: $e");
    } finally {
      isLoading.value = false;
      update();
    }
  }

  // ── Drivers filtered by selected section ────────────────────────────────

  List<UserModel> get filteredDrivers {
    final sectionId = selectedSection.value?.id;
    if (sectionId == null) return driverList;
    final inSection = driverList
        .where((d) => d.sectionIds?.contains(sectionId) == true)
        .toList();
    // If fleet drivers don't have explicit sectionIds yet, fallback to all fleet drivers
    return inSection.isNotEmpty ? inSection : driverList;
  }

  // ── Search button ───────────────────────────────────────────────────────

  void searchOrders() {
    fetchOrdersForSection();
  }

  // ── Fetch orders based on selected section ──────────────────────────────

  Future<void> fetchOrdersForSection() async {
    final section = selectedSection.value;
    if (section == null || section.id == null) return;

    isLoadingOrders.value = true;
    update();

    try {
      // Determine which drivers to query.
      final List<String> targetDriverIds;
      if (selectedDriver.value != null) {
        targetDriverIds = [selectedDriver.value!.id ?? ''];
      } else {
        targetDriverIds =
            filteredDrivers.map((d) => d.id ?? '').where((id) => id.isNotEmpty).toList();
      }

      final sectionId = section.id!;
      final flag = section.serviceTypeFlag;

      final bool isParcel = flag == 'parcel_delivery' || flag == 'parcel-service' || flag == 'parcel';

      if (targetDriverIds.isEmpty && !isParcel) {
        cabOrders.clear();
        parcelOrders.clear();
        rentalOrders.clear();
        vendorOrders.clear();
        return;
      }

      // Clear all lists before fetching for the selected section.
      cabOrders.clear();
      parcelOrders.clear();
      rentalOrders.clear();
      vendorOrders.clear();

      if (isParcel) {
        parcelOrders.value = await FireStoreUtils.getParcelOrdersBySection(
          sectionId: sectionId,
          driverIds: targetDriverIds,
        );
      } else {
        switch (flag) {
          case 'cab-service':
            cabOrders.value = await FireStoreUtils.getCabOrdersBySection(
              sectionId: sectionId,
              driverIds: targetDriverIds,
            );
            break;
          case 'rental-service':
            rentalOrders.value = await FireStoreUtils.getRentalOrdersBySection(
              sectionId: sectionId,
              driverIds: targetDriverIds,
            );
            break;
          case 'delivery-service':
            vendorOrders.value = await FireStoreUtils.getVendorOrdersBySection(
              sectionId: sectionId,
              driverIds: targetDriverIds,
            );
            break;
          default:
            break;
        }
      }
    } catch (e) {
      ShowToastDialog.showToast("Error fetching orders: $e");
    } finally {
      isLoadingOrders.value = false;
      update();
    }
  }

  // ── Tab filters ─────────────────────────────────────────────────────────

  static const _onGoingStatuses = [
    "Order Placed",
    "Order Accepted",
    "Driver Accepted",
    "Driver Pending",
    "Order Shipped",
    "In Transit",
  ];

  List<CabOrderModel> getCabOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return cabOrders.where((o) => _onGoingStatuses.contains(o.status)).toList();
      case "Completed":
        return cabOrders.where((o) => o.status == "Order Completed").toList();
      case "Cancelled":
        return cabOrders
            .where((o) => ["Order Rejected", "Order Cancelled"].contains(o.status))
            .toList();
      default:
        return [];
    }
  }

  List<ParcelOrderModel> getParcelOrdersForTab(String tab) {
    switch (tab) {
      case "All":
        return parcelOrders.toList();
      case "Pending":
        // Waiting for the owner to pick a driver.
        return parcelOrders.where((o) => CarrierParcelRules.awaitsOwner(status: o.status, driverId: o.driverId)).toList();
      case "Assigned":
        // Offered to a company driver, not answered yet.
        return parcelOrders.where((o) => CarrierParcelRules.awaitsDriver(status: o.status, driverId: o.driverId)).toList();
      case "In Transit":
        return parcelOrders.where((o) => (o.driverId ?? '').isNotEmpty && CarrierParcelRules.workingStatuses.contains(o.status)).toList();
      case "Delivered":
        return parcelOrders.where((o) => o.status == "Order Completed").toList();
      case "Cancelled":
        return parcelOrders
            .where((o) => ["Order Rejected", "Order Cancelled"].contains(o.status))
            .toList();
      default:
        return [];
    }
  }

  List<RentalOrderModel> getRentalOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return rentalOrders.where((o) => _onGoingStatuses.contains(o.status)).toList();
      case "Completed":
        return rentalOrders.where((o) => o.status == "Order Completed").toList();
      case "Cancelled":
        return rentalOrders
            .where((o) => ["Order Rejected", "Order Cancelled"].contains(o.status))
            .toList();
      default:
        return [];
    }
  }

  List<OrderModel> getVendorOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return vendorOrders.where((o) => _onGoingStatuses.contains(o.status)).toList();
      case "Completed":
        return vendorOrders.where((o) => o.status == "Order Completed").toList();
      case "Cancelled":
        return vendorOrders
            .where((o) => ["Order Rejected", "Order Cancelled"].contains(o.status))
            .toList();
      default:
        return [];
    }
  }

  // ── Date format ─────────────────────────────────────────────────────────

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  // ── Carrier parcels: the owner assigns a driver ─────────────────────────

  /// The company's drivers that may be assigned a parcel (online first).
  List<UserModel> get assignableDrivers => CarrierParcelService.assignableDrivers(driverList, FireStoreUtils.getCurrentUid());

  /// The company driver an order names (the `driver` snapshot is written
  /// only once a driver accepted), or null.
  UserModel? driverOf(ParcelOrderModel order) {
    final String id = (order.driverId ?? '').trim();
    if (id.isEmpty) return null;
    return driverList.firstWhereOrNull((d) => d.id == id) ?? (order.driver?.id == id ? order.driver : null);
  }

  /// The owner may (re)assign this parcel: one of the company's carrier
  /// parcels, placed / handed back, or offered and not answered yet.
  bool canAssign(ParcelOrderModel order) => _isCompanyCarrierParcel(order) && CarrierParcelRules.canAssignStatus(order.status);

  bool _isCompanyCarrierParcel(ParcelOrderModel order) => CarrierParcelRules.belongsToCompany(
        {'carrierId': order.carrierId, 'carrierOwnerId': order.carrierOwnerId},
        ownerUid: FireStoreUtils.getCurrentUid(),
        ownerCarrierId: Constant.userModel?.carrierId,
      );

  /// Assigns (or reassigns, before the driver answered) [order] to
  /// [driver]: the driver gets the normal offer with its countdown
  /// ([CarrierParcelService.assign]).
  Future<bool> assignParcelOrderToDriver(ParcelOrderModel order, UserModel driver) async {
    final String? orderId = order.id;
    if (orderId == null || orderId.isEmpty || (driver.id ?? '').isEmpty) return false;
    ShowToastDialog.showLoader("Assigning driver...".tr);
    final CarrierAssignResult result = await CarrierParcelService.assign(
      orderId: orderId,
      driver: driver,
      ownerUid: FireStoreUtils.getCurrentUid(),
      ownerCarrierId: Constant.userModel?.carrierId,
    );
    ShowToastDialog.closeLoader();
    if (result.failed) {
      ShowToastDialog.showToast("Could not assign the driver. Please try again.".tr);
      return false;
    }
    switch (result.check) {
      case CarrierAssignCheck.ok:
        ShowToastDialog.showToast("Order sent to the driver. Waiting for the driver to accept.".tr);
      case CarrierAssignCheck.sameDriver:
        ShowToastDialog.showToast("This order is already waiting for this driver.".tr);
      case CarrierAssignCheck.accepted:
        ShowToastDialog.showToast("A driver already accepted this order.".tr);
      case CarrierAssignCheck.notPaid:
        ShowToastDialog.showToast("This quote is not paid yet.".tr);
      case CarrierAssignCheck.driverNotVerified:
        ShowToastDialog.showToast(CarrierParcelRules.notVerifiedMessageKey(result.overall).tr);
      case CarrierAssignCheck.verificationUnavailable:
        ShowToastDialog.showToast("Could not check this driver's documents. Please try again.".tr);
      case CarrierAssignCheck.notMine:
      case CarrierAssignCheck.ended:
      case CarrierAssignCheck.gone:
        ShowToastDialog.showToast("This order is no longer available.".tr);
    }
    await fetchOrdersForSection();
    return result.isDone;
  }
}
