import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/cancel_reason_list.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A reason chosen in [CancelReasonSheet]: [code] is the list entry's code
/// (a stored `{code, label}` entry's own code, a plain string entry's text, or
/// "other" for typed text), [reason] the text shown to people (the entry's
/// label, or the free text for "Other").
class CancelReasonResult {
  final String reason;
  final String code;

  const CancelReasonResult({required this.reason, required this.code});

  /// The result for a chosen list entry; [otherText] is the typed text when
  /// [option] is "Other".
  factory CancelReasonResult.fromOption(CancelReasonOption option, {String otherText = ''}) => option.isOther
      ? CancelReasonResult(reason: otherText.trim(), code: CancelReasonOption.otherCode)
      : CancelReasonResult(reason: option.label, code: option.code);

  /// Fields for a driver passing on / handing back a ride or rental.
  ///
  /// The booking stays open to other drivers, so the reason is appended to a
  /// per-driver `driverRejections` list rather than written to the booking's
  /// own cancelReason / cancelledBy (those would otherwise stay on a booking
  /// another driver later completes). [afterAccept] marks a driver who had
  /// accepted and then cancelled, so the customer app can say "your driver
  /// cancelled - finding another driver".
  Map<String, dynamic> toFields(String? driverId, {bool afterAccept = false}) => {
        'driverRejections': FieldValue.arrayUnion([
          {
            'driverId': driverId ?? '',
            'reason': reason,
            'code': code,
            'at': Timestamp.now(),
            'afterAccept': afterAccept,
          },
        ]),
      };
}

/// Mandatory cancellation reason (spec 9.1 / 4.8 step 6). Reasons come from
/// `settings/cancellationReasons` (`driver`, then `reasons`, then `list`),
/// else the contract defaults; "Other" requires free text. Returns null when
/// the driver backs out.
class CancelReasonSheet {
  CancelReasonSheet._();

  static Future<CancelReasonResult?> show({String? title}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final reasons = await FireStoreUtils.getDriverCancellationReasons();
    ShowToastDialog.closeLoader();
    final isDark = Get.find<ThemeController>().isDark.value;
    return Get.bottomSheet<CancelReasonResult>(
      _CancelReasonBody(reasons: reasons, title: title ?? "Why are you cancelling?".tr),
      isScrollControlled: true,
      backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    );
  }
}

class _CancelReasonBody extends StatefulWidget {
  final List<CancelReasonOption> reasons;
  final String title;

  const _CancelReasonBody({required this.reasons, required this.title});

  @override
  State<_CancelReasonBody> createState() => _CancelReasonBodyState();
}

class _CancelReasonBodyState extends State<_CancelReasonBody> {
  CancelReasonOption? _selected;
  final TextEditingController _other = TextEditingController();

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
    if (_selected!.isOther && _other.text.trim().length < 3) {
      ShowToastDialog.showToast("Please describe the reason (at least 3 characters)".tr);
      return;
    }
    Get.back(result: CancelReasonResult.fromOption(_selected!, otherText: _other.text));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return SafeArea(
      child: Padding(
        // Get.bottomSheet already lifts the sheet above the keyboard; adding the
        // inset again pushed it up by twice the keyboard height.
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
              const SizedBox(height: 4),
              Text("A reason is required.".tr, style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600)),
              const SizedBox(height: 8),
              RadioGroup<CancelReasonOption>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value),
                child: Column(
                  children: widget.reasons
                      .map((reason) => RadioListTile<CancelReasonOption>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: reason,
                            activeColor: AppThemeData.primary300,
                            title: Text(reason.label.tr, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                          ))
                      .toList(),
                ),
              ),
              if (_selected?.isOther == true)
                TextFieldWidget(
                  title: 'Reason'.tr,
                  controller: _other,
                  hintText: 'Describe the reason'.tr,
                  maxLine: 3,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Back".tr,
                      height: 5.5,
                      borderRadius: 10,
                      color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                      textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      onPress: () => Get.back(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Confirm".tr,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.grey50,
                      onPress: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
