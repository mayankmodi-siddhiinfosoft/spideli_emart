import 'package:customer/screen_ui/parcel_service/parcel_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import '../../controllers/parcel_dashboard_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/parcel_order_model.dart';
import '../../utils/parcel_receipt_pdf.dart';
import 'parcel_shipping_widgets.dart';
import 'parcel_tracking_screen.dart';

class OrderSuccessfullyPlaced extends StatelessWidget {
  const OrderSuccessfullyPlaced({super.key});

  @override
  Widget build(BuildContext context) {
    final dynamic parcelOrder = Get.arguments['parcelOrder'];
    final ParcelOrderModel? order = parcelOrder is ParcelOrderModel ? parcelOrder : null;
    final bool isQuote = order?.quoteRequested == true && order?.manualPrice == null;
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (order?.isTrackable != true) Image.asset("assets/images/parcel_order_successfully_placed.png"),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    isQuote ? "Quote requested!".tr : "Your Order Has Been Placed!".tr,
                    style: AppThemeData.boldTextStyle(fontSize: 22, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    isQuote
                        ? "We will price your shipment and notify you. You can then pay it from your parcel orders.".tr
                        : "We’ve received your parcel booking and it’s now being processed. You can track its status in real time.".tr,
                    style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Confirmation: QR + barcode (tracking number) + receiver's pickup code.
                if (order != null && order.isTrackable) ...[
                  const SizedBox(height: 20),
                  ParcelCodesCard(order: order, isDark: isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(onPressed: () => ParcelReceiptPdf.showOptions(context, order), icon: const Icon(Icons.receipt_long_outlined), label: Text("Receipt (PDF)".tr)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(onPressed: () => Get.to(() => ParcelTrackingScreen(order: order)), icon: const Icon(Icons.timeline), label: Text("Track".tr)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 30),
                RoundedButtonFill(
                  title: "Track Your Order".tr,
                  onPress: () {
                    print("Tracking Order: $parcelOrder");
                    //Get.to(() => TrackOrderScreen(), arguments: {'order': parcelOrder});
                    Get.offAll(const ParcelDashboardScreen());
                    ParcelDashboardController controller = Get.put(ParcelDashboardController());
                    controller.selectedIndex.value = 1;
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
