import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/order_receipt_pdf.dart' show Code128;
import 'package:customer/utils/parcel_pricing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:qr_flutter/qr_flutter.dart';

/// Labels shared by the parcel shipping screens and the PDF receipt.
class ParcelLabels {
  ParcelLabels._();

  static String scope(String? scope) {
    switch (scope) {
      case ParcelScope.intercity:
        return 'Other city'.tr;
      case ParcelScope.intercountry:
        return 'Other country'.tr;
      default:
        return 'Same city'.tr;
    }
  }

  static String shipmentType(String? type) => type == ParcelShipping.mail ? 'Mail'.tr : 'Parcel'.tr;

  static String pickupMethod(String? method) => method == ParcelShipping.pickupPoint ? 'Drop-off at a pickup point'.tr : 'Home pickup by a driver'.tr;

  static String deliveryMethod(String? method) => method == ParcelShipping.pickupPoint ? 'Collection at a pickup point'.tr : 'Home delivery'.tr;

  static Map<String, dynamic> breakdownOf(ParcelQuote q, String? currencyCode) => {
    'carrierPrice': q.carrierPrice,
    'extraKgCharge': q.extraKgCharge,
    'fixedTax': q.fixedTax,
    'commission': q.commission,
    'options': q.options,
    'total': q.total,
    'currency': currencyCode ?? '',
    'source': q.source,
  };

  static double n(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

  /// Lines of `priceBreakdown` (zero lines skipped except the carrier price).
  static List<MapEntry<String, double>> breakdownLines(Map<String, dynamic> b) => [
    MapEntry('Carrier price'.tr, n(b['carrierPrice'])),
    if (n(b['extraKgCharge']) > 0) MapEntry('Extra kg'.tr, n(b['extraKgCharge'])),
    if (n(b['fixedTax']) > 0) MapEntry('Fixed tax'.tr, n(b['fixedTax'])),
    if (n(b['commission']) > 0) MapEntry('Commission'.tr, n(b['commission'])),
    if (n(b['options']) > 0) MapEntry('Options'.tr, n(b['options'])),
  ];
}

/// Section header used inside the parcel cards ("Shipment", "Shipping price").
class ParcelCardTitle extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;

  const ParcelCardTitle(this.label, {super.key, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: c.brandStrong), const DsGap(DsSpace.sm)],
          Expanded(child: Text(label.toUpperCase(), style: t.overline)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Neutral surface used by every parcel shipping block.
class ParcelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const ParcelCard({super.key, required this.child, this.padding = const EdgeInsets.all(DsSpace.lg), this.margin, this.borderColor, this.onTap, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return DsCard.outlined(padding: padding, margin: margin, borderColor: borderColor, onTap: onTap, semanticLabel: semanticLabel, child: child);
  }
}

/// Price breakdown shown before payment (spec 7.4) and on the order details.
class ParcelBreakdownCard extends StatelessWidget {
  final CurrencyModel? currency;
  final Map<String, dynamic> breakdown;
  final String? title;

  const ParcelBreakdownCard({super.key, required this.currency, required this.breakdown, this.title});

  @override
  Widget build(BuildContext context) {
    final lines = ParcelLabels.breakdownLines(breakdown);
    final double subtotal = lines.fold(0.0, (a, e) => a + e.value);
    return ParcelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParcelCardTitle(title ?? "Shipping price".tr, icon: Icons.receipt_long_rounded),
          for (final l in lines) OrderMoneyRow(label: l.key, value: Constant.amountShow(amount: l.value.toString(), currency: currency)),
          OrderTotalRow(label: "Shipping total".tr, value: Constant.amountShow(amount: subtotal.toString(), currency: currency)),
        ],
      ),
    );
  }
}

/// Code 128 barcode drawn with the receipt encoder.
class Code128BarcodeWidget extends StatelessWidget {
  final String value;
  final double height;

  const Code128BarcodeWidget({super.key, required this.value, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final List<int>? modules = Code128.encode(value);
    if (modules == null) return const SizedBox.shrink();
    return SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _BarcodePainter(modules)));
  }
}

class _BarcodePainter extends CustomPainter {
  final List<int> modules;

  _BarcodePainter(this.modules);

  @override
  void paint(Canvas canvas, Size size) {
    final int total = modules.fold(0, (a, b) => a + b);
    // Quiet zone of 10 modules each side.
    final double module = size.width / (total + 20);
    final Paint paint = Paint()..color = Colors.black;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    double x = module * 10;
    for (int i = 0; i < modules.length; i++) {
      final double w = modules[i] * module;
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) => oldDelegate.modules != modules;
}

/// QR (qrValue) + Code 128 barcode (trackingNumber) + pickup code for the sender to share.
///
/// Laid out as a "boarding pass": the scannable block sits on a white plate so
/// the codes stay readable in dark mode, the tracking number is tabular and
/// copyable, and the receiver code is a tinted callout.
class ParcelCodesCard extends StatelessWidget {
  final ParcelOrderModel order;

