import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/qr_code_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: QrCodeController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Store QR Code".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                ),
                Text(
                  "Your unique QR code for seamless customers  interactions..".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                ),
                const SizedBox(height: 50),
                RepaintBoundary(
                  key: controller.globalKey,
                  child: QrImageView(
                    data: '${controller.vendorModel.value.id}',
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50, // White background for QR code
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Save".tr,
                height: 5.5,
                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
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
          ),
        );
      },
    );
  }
}
