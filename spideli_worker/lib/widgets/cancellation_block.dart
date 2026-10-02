import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/cancellation_info.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/themes/ds/ds.dart';

/// Who cancelled / rejected a booking and why, as the contract shows it
/// (`.claude/CANCEL-REASON-CONTRACT.md`): "Cancelled by Customer",
/// "Reason: …", date and time. Null unless the booking ended cancelled or
/// rejected.
class CancellationSummary {
  final String title;
  final String reason;
  final Timestamp? at;

  const CancellationSummary({required this.title, required this.reason, this.at});

  String get line => "$title · $reason";

  static CancellationSummary? of(OnProviderOrderModel order) {
    final status = order.status;
    if (status != ORDER_STATUS_REJECTED && status != ORDER_STATUS_CANCELLED) return null;
    final bool rejectedStatus = status == ORDER_STATUS_REJECTED;
    final CancellationInfo info = order.cancellation;
    // Pre-contract field: the customer app wrote its cancellation reason here.
    final String? legacy = CancellationInfo.text(order.reason);

    if (info.by != null || info.reason != null) {
      final action = (info.action?.toLowerCase() ?? (rejectedStatus ? 'rejected' : 'cancelled')) == 'rejected' ? 'rejected' : 'cancelled';
      final party = partyLabel(info.by);
      var title = party == null
          ? (action == 'rejected' ? "Rejected".tr : "Cancelled".tr)
          : (action == 'rejected' ? "${'Rejected by'.tr} $party" : "${'Cancelled by'.tr} $party");
      if (info.byName != null && info.byName != party) title = "$title (${info.byName})";
      return CancellationSummary(title: title, reason: info.reason ?? legacy ?? "No reason recorded".tr, at: info.at);
    }

    if (legacy != null) {
      return CancellationSummary(title: rejectedStatus ? "Rejected".tr : "${'Cancelled by'.tr} ${'Customer'.tr}", reason: legacy);
    }
    return CancellationSummary(title: rejectedStatus ? "Rejected".tr : "Cancelled".tr, reason: "No reason recorded".tr);
  }

  /// Contract labels by `cancelledBy`; vendor / store / restaurant are one party.
  static String? partyLabel(String? by) {
    switch (by?.trim().toLowerCase()) {
      case null:
      case '':
        return null;
      case 'customer':
      case 'user':
        return "Customer".tr;
      case 'vendor':
      case 'store':
      case 'restaurant':
        return "Store".tr;
      case 'driver':
        return "Driver".tr;
      case 'provider':
        return "Service provider".tr;
      case 'worker':
        return "Worker".tr;
      case 'admin':
        return "Admin".tr;
      default:
        final s = by!.trim();
        return s[0].toUpperCase() + s.substring(1);
    }
  }
}

/// The details-screen block for a cancelled / rejected booking. Renders
/// nothing when [summary] is null.
class CancellationBlock extends StatelessWidget {
  final CancellationSummary? summary;

  const CancellationBlock({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.tinted(
      tone: DsTone.danger,
      semanticLabel: "${s.title}. ${'Reason'.tr}: ${s.reason}",
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DsIconWell(icon: Icons.block_rounded, tone: DsTone.danger, size: 40),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: t.titleSm.copyWith(color: c.dangerStrong)),
                const DsGap(DsSpace.xs),
                Text("${'Reason'.tr}: ${s.reason}", style: t.body),
                if (s.at != null) ...[
                  const DsGap(DsSpace.xs),
                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(s.at!.toDate()), style: t.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-line list-card version. Renders nothing when [summary] is null.
class CancellationLine extends StatelessWidget {
  final CancellationSummary? summary;

  const CancellationLine({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    final c = context.dsColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.block_rounded, size: 16, color: c.dangerStrong),
        const DsGap(DsSpace.xs),
        Expanded(child: Text(s.line, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.dsText.bodySm.copyWith(color: c.dangerStrong))),
      ],
    );
  }
}
