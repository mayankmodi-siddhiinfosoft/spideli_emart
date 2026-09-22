import 'package:driver/constant/constant.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shipment details of the parcel/mail contract: type, scope, route, methods, pickup points,
/// tracking number and the tracking timeline. Renders nothing for parcels created before the contract.
class ParcelShipmentInfoCard extends StatelessWidget {
  final ParcelOrderModel order;
  final bool isDark;

  const ParcelShipmentInfoCard({super.key, required this.order, required this.isDark});

  static String _label(String? v) {
    switch (v) {
      case 'parcel':
        return 'Parcel'.tr;
      case 'mail':
        return 'Mail'.tr;
      case 'city':
        return 'Same city'.tr;
      case 'intercity':
        return 'Intercity'.tr;
      case 'intercountry':
        return 'Intercountry'.tr;
      case 'home':
        return 'Home'.tr;
      case 'pickup_point':
        return 'Pickup point'.tr;
      default:
        return v ?? '-';
    }
  }

  static String _place(Map<String, dynamic>? m) {
    if (m == null) return '';
    return [m['city'], m['country']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (!order.hasTrackingContract && order.trackingEvents.isEmpty) return const SizedBox.shrink();
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final subColor = isDark ? AppThemeData.grey300 : AppThemeData.grey600;
    final origin = _place(order.origin);
    final destination = _place(order.destination);

    Widget row(String title, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(title, style: TextStyle(color: subColor, fontSize: 13))),
            Expanded(child: Text(value, style: TextStyle(color: textColor, fontSize: 14, fontFamily: AppThemeData.semiBold))),
          ],
        ),
      );
    }

    Widget pointRow(String title, String? id) {
      if (id == null || id.isEmpty) return const SizedBox.shrink();
      return FutureBuilder<String?>(
        future: ParcelTrackingService.pickupPointName(id),
        builder: (_, snap) => row(title, snap.data ?? id),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Shipment".tr, style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, color: textColor)),
          const SizedBox(height: 8),
          row("Tracking number".tr, order.trackingNumber),
          row("Tracking status".tr, (ParcelTrackingService.currentStatus(order) ?? '').tr),
          row("Type".tr, order.shipmentType == null ? null : _label(order.shipmentType)),
          row("Scope".tr, order.scope == null ? null : _label(order.scope)),
          row("Route".tr, origin.isEmpty && destination.isEmpty ? null : '$origin  →  $destination'),
          row("Carrier".tr, order.carrierName),
          row("Pickup".tr, order.pickupMethod == null ? null : _label(order.pickupMethod)),
          pointRow("Origin pickup point".tr, order.originPickupPointId),
          row("Delivery".tr, order.deliveryMethod == null ? null : _label(order.deliveryMethod)),
          pointRow("Destination pickup point".tr, order.destinationPickupPointId),
          row("Content".tr, order.contentDescription),
          row("Declared value".tr, order.declaredValue),
          row("Proof of delivery".tr, order.deliveryProof?['type']?.toString()),
          if (order.trackingEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("Timeline".tr, style: TextStyle(fontSize: 15, fontFamily: AppThemeData.semiBold, color: textColor)),
            const SizedBox(height: 6),
            ...order.trackingEvents.reversed.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 10, color: AppThemeData.primary300),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((e.status ?? '').tr, style: TextStyle(color: textColor, fontFamily: AppThemeData.semiBold)),
                          Text(
                            [if (e.at != null) Constant.timestampToDateTime(e.at!), if (e.role != null) e.role!.tr, if (e.note != null) e.note!].join(' · '),
                            style: TextStyle(color: subColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
