import 'package:driver/app/parcel_screen/parcel_tracking/parcel_scan_result_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR / barcode scanner for parcel pickup, hand-over and delivery (spec 9.1).
/// Accepts the QR (`spideli:parcel:<id>`), the Code 128 tracking number, or a raw order id.
/// When [expectedOrderId] is set (from the manifest), a different parcel is rejected.
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
    final isDark = Get.find<ThemeController>().isDark.value;
    return Scaffold(
      appBar: AppBar(title: Text("Scan parcel".tr)),
      backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
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
                      padding: const EdgeInsets.all(24),
                      child: Text("Camera unavailable. Enter the tracking number below.".tr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(border: Border.all(color: AppThemeData.primary300, width: 3), borderRadius: BorderRadius.circular(16)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                      decoration: InputDecoration(labelText: "Tracking number or order id".tr, border: const OutlineInputBorder(), isDense: true),
                      onSubmitted: _handle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: () => _handle(_manual.text), icon: const Icon(Icons.search)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
