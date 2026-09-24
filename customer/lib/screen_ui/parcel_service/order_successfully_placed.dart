import 'package:customer/screen_ui/parcel_service/parcel_dashboard_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/parcel_dashboard_controller.dart';
import '../../models/parcel_order_model.dart';
import '../../utils/parcel_receipt_pdf.dart';
import 'parcel_shipping_widgets.dart';
import 'parcel_tracking_screen.dart';

/// Booking confirmation (archetype K — result): a success-toned halo with the
/// headline, then the scannable codes card and the follow-up actions. The
/// primary action lives in a sticky bar so it is reachable on small phones.
class OrderSuccessfullyPlaced extends StatelessWidget {
  const OrderSuccessfullyPlaced({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    final dynamic parcelOrder = Get.arguments['parcelOrder'];
    final ParcelOrderModel? order = parcelOrder is ParcelOrderModel ? parcelOrder : null;
    final bool isQuote = order?.quoteRequested == true && order?.manualPrice == null;
    final bool trackable = order != null && order.isTrackable;
    return DsScaffold(
      maxContentWidth: DsLayout.contentMax,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xxxl, l.gutter, DsSpace.xxl),
          children: DsFadeSlideIn.stagger([
            Center(
              child: Container(
                width: 132,
                height: 132,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [c.tone(isQuote ? DsTone.warning : DsTone.success).soft, c.tone(isQuote ? DsTone.warning : DsTone.success).soft.withValues(alpha: 0)],
                    stops: const [0.55, 1],
                  ),
                ),
                child: order?.isTrackable != true
                    ? Image.asset("assets/images/parcel_order_successfully_placed.png", height: 108, fit: BoxFit.contain)
                    : Icon(Icons.check_circle_rounded, size: 76, color: c.successStrong),
              ),
            ),
            const DsGap(DsSpace.xl),
            Text(
              isQuote ? "Quote requested!".tr : "Your Order Has Been Placed!".tr,
              style: t.display,
              textAlign: TextAlign.center,
            ),
            const DsGap(DsSpace.md),
            Text(
              isQuote
                  ? "We will price your shipment and notify you. You can then pay it from your parcel orders.".tr
                  : "We’ve received your parcel booking and it’s now being processed. You can track its status in real time.".tr,
              style: t.bodySecondary,
              textAlign: TextAlign.center,
            ),
            // Confirmation: QR + barcode (tracking number) + receiver's pickup code.
            if (trackable) ...[
              const DsGap(DsSpace.xxl),
              ParcelCodesCard(order: order),
              const DsGap(DsSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: DsButton.secondary(
                      label: "Receipt (PDF)".tr,
                      icon: Icons.receipt_long_outlined,
                      expand: true,
                      onPressed: () => ParcelReceiptPdf.showOptions(context, order),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: DsButton.secondary(
                      label: "Track".tr,
                      icon: Icons.timeline_rounded,
                      expand: true,
                      onPressed: () => Get.to(() => ParcelTrackingScreen(order: order)),
                    ),
                  ),
                ],
              ),
            ],
          ]),
        ),
      ),
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Track Your Order".tr,
          icon: Icons.local_shipping_outlined,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: () {
            //Get.to(() => TrackOrderScreen(), arguments: {'order': parcelOrder});
            Get.offAll(const ParcelDashboardScreen());
            ParcelDashboardController controller = Get.put(ParcelDashboardController());
            controller.selectedIndex.value = 1;
          },
        ),
      ),
    );
  }
}
