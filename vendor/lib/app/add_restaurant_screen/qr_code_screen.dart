import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/qr_code_controller.dart';
import 'package:vendor/themes/app_them_data.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: QrCodeController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsScaffold(
          title: '',
          maxContentWidth: null,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([
                    Column(
                      children: [
                        DsIconWell(icon: Icons.qr_code_scanner_rounded, size: 56, circle: true),
                        const DsGap(DsSpace.md),
                        Text("Store QR Code".tr, textAlign: TextAlign.center, style: t.headline),
                        const DsGap(DsSpace.xs),
                        Text("Your unique QR code for seamless customers  interactions..".tr, textAlign: TextAlign.center, style: t.bodySecondary),
                      ],
                    ),
                    const DsGap(DsSpace.xxl),
                    // Ticket-like frame around the code.
                    DsCard(
                      padding: EdgeInsets.zero,
                      radius: DsRadius.xl,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                            decoration: BoxDecoration(gradient: DsGradients.brand(context)),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                const DsGap(DsSpace.sm),
                                Expanded(
                                  child: Text(
                                    controller.vendorModel.value.title?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleSm.withColor(Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(DsSpace.xxl),
                            child: _CornerFrame(
                              color: c.brand,
                              child: Padding(
                                padding: const EdgeInsets.all(DsSpace.md),
                                child: RepaintBoundary(
                                  key: controller.globalKey,
                                  child: QrImageView(
                                    data: '${controller.vendorModel.value.id}',
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    // Saved image colours kept as before.
                                    foregroundColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                    backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50, // White background for QR code
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.lg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 16, color: c.textMuted),
                                const DsGap(DsSpace.xs),
                                Flexible(child: Text("Scan to view the store".tr, style: t.caption, textAlign: TextAlign.center)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save".tr,
              icon: Icons.download_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                try {
                  final boundary = controller.globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                  if (boundary == null) {
                    ShowToastDialog.showToast("Error capturing QR Code".tr);
                    return;
                  }

                  final image = await boundary.toImage(pixelRatio: 3.0);
                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

                  if (byteData == null) {
                    ShowToastDialog.showToast("Error converting image".tr);
                    return;
                  }

                  // Request permissions (Android + iOS)
                  final storagePermission = await Permission.storage.request();
                  final photosPermission = await Permission.photos.request();
                  final managePermission = await Permission.manageExternalStorage.request();

                  if (storagePermission.isGranted || photosPermission.isGranted || managePermission.isGranted) {
                    final result = await ImageGallerySaverPlus.saveImage(
                      byteData.buffer.asUint8List(),
                      quality: 100,
                      name: "qrcode_${DateTime.now().toIso8601String()}",
                      isReturnImagePathOfIOS: true,
                    );

                    debugPrint("Saved: $result");
                    ShowToastDialog.showToast("Image Saved!".tr);
                  } else {
                    ShowToastDialog.showToast("Permission denied".tr);
                  }
                } catch (e) {
                  debugPrint("Error saving image: $e");
                  ShowToastDialog.showToast("Something went wrong".tr);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// Scanner-style corner brackets drawn around the QR code.
class _CornerFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  const _CornerFrame({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(foregroundPainter: _CornerPainter(color), child: child);
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    const r = 10.0;
    final w = size.width;
    final h = size.height;
    Path corner(Offset o, double dx, double dy) => Path()
      ..moveTo(o.dx, o.dy + dy * l)
      ..lineTo(o.dx, o.dy + dy * r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * r, o.dy)
      ..lineTo(o.dx + dx * l, o.dy);
    canvas.drawPath(corner(Offset.zero, 1, 1), p);
    canvas.drawPath(corner(Offset(w, 0), -1, 1), p);
    canvas.drawPath(corner(Offset(0, h), 1, -1), p);
    canvas.drawPath(corner(Offset(w, h), -1, -1), p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => oldDelegate.color != color;
}
