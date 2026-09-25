import 'package:customer/utils/order_receipt_pdf.dart';
import 'package:customer/utils/ride_receipt_pdf.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:customer/screen_ui/cab_service_screens/widget/cab_ride_options_widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../constant/constant.dart';
import '../../controllers/cab_order_details_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';

import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as osm;

import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';
import 'cab_review_screen.dart';
import 'complain_screen.dart';

/// Ride detail (archetype F — detail): a status hero tinted by the ride
/// status, the A → B route, a route map, the ride extras, the driver card
/// with contact actions, trip metrics and the bill; review and complaint sit
/// in a sticky bar once the ride is complete.
class CabOrderDetails extends StatelessWidget {
  const CabOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CabOrderDetailsController(),
      builder: (controller) {
        final l = context.dsLayout;
        final loading = controller.isLoading.value;
        final order = controller.cabOrder.value;
        final isCompleted = order.status == Constant.orderCompleted;
        return DsScaffold(
          title: "Ride Details".tr,
          onBack: () => Get.back(),
          actions: [
            // PDF receipt: download / share (spec 7.6).
            if (!loading)
              DsIconButton(
                icon: Icons.receipt_long_outlined,
                semanticLabel: "Receipt".tr,
                variant: DsIconButtonVariant.tonal,
                onPressed: () => OrderReceiptPdf.showOptions(context, () => RideReceiptPdf.fromCabOrder(controller)),
              ),
          ],
          maxContentWidth: DsLayout.contentMax,
          body: loading
              ? const DsSkeletonDetail(mediaHeight: 180)
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: DsFadeSlideIn.stagger([
                      _RideHero(controller: controller),
                      const DsGap(DsSpace.lg),
                      _RouteMap(controller: controller),
                      // Stops, passengers, instructions, rider, cancellation reason (spec 4.8).
                      CabRideExtrasView(order: order, showCancellation: true),
                      if (order.driver != null) ...[const DsGap(DsSpace.lg), _DriverCard(controller: controller)],
                      const DsGap(DsSpace.lg),
                      _TripMetrics(controller: controller),
                      const DsGap(DsSpace.lg),
                      _BillCard(controller: controller, onTaxTap: () => showBillBifurcationDialog(context, controller)),
                    ]),
                  ),
                ),
          bottomBar: loading || !isCompleted || order.driver == null
              ? null
              : DsStickyBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: DsButton.primary(
                          label: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                          icon: Icons.star_rounded,
                          onPressed: () async {
                            final result = await Get.to(() => CabReviewScreen(), arguments: {'order': controller.cabOrder.value});

                            // If review was submitted successfully
                            if (result == true) {
                              await controller.fetchDriverDetails();
                            }
                          },
                        ),
                      ),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: DsButton.secondary(
                          label: 'Complain'.tr,
                          icon: Icons.report_gmailerrorred_rounded,
                          onPressed: () async {
                            Get.to(() => ComplainScreen(), arguments: {'order': controller.cabOrder.value});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void showBillBifurcationDialog(BuildContext context, CabOrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        final currency = RegionService.currencyForRecord(controller.cabOrder.value.regionId);
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.receipt_long_rounded,
          tone: DsTone.info,
          content: Column(
            children: [
              CabBillRow(
                label: "Tax on Order Total".tr,
                value: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: currency),
              ),
              const DsDivider(spacing: DsSpace.xl),
              CabBillRow(
                label: "Tax on Platform Fee".tr,
                value: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: currency),
              ),
              const DsDivider(spacing: DsSpace.xl),
              CabBillRow(
                label: "Total Tax Amount".tr,
                value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: currency),
                valueColor: context.dsColors.brandStrong,
                emphasize: true,
              ),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}

/// Status, ride id, booking date and the A → B route.
class _RideHero extends StatelessWidget {
  final CabOrderDetailsController controller;

  const _RideHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DsObserve(
      builder: (_) {
        final order = controller.cabOrder.value;
        final status = order.status.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsCard.tinted(
              tone: DsTone.fromStatus(order.status),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OrderIdHeader(
                    title: 'Order Id:'.tr,
                    id: order.id.toString(),
                    subtitle: "${'Booking Date:'.tr} ${controller.formatDate(order.scheduleDateTime!)}".tr,
                    statusLabel: status,
                    status: order.status,
                    pulse: order.status == Constant.orderInTransit,
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.lg),
            DsCard.outlined(
              child: CabRouteRail(source: order.sourceLocationName.toString(), destination: order.destinationLocationName.toString()),
            ),
          ],
        );
      },
    );
  }
}

