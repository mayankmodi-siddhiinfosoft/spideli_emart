import 'package:customer/controllers/gateway_checkout_controller.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Payment option picker + "Pay Now" for a subscription purchase. Pops with
/// `true` once the payment succeeded AND the purchase was recorded.
///
/// Archetype **C — checkout**: an order summary card, provider rows with a
/// radio, and the pay action in a sticky bar.
class GatewayCheckoutScreen extends StatelessWidget {
  final String title;
  final String amount;
  final CurrencyModel? currency;
  final String? regionId;
  final Future<void> Function(String paymentMethod) onPaid;

  /// What the wallet row / gateway reference calls this payment. Defaults to
  /// [title]; a caller passes it when the panels have fixed a wording (the
  /// customer plan purchase writes `note: "Subscription purchase"`, WEB spec
  /// 5) that differs from what the screen shows.
  final String? note;

  const GatewayCheckoutScreen({super.key, required this.title, required this.amount, required this.currency, required this.regionId, required this.onPaid, this.note});

  @override
  Widget build(BuildContext context) {
    return GetX<GatewayCheckoutController>(
      init: GatewayCheckoutController(amount: amount, regionId: regionId, description: note ?? title, onPaid: onPaid),
      global: false,
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final methods = controller.availableMethods;
        final loading = controller.isLoading.value;
        final paying = controller.isPaying.value;
        final paid = controller.isPaid.value;
        return DsScaffold(
          title: "Payment Option".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: loading || methods.isEmpty
              ? null
              : DsStickyBar(
                  // Disabled while a payment runs (no double charge). Once
                  // paid, it only retries saving the purchase.
                  child: DsButton.primary(
                    label: paid ? "Retry saving".tr : "Pay Now".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    loading: paying,
                    icon: paid ? Icons.refresh_rounded : Icons.lock_outline_rounded,
                    onPressed: paying ? null : () => controller.pay(context),
                  ),
                ),
          body: DsAsync(
            isLoading: loading,
            skeleton: const _CheckoutSkeleton(),
            builder: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
              children: DsFadeSlideIn.stagger([
                DsCard.gradient(
                  padding: const EdgeInsets.all(DsSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amount to pay".tr, style: DsTypography.overline.copyWith(color: Colors.white.withValues(alpha: 0.78))),
                      const DsGap(DsSpace.xs),
                      Text(Constant.amountShow(amount: amount, currency: currency), style: DsTypography.metricLg.copyWith(color: Colors.white)),
                      const DsGap(DsSpace.sm),
                      Text(title, style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
                const DsGap(DsSpace.lg),
                if (methods.isEmpty)
                  DsInlineAlert(tone: DsTone.warning, icon: Icons.credit_card_off_outlined, message: "No payment method is available in your region.".tr)
                else ...[
                  DsSectionHeader(title: "Payment Option".tr, icon: Icons.account_balance_wallet_outlined, padding: const EdgeInsets.only(bottom: DsSpace.md)),
                  ...methods.map((g) => _option(context, controller, g)),
                  const DsGap(DsSpace.md),
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: c.textMuted),
                      const DsGap(DsSpace.sm),
                      Expanded(child: Text("Payments are processed securely by the selected provider.".tr, style: t.caption)),
                    ],
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  /// One provider row. Its own `Obx` because the selected method and the
  /// wallet balance are read while this row builds.
  Widget _option(BuildContext context, GatewayCheckoutController controller, PaymentGateway g) {
    final bool isWallet = g == PaymentGateway.wallet;
    return Obx(() {
      final c = DsColors.of(context);
      final selected = controller.selectedPaymentMethod.value == g.name;
      return DsCard.outlined(
        margin: const EdgeInsets.only(bottom: DsSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        borderColor: selected ? c.brand : null,
        color: selected ? c.brandSoft : null,
        semanticLabel: g.name.capitalizeString(),
        onTap: () => controller.selectedPaymentMethod.value = g.name,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
              child: Padding(padding: EdgeInsets.all(g == PaymentGateway.payFast ? 0 : 8.0), child: Image.asset(GatewayCheckoutController.imageOf(g))),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name.capitalizeString(), style: selected ? DsTypography.label.copyWith(color: c.brandStrong) : DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                  if (isWallet)
                    Text(
                      Constant.amountShow(amount: (controller.userModel.value.walletAmount ?? 0).toString(), currency: controller.walletCurrency),
                      style: DsTypography.bodySm.copyWith(color: c.successStrong, fontWeight: FontWeight.w600).tabular,
                    ),
                ],
              ),
            ),
            Radio<String>(
              value: g.name,
              groupValue: controller.selectedPaymentMethod.value,
              activeColor: c.brand,
              onChanged: (v) => controller.selectedPaymentMethod.value = v ?? '',
            ),
          ],
        ),
      );
    });
  }
}

/// Summary + provider list skeleton.
class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: double.infinity, child: DsSkeleton.box(height: 140, radius: DsRadius.xl)),
            const DsGap(DsSpace.xxl),
            for (var i = 0; i < 5; i++) ...[
              SizedBox(width: double.infinity, child: DsSkeleton.box(height: 72, radius: DsRadius.lg)),
              const DsGap(DsSpace.sm),
            ],
          ],
        ),
      ),
    );
  }
}
