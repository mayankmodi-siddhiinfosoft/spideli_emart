import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/business_account.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Profile > Business account (spec 8.2): request verification so that
/// business-only wholesale prices apply. The admin panel approves/rejects.
///
/// Archetype **E — verification form**: a benefit banner, the review status
/// card, then the form with a document uploader and a sticky submit bar.
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
    return DsScaffold(
      title: "Business account".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: _loading || !_editing
          ? null
          : DsStickyBar(
              child: DsButton.primary(label: "Submit for verification".tr, size: DsButtonSize.lg, expand: true, icon: Icons.verified_outlined, onPressed: _submit),
            ),
      body: DsAsync(
        isLoading: _loading,
        skeleton: const DsSkeletonForm(fields: 3),
        builder: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
          children: DsFadeSlideIn.stagger([
            DsCard.tinted(
              tone: DsTone.brand,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsIconWell(icon: Icons.storefront_outlined, tone: DsTone.brand, size: 44),
                  const DsGap(DsSpace.md),
                  Expanded(child: SubUi.body(context, "A verified business account unlocks wholesale prices that stores reserve for business customers.".tr)),
                ],
              ),
            ),
            const DsGap(DsSpace.md),
            if (_profile != null) _statusCard(context),
            if (_editing) ..._form(context),
          ]),
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final status = _profile?['status']?.toString() ?? BusinessAccount.statusPending;
    final submitted = _profile?['submittedAt'];
    Widget chip;
    String note;
    DsTone tone;
    IconData icon;
    if (status == BusinessAccount.statusApproved) {
      chip = SubUi.chip("Approved".tr, DsTone.success);
      note = "Business wholesale prices are applied to your orders.".tr;
      tone = DsTone.success;
      icon = Icons.verified_rounded;
    } else if (status == BusinessAccount.statusRejected) {
      chip = SubUi.chip("Rejected".tr, DsTone.danger);
      note = "${"Reason".tr}: ${_profile?['rejectionReason']?.toString() ?? '-'}";
      tone = DsTone.danger;
      icon = Icons.gpp_bad_outlined;
    } else {
      chip = SubUi.chip("Pending review".tr, DsTone.warning);
      note = "Your request is being reviewed.".tr;
      tone = DsTone.warning;
      icon = Icons.hourglass_top_rounded;
    }
    final docUrl = _profile?['documentUrl']?.toString() ?? '';
    return SubUi.card(
      context,
      tone: tone,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: icon, tone: tone, size: 44),
              const DsGap(DsSpace.md),
              Expanded(child: SubUi.title(context, _profile?['companyName']?.toString() ?? '-')),
              const DsGap(DsSpace.sm),
              chip,
            ],
          ),
          const DsGap(DsSpace.md),
          SubUi.row(context, "Registration no.".tr, _profile?['registrationNumber']?.toString() ?? '-'),
          if (submitted is Timestamp) SubUi.row(context, "Submitted".tr, Constant.timestampToDateTime(submitted)),
          const DsGap(DsSpace.sm),
          SubUi.body(context, note),
          if (docUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: ClipRRect(borderRadius: DsRadius.brMd, child: NetworkImageWidget(imageUrl: docUrl, height: 130, width: double.infinity, fit: BoxFit.cover)),
            ),
          if (!_editing && status == BusinessAccount.statusRejected)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DsButton.tonal(label: "Submit again".tr, icon: Icons.replay_rounded, size: DsButtonSize.sm, onPressed: () => setState(() => _editing = true)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final c = DsColors.of(context);
    return [
      DsFormSection(
        title: "Business account".tr,
        icon: Icons.badge_outlined,
        children: [
          DsTextField(label: "Company name".tr, hint: "Company name".tr, controller: _company, requiredMark: true, textCapitalization: TextCapitalization.words),
          DsTextField(label: "Registration number".tr, hint: "Registration number".tr, controller: _registration, requiredMark: true, bottomSpacing: 0),
        ],
      ),
      DsFormSection(
        title: "Registration document".tr,
        icon: Icons.description_outlined,
        children: [
          if (_document != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.md),
              child: ClipRRect(borderRadius: DsRadius.brMd, child: Image.file(_document!, height: 170, width: double.infinity, fit: BoxFit.cover)),
            )
          else
            Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: DsSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: DsRadius.brMd,
                border: Border.all(color: c.border),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file_outlined, color: c.textMuted, size: 26),
                  const DsGap(DsSpace.sm),
                  Text("Please add a photo of your registration document".tr, textAlign: TextAlign.center, style: DsTypography.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: DsButton.secondary(label: "Camera".tr, icon: Icons.photo_camera_outlined, onPressed: () => _pickDocument(ImageSource.camera))),
              const DsGap(DsSpace.md),
              Expanded(child: DsButton.secondary(label: "Gallery".tr, icon: Icons.photo_library_outlined, onPressed: () => _pickDocument(ImageSource.gallery))),
            ],
          ),
        ],
      ),
    ];
  }
}