/// The ride's route on the map. Map, marker and polyline wiring is unchanged.
class _RouteMap extends StatelessWidget {
  final CabOrderDetailsController controller;

  const _RouteMap({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsObserve(
      builder: (_) => Container(
        height: context.dsLayout.value(phone: 180.0, tablet: 260.0),
        decoration: BoxDecoration(
          borderRadius: DsRadius.brLg,
          color: c.surfaceAlt,
          border: Border.all(color: c.border),
        ),
        child: ClipRRect(
          borderRadius: DsRadius.brLg,
          child: Constant.selectedMapType == "osm"
              ? fm.FlutterMap(
                  options: fm.MapOptions(initialCenter: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!), initialZoom: 13),
                  children: [
                    fm.TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.spideli.customer'),

                    // Only show polyline if points exist
                    if (controller.osmPolyline.isNotEmpty)
                      fm.PolylineLayer(
                        polylines: [fm.Polyline(points: controller.osmPolyline.toList(), color: Colors.blue, strokeWidth: 4)],
                      ),

                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                          width: 20,
                          height: 20,
                          child: Image.asset('assets/icons/ic_cab_pickup.png', width: 10, height: 10),
                        ),
                        fm.Marker(
                          point: osm.LatLng(controller.cabOrder.value.destinationLocation!.latitude!, controller.cabOrder.value.destinationLocation!.longitude!),
                          width: 20,
                          height: 20,
                          child: Image.asset('assets/icons/ic_cab_destination.png', width: 10, height: 10),
                        ),
                      ],
                    ),
                  ],
                )
              : gmap.GoogleMap(
                  initialCameraPosition: gmap.CameraPosition(target: gmap.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!), zoom: 13),
                  polylines: controller.googlePolylines.toSet(),
                  markers: controller.googleMarkers.toSet(),
                ),
        ),
      ),
    );
  }
}

/// Driver, vehicle, rating and the call / chat actions while the ride runs.
class _DriverCard extends StatelessWidget {
  final CabOrderDetailsController controller;