  const ParcelCodesCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool hasQr = (order.qrValue ?? '').isNotEmpty;
    final bool hasTracking = (order.trackingNumber ?? '').isNotEmpty;
    return ParcelCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        children: [
          if (hasQr || hasTracking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
              decoration: BoxDecoration(color: Colors.white, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
              child: Column(
                children: [
                  if (hasQr) QrImageView(data: order.qrValue!, size: 170, backgroundColor: Colors.white),
                  if (hasQr && hasTracking) const DsGap(DsSpace.lg),
                  if (hasTracking) Code128BarcodeWidget(value: order.trackingNumber!),
                ],
              ),
            ),
          if (hasTracking) ...[
            const DsGap(DsSpace.md),
            Semantics(
              button: true,
              label: "Tracking number".tr,
              child: InkWell(
                borderRadius: DsRadius.brSm,
                onTap: () => _copy(order.trackingNumber!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(order.trackingNumber!, style: t.title.tabular, textAlign: TextAlign.center)),
                      const DsGap(DsSpace.sm),
                      Icon(Icons.copy_rounded, size: 16, color: c.brandStrong),
                    ],
                  ),
                ),
              ),
            ),
            Text("Tracking number".tr, style: t.caption),
          ],
          if ((order.pickupCode ?? '').isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            DsCard.tinted(
              padding: const EdgeInsets.all(DsSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Receiver code (give to the driver or at the pickup point)".tr, style: t.label),
                        const DsGap(DsSpace.xxs),
                        Text(
                          "Share it with the receiver: it is asked at delivery or to collect the parcel at the pickup point.".tr,
                          style: t.bodySm,
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Semantics(
                    button: true,
                    label: "Receiver code (give to the driver or at the pickup point)".tr,
                    child: InkWell(
                      borderRadius: DsRadius.brSm,
                      onTap: () => _copy(order.pickupCode!),
                      child: Padding(
                        padding: const EdgeInsets.all(DsSpace.sm),
                        child: Text(order.pickupCode!, style: t.headline.tabular.withColor(c.brandStrong)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ShowToastDialog.showToast("Copied".tr);
  }
}

/// Type, scope, route, methods (with pickup point names), carrier and parcel details.
class ParcelShippingSummaryCard extends StatelessWidget {
  final ParcelOrderModel order;

  const ParcelShippingSummaryCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    // Label column is proportional, not a fixed 118px, so it still reads at
    // 1.3x text scale; values stay capped at two lines.
    Widget pair(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(c.textMuted))),
          const DsGap(DsSpace.md),
          Expanded(flex: 3, child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyStrong)),
        ],
      ),
    );
    final dims = order.dimensions;
    return FutureBuilder<List<PickupPointModel?>>(
      future: Future.wait([ParcelShippingService.pickupPoint(order.originPickupPointId), ParcelShippingService.pickupPoint(order.destinationPickupPointId)]),
      builder: (context, snap) {
        final PickupPointModel? from = snap.data?[0];
        final PickupPointModel? to = snap.data?[1];
        return ParcelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParcelCardTitle("Shipment".tr, icon: Icons.inventory_2_outlined),
              pair("Type".tr, "${ParcelLabels.shipmentType(order.shipmentType)} - ${ParcelLabels.scope(order.scope)}"),
              if ((order.origin?.label ?? '').isNotEmpty || (order.destination?.label ?? '').isNotEmpty) pair("Route".tr, "${order.origin?.label ?? ''}  >  ${order.destination?.label ?? ''}"),
              pair("Pickup".tr, from != null ? "${ParcelLabels.pickupMethod(order.pickupMethod)}: ${from.name}" : ParcelLabels.pickupMethod(order.pickupMethod)),
              pair("Delivery".tr, to != null ? "${ParcelLabels.deliveryMethod(order.deliveryMethod)}: ${to.name}" : ParcelLabels.deliveryMethod(order.deliveryMethod)),
              pair("Carrier".tr, order.carrierName ?? (order.quoteRequested == true ? "To be assigned".tr : "Spideli drivers".tr)),
              if ((order.parcelWeight ?? '').isNotEmpty) pair("Weight".tr, order.parcelWeight!),
              if (dims != null) pair("Dimensions".tr, "${dims['l'] ?? 0} x ${dims['w'] ?? 0} x ${dims['h'] ?? 0} cm"),
              if ((order.declaredValue ?? '').isNotEmpty) pair("Declared value".tr, order.declaredValue!),
              if ((order.contentDescription ?? '').isNotEmpty) pair("Content".tr, order.contentDescription!),
              if ((order.receiver?.email ?? '').isNotEmpty) pair("Receiver email".tr, order.receiver!.email!),
            ],
          ),
        );
      },
    );
  }
}

