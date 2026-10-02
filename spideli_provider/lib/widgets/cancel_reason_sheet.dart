import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

/// A reason chosen in [CancelReasonSheet]: [code] is the list entry (or
/// "other"), [reason] the text shown to people (the typed text for "Other").
class CancelReasonResult {
  final String reason;
  final String code;

  const CancelReasonResult({required this.reason, required this.code});

  /// Contract fields of a FINAL cancellation / rejection by the provider,
  /// written in the same write as the status change. [action] is
  /// `cancelled` or `rejected`.
  Map<String, dynamic> toFields({required String action, String? byName}) => {
        'cancelReason': reason,
        'cancelReasonCode': code,
        'cancelledBy': 'provider',
        if (byName != null && byName.trim().isNotEmpty) 'cancelledByName': byName.trim(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelAction': action,
      };
}

/// Mandatory cancellation / rejection reason (CANCEL-REASON-CONTRACT).
/// Reasons come from `settings/cancellationReasons.provider`, else the
/// built-in defaults; the list always ends with "Other", which needs at least
/// 3 characters of text. Returns null when the provider backs out, and the
/// caller then changes nothing.
class CancelReasonSheet {
  CancelReasonSheet._();

  static const List<String> defaultReasons = [
    "Not available at the scheduled time",
    "Service location is too far",
    "Unable to provide this service",
    "Customer asked to cancel",
    "Other",
  ];

  static Future<List<String>> _reasons() async {
    List<String> reasons = [];
    try {
      final doc = await FireStoreUtils.firestore.collection('settings').doc('cancellationReasons').get();
      final raw = doc.data()?['provider'];
      if (raw is Iterable) {
        reasons = raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    if (reasons.isEmpty) reasons = List<String>.from(defaultReasons);
    // "Other" always last.
    reasons.removeWhere((e) => e.toLowerCase() == 'other');
    reasons.add("Other");
    return reasons;
  }

  static Future<CancelReasonResult?> show({required String title}) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    final reasons = await _reasons();
    ShowToastDialog.closeLoader();
    return DsBottomSheet.show<CancelReasonResult>(
      title: title,
      subtitle: "A reason is required.".tr,
      child: _CancelReasonBody(reasons: reasons),
    );
  }
}

class _CancelReasonBody extends StatefulWidget {
  final List<String> reasons;

  const _CancelReasonBody({required this.reasons});

  @override
  State<_CancelReasonBody> createState() => _CancelReasonBodyState();
}

class _CancelReasonBodyState extends State<_CancelReasonBody> {
  String? _selected;
  String? _error;
  final TextEditingController _other = TextEditingController();

  bool get _isOther => _selected?.toLowerCase() == 'other';

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) {
      setState(() => _error = "Please select a reason".tr);
      return;
    }
    if (_isOther) {
      final text = _other.text.trim();
      if (text.length < 3) {
        setState(() => _error = "Please describe the reason (at least 3 characters)".tr);
        return;
      }
      Get.back(result: CancelReasonResult(reason: text, code: 'other'));
      return;
    }
    Get.back(result: CancelReasonResult(reason: _selected!, code: _selected!));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in widget.reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.sm),
            child: DsCard.outlined(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
              borderColor: _selected == reason ? c.brand : null,
              semanticLabel: reason.tr,
              onTap: () => setState(() {
                _selected = reason;
                _error = null;
              }),
              child: Row(
                children: [
                  Icon(
                    _selected == reason ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: _selected == reason ? c.brand : c.iconDefault,
                    size: 22,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text(reason.tr, style: t.bodyStrong)),
                ],
              ),
            ),
          ),
        if (_isOther) ...[
          const DsGap(DsSpace.xs),
          DsTextField(
            label: "Reason".tr,
            hint: "Describe the reason".tr,
            controller: _other,
            maxLines: 3,
            requiredMark: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
        if (_error != null) ...[
          DsInlineAlert(tone: DsTone.danger, message: _error!),
          const DsGap(DsSpace.md),
        ],
        Row(
          children: [
            Expanded(child: DsButton.secondary(label: "Back".tr, expand: true, onPressed: () => Get.back())),
            const DsGap(DsSpace.md),
            Expanded(child: DsButton.danger(label: "Confirm".tr, expand: true, onPressed: _confirm)),
          ],
        ),
      ],
    );
  }
}
