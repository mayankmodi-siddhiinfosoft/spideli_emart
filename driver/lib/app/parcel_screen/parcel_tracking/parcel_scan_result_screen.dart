import 'package:driver/app/parcel_screen/parcel_tracking/parcel_proof_sheet.dart';
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_shipment_info_card.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The scanned parcel and the next statuses this driver may record (spec 4.2 steps 8–9, 9.1).
class ParcelScanResultScreen extends StatefulWidget {
  final ParcelOrderModel order;

  const ParcelScanResultScreen({super.key, required this.order});

  @override
  State<ParcelScanResultScreen> createState() => _ParcelScanResultScreenState();
}

class _ParcelScanResultScreenState extends State<ParcelScanResultScreen> {
  late ParcelOrderModel _order = widget.order;

  Future<void> _apply(String status, bool isDark) async {
    Map<String, dynamic>? proof;
    final isFinal = ParcelTrackingService.isDriverFinalStep(_order, status);
    if (status == ParcelTrackingStatus.delivered) {
      proof = await showParcelProofSheet(context, _order, isDark: isDark);
      if (proof == null) return;
    } else if (isFinal) {
      final ok = await Get.dialog<bool>(AlertDialog(
        title: Text("Hand over at the pickup point".tr),
        content: Text("Confirm the parcel was handed over at the destination pickup point. This completes your delivery.".tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text("Cancel".tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text("Confirm".tr)),
        ],
      ));
      if (ok != true) return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final updated = await ParcelTrackingService.recordStatus(_order, status, deliveryProof: proof);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Status updated:'.tr} ${status.tr}");
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e is String ? e.tr : "Something went wrong".tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final next = ParcelTrackingService.nextActions(_order);
    return Scaffold(
      appBar: AppBar(title: Text(_order.trackingNumber ?? Constant.orderId(orderId: _order.id ?? ''))),
      backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${'Order Id:'.tr} ${Constant.orderId(orderId: _order.id ?? '')}", style: TextStyle(color: textColor, fontFamily: AppThemeData.semiBold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("${_order.sender?.address ?? ''}  →  ${_order.receiver?.address ?? ''}", style: TextStyle(color: textColor)),
            if (_order.receiver?.name != null) Text("${'Receiver'.tr}: ${_order.receiver!.name} ${_order.receiver?.phone ?? ''}", style: TextStyle(color: textColor)),
            const SizedBox(height: 16),
            ParcelShipmentInfoCard(order: _order, isDark: isDark),
            if (!_order.hasTrackingContract)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text("${'Status'.tr}: ${(ParcelTrackingService.currentStatus(_order) ?? _order.status ?? '').tr}", style: TextStyle(color: textColor)),
              ),
            if (next.statuses.isEmpty)
              Text((next.reason ?? 'No action available.').tr, style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600))
            else ...[
              Text("Update status".tr, style: TextStyle(color: textColor, fontFamily: AppThemeData.semiBold, fontSize: 16)),
              const SizedBox(height: 8),
              ...next.statuses.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RoundedButtonFill(
                    title: s == ParcelTrackingStatus.delivered ? "Delivered (with proof)".tr : s.tr,
                    height: 5.5,
                    color: ParcelTrackingService.isDriverFinalStep(_order, s) ? AppThemeData.success400 : AppThemeData.primary300,
                    textColor: AppThemeData.grey50,
                    onPress: () => _apply(s, isDark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