/// A point shown on a parcel map.
class ParcelMapPoint {
  final double lat;
  final double lng;
  final String label;
  final bool highlight;

  ParcelMapPoint(this.lat, this.lng, this.label, {this.highlight = false});
}

/// Small map (OSM or Google, per the app setting) with markers.
class ParcelPointsMap extends StatelessWidget {
  final List<ParcelMapPoint> points;
  final double height;
  final void Function(int index)? onTap;

  const ParcelPointsMap({super.key, required this.points, this.height = 220, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final double lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final double lng = points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;
    final double zoom = _zoomFor(points);
    return ClipRRect(
      borderRadius: DsRadius.brLg,
      child: SizedBox(
        height: height,
        child:
            Constant.selectedMapType == 'osm'
                ? fm.FlutterMap(
                  options: fm.MapOptions(initialCenter: ll.LatLng(lat, lng), initialZoom: zoom),
                  children: [
                    fm.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spideli.customer'),
                    if (points.length > 1) fm.PolylineLayer(polylines: [fm.Polyline(points: points.map((p) => ll.LatLng(p.lat, p.lng)).toList(), strokeWidth: 3, color: AppThemeData.primary300)]),
                    fm.MarkerLayer(
                      markers: [
                        for (int i = 0; i < points.length; i++)
                          fm.Marker(
                            point: ll.LatLng(points[i].lat, points[i].lng),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: onTap == null ? null : () => onTap!(i),
                              child: Tooltip(message: points[i].label, child: Icon(Icons.location_on, size: 34, color: points[i].highlight ? Colors.red : AppThemeData.primary300)),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
                : gmap.GoogleMap(
                  initialCameraPosition: gmap.CameraPosition(target: gmap.LatLng(lat, lng), zoom: zoom),
                  zoomControlsEnabled: false,
                  markers: {
                    for (int i = 0; i < points.length; i++)
                      gmap.Marker(
                        markerId: gmap.MarkerId('p$i'),
                        position: gmap.LatLng(points[i].lat, points[i].lng),
                        infoWindow: gmap.InfoWindow(title: points[i].label),
                        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(points[i].highlight ? gmap.BitmapDescriptor.hueRed : gmap.BitmapDescriptor.hueOrange),
                        onTap: onTap == null ? null : () => onTap!(i),
                      ),
                  },
                  polylines: {
                    if (points.length > 1)
                      gmap.Polyline(polylineId: const gmap.PolylineId('route'), points: points.map((p) => gmap.LatLng(p.lat, p.lng)).toList(), width: 3, color: AppThemeData.primary300),
                  },
                ),
      ),
    );
  }

  static double _zoomFor(List<ParcelMapPoint> points) {
    if (points.length < 2) return 14;
    double span = 0;
    for (final p in points) {
      for (final q in points) {
        final double d = [(p.lat - q.lat).abs(), (p.lng - q.lng).abs()].reduce((a, b) => a > b ? a : b);
        if (d > span) span = d;
      }
    }
    if (span > 20) return 2;
    if (span > 5) return 4;
    if (span > 1) return 7;
    if (span > 0.2) return 10;
    if (span > 0.05) return 12;
    return 14;
  }
}

/// Timeline of `trackingEvents` (newest last in the data, shown newest first).
class ParcelTimeline extends StatelessWidget {
  final List<ParcelTrackingEvent> events;
  final Map<String, PickupPointModel> pickupPoints;

  const ParcelTimeline({super.key, required this.events, required this.pickupPoints});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final List<ParcelTrackingEvent> list = events.reversed.toList();
    if (list.isEmpty) return Text("No tracking events yet".tr, style: t.bodySecondary);
    return DsTimeline(
      steps: [
        for (int i = 0; i < list.length; i++)
          DsTimelineStep(
            title: list[i].status.tr,
            state: i == 0 ? DsStepState.current : DsStepState.done,
            subtitle: _subtitle(list[i]),
          ),
      ],
    );
  }

  String? _subtitle(ParcelTrackingEvent event) {
    final parts = <String>[
      if (event.at != null) DateFormat('dd MMM yyyy, hh:mm a').format(event.at!.toDate()),
      if (event.pickupPointId != null && pickupPoints[event.pickupPointId] != null) pickupPoints[event.pickupPointId]!.name,
      if (event.note != null) event.note!,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }
}
