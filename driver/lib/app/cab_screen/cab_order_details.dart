import 'package:driver/app/cab_screen/widget/cab_ride_extras.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_order_details_controller.dart';
import '../../themes/ds/ds.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as osm;

/// Archetype J (detail) – static map header, route, trip metrics and the fare
/// breakdown as info rows.
class CabOrderDetails extends StatelessWidget {
  const CabOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CabOrderDetailsController(),
      builder: (controller) {
        return DsScaffold(
          title: "Ride Details",
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const DsSkeletonDetail(),
            builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.all(DsSpace.lg),
              child: Column(
                children: DsFadeSlideIn.stagger([
                  _orderIdCard(context, controller),
                  const DsGap(DsSpace.lg),
                  _routeCard(context, controller),
                  const DsGap(DsSpace.lg),
                  _mapCard(context, controller),
                  if (controller.cabOrder.value.driver != null) ...[
                    const DsGap(DsSpace.lg),
                    _customerCard(context, controller),
                  ],
                  const DsGap(DsSpace.lg),
                  _metricsCard(context, controller),
                  if (CabRideExtras.hasContent(controller.cabOrder.value, showCancellation: true)) ...[
                    const DsGap(DsSpace.lg),
                    DsCard(child: CabRideExtras(order: controller.cabOrder.value, isDark: context.dsIsDark, showCancellation: true)),
                  ],
                  const DsGap(DsSpace.lg),
                  _summaryCard(context, controller),
                  const DsGap(DsSpace.xxl),
                  if (!(controller.cabOrder.value.driver!.ownerId != null && controller.cabOrder.value.driver!.ownerId!.isNotEmpty ||
                      controller.cabOrder.value.status == Constant.orderPlaced))
                    DsInlineAlert(
                      tone: DsTone.danger,
                      icon: Icons.info_outline_rounded,
                      message: "Note : Admin commission will be debited from your wallet balance. \n \nAdmin commission will apply on your booking Amount minus Discount(if applicable).",
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _orderIdCard(BuildContext context, CabOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard.tinted(
      tone: DsTone.brand,
      child: Row(
        children: [
          DsIconWell(icon: Icons.confirmation_number_outlined, tone: DsTone.brand),
          const DsGap(DsSpace.md),
          Expanded(
            child: Text(
              "${'Order Id:'.tr} ${Constant.orderId(orderId: controller.cabOrder.value.id.toString())}".tr,
              style: t.titleSm.tabular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeCard(BuildContext context, CabOrderDetailsController controller) {
    final t = context.dsText;
    final order = controller.cabOrder.value;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text("${'Booking Date:'.tr}${controller.formatDate(order.scheduleDateTime!)}".tr, style: t.titleSm),
              ),
              const DsGap(DsSpace.sm),
              DsStatusChip(label: order.status.toString(), status: order.status),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsRouteStops(
            stops: [
              DsRouteStop(kind: DsStopKind.pickup, label: "Pickup".tr, address: order.sourceLocationName.toString()),
              DsRouteStop(kind: DsStopKind.drop, label: "Destination".tr, address: order.destinationLocationName.toString()),
            ],
          ),
        ],
      ),
    );
  }

  /// Map widget, markers and polylines are untouched – only the frame changed.
  Widget _mapCard(BuildContext context, CabOrderDetailsController controller) {
    final c = context.dsColors;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: DsRadius.brLg,
        color: c.surface,
        border: Border.all(color: c.border),
        boxShadow: DsShadows.sm(context),
      ),
      child: ClipRRect(
        borderRadius: DsRadius.brLg,
        child: Constant.selectedMapType == "osm"
            ? fm.FlutterMap(
                options: fm.MapOptions(
                  initialCenter: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                  initialZoom: 13,
                ),
                children: [
                  fm.TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.spideli.driver'),

                  // Only show polyline if points exist
                  if (controller.osmPolyline.isNotEmpty)
                    fm.PolylineLayer(polylines: [fm.Polyline(points: controller.osmPolyline.toList(), color: Colors.blue, strokeWidth: 4)]),

                  fm.MarkerLayer(
                    markers: [
                      fm.Marker(
                        point: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                        width: 20,
                        height: 20,
                        child: Image.asset('assets/icons/ic_cab_pickup.png', width: 10, height: 10),
                      ),
                      fm.Marker(
                        point: osm.LatLng(
                          controller.cabOrder.value.destinationLocation!.latitude!,
                          controller.cabOrder.value.destinationLocation!.longitude!,
                        ),
                        width: 20,
                        height: 20,
                        child: Image.asset('assets/icons/ic_cab_destination.png', width: 10, height: 10),
                      ),
                    ],
                  ),
                ],
              )
            : gmap.GoogleMap(
                initialCameraPosition: gmap.CameraPosition(
                  target: gmap.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                  zoom: 13,
                ),
                polylines: controller.googlePolylines.toSet(),
                markers: controller.googleMarkers.toSet(),
              ),
      ),
    );
  }

  Widget _customerCard(BuildContext context, CabOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("About Customer".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              DsAvatar(
                imageUrl: controller.cabOrder.value.author?.profilePictureURL ?? '',
                name: controller.cabOrder.value.author?.fullName(),
                size: 52,
              ),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Text(controller.cabOrder.value.author?.fullName() ?? '', style: t.title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricsCard(BuildContext context, CabOrderDetailsController controller) {
    final order = controller.cabOrder.value;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.sm),
      child: DsTripMetrics(
        filled: false,
        items: [
          DsTripMetric(
            icon: Icons.route_rounded,
            value: order.distance != null ? "${double.tryParse(order.distance.toString())?.toStringAsFixed(2) ?? '--'} KM" : "-- KM",
            label: "Distance".tr,
          ),
          DsTripMetric(icon: Icons.schedule_rounded, value: order.duration ?? '--', label: "Duration".tr),
          DsTripMetric(
            icon: Icons.payments_outlined,
            value: Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.subTotal),
            label: "${order.paymentMethod}".tr,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, CabOrderDetailsController controller) {
    final t = context.dsText;
    final order = controller.cabOrder.value;
    final currency = RegionService.currencyForRecord(order.regionId);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Order Summary".tr, style: t.overline),
          const DsGap(DsSpace.sm),

          // Subtotal
          DsInfoRow(label: "Subtotal".tr, value: Constant.amountShow(currency: currency, amount: controller.subTotal.value.toString())),

          // Discount
          DsInfoRow(label: "Discount".tr, value: Constant.amountShow(currency: currency, amount: controller.discount.value.toString())),

          // Tax List
          ...List.generate(order.taxSetting!.length, (index) {
            return DsInfoRow(
              label:
                  "${order.taxSetting![index].title} ${order.taxSetting![index].type == 'fix' ? '' : '(${order.taxSetting![index].tax}%)'}",
              value: Constant.amountShow(
                currency: currency,
                amount: Constant.getTaxValue(
                  amount: ((double.tryParse(order.subTotal.toString()) ?? 0.0) - (double.tryParse(order.discount.toString()) ?? 0.0)).toString(),
                  taxModel: order.taxSetting![index],
                ).toString(),
              ),
            );
          }),

          const DsDivider(spacing: DsSpace.sm),

          // Total
          DsInfoRow(label: "Order Total".tr, value: Constant.amountShow(currency: currency, amount: controller.totalAmount.value.toString()), emphasize: true),
          DsInfoRow(
            label: "Admin Commission (${order.adminCommission}${order.adminCommissionType == "Percentage" || order.adminCommissionType == "percentage" ? "%" : Constant.currencyModel!.symbol})".tr,
            value: Constant.amountShow(currency: currency, amount: controller.adminCommission.value.toString()),
            valueTone: DsTone.danger,
          ),
        ],
      ),
    );
  }
}
