import 'package:customer/controllers/scan_qr_code_controller.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

import '../../../themes/show_toast_dialog.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

class ScanQrCodeScreen extends StatelessWidget {
  const ScanQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      init: ScanQrCodeController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: DsAppBar(title: "Scan QR Code".tr, transparent: true),
          body: Stack(
            fit: StackFit.expand,
            children: [
              QRCodeDartScanView(
                // enable scan invert qr code ( default = false)
                typeScan: TypeScan.live,
                // if TypeScan.takePicture will try decode when click to take a picture(default TypeScan.live)
                onCapture: (ScanResult result) {
                  Get.back();
                  ShowToastDialog.showLoader("Please wait...".tr);
                  if (controller.allNearestRestaurant.isNotEmpty) {
                    if (controller.allNearestRestaurant.where((vendor) => vendor.id == result.text).isEmpty) {
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Store is not available".tr);
                      return;
                    }
                    VendorModel storeModel = controller.allNearestRestaurant.firstWhere((vendor) => vendor.id == result.text);
                    ShowToastDialog.closeLoader();
                    Get.back();
                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": storeModel});
                  } else {
                    Get.back();
                    ShowToastDialog.showToast("Store is not available".tr);
                  }
                },
              ),
              // Viewfinder: dim the frame and draw brand corner brackets.
              IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = (constraints.maxWidth * 0.68).clamp(200.0, 320.0);
                    return Stack(
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.srcOut),
                          child: Stack(
                            children: [
                              Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                              Center(
                                child: Container(
                                  width: side,
                                  height: side,
                                  decoration: BoxDecoration(color: Colors.black, borderRadius: DsRadius.brXl),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Container(
                            width: side,
                            height: side,
                            decoration: BoxDecoration(
                              borderRadius: DsRadius.brXl,
                              border: Border.all(color: c.brand.withValues(alpha: 0.9), width: 3),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    child: DsCard.glass(
                      child: Row(
                        children: [
                          const DsIconWell(icon: Icons.qr_code_scanner_rounded, size: 40, circle: true),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Point at a store QR code".tr, style: t.bodyStrong.withColor(Colors.white)),
                                const DsGap(DsSpace.xxs),
                                Text("We'll open the store as soon as it's recognised".tr, style: t.bodySm.withColor(Colors.white70)),
                              ],
                            ),
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
      },
    );
  }
}