  const _DriverCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsObserve(
      builder: (_) {
        final order = controller.cabOrder.value;
        final sid = order.sectionId ?? '';
        final vehicle = order.driver?.vehicleDetails?[sid];
        final vType = vehicle?['vehicleType']?.toString() ?? '';
        final brand = vehicle?['carBrand']?.toString() ?? '';
        final carModel = vehicle?['carModel']?.toString() ?? '';
        final plate = vehicle?['carPlateNumber']?.toString() ?? '';
        final car = "$brand $carModel".trim();
        return DsCard.outlined(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ride & Fare Summary".tr, style: t.overline),
              const DsGap(DsSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsAvatar(imageUrl: order.driver?.profilePictureURL ?? '', name: order.driver?.fullName(), size: 56, ring: true),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.driver?.fullName() ?? '', style: t.titleSm),
                        if (vehicle != null) ...[
                          if (vType.isNotEmpty || car.isNotEmpty) ...[
                            const DsGap(DsSpace.xxs),
                            Text([if (vType.isNotEmpty) vType, if (car.isNotEmpty) car].join(' · '), style: t.bodySm),
                          ],
                          if (plate.isNotEmpty) ...[const DsGap(DsSpace.sm), DsBadge(label: plate.toUpperCase(), style: DsBadgeStyle.outline, tone: DsTone.neutral)],
                        ],
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  DsBadge(label: controller.driverUser.value.averageRating.toStringAsFixed(1), tone: DsTone.warning, icon: Icons.star_rounded),
                ],
              ),
              if (order.status != Constant.orderCompleted) ...[
                const DsGap(DsSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: DsButton.tonal(
                        label: "Call".tr,
                        icon: Icons.call_rounded,
                        expand: true,
                        onPressed: () {
                          Constant.makePhoneCall(controller.cabOrder.value.driver!.phoneNumber.toString());
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: DsButton.tonal(
                        label: "Chat".tr,
                        icon: Icons.chat_bubble_outline_rounded,
                        expand: true,
                        onPressed: () async {
                          ShowToastDialog.showLoader("Please wait...".tr);

                          UserModel? customer = await FireStoreUtils.getUserProfile(controller.cabOrder.value.authorID ?? '');
                          UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.cabOrder.value.driverId ?? '');

                          ShowToastDialog.closeLoader();

                          Get.to(
                            const ChatScreen(),
                            arguments: {
                              "senderName": customer?.fullName(),
                              "receivedName": driverUser?.fullName(),
                              "orderId": controller.cabOrder.value.id,
                              "senderId": driverUser?.id,
                              "customerId": customer?.id,
                              "senderProfileUrl": customer?.profilePictureURL,
                              "receivedProfileUrl": driverUser?.profilePictureURL,
                              "token": driverUser?.fcmToken,
                              "chatType": Constant.userRoleDriver,
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Distance / duration / fare strip.
class _TripMetrics extends StatelessWidget {
  final CabOrderDetailsController controller;

  const _TripMetrics({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DsObserve(
      builder: (_) {
        final order = controller.cabOrder.value;
        return DsCard.outlined(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(value: "${double.parse(order.distance.toString()).toStringAsFixed(2)} ${'KM'.tr}", title: "Distance".tr, icon: "assets/icons/ic_distance_parcel.svg", tone: DsTone.info),
              ),
              Expanded(
                child: _Metric(value: order.duration ?? '--', title: "Duration".tr, icon: "assets/icons/ic_duration.svg", tone: DsTone.warning),
              ),
              Expanded(
                child: _Metric(
                  value: Constant.amountShow(amount: order.subTotal, currency: RegionService.currencyForRecord(order.regionId)),
                  title: "${order.paymentMethod}".tr,
                  icon: "assets/icons/ic_rate_parcel.svg",
                  tone: DsTone.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String title;
  final String icon;
  final DsTone tone;

  const _Metric({required this.value, required this.title, required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final accent = c.tone(tone);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIconWell(
          tone: tone,
          size: 40,
          circle: true,
          child: SvgPicture.asset(icon, height: 20, width: 20, colorFilter: ColorFilter.mode(accent.strong, BlendMode.srcIn)),
        ),
        const DsGap(DsSpace.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1, style: t.titleSm.tabular),
        ),
        const DsGap(DsSpace.xxs),
        Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption),
      ],
    );
  }
}

/// Bill summary: subtotal, discount, platform fee, tax (tap for the split)
/// and the total.
class _BillCard extends StatelessWidget {
  final CabOrderDetailsController controller;
  final VoidCallback onTaxTap;

  const _BillCard({required this.controller, required this.onTaxTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsObserve(
      builder: (_) {
        final currency = RegionService.currencyForRecord(controller.cabOrder.value.regionId);
        return DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Order Summary".tr, style: t.overline),
              const DsGap(DsSpace.md),

              // Subtotal
              CabBillRow(
                label: "Subtotal".tr,
                value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: currency),
              ),

              // Discount
              CabBillRow(
                label: "Discount".tr,
                value: Constant.amountShow(amount: controller.discount.value.toString(), currency: currency),
              ),

              // Tax List
              if (Constant.platformFeeModel?.enable == true)
                CabBillRow(
                  label: "Platform fee".tr,
                  value: Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: currency),
                ),

              CabBillRow(
                label: "Tax amount".tr,
                value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: currency),
                onTap: onTaxTap,
              ),

              const DsDivider(spacing: DsSpace.lg),

              // Total
              CabBillRow(
                label: "Order Total".tr,
                value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: currency),
                emphasize: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
