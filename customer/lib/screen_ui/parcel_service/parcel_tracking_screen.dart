import 'dart:async';

import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

/// Spec 7.5: scan the QR or type the tracking number, then a live timeline of
/// `trackingEvents` and a map of the known positions.
class ParcelTrackingScreen extends StatefulWidget {
  /// Optional order to open directly (from the order details).
  final ParcelOrderModel? order;

  const ParcelTrackingScreen({super.key, this.order});

  @override
  State<ParcelTrackingScreen> createState() => _ParcelTrackingScreenState();
}

class _ParcelTrackingScreenState extends State<ParcelTrackingScreen> {
  final TextEditingController input = TextEditingController();
  ParcelOrderModel? order;
  StreamSubscription<ParcelOrderModel?>? _sub;
  Map<String, PickupPointModel> points = {};
  bool searching = false;
  bool notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) _show(widget.order!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    if (value.trim().isEmpty) {
      ShowToastDialog.showToast("Enter a tracking number".tr);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      notFound = false;
    });
    final ParcelOrderModel? found = await ParcelShippingService.findOrder(value);
    if (!mounted) return;
    setState(() => searching = false);
    if (found == null) {
      setState(() => notFound = true);
      return;
    }
    _show(found);
  }

  void _show(ParcelOrderModel o) {
    setState(() => order = o);
    input.text = o.trackingNumber ?? o.id ?? '';
    _loadPoints(o);
    _sub?.cancel();
    if (o.id != null) {
      _sub = ParcelShippingService.watch(o.id!).listen(
        (live) {
          if (live != null && mounted) {
            setState(() => order = live);
            _loadPoints(live);
          }
        },
        onError: (_) {}, // keep the snapshot we already have
      );
    }
  }

  Future<void> _loadPoints(ParcelOrderModel o) async {
    final ids = {o.originPickupPointId, o.destinationPickupPointId, ...o.trackingEvents.map((e) => e.pickupPointId)}.whereType<String>().where((e) => !points.containsKey(e));
    if (ids.isEmpty) return;
    final Map<String, PickupPointModel> loaded = {};
    for (final id in ids) {
      final p = await ParcelShippingService.pickupPoint(id);
      if (p != null) loaded[id] = p;
    }
    if (mounted && loaded.isNotEmpty) setState(() => points = {...points, ...loaded});
  }

  Future<void> _scan() async {
    final String? value = await Get.to<String>(() => const _ParcelScanScreen());
    if (value != null && value.isNotEmpty) {
      input.text = value;
      _search(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.find<ThemeController>().isDark.value;
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    final ParcelOrderModel? o = order;
    return Scaffold(
      appBar: AppBar(backgroundColor: AppThemeData.primary300, title: Text("Track a parcel".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(hintText: "Tracking number (SPD-...)".tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), style: IconButton.styleFrom(backgroundColor: AppThemeData.primary300, foregroundColor: AppThemeData.grey900)),
            ],
          ),
          const SizedBox(height: 10),
          RoundedButtonFill(title: searching ? "Searching...".tr : "Track".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey900, onPress: searching ? () {} : () => _search(input.text)),
          if (notFound) ...[
            const SizedBox(height: 16),
            Text("No parcel found for this number.".tr, textAlign: TextAlign.center, style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.danger300)),
          ],
          if (o != null) ...[
            const SizedBox(height: 16),
            ParcelCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.trackingNumber ?? o.id ?? '', style: AppThemeData.boldTextStyle(fontSize: 18, color: text)),
                  const SizedBox(height: 4),
                  Text((o.parcelStatus ?? o.status ?? '').tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.primary300)),
                  if ((o.origin?.label ?? '').isNotEmpty) Text("${o.origin!.label}  >  ${o.destination?.label ?? ''}", style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted)),
                  Text("${ParcelLabels.pickupMethod(o.pickupMethod)} / ${ParcelLabels.deliveryMethod(o.deliveryMethod)}", style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted)),
                  if (o.carrierName != null) Text("${'Carrier'.tr}: ${o.carrierName}", style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted)),
                  if (o.destinationPickupPointId != null && points[o.destinationPickupPointId] != null)
                    Text("${'Collect at'.tr}: ${points[o.destinationPickupPointId]!.name} ${points[o.destinationPickupPointId]!.subtitle}", style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            // The sender sees the receiver's pickup code to share it.
            if (o.authorID == FireStoreUtils.getCurrentUid()) ...[const SizedBox(height: 12), ParcelCodesCard(order: o, isDark: isDark)],
            const SizedBox(height: 12),
            ..._map(o),
            ParcelCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tracking history".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
                  const SizedBox(height: 10),
                  o.trackingEvents.isEmpty
                      ? Text("${'Status'.tr}: ${(o.status ?? '').tr}", style: AppThemeData.mediumTextStyle(fontSize: 14, color: text))
                      : ParcelTimeline(events: o.trackingEvents, pickupPoints: points, isDark: isDark),
                ],
              ),
            ),
            if (o.authorID == FireStoreUtils.getCurrentUid() && o.isTrackable) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => ParcelReceiptPdf.showOptions(context, o), icon: const Icon(Icons.receipt_long_outlined), label: Text("Receipt (PDF)".tr)),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Map of the event positions (driver scans) and pickup points, in order.
  List<Widget> _map(ParcelOrderModel o) {
    final List<ParcelMapPoint> list = [];
    for (final e in o.trackingEvents) {
      if (e.lat != null && e.lng != null) {
        list.add(ParcelMapPoint(e.lat!, e.lng!, e.status.tr));
      } else if (e.pickupPointId != null && points[e.pickupPointId]?.hasLocation == true) {
        final p = points[e.pickupPointId]!;
        list.add(ParcelMapPoint(p.latitude!, p.longitude!, '${e.status.tr} - ${p.name}'));
      }
    }
    if (list.isEmpty) return const [];
    list[list.length - 1] = ParcelMapPoint(list.last.lat, list.last.lng, list.last.label, highlight: true);
    return [ParcelPointsMap(points: list), const SizedBox(height: 12)];
  }
}

/// Camera scan of a parcel QR / barcode; pops with the decoded text.
class _ParcelScanScreen extends StatefulWidget {
  const _ParcelScanScreen();

  @override
  State<_ParcelScanScreen> createState() => _ParcelScanScreenState();
}

class _ParcelScanScreenState extends State<_ParcelScanScreen> {
  bool done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan the parcel QR code".tr)),
      body: QRCodeDartScanView(
        typeScan: TypeScan.live,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
        onCapture: (ScanResult result) {
          if (done) return;
          done = true;
          Get.back(result: result.text);
        },
      ),
    );
  }
}
