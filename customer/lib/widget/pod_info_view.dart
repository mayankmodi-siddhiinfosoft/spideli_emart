import 'package:customer/constant/constant.dart';
import 'package:customer/models/order_pod.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// "02 Oct 2026, 03:15 PM", or null without a time.
String? podVerifiedAtLabel(OrderPod pod) {
  final at = pod.verifiedAt?.toDate();
  return at == null ? null : DateFormat('dd MMM yyyy, hh:mm a').format(at);
}

/// Order-details block once the delivery code was verified
/// (POD-OTP-CONTRACT, "Order Details — what everyone sees once verified"):
///
///   Delivery status   Delivered
///   POD status        OTP Verified
///   Verified on       the date and time (`pod.verifiedAt`)
///   Delivery man      photo, name, phone (`pod.deliveredBy`)
///
/// Renders nothing for an order without a verified `pod` (older orders), and
/// leaves out any row whose value is missing — never "null".
class PodInfoBlock extends StatelessWidget {
  final OrderPod? pod;
  final EdgeInsetsGeometry padding;

  const PodInfoBlock({super.key, required this.pod, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final OrderPod? pod = this.pod;
    if (pod == null || !pod.isVerified) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final String? verifiedAt = podVerifiedAtLabel(pod);
    final deliveredBy = pod.deliveredBy;

    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(top: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: t.bodySm)),
          const DsGap(DsSpace.sm),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );

    return Padding(
      padding: padding,
      child: DsCard.outlined(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DsIconWell(icon: Icons.verified_outlined, tone: DsTone.success, size: 36),
                const DsGap(DsSpace.sm),
                Expanded(child: Text('Proof of delivery'.tr, style: t.titleSm)),
              ],
            ),
            const DsGap(DsSpace.xs),
            row('Delivery status'.tr, DsBadge(label: 'Delivered'.tr, tone: DsTone.success, icon: Icons.check_circle_outline_rounded, small: true)),
            row('POD status'.tr, DsBadge(label: 'OTP Verified'.tr, tone: DsTone.success, icon: Icons.verified_user_outlined, small: true)),
            if (verifiedAt != null) row('Verified on'.tr, Text(verifiedAt, textAlign: TextAlign.right, style: t.bodyStrong.tabular)),
            if (deliveredBy != null) ...[
              const DsDivider(spacing: DsSpace.md),
              Text('Delivery man'.tr, style: t.labelSm),
              const DsGap(DsSpace.sm),
              Row(
                children: [
                  DsAvatar(imageUrl: deliveredBy.photo, name: deliveredBy.name, size: 44),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deliveredBy.name ?? 'Delivery partner'.tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                        if (deliveredBy.phone != null) Text(deliveredBy.phone!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.tabular),
                      ],
                    ),
                  ),
                  if (deliveredBy.phone != null)
                    DsIconButton(
                      icon: Icons.call_outlined,
                      semanticLabel: 'Call Now'.tr,
                      variant: DsIconButtonVariant.outlined,
                      color: c.successStrong,
                      onPressed: () => Constant.makePhoneCall(deliveredBy.phone!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line for the order history card:
/// "Delivered · OTP Verified · 02 Oct 2026, 03:15 PM · Ravi Kumar".
/// Renders nothing without a verified `pod`.
class PodInfoLine extends StatelessWidget {
  final OrderPod? pod;
  final EdgeInsetsGeometry padding;

  const PodInfoLine({super.key, required this.pod, this.padding = const EdgeInsets.only(top: DsSpace.xs)});

  @override
  Widget build(BuildContext context) {
    final OrderPod? pod = this.pod;
    if (pod == null || !pod.isVerified) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.success);
    final parts = <String>[
      'Delivered'.tr,
      'OTP Verified'.tr,
      ?podVerifiedAtLabel(pod),
      ?pod.deliveredBy?.name,
    ];
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.verified_outlined, size: 14, color: tone.strong)),
          const DsGap(DsSpace.xs),
          Expanded(child: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.withColor(tone.strong))),
        ],
      ),
    );
  }
}
