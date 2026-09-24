import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_order_controller.dart';
import '../cab_screen/cab_order_list_screen.dart';
import '../parcel_screen/parcel_order_list_screen.dart';
import '../rental_service/rental_order_list_screen.dart';

/// Archetype J – host for a single driver's order history; the service list
/// itself is rendered by the matching service screen.
class DriverOrderList extends StatelessWidget {
  const DriverOrderList({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DriverOrderListController>(
      init: DriverOrderListController(),
      builder: (controller) {
        final String serviceType = controller.serviceType.value;
        return DsScaffold(
          title: "Driver Orders".tr,
          subtitle: _serviceLabel(serviceType),
          maxContentWidth: null,
          body: _buildBody(serviceType),
        );
      },
    );
  }

  String? _serviceLabel(String serviceType) {
    switch (serviceType) {
      case "cab-service":
        return "Cab".tr;
      case "parcel_delivery":
        return "Parcel".tr;
      case "rental-service":
        return "Rental".tr;
      default:
        return null;
    }
  }

  Widget _buildBody(String? serviceType) {
    switch (serviceType) {
      case "cab-service":
        return const CabOrderListScreen();
      case "parcel_delivery":
        return const ParcelOrderListScreen();
      case "rental-service":
        return const RentalOrderListScreen();
      default:
        return const Center(child: DsEmptyState(icon: Icons.help_outline_rounded, title: "Service type not supported"));
    }
  }
}
