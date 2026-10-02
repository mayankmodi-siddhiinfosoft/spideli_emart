import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/cancellation_fields.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/cancel_reason_list.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A reason chosen in [CancelReasonSheet]: [code] is the list entry (or
/// "other"), [reason] the text shown to people (the free text for "Other").
class CancelReasonResult {
  final String reason;
  final String code;

  const CancelReasonResult({required this.reason, required this.code});

  /// The customer's display name for `cancelledByName`, or null.
  static String? get customerName {
    final name = Constant.userModel?.fullName().trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// Contract fields for a customer cancellation (CANCEL-REASON-CONTRACT),
  /// written in the same update as the status change.
  Map<String, dynamic> toFields() {
    final name = customerName;
    return {
      'cancelReason': reason,
      'cancelReasonCode': code,
      'cancelledBy': 'customer',
      'cancelledByName': ?name,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelAction': 'cancelled',
    };
  }

  /// Mirrors [toFields] on a local model so the screen shows the result
  /// before the listener catches up (local clock for the time).
  void applyTo(CancellationFields model) {
    model
      ..cancelReason = reason
      ..cancelReasonCode = code
      ..cancelledBy = 'customer'
      ..cancelledByName = customerName
      ..cancelledAt = Timestamp.now()
      ..cancelAction = 'cancelled';
  }
}

/// Mandatory cancellation reason (spec 7.10 / 4.8). Reasons come from
/// `settings/cancellationReasons` (`customer`, else `reasons` / `list`, strings
/// or `{code, label}`), else the contract defaults; "Other" requires free
/// text. Returns null when the customer backs out.
class CancelReasonSheet {
  CancelReasonSheet._();

  static const List<String> defaultCustomerReasons = ["Driver is taking too long", "Changed my plans", "Booked by mistake", "Price too high", "Other"];

  /// `settings/cancellationReasons` read by [parseCancelReasonList], else the
  /// defaults. Always ends with "Other" exactly once.
  static Future<List<CancelReasonOption>> customerReasons() async {
    Map<String, dynamic>? data;
    try {
      final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('cancellationReasons').get();
      data = doc.data();
    } catch (e) {
      log("customerReasons failed: $e");
    }
    return parseCancelReasonList(data, roleKeys: const ['customer'], defaults: defaultCustomerReasons);
  }

  /// [message] is an optional note under the title (e.g. what happens to
  /// payments). Backing out returns null and must change nothing.
  static Future<CancelReasonResult?> show({String? title, String? message}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final reasons = await customerReasons();
    ShowToastDialog.closeLoader();
    final isDark = Get.find<ThemeController>().isDark.value;
    return Get.bottomSheet<CancelReasonResult>(
      _CancelReasonBody(reasons: reasons, title: title ?? "Why are you cancelling?".tr, message: message),
      isScrollControlled: true,
      backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    );
  }
}

class _CancelReasonBody extends StatefulWidget {
  final List<CancelReasonOption> reasons;
  final String title;
  final String? message;

  const _CancelReasonBody({required this.reasons, required this.title, this.message});

  @override
  State<_CancelReasonBody> createState() => _CancelReasonBodyState();
}

class _CancelReasonBodyState extends State<_CancelReasonBody> {
  CancelReasonOption? _selected;
  final TextEditingController _other = TextEditingController();

  bool _isOther(CancelReasonOption? value) => value?.isOther ?? false;

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
      final text = _other.text.trim();
      // Contract: "Other" needs at least 3 characters of free text.
      if (text.length < 3) {
        ShowToastDialog.showToast(text.isEmpty ? "Please describe the reason".tr : "Please describe the reason in at least 3 characters".tr);
        return;
      }
      Get.back(result: CancelReasonResult(reason: text, code: 'other'));
      return;
    }
    Get.back(result: CancelReasonResult(reason: _selected!.label, code: _selected!.code));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
              const SizedBox(height: 4),
              Text("A reason is required.".tr, style: AppThemeData.regularTextStyle(fontSize: 13, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600)),
              if (widget.message != null) ...[
                const SizedBox(height: 4),
                Text(widget.message!, style: AppThemeData.regularTextStyle(fontSize: 13, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600)),
              ],
              const SizedBox(height: 8),
              RadioGroup<CancelReasonOption>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value),
                child: Column(
                  children:
                      widget.reasons
                          .map(
                            (reason) => RadioListTile<CancelReasonOption>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: reason,
                              activeColor: AppThemeData.primary300,
                              title: Text(reason.label.tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                            ),
                          )
                          .toList(),
                ),
              ),
              if (_isOther(_selected)) TextFieldWidget(title: 'Reason'.tr, controller: _other, hintText: 'Describe the reason'.tr, maxLine: 3),
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
                    child: RoundedButtonFill(title: "Confirm".tr, height: 5.5, borderRadius: 10, color: AppThemeData.danger300, textColor: AppThemeData.grey50, onPress: _confirm),
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
