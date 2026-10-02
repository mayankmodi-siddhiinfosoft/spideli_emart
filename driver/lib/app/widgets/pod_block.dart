import 'package:driver/constant/constant.dart';
import 'package:driver/models/delivery_pod.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Proof of delivery once the customer's OTP was verified
/// (`.claude/POD-OTP-CONTRACT.md` "Order Details"): Delivered, "POD: OTP
/// Verified", the verification date and time and the delivery man. Renders
/// nothing for an order without a verified `pod` (older orders).
class PodVerifiedBlock extends StatelessWidget {
  final DeliveryPod? pod;

  const PodVerifiedBlock({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    final DeliveryPod? p = pod;
    if (p == null || !p.isVerified) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final PodDeliveredBy? man = p.deliveredBy;
    final bool hasMan = man != null && (man.name != null || man.phone != null || man.photo != null);
    return DsCard.tinted(
      tone: DsTone.success,
      semanticLabel: "${'Delivered'.tr}. ${'POD: OTP Verified'.tr}",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DsIconWell(icon: Icons.verified_rounded, tone: DsTone.success, size: 40),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Delivered".tr, style: t.titleSm.copyWith(color: c.tone(DsTone.success).strong)),
                    Text("POD: OTP Verified".tr, style: t.bodySm),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          DsInfoRow(label: "Delivery status".tr, value: "Delivered".tr, icon: Icons.local_shipping_outlined, divider: true),
          DsInfoRow(label: "POD status".tr, value: "OTP Verified".tr, icon: Icons.pin_outlined, divider: p.verifiedAt != null || hasMan),
          if (p.verifiedAt != null) DsInfoRow(label: "Verified on".tr, value: Constant.timestampToDateTime(p.verifiedAt!), icon: Icons.schedule_rounded, divider: hasMan),
          if (hasMan) ...[
            const DsGap(DsSpace.md),
            Text("Delivery man".tr, style: t.caption),
            const DsGap(DsSpace.sm),
            Row(
              children: [
                DsAvatar(imageUrl: man.photo, name: man.name, size: 44),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (man.name != null) Text(man.name!, style: t.bodyStrong),
                      if (man.phone != null) Text(man.phone!, style: t.bodySm.tabular),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The one-line list-card version: "POD: OTP Verified · date time · name".
/// Renders nothing without a verified `pod`.
class PodVerifiedLine extends StatelessWidget {
  final DeliveryPod? pod;

  const PodVerifiedLine({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    final DeliveryPod? p = pod;
    if (p == null || !p.isVerified) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final String when = p.verifiedAt == null ? '' : ' · ${Constant.timestampToDateTime(p.verifiedAt!)}';
    final String by = p.deliveredBy?.name == null ? '' : ' · ${p.deliveredBy!.name}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_rounded, size: 16, color: c.tone(DsTone.success).strong),
        const DsGap(DsSpace.xs),
        Expanded(
          child: Text(
            "${'POD: OTP Verified'.tr}$when$by",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySm.copyWith(color: c.tone(DsTone.success).strong),
          ),
        ),
      ],
    );
  }
}
