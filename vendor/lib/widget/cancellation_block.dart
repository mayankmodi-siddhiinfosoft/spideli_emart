import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/cancellation.dart';

/// Who ended an order / booking, why and when — the block every details
/// screen shows for a cancelled or rejected record:
///
///   **Cancelled by Restaurant**
///   Reason: Item out of stock
///   Oct 02,2026 10:14 AM
///
/// With [showDriverRejections], the drivers who passed on the offer are
/// listed underneath as "Passed by drivers".
class CancellationBlock extends StatelessWidget {
  final CancellationDetails details;
  final bool showDriverRejections;

  const CancellationBlock({super.key, required this.details, this.showDriverRejections = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final List<DriverRejection> passes = showDriverRejections ? details.driverRejections : const [];
    return DsCard.tinted(
      tone: DsTone.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(details.isRejected ? Icons.block_rounded : Icons.cancel_outlined, size: 18, color: c.dangerStrong),
              DsGap.sm,
              Expanded(child: Text(details.headline, style: t.bodyStrong.copyWith(color: c.dangerStrong))),
            ],
          ),
          const DsGap(DsSpace.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "${"Reason".tr}: ", style: t.bodySm.copyWith(color: c.textMuted)),
                TextSpan(
                  text: details.reason == null ? details.reasonText : details.reason!.tr,
                  style: details.reason == null ? t.bodySm.copyWith(color: c.textMuted, fontStyle: FontStyle.italic) : t.body.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
          if (details.timeText.isNotEmpty) ...[const DsGap(DsSpace.xxs), Text(details.timeText, style: t.caption.copyWith(color: c.textMuted))],
          if (passes.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Divider(height: 1, thickness: 1, color: c.divider),
            const DsGap(DsSpace.sm),
            Text("Passed by drivers".tr, style: t.overline),
            const DsGap(DsSpace.xs),
            DriverPassesList(passes: passes),
          ],
        ],
      ),
    );
  }
}

/// `driverRejections`, one row per driver who passed: who, why, when, and
/// whether they had already accepted.
class DriverPassesList extends StatelessWidget {
  final List<DriverRejection> passes;
  const DriverPassesList({super.key, required this.passes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < passes.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : DsSpace.sm),
            child: _DriverPassRow(pass: passes[i]),
          ),
      ],
    );
  }
}

class _DriverPassRow extends StatelessWidget {
  final DriverRejection pass;
  const _DriverPassRow({required this.pass});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String who = pass.driverName ?? (pass.driverId.isEmpty ? "Driver".tr : "${"Driver".tr} ${pass.driverId.length > 6 ? pass.driverId.substring(0, 6) : pass.driverId}");
    final List<String> meta = [
      if (pass.afterAccept) "after accepting".tr,
      if (pass.at != null) Constant.timestampToDateTime(pass.at!),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.delivery_dining_outlined, size: 16, color: c.textMuted),
        ),
        DsGap.sm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$who · ${pass.reason == null ? "No reason recorded".tr : pass.reason!.tr}", style: t.bodySm),
              if (meta.isNotEmpty) Text(meta.join(' · '), style: t.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one-line version for list cards: "Cancelled by Customer · Changed my
/// plans", with the time underneath.
class CancellationLine extends StatelessWidget {
  final CancellationDetails details;

  const CancellationLine({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(details.isRejected ? Icons.block_rounded : Icons.cancel_outlined, size: 16, color: c.dangerStrong),
          ),
          DsGap.sm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(details.oneLine, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySm.copyWith(color: c.textPrimary)),
                if (details.timeText.isNotEmpty) ...[const DsGap(DsSpace.xxs), Text(details.timeText, style: t.caption.copyWith(color: c.textMuted))],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
