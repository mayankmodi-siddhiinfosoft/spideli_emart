import 'package:driver/app/parcel_screen/parcel_tracking/parcel_scan_result_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR / barcode scanner for parcel pickup, hand-over and delivery (spec 9.1).
/// Accepts the QR (`spideli:parcel:<id>`), the Code 128 tracking number, or a raw order id.
/// When [expectedOrderId] is set (from the manifest), a different parcel is rejected.
///
/// Archetype D (scanner): full-bleed camera under a scrim with a brand
/// viewfinder, and a docked panel with the instruction and manual entry.
class ParcelScanScreen extends StatefulWidget {
  final String? expectedOrderId;

  const ParcelScanScreen({super.key, this.expectedOrderId});

  @override
  State<ParcelScanScreen> createState() => _ParcelScanScreenState();
}

class _ParcelScanScreenState extends State<ParcelScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final TextEditingController _manual = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (_busy || raw.trim().isEmpty) return;
    _busy = true;
    await _scanner.stop();
    ShowToastDialog.showLoader("Please wait".tr);
    final order = await ParcelTrackingService.resolveScan(raw);
    ShowToastDialog.closeLoader();
    if (order == null) {
      ShowToastDialog.showToast("No parcel found for this code".tr);
    } else if (widget.expectedOrderId != null && order.id != widget.expectedOrderId) {
      ShowToastDialog.showToast("This is not the selected parcel".tr);
    } else {
      await Get.to(() => ParcelScanResultScreen(order: order));
    }
    _busy = false;
    if (mounted) await _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsScaffold(
      maxContentWidth: null,
      backgroundColor: Colors.black,
      appBar: DsAppBar(title: "Scan parcel".tr, transparent: true),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final v = b.rawValue;
                      if (v != null && v.trim().isNotEmpty) {
                        _handle(v);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpace.xxl),
                      child: Text(
                        "Camera unavailable. Enter the tracking number below.".tr,
                        textAlign: TextAlign.center,
                        style: t.bodyLg.withColor(Colors.white),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(child: IgnorePointer(child: _Viewfinder())),
                Positioned(
                  left: DsSpace.xxl,
                  right: DsSpace.xxl,
                  bottom: DsSpace.xxl,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: DsRadius.brPill),
                        child: Text(
                          "Point the camera at the parcel code".tr,
                          textAlign: TextAlign.center,
                          style: t.labelSm.withColor(Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: DsRadius.sheetTop,
              boxShadow: DsShadows.lg(context),
            ),
            child: SafeArea(
              top: false,
              child: DsResponsive(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DsTextField(
                          controller: _manual,
                          textCapitalization: TextCapitalization.characters,
                          label: "Tracking number or order id".tr,
                          bottomSpacing: 0,
                          prefixIcon: Icons.tag_rounded,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _handle,
                        ),
                      ),
                      const DsGap(DsSpace.md),
                      DsIconButton(
                        icon: Icons.search_rounded,
                        semanticLabel: "Search".tr,
                        variant: DsIconButtonVariant.filled,
                        size: 52,
                        onPressed: () => _handle(_manual.text),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrim with a rounded viewfinder cut-out and brand corner brackets.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = (constraints.biggest.shortestSide * 0.72).clamp(180.0, 320.0);
        return CustomPaint(
          painter: _ViewfinderPainter(side: side, scrim: c.scrim, accent: c.brand),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final double side;
  final Color scrim;
  final Color accent;

  const _ViewfinderPainter({required this.side, required this.scrim, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: side, height: side);
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(DsRadius.xl));
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrimPath, Paint()..color = scrim);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent.withValues(alpha: 0.55);
    canvas.drawRRect(hole, border);

    // Corner brackets: clearer than a full frame in low light.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = accent;
    const double len = 30;
    const double r = DsRadius.xl;
    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + r + len)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.left + r, rect.top), radius: const Radius.circular(r))
        ..lineTo(rect.left + r + len, rect.top),
      bracket,
    );
    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - r - len, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r), radius: const Radius.circular(r))
        ..lineTo(rect.right, rect.top + r + len),
      bracket,
    );
    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - r - len)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: const Radius.circular(r))
        ..lineTo(rect.right - r - len, rect.bottom),
      bracket,
    );
    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + r + len, rect.bottom)
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: const Radius.circular(r))
        ..lineTo(rect.left, rect.bottom - r - len),
      bracket,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.side != side || old.scrim != scrim || old.accent != accent;
}
