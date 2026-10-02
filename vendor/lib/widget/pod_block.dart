import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/pod_otp.dart';

/// Proof of delivery once the customer's code was verified
/// (`.claude/POD-OTP-CONTRACT.md`, "Order Details"): delivery status, POD
/// status, when it was verified and the delivery man. Shows nothing for an
/// order without a verified `pod`, and never the code.
class PodVerifiedBlock extends StatelessWidget {
  final OrderPod pod;

  const PodVerifiedBlock({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final PodDeliveryMan? man = pod.deliveredBy;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: t.bodySm)),
          DsGap.md,
          Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: value)),
        ],
      ),
    );
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row("Delivery status".tr, DsBadge(label: "Delivered".tr, tone: DsTone.success, icon: Icons.task_alt_rounded)),
          row("POD status".tr, DsBadge(label: "OTP Verified".tr, tone: DsTone.success, icon: Icons.verified_rounded)),
          if (pod.verifiedAtText.isNotEmpty) row("Verified on".tr, Text(pod.verifiedAtText, textAlign: TextAlign.end, style: t.bodyStrong)),
          if (man != null) ...[
            Divider(height: DsSpace.lg, thickness: 1, color: c.divider),
            PodDeliveryManRow(man: man),
          ],
        ],
      ),
    );
  }
}

/// The delivery man on `pod.deliveredBy`: photo, name and phone (tap to call).
class PodDeliveryManRow extends StatelessWidget {
  final PodDeliveryMan man;
  final double avatarSize;

  const PodDeliveryManRow({super.key, required this.man, this.avatarSize = 44});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      children: [
        DsAvatar(imageUrl: man.photo ?? '', name: man.name, size: avatarSize, fallbackIcon: Icons.delivery_dining_rounded),
        DsGap.md,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Delivered by".tr, style: t.caption),
              Text(man.name ?? "Delivery man".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
              if (man.phone != null) Text(man.phone!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
            ],
          ),
        ),
        if (man.phone != null)
          DsIconButton(
            icon: Icons.call_rounded,
            semanticLabel: "Call".tr,
            variant: DsIconButtonVariant.brand,
            size: 44,
            color: c.brandStrong,
            onPressed: () => Constant.makePhoneCall(man.phone!.replaceAll(' ', '')),
          ),
      ],
    );
  }
}

/// The compact version for the Completed tab's card: "Delivered · OTP
/// Verified", when, and who delivered.
class PodVerifiedLine extends StatelessWidget {
  final OrderPod pod;

  const PodVerifiedLine({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tc = c.tone(DsTone.success);
    final PodDeliveryMan? man = pod.deliveredBy;
    return Container(
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 16, color: tc.strong),
              DsGap.sm,
              Expanded(
                child: Text("${"Delivered".tr} · ${"OTP Verified".tr}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.copyWith(color: tc.strong)),
              ),
            ],
          ),
          if (pod.verifiedAtText.isNotEmpty) ...[const DsGap(DsSpace.xxs), Text("${"Verified on".tr} ${pod.verifiedAtText}", style: t.caption)],
          if (man != null) ...[DsGap.sm, PodDeliveryManRow(man: man, avatarSize: 36)],
        ],
      ),
    );
  }
}

/// A code was asked for and the order is still on its way.
class PodWaitingNote extends StatelessWidget {
  const PodWaitingNote({super.key});

  @override
  Widget build(BuildContext context) {
    return DsInlineAlert(tone: DsTone.info, icon: Icons.pin_outlined, message: "Waiting for the customer's delivery code".tr);
  }
}
