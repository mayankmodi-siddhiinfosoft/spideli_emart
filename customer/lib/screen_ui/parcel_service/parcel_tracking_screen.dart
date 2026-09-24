import 'dart:async';

import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

/// Spec 7.5: scan the QR or type the tracking number, then a live timeline of
/// `trackingEvents` and a map of the known positions.
///
/// Archetype F/D (tracking timeline): a lookup card on top, a tinted status
/// hero for the found parcel, the positions map and the live event timeline.
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
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    final ParcelOrderModel? o = order;
    return DsScaffold(
      title: "Track a parcel".tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
        children: [
          DsCard(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DsTextField(
                        controller: input,
                        hint: "Tracking number (SPD-...)".tr,
                        prefixIcon: Icons.confirmation_number_outlined,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        bottomSpacing: 0,
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    DsIconButton(
                      icon: Icons.qr_code_scanner_rounded,
                      semanticLabel: "Scan the parcel QR code".tr,
                      variant: DsIconButtonVariant.brand,
                      size: 48,
                      onPressed: _scan,
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsButton.primary(
                  label: searching ? "Searching...".tr : "Track".tr,
                  icon: Icons.search_rounded,
                  expand: true,
                  onPressed: searching ? () {} : () => _search(input.text),
                ),
              ],
            ),
          ),
          if (notFound) ...[
            const DsGap(DsSpace.lg),
            DsInlineAlert(tone: DsTone.danger, message: "No parcel found for this number.".tr),
          ],
          if (o != null) ...[
            const DsGap(DsSpace.lg),
            DsCard.tinted(
              tone: DsTone.fromStatus(o.parcelStatus ?? o.status ?? ''),
              padding: const EdgeInsets.all(DsSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o.trackingNumber ?? o.id ?? '', style: t.headline.tabular)),
                      const DsGap(DsSpace.sm),
                      DsStatusChip(label: (o.parcelStatus ?? o.status ?? '').tr, status: o.parcelStatus ?? o.status, pulse: true),
                    ],
                  ),
                  if ((o.origin?.label ?? '').isNotEmpty) ...[
                    const DsGap(DsSpace.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.alt_route_rounded, size: 16, color: c.brandStrong),
                        const DsGap(DsSpace.sm),
                        Expanded(child: Text("${o.origin!.label}  >  ${o.destination?.label ?? ''}", style: t.bodyStrong)),
                      ],
                    ),
                  ],
                  const DsGap(DsSpace.sm),
                  _MetaLine(icon: Icons.swap_horiz_rounded, text: "${ParcelLabels.pickupMethod(o.pickupMethod)} / ${ParcelLabels.deliveryMethod(o.deliveryMethod)}"),
                  if (o.carrierName != null) _MetaLine(icon: Icons.local_shipping_outlined, text: "${'Carrier'.tr}: ${o.carrierName}"),
                  if (o.destinationPickupPointId != null && points[o.destinationPickupPointId] != null)
                    _MetaLine(
                      icon: Icons.storefront_outlined,
                      text: "${'Collect at'.tr}: ${points[o.destinationPickupPointId]!.name} ${points[o.destinationPickupPointId]!.subtitle}",
                    ),
                ],
              ),
            ),
            // The sender sees the receiver's pickup code to share it.
            if (o.authorID == FireStoreUtils.getCurrentUid()) ...[const DsGap(DsSpace.lg), ParcelCodesCard(order: o)],
            const DsGap(DsSpace.lg),
            ..._map(o),
            ParcelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParcelCardTitle("Tracking history".tr, icon: Icons.timeline_rounded),
                  o.trackingEvents.isEmpty
                      ? Text("${'Status'.tr}: ${(o.status ?? '').tr}", style: t.body)
                      : ParcelTimeline(events: o.trackingEvents, pickupPoints: points),
                ],
              ),
            ),
            if (o.authorID == FireStoreUtils.getCurrentUid() && o.isTrackable) ...[
              const DsGap(DsSpace.lg),
              DsButton.secondary(
                label: "Receipt (PDF)".tr,
                icon: Icons.receipt_long_outlined,
                expand: true,
                onPressed: () => ParcelReceiptPdf.showOptions(context, o),
              ),
            ],
          ],
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
    return [ParcelPointsMap(points: list), const DsGap(DsSpace.lg)];
  }
}

/// Icon + muted line used by the tracking status hero.
class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const DsGap(DsSpace.sm),
          Expanded(child: Text(text, style: t.bodySm)),
        ],
      ),
    );
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
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: DsAppBar(title: "Scan the parcel QR code".tr, transparent: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          QRCodeDartScanView(
            typeScan: TypeScan.live,
            formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
            onCapture: (ScanResult result) {
              if (done) return;
              done = true;
              Get.back(result: result.text);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 248,
                height: 248,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                  borderRadius: DsRadius.brLg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
