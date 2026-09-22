import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A reason chosen in [CancelReasonSheet]: [code] is the list entry (or
/// "other"), [reason] the text shown to people (the free text for "Other").
class CancelReasonResult {
  final String reason;
  final String code;

  const CancelReasonResult({required this.reason, required this.code});

  /// Contract fields for a customer cancellation (APP-CONTRACT, CabCar).
  Map<String, dynamic> toFields() => {'cancelReason': reason, 'cancelReasonCode': code, 'cancelledBy': 'customer', 'cancelledAt': Timestamp.now()};
}

/// Mandatory cancellation reason (spec 7.10 / 4.8). Reasons come from
/// `settings/cancellationReasons.customer`, else the contract defaults; "Other"
/// requires free text. Returns null when the customer backs out.
class CancelReasonSheet {
  CancelReasonSheet._();

  static const List<String> defaultCustomerReasons = ["Driver is taking too long", "Changed my plans", "Booked by mistake", "Price too high", "Other"];

  /// `settings/cancellationReasons.customer`, else the defaults. Always ends
  /// with "Other".
  static Future<List<String>> customerReasons() async {
    List<String> reasons = [];
    try {
      final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('cancellationReasons').get();
      final raw = doc.data()?['customer'];
      if (raw is Iterable) {
        reasons = raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      log("customerReasons failed: $e");
    }
    if (reasons.isEmpty) reasons = List<String>.from(defaultCustomerReasons);
    if (!reasons.any((e) => e.toLowerCase() == 'other')) reasons.add("Other");
    return reasons;
  }

  static Future<CancelReasonResult?> show({String? title}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final reasons = await customerReasons();
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
  final List<String> reasons;
  final String title;

  const _CancelReasonBody({required this.reasons, required this.title});

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
      final text = _other.text.trim();
      if (text.isEmpty) {
        ShowToastDialog.showToast("Please describe the reason".tr);
        return;
      }
      Get.back(result: CancelReasonResult(reason: text, code: 'other'));
      return;
    }
    Get.back(result: CancelReasonResult(reason: _selected!, code: _selected!));
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
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value),
                child: Column(
                  children:
                      widget.reasons
                          .map(
                            (reason) => RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: reason,
                              activeColor: AppThemeData.primary300,
                              title: Text(reason.tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
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
