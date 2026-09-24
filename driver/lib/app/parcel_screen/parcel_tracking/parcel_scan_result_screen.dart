import 'package:driver/app/parcel_screen/parcel_tracking/parcel_proof_sheet.dart';
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_shipment_info_card.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The scanned parcel and the next statuses this driver may record (spec 4.2 steps 8–9, 9.1).
///
/// Archetype D: scan summary card → shipment contract → the step's action.
/// A single next step is a deliberate swipe; several become xl buttons.
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
      final ok = await Get.dialog<bool>(DsDialog(
        title: "Hand over at the pickup point".tr,
        message: "Confirm the parcel was handed over at the destination pickup point. This completes your delivery.".tr,
        icon: Icons.storefront_outlined,
        tone: DsTone.warning,
        secondaryLabel: "Cancel".tr,
        onSecondary: () => Get.back(result: false),
        primaryLabel: "Confirm".tr,
        onPrimary: () => Get.back(result: true),
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

  String _actionLabel(String s) => s == ParcelTrackingStatus.delivered ? "Delivered (with proof)".tr : s.tr;

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    final c = context.dsColors;
    final t = context.dsText;
    final next = ParcelTrackingService.nextActions(_order);
    final bool singleStep = next.statuses.length == 1;
    return DsScaffold(
      backgroundColor: c.background,
      title: _order.trackingNumber ?? Constant.orderId(orderId: _order.id ?? ''),
      body: DsResponsive(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: DsFadeSlideIn.stagger([
              // ------------------------------------------- scanned parcel
              DsCard.gradient(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                        const DsGap(DsSpace.sm),
                        Expanded(
                          child: Text(
                            "${'Order Id:'.tr} ${Constant.orderId(orderId: _order.id ?? '')}",
                            style: t.labelSm.withColor(Colors.white).tabular,
                          ),
                        ),
                      ],
                    ),
                    if ((_order.trackingNumber ?? '').isNotEmpty) ...[
                      const DsGap(DsSpace.xs),
                      Text(_order.trackingNumber!, style: t.title.withColor(Colors.white).tabular),
                    ],
                  ],
                ),
              ),
              const DsGap(DsSpace.lg),

              // ----------------------------------------------------- route
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DsRouteStops(
                      stops: [
                        DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: _order.sender?.address ?? ''),
                        DsRouteStop(kind: DsStopKind.drop, label: 'Delivery'.tr, address: _order.receiver?.address ?? ''),
                      ],
                    ),
                    if (_order.receiver?.name != null) ...[
                      const DsDivider(spacing: DsSpace.md),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 18, color: c.iconDefault),
                          const DsGap(DsSpace.sm),
                          Expanded(
                            child: Text(
                              "${'Receiver'.tr}: ${_order.receiver!.name} ${_order.receiver?.phone ?? ''}",
                              style: t.bodyStrong,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const DsGap(DsSpace.lg),

              // -------------------------------------------------- shipment
              ParcelShipmentInfoCard(order: _order, isDark: isDark),

              if (!_order.hasTrackingContract)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.lg),
                  child: DsInlineAlert(
                    tone: DsTone.info,
                    icon: Icons.info_outline_rounded,
                    message: "${'Status'.tr}: ${(ParcelTrackingService.currentStatus(_order) ?? _order.status ?? '').tr}",
                  ),
                ),

              // --------------------------------------------- next actions
              if (next.statuses.isEmpty)
                DsInlineAlert(
                  tone: DsTone.neutral,
                  icon: Icons.do_not_disturb_on_outlined,
                  message: (next.reason ?? 'No action available.').tr,
                )
              else
                DsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Update status".tr, style: t.titleSm.w700),
                      const DsGap(DsSpace.md),
                      if (singleStep)
                        DsSlideToConfirm(
                          label: _actionLabel(next.statuses.first),
                          icon: ParcelTrackingService.isDriverFinalStep(_order, next.statuses.first) ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                          tone: ParcelTrackingService.isDriverFinalStep(_order, next.statuses.first) ? DsTone.success : DsTone.brand,
                          onConfirmed: () => _apply(next.statuses.first, isDark),
                        )
                      else
                        ...next.statuses.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: ParcelTrackingService.isDriverFinalStep(_order, s)
                                ? DsButton.success(
                                    label: _actionLabel(s),
                                    icon: Icons.check_circle_outline_rounded,
                                    size: DsButtonSize.xl,
                                    expand: true,
                                    onPressed: () => _apply(s, isDark),
                                  )
                                : DsButton.primary(
                                    label: _actionLabel(s),
                                    icon: Icons.arrow_forward_rounded,
                                    size: DsButtonSize.xl,
                                    expand: true,
                                    onPressed: () => _apply(s, isDark),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              const DsGap(DsSpace.xxl),
            ]),
          ),
        ),
      ),
    );
  }
}
