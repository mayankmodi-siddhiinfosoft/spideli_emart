import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/cancellation_info.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Who cancelled / rejected a record and why, as the contract shows it
/// (`.claude/CANCEL-REASON-CONTRACT.md`): "Cancelled by Customer",
/// "Reason: …", date and time. Built only for a record that ended cancelled
/// or rejected; returns null otherwise.
class CancellationSummary {
  final String title;
  final String reason;
  final Timestamp? at;

  const CancellationSummary({required this.title, required this.reason, this.at});

  static const _cancelledStatuses = {Constant.orderCancelled, Constant.orderRejected, Constant.driverRejected};

  /// [storeWord] is the section's own word for the store ("Restaurant" /
  /// "Store"); [cancelled] forces the block for a record whose cancellation
  /// lives in another status field (a parcel's `parcelStatus`).
  static CancellationSummary? of({required String? status, required CancellationInfo info, String? storeWord, bool cancelled = false}) {
    if (!cancelled && !_cancelledStatuses.contains(status)) return null;

    final rejectedStatus = status == Constant.orderRejected || status == Constant.driverRejected;

    // Final cancellation / rejection with the contract fields.
    if (info.by != null || info.reason != null) {
      final action = (info.action?.toLowerCase() ?? (rejectedStatus ? 'rejected' : 'cancelled')) == 'rejected' ? 'rejected' : 'cancelled';
      final party = partyLabel(info.by, storeWord: storeWord);
      var title = party == null
          ? (action == 'rejected' ? "Rejected".tr : "Cancelled".tr)
          : (action == 'rejected' ? "${'Rejected by'.tr} $party" : "${'Cancelled by'.tr} $party");
      if (info.byName != null && info.byName != party) title = "$title (${info.byName})";
      return CancellationSummary(title: title, reason: info.reason ?? "No reason recorded".tr, at: info.at);
    }

    // A driver passed on / handed back the offer (`driverRejections`): show
    // this driver's own entry, else the latest one.
    if (status == Constant.driverRejected && info.driverRejections.isNotEmpty) {
      final uid = _currentUid();
      final entry = info.driverRejections.lastWhere((e) => e['driverId']?.toString() == uid, orElse: () => info.driverRejections.last);
      final afterAccept = entry['afterAccept'] == true;
      return CancellationSummary(
        title: afterAccept ? "${'Cancelled by'.tr} ${'Driver'.tr}" : "${'Rejected by'.tr} ${'Driver'.tr}",
        reason: CancellationInfo.text(entry['reason']) ?? "No reason recorded".tr,
        at: CancellationInfo.parseAt(entry['at']),
      );
    }

    // Cancelled before reasons were recorded.
    return CancellationSummary(
      title: status == Constant.driverRejected
          ? "${'Rejected by'.tr} ${'Driver'.tr}"
          : rejectedStatus
              ? "Rejected".tr
              : "Cancelled".tr,
      reason: "No reason recorded".tr,
    );
  }

  /// Contract labels by `cancelledBy`; vendor / store / restaurant are one party.
  static String? partyLabel(String? by, {String? storeWord}) {
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
        return storeWord ?? "Store".tr;
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

  /// "Restaurant" for a food section, else "Store".
  static String storeWordFor(String? sectionId) {
    final name = '${Constant.sectionNameFromId(sectionId)} ${Constant.sectionModelFor(sectionId)?.name ?? ''}'.toLowerCase();
    return name.contains('food') || name.contains('restaurant') ? "Restaurant".tr : "Store".tr;
  }

  static String? _currentUid() {
    try {
      return FireStoreUtils.getCurrentUid();
    } catch (_) {
      return null;
    }
  }

  /// One line for list cards: "Cancelled by Customer · Changed my plans".
  String get line => "$title · $reason";
}

/// The details-screen block for a cancelled / rejected record. Renders
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
    final tone = c.tone(DsTone.danger);
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
                Text(s.title, style: t.titleSm.copyWith(color: tone.strong)),
                const DsGap(DsSpace.xs),
                Text("${'Reason'.tr}: ${s.reason}", style: t.body.copyWith(color: c.textPrimary)),
                if (s.at != null) ...[
                  const DsGap(DsSpace.xs),
                  Text(Constant.timestampToDateTime(s.at!), style: t.caption),
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
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.block_rounded, size: 16, color: c.dangerStrong),
        const DsGap(DsSpace.xs),
        Expanded(child: Text(s.line, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm.copyWith(color: c.dangerStrong))),
      ],
    );
  }
}
