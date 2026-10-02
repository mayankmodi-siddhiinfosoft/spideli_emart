import 'package:customer/models/cancellation_fields.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Details-screen block for a cancelled / rejected record
/// (CANCEL-REASON-CONTRACT):
///
///   Cancelled by Restaurant
///   Reason: `cancelReason`      (or "No reason recorded")
///   the date and time
///
/// Renders nothing while the record is not cancelled or rejected.
class CancellationInfoBlock extends StatelessWidget {
  final String? status;
  final CancellationFields fields;

  /// The section's own word for the store ("Restaurant" / "Store").
  final String vendorWord;

  /// A pre-contract reason field (e.g. on-demand `reason`).
  final String? fallbackReason;
  final EdgeInsetsGeometry padding;

  const CancellationInfoBlock({super.key, required this.status, required this.fields, this.vendorWord = 'Store', this.fallbackReason, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final summary = CancellationSummary.of(status: status, fields: fields, vendorWord: vendorWord, fallbackReason: fallbackReason);
    if (summary == null) return const SizedBox.shrink();
    final title = summary.actorName == null ? summary.headline : '${summary.headline} (${summary.actorName})';
    final lines = <String>[
      summary.hasReason ? '${'Reason'.tr}: ${summary.reason}' : summary.reason,
      if (summary.timeLabel != null) summary.timeLabel!,
    ];
    return Padding(
      padding: padding,
      child: DsInlineAlert(tone: DsTone.danger, icon: Icons.cancel_outlined, title: title, message: lines.join('\n')),
    );
  }
}

/// One-line version for list / history cards:
/// "Cancelled by Customer · Changed my plans". Renders nothing while the
/// record is not cancelled or rejected.
class CancellationInfoLine extends StatelessWidget {
  final String? status;
  final CancellationFields fields;
  final String vendorWord;
  final String? fallbackReason;
  final EdgeInsetsGeometry padding;

  const CancellationInfoLine({super.key, required this.status, required this.fields, this.vendorWord = 'Store', this.fallbackReason, this.padding = const EdgeInsets.only(top: DsSpace.sm)});

  @override
  Widget build(BuildContext context) {
    final summary = CancellationSummary.of(status: status, fields: fields, vendorWord: vendorWord, fallbackReason: fallbackReason);
    if (summary == null) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.danger);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.cancel_outlined, size: 14, color: tone.strong)),
          const DsGap(DsSpace.xs),
          Expanded(child: Text(summary.oneLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption.withColor(tone.strong))),
        ],
      ),
    );
  }
}
