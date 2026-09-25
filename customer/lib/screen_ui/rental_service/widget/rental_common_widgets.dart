import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Titled surface used by the rental confirmation and detail screens.
class RentalInfoCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const RentalInfoCard({super.key, this.title, this.icon, required this.child, this.padding = const EdgeInsets.all(DsSpace.lg), this.margin});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: padding,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: c.brandStrong), const DsGap(DsSpace.sm)],
                Expanded(child: Text(title!.toUpperCase(), style: t.overline)),
              ],
            ),
            const DsGap(DsSpace.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// One bill line. [emphasis] is the total row, [onTap] opens the tax details.
class RentalSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final bool underline;
  final DsTone? tone;
  final VoidCallback? onTap;

  const RentalSummaryRow({super.key, required this.label, required this.value, this.emphasis = false, this.underline = false, this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Shared bill row / total row, so the rental bill lines up with the rest
    // of the app.
    if (emphasis) return OrderTotalRow(label: label, value: value, divider: false);
    return OrderMoneyRow(label: label, value: value, tone: tone, underline: underline, onTap: onTap);
  }
}

/// A "label → value" line of the rental package details.
class RentalDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const RentalDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return OrderMoneyRow(label: label, value: value, padding: const EdgeInsets.symmetric(vertical: DsSpace.sm));
  }
}

/// A payment gateway row inside the rental payment sheets.
class RentalPaymentRow extends StatelessWidget {
  final String image;
  final String name;
  final bool selected;
  final String? walletAmount;
  final VoidCallback onTap;

  const RentalPaymentRow({super.key, required this.image, required this.name, required this.selected, required this.onTap, this.walletAmount});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: InkWell(
        borderRadius: DsRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                child: Padding(padding: EdgeInsets.all(name == "payFast" ? 0 : DsSpace.sm), child: Image.asset(image)),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.capitalizeString(), textAlign: TextAlign.start, style: t.titleSm),
                    if (walletAmount != null) Text(walletAmount!, textAlign: TextAlign.start, style: t.bodyStrong.tabular.withColor(c.brandStrong)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 22,
                color: selected ? c.brand : c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for the rental bottom sheets (grabber, title, close button).
class RentalSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final bool showClose;

  const RentalSheetShell({super.key, required this.title, required this.child, this.footer, this.showClose = true});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: DsRadius.sheetTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill)),
          ),
          const DsGap(DsSpace.md),
          Row(
            children: [
              Expanded(child: Text(title, style: t.title)),
              if (showClose)
                DsIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: "Close".tr,
                  onPressed: () => Get.back(),
                ),
            ],
          ),
          const DsGap(DsSpace.lg),
          Expanded(child: child),
          if (footer != null) ...[const DsGap(DsSpace.md), SafeArea(top: false, child: footer!)],
        ],
      ),
    );
  }
}
