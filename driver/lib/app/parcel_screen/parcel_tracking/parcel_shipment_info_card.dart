import 'package:driver/constant/constant.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shipment details of the parcel/mail contract: type, scope, route, methods, pickup points,
/// tracking number and the tracking timeline. Renders nothing for parcels created before the contract.
///
/// Archetype D: a summary card whose facts read as `DsInfoRow`s and whose scan
/// history reads as a `DsTimeline` (newest step current, older ones done).
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
    final c = context.dsColors;
    final t = context.dsText;
    final origin = _place(order.origin);
    final destination = _place(order.destination);
    final String trackingStatus = (ParcelTrackingService.currentStatus(order) ?? '').tr;

    Widget row(String title, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return DsInfoRow(label: title, value: value);
    }

    Widget pointRow(String title, String? id) {
      if (id == null || id.isEmpty) return const SizedBox.shrink();
      return FutureBuilder<String?>(
        future: ParcelTrackingService.pickupPointName(id),
        builder: (_, snap) => row(title, snap.data ?? id),
      );
    }

    final events = order.trackingEvents.reversed.toList();

    return DsCard(
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: Icons.local_shipping_outlined, tone: DsTone.brand, size: 36),
              const DsGap(DsSpace.md),
              Expanded(child: Text("Shipment".tr, style: t.titleSm.w700)),
            ],
          ),
          const DsGap(DsSpace.sm),
          if ((order.trackingNumber ?? '').isNotEmpty || trackingStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((order.trackingNumber ?? '').isNotEmpty) ...[
                      Text("Tracking number".tr, style: t.overline),
                      Text(order.trackingNumber!, style: t.titleSm.w700.tabular),
                    ],
                    if (trackingStatus.isNotEmpty) ...[
                      const DsGap(DsSpace.sm),
                      Row(
                        children: [
                          Text("Tracking status".tr, style: t.caption),
                          const DsGap(DsSpace.sm),
                          Flexible(child: DsStatusChip(label: trackingStatus, status: ParcelTrackingService.currentStatus(order))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
          if (events.isNotEmpty) ...[
            const DsDivider(spacing: DsSpace.lg),
            Text("Timeline".tr, style: t.labelSm.withColor(c.textPrimary)),
            const DsGap(DsSpace.md),
            DsTimeline(
              steps: [
                for (var i = 0; i < events.length; i++)
                  DsTimelineStep(
                    title: (events[i].status ?? '').tr,
                    subtitle: [
                      if (events[i].at != null) Constant.timestampToDateTime(events[i].at!),
                      if (events[i].role != null) events[i].role!.tr,
                      if (events[i].note != null) events[i].note!,
                    ].join(' · '),
                    state: i == 0 ? DsStepState.current : DsStepState.done,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
