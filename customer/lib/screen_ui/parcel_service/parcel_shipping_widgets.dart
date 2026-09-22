import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/app_them_data.dart';
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

class ParcelCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsets padding;

  const ParcelCard({super.key, required this.isDark, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      child: child,
    );
  }
}

/// Price breakdown shown before payment (spec 7.4) and on the order details.
class ParcelBreakdownCard extends StatelessWidget {
  final bool isDark;
  final CurrencyModel? currency;
  final Map<String, dynamic> breakdown;
  final String? title;

  const ParcelBreakdownCard({super.key, required this.isDark, required this.currency, required this.breakdown, this.title});

  @override
  Widget build(BuildContext context) {
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    Widget row(String l, double v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(l, style: bold ? AppThemeData.boldTextStyle(fontSize: 16, color: text) : AppThemeData.mediumTextStyle(fontSize: 15, color: text))),
          Text(Constant.amountShow(amount: v.toString(), currency: currency), style: bold ? AppThemeData.boldTextStyle(fontSize: 16, color: text) : AppThemeData.semiBoldTextStyle(fontSize: 15, color: text)),
        ],
      ),
    );
    final lines = ParcelLabels.breakdownLines(breakdown);
    final double subtotal = lines.fold(0.0, (a, e) => a + e.value);
    return ParcelCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title ?? "Shipping price".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
          const SizedBox(height: 6),
          for (final l in lines) row(l.key, l.value),
          const Divider(),
          row("Shipping total".tr, subtotal, bold: true),
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
class ParcelCodesCard extends StatelessWidget {
  final ParcelOrderModel order;
  final bool isDark;

  const ParcelCodesCard({super.key, required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    return ParcelCard(
      isDark: isDark,
      child: Column(
        children: [
          if ((order.qrValue ?? '').isNotEmpty)
            Container(color: Colors.white, padding: const EdgeInsets.all(8), child: QrImageView(data: order.qrValue!, size: 170, backgroundColor: Colors.white)),
          const SizedBox(height: 10),
          if ((order.trackingNumber ?? '').isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Code128BarcodeWidget(value: order.trackingNumber!)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _copy(order.trackingNumber!),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(order.trackingNumber!, style: AppThemeData.boldTextStyle(fontSize: 18, color: text)),
                  const SizedBox(width: 6),
                  Icon(Icons.copy, size: 16, color: muted),
                ],
              ),
            ),
            Text("Tracking number".tr, style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
          ],
          if ((order.pickupCode ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Receiver code (give to the driver or at the pickup point)".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: text)),
                      Text(
                        "Share it with the receiver: it is asked at delivery or to collect the parcel at the pickup point.".tr,
                        style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copy(order.pickupCode!),
                  child: Text(order.pickupCode!, style: AppThemeData.boldTextStyle(fontSize: 22, color: AppThemeData.primary300)),
                ),
              ],
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
  final bool isDark;

  const ParcelShippingSummaryCard({super.key, required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    Widget pair(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted))),
          Expanded(child: Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: text))),
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
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Shipment".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
              const SizedBox(height: 6),
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
      borderRadius: BorderRadius.circular(15),
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
  final bool isDark;

  const ParcelTimeline({super.key, required this.events, required this.pickupPoints, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    final List<ParcelTrackingEvent> list = events.reversed.toList();
    if (list.isEmpty) return Text("No tracking events yet".tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: muted));
    return Column(
      children: [
        for (int i = 0; i < list.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Icon(i == 0 ? Icons.radio_button_checked : Icons.circle, size: i == 0 ? 20 : 12, color: i == 0 ? AppThemeData.primary300 : muted),
                      if (i < list.length - 1) Expanded(child: Container(width: 2, color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list[i].status.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 15, color: text)),
                        if (list[i].at != null) Text(DateFormat('dd MMM yyyy, hh:mm a').format(list[i].at!.toDate()), style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                        if (list[i].pickupPointId != null && pickupPoints[list[i].pickupPointId] != null)
                          Text(pickupPoints[list[i].pickupPointId]!.name, style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                        if (list[i].note != null) Text(list[i].note!, style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
