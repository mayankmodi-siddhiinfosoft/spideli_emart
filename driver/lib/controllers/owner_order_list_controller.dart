import 'package:get/get.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import '../models/cab_order_model.dart';
import '../models/order_model.dart';
import '../models/parcel_order_model.dart';
import '../models/rental_order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  RxString parcelSelectedTab = 'In Transit'.obs;
  final List<String> parcelTabTitles = ["In Transit", "Delivered", "Cancelled"];

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
          ownerSections.value = allSections
              .where((s) => s.id != null && ownerSectionIds.contains(s.id))
              .toList();
        }),
        FireStoreUtils.getOwnerDriver().then((drivers) {
          driverList.value = drivers;
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
    return driverList
        .where((d) => d.sectionIds?.contains(sectionId) == true)
        .toList();
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

      if (targetDriverIds.isEmpty) {
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

      final sectionId = section.id!;
      final flag = section.serviceTypeFlag;

      switch (flag) {
        case 'cab-service':
          cabOrders.value = await FireStoreUtils.getCabOrdersBySection(
            sectionId: sectionId,
            driverIds: targetDriverIds,
          );
          break;
        case 'parcel_delivery':
          parcelOrders.value = await FireStoreUtils.getParcelOrdersBySection(
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
            .where((o) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(o.status))
            .toList();
      default:
        return [];
    }
  }

  List<ParcelOrderModel> getParcelOrdersForTab(String tab) {
    switch (tab) {
      case "In Transit":
        return parcelOrders.where((o) => _onGoingStatuses.contains(o.status)).toList();
      case "Delivered":
        return parcelOrders.where((o) => o.status == "Order Completed").toList();
      case "Cancelled":
        return parcelOrders
            .where((o) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(o.status))
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
            .where((o) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(o.status))
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
            .where((o) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(o.status))
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
}
