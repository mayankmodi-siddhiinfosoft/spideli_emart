import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// A reason chosen in [CancelReasonSheet]: [code] is the list entry (or
/// "other"), [reason] the text shown to people (the free text for "Other").
class CancelReasonResult {
  final String reason;
  final String code;

  const CancelReasonResult({required this.reason, required this.code});
}

/// Mandatory reason for anything the store cancels or rejects (report #14 and
/// the 2 Oct 2026 contract, `.claude/CANCEL-REASON-CONTRACT.md`).
///
/// Reasons come from `settings/cancellationReasons.vendor` (`.store` is read
/// as well, for panels that named the list that way), else the built-in
/// defaults for what is being done ([defaults]); "Other" requires free text of
/// at least 3 characters. Returns null when the vendor backs out of the sheet,
/// and the caller must then leave the order alone: no status, refund, wallet
/// reversal or notification.
class CancelReasonSheet {
  CancelReasonSheet._();

  static Future<CancelReasonResult?> show({String? title, String? subtitle, String? confirmLabel, List<String> defaults = FireStoreUtils.defaultVendorCancellationReasons}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final List<String> reasons = await FireStoreUtils.getVendorCancellationReasons(defaults: defaults);
    ShowToastDialog.closeLoader();
    return Get.bottomSheet<CancelReasonResult>(
      _CancelReasonBody(
        reasons: reasons,
        title: title ?? "Why are you cancelling?".tr,
        subtitle: subtitle ?? "A reason is required and is shown to the customer.".tr,
        confirmLabel: confirmLabel ?? "Confirm".tr,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// Rejecting a new order.
  static Future<CancelReasonResult?> showForRejection() => show(
    title: "Why are you rejecting this order?".tr,
    confirmLabel: "Reject order".tr,
    defaults: FireStoreUtils.defaultVendorRejectionReasons,
  );

  /// Rejecting a dine-in table booking.
  static Future<CancelReasonResult?> showForBookingRejection() => show(
    title: "Why are you rejecting this booking?".tr,
    confirmLabel: "Reject booking".tr,
    defaults: FireStoreUtils.defaultDineInRejectionReasons,
  );
}

class _CancelReasonBody extends StatefulWidget {
  final List<String> reasons;
  final String title;
  final String subtitle;
  final String confirmLabel;

  const _CancelReasonBody({required this.reasons, required this.title, required this.subtitle, required this.confirmLabel});

  @override
  State<_CancelReasonBody> createState() => _CancelReasonBodyState();
}

class _CancelReasonBodyState extends State<_CancelReasonBody> {
  String? _selected;
  final TextEditingController _other = TextEditingController();

  bool _isOther(String? value) => value != null && value.toLowerCase() == 'other';

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) {
      ShowToastDialog.showToast("Please select a reason".tr);
      return;
    }
    if (_isOther(_selected)) {
      final String text = _other.text.trim();
      if (text.length < 3) {
        ShowToastDialog.showToast("Please describe the reason (at least 3 characters)".tr);
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
    return DsSheet(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: Row(
        children: [
          Expanded(child: DsButton.secondary(label: "Back".tr, expand: true, onPressed: () => Get.back())),
          DsGap.md,
          Expanded(child: DsButton.danger(label: widget.confirmLabel, icon: Icons.cancel_outlined, expand: true, onPressed: _confirm)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final String reason in widget.reasons)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: reason,
                    activeColor: c.brand,
                    title: Text(reason.tr, style: context.dsText.body),
                  ),
              ],
            ),
          ),
          if (_isOther(_selected))
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: DsTextField(label: 'Reason'.tr, controller: _other, hint: 'Describe the reason'.tr, maxLines: 3, bottomSpacing: 0, autofocus: true),
            ),
        ],
      ),
    );
  }
}
