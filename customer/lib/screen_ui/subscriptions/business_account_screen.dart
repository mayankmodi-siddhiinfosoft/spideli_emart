import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/business_account.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Profile > Business account (spec 8.2): request verification so that
/// business-only wholesale prices apply. The admin panel approves/rejects.
class BusinessAccountScreen extends StatefulWidget {
  const BusinessAccountScreen({super.key});

  @override
  State<BusinessAccountScreen> createState() => _BusinessAccountScreenState();
}

class _BusinessAccountScreenState extends State<BusinessAccountScreen> {
  bool _loading = true;
  bool _editing = false;
  Map<String, dynamic>? _profile;
  final _company = TextEditingController();
  final _registration = TextEditingController();
  File? _document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _company.dispose();
    _registration.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _profile = await BusinessAccount.refresh();
    } catch (e) {
      _profile = BusinessAccount.profile;
    }
    _company.text = _profile?['companyName']?.toString() ?? '';
    _registration.text = _profile?['registrationNumber']?.toString() ?? '';
    _editing = _profile == null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDocument(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _document = File(picked.path));
  }

  Future<void> _submit() async {
    if (_company.text.trim().isEmpty || _registration.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter the company name and registration number".tr);
      return;
    }
    if (_document == null) {
      ShowToastDialog.showToast("Please add a photo of your registration document".tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final url = await BusinessAccount.uploadDocument(_document!);
      await BusinessAccount.submit(companyName: _company.text.trim(), registrationNumber: _registration.text.trim(), documentUrl: url);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Request sent. We will review it shortly.".tr);
      _document = null;
      await _load();
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return Scaffold(
      backgroundColor: SubUi.surface(isDark),
      appBar: SubUi.appBar("Business account".tr, isDark),
      body:
          _loading
              ? Constant.loader()
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SubUi.body("A verified business account unlocks wholesale prices that stores reserve for business customers.".tr, isDark),
                  const SizedBox(height: 12),
                  if (_profile != null) _statusCard(isDark),
                  if (_editing) ..._form(isDark),
                ],
              ),
      bottomNavigationBar:
          _loading || !_editing
              ? null
              : Container(
                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                child: RoundedButtonFill(title: "Submit for verification".tr, height: 5.5, color: AppThemeData.primary300, textColor: AppThemeData.grey50, fontSizes: 16, onPress: _submit),
              ),
    );
  }

  Widget _statusCard(bool isDark) {
    final status = _profile?['status']?.toString() ?? BusinessAccount.statusPending;
    final submitted = _profile?['submittedAt'];
    Widget chip;
    String note;
    if (status == BusinessAccount.statusApproved) {
      chip = SubUi.chip("Approved".tr, AppThemeData.success400);
      note = "Business wholesale prices are applied to your orders.".tr;
    } else if (status == BusinessAccount.statusRejected) {
      chip = SubUi.chip("Rejected".tr, AppThemeData.danger300);
      note = "${"Reason".tr}: ${_profile?['rejectionReason']?.toString() ?? '-'}";
    } else {
      chip = SubUi.chip("Pending review".tr, AppThemeData.warning400);
      note = "Your request is being reviewed.".tr;
    }
    final docUrl = _profile?['documentUrl']?.toString() ?? '';
    return SubUi.card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: SubUi.title(_profile?['companyName']?.toString() ?? '-', isDark)), chip]),
          const SizedBox(height: 6),
          SubUi.row("Registration no.".tr, _profile?['registrationNumber']?.toString() ?? '-', isDark),
          if (submitted is Timestamp) SubUi.row("Submitted".tr, Constant.timestampToDateTime(submitted), isDark),
          const SizedBox(height: 4),
          SubUi.body(note, isDark),
          if (docUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: NetworkImageWidget(imageUrl: docUrl, height: 120, width: double.infinity, fit: BoxFit.cover))),
          if (!_editing && status == BusinessAccount.statusRejected)
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => _editing = true), child: Text("Submit again".tr))),
        ],
      ),
    );
  }

  List<Widget> _form(bool isDark) {
    return [
      TextFieldWidget(title: "Company name".tr, hintText: "Company name".tr, controller: _company),
      TextFieldWidget(title: "Registration number".tr, hintText: "Registration number".tr, controller: _registration),
      const SizedBox(height: 8),
      SubUi.title("Registration document".tr, isDark),
      const SizedBox(height: 8),
      if (_document != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_document!, height: 160, width: double.infinity, fit: BoxFit.cover))),
      Row(
        children: [
          OutlinedButton.icon(onPressed: () => _pickDocument(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text("Camera".tr)),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () => _pickDocument(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: Text("Gallery".tr)),
        ],
      ),
    ];
  }
}
