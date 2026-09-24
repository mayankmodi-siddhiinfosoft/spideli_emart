import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/provider_documents_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

/// Semantic tone of a verification status – drives every chip, alert and
/// icon well on the documents screens.
DsTone documentStatusTone(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return DsTone.success;
    case DocumentStatus.rejected:
      return DsTone.danger;
    case DocumentStatus.expired:
      return DsTone.warning;
    case DocumentStatus.pendingReview:
      return DsTone.info;
    case DocumentStatus.notSubmitted:
      return DsTone.neutral;
  }
}

/// Company information + documents (spec 10: "Company information > Upload
/// documents > Pending verification > Approved").
///
/// [pendingMode] is the pre-approval flow: the account exists but is not
/// active yet, so the screen has its own app bar and a "Back to login" action
/// that signs out.
class ProviderDocumentsScreen extends StatelessWidget {
  final bool pendingMode;

  const ProviderDocumentsScreen({super.key, this.pendingMode = false});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    return GetBuilder<ProviderDocumentsController>(
      init: ProviderDocumentsController(),
      global: false,
      builder: (controller) {
        final Widget body = controller.isLoading.value
            ? const _DocumentsSkeleton()
            : RefreshIndicator(
                onRefresh: controller.load,
                color: c.brand,
                backgroundColor: c.surface,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.xxxl),
                  children: [
                    DsResponsive(
                      maxWidth: DsLayout.contentMax,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          _statusHeader(context, controller),
                          const DsGap(DsSpace.lg),
                          _companyCard(context, controller),
                          const DsGap(DsSpace.lg),
                          DsSectionHeader(
                            title: 'Documents'.tr,
                            icon: Icons.folder_copy_outlined,
                            subtitle: 'A service provider needs a commercial register and a unique identification number. Rejected or expired documents can be uploaded again.'.tr,
                            padding: EdgeInsets.zero,
                          ),
                          const DsGap(DsSpace.md),
                          ...controller.types.map((type) => _documentTile(context, controller, type)),
                          if (pendingMode) ...[
                            const DsGap(DsSpace.xxl),
                            DsButton.secondary(
                              label: 'Back to login'.tr,
                              icon: Icons.logout_rounded,
                              expand: true,
                              onPressed: () async {
                                await auth.FirebaseAuth.instance.signOut();
                                MyAppState.currentUser = null;
                                RegionService.clearProvider();
                                Get.offAll(() => AuthScreen());
                              },
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              );
        if (!pendingMode) return Scaffold(backgroundColor: c.background, body: body);
        return Scaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(title: 'Verification'.tr, showBack: false, backgroundColor: c.background),
          body: body,
        );
      },
    );
  }

  /// Verification banner + progress: how many required documents are approved.
  Widget _statusHeader(BuildContext context, ProviderDocumentsController controller) {
    final DocumentStatus status = controller.overallStatus;
    String message;
    switch (status) {
      case DocumentStatus.approved:
        message = 'Your documents are verified.'.tr;
        break;
      case DocumentStatus.pendingReview:
        message = 'Your documents are pending verification by the administrator.'.tr;
        break;
      case DocumentStatus.rejected:
        message = 'A document was rejected. Check the reason and upload it again.'.tr;
        break;
      case DocumentStatus.expired:
        message = 'A document has expired. Upload a valid one.'.tr;
        break;
      case DocumentStatus.notSubmitted:
        message = 'Upload the required documents to get verified.'.tr;
        break;
    }
    final DsTone tone = documentStatusTone(status);
    final int total = controller.types.length;
    final int approved = controller.types.where((t) => controller.statusFor(t) == DocumentStatus.approved).length;
    return DsCard.tinted(
      tone: tone,
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: status == DocumentStatus.approved ? Icons.verified : Icons.info_outline, tone: tone, size: 44, circle: true),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.label, style: context.dsText.titleSm.withColor(context.dsColors.tone(tone).strong)),
                    const DsGap(DsSpace.xxs),
                    Text(message, style: context.dsText.bodySm.withColor(context.dsColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[const DsGap(DsSpace.lg), DsProgressBar(value: approved / total, tone: tone, label: '${'Verification'.tr} · $approved/$total', showPercent: true)],
        ],
      ),
    );
  }

  Widget _companyCard(BuildContext context, ProviderDocumentsController controller) {
    final region = RegionService.regionById(controller.user.value?.regionId);
    final c = context.dsColors;
    return DsFormSection(
      title: 'Company information'.tr,
      icon: Icons.business_outlined,
      margin: EdgeInsets.zero,
      children: [
        DsTextField(label: 'Company name'.tr, controller: controller.companyName.value, prefixIcon: Icons.storefront_outlined, bottomSpacing: DsSpace.lg),
        if (controller.canPickRegion)
          DsDropdown<String>(
            label: 'Management zone'.tr,
            value: controller.selectedRegionId.value.isEmpty ? null : controller.selectedRegionId.value,
            items: RegionService.regions.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.displayName))).toList(),
            onChanged: (value) => controller.selectedRegionId.value = value ?? '',
            prefixIcon: Icons.map_outlined,
            bottomSpacing: DsSpace.md,
          )
        else if (region != null)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(child: Text('${'Management zone'.tr}: ${region.displayName}', style: context.dsText.bodyStrong)),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: DsButton.tonal(
            label: 'Save'.tr,
            icon: Icons.check_rounded,
            size: DsButtonSize.sm,
            onPressed: () async {
              ShowToastDialog.showLoader('Please wait...'.tr);
              final ok = await controller.saveCompanyInfo();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast(ok ? 'Company information saved'.tr : 'Could not save. Please try again.'.tr);
            },
          ),
        ),
        const DsGap(DsSpace.sm),
      ],
    );
  }

  Widget _documentTile(BuildContext context, ProviderDocumentsController controller, DocumentType type) {
    final UploadedDocument? upload = controller.uploadFor(type);
    final DocumentStatus status = controller.statusFor(type);
    final DsTone tone = documentStatusTone(status);
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.lg),
        borderColor: status == DocumentStatus.rejected ? c.danger : null,
        semanticLabel: '${type.title} · ${status.label}',
        onTap: () async {
          final result = await Get.to(() => DocumentUploadScreen(controller: controller, type: type));
          if (result == true) controller.update();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIconWell(icon: Icons.badge_outlined, tone: tone, size: 44),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.title, style: t.titleSm),
                      const DsGap(DsSpace.sm),
                      Wrap(
                        spacing: DsSpace.sm,
                        runSpacing: DsSpace.xs,
                        children: [
                          DsStatusChip(label: status.label, tone: tone, pulse: status == DocumentStatus.pendingReview),
                          if ((upload?.number ?? '').isNotEmpty) DsBadge(label: '${'Number'.tr}: ${upload!.number}', small: true),
                          if (upload?.expireAt != null)
                            DsBadge(
                              label: '${'Expires on'.tr}: ${DateFormat('dd MMM yyyy').format(upload!.expireAt!.toDate())}',
                              icon: Icons.event_outlined,
                              small: true,
                              tone: status == DocumentStatus.expired ? DsTone.warning : DsTone.neutral,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.md),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: c.textMuted),
                ),
              ],
            ),
            if (status == DocumentStatus.rejected) ...[
              const DsGap(DsSpace.md),
              DsCard.tinted(
                tone: DsTone.danger,
                padding: const EdgeInsets.all(DsSpace.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_gmailerrorred_rounded, size: 18, color: c.dangerStrong),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text('${'Reason'.tr}: ${upload?.rejectionReason ?? 'No reason given'.tr}', style: t.bodySm.withColor(c.dangerStrong))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner + company card + three document rows, shown while the documents
/// load so the page does not jump.
class _DocumentsSkeleton extends StatelessWidget {
  const _DocumentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsResponsive(
      maxWidth: DsLayout.contentMax,
      padded: true,
      child: DsShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DsGap(DsSpace.lg),
              DsSkeleton.box(width: double.infinity, height: 116),
              const DsGap(DsSpace.lg),
              DsSkeleton.box(width: double.infinity, height: 200),
              const DsGap(DsSpace.lg),
              DsSkeleton.line(width: 160, height: 16),
              const DsGap(DsSpace.md),
              for (int i = 0; i < 3; i++) ...[DsSkeleton.box(width: double.infinity, height: 92), const DsGap(DsSpace.md)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Upload / re-upload of one document. Read-only while it is pending review
/// or approved.
class DocumentUploadScreen extends StatefulWidget {
  final ProviderDocumentsController controller;
  final DocumentType type;

  const DocumentUploadScreen({super.key, required this.controller, required this.type});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _number = TextEditingController();
  File? _front;
  File? _back;
  DateTime? _expiry;

  bool get _needsFront => widget.type.frontSide || !widget.type.backSide;

  @override
  void initState() {
    super.initState();
    _number.text = widget.controller.uploadFor(widget.type)?.number ?? '';
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick(bool front) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DsSheet(
        title: 'Add document'.tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsListTile(title: 'Take a photo'.tr, leadingIcon: Icons.photo_camera, showChevron: true, onTap: () => Navigator.pop(context, ImageSource.camera)),
            DsListTile(title: 'Choose from gallery'.tr, leadingIcon: Icons.photo_library, showChevron: true, onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;
    setState(() => front ? _front = File(image.path) : _back = File(image.path));
  }

  Future<void> _submit() async {
    final type = widget.type;
    if (type.isBuiltIn && _number.text.trim().isEmpty) {
      ShowToastDialog.showToast('Please enter the number'.tr);
      return;
    }
    if (_needsFront && _front == null) {
      ShowToastDialog.showToast('Please add the front side'.tr);
      return;
    }
    if (type.backSide && _back == null) {
      ShowToastDialog.showToast('Please add the back side'.tr);
      return;
    }
    if (type.hasExpiry && _expiry == null) {
      ShowToastDialog.showToast('Please select the expiry date'.tr);
      return;
    }
    ShowToastDialog.showLoader('Uploading document...'.tr);
    final ok = await widget.controller.submit(type: type, front: _front, back: _back, number: _number.text, expiry: _expiry);
    ShowToastDialog.closeLoader();
    if (ok) {
      ShowToastDialog.showToast('Document submitted for verification'.tr);
      Get.back(result: true);
    } else {
      ShowToastDialog.showToast('Upload failed. Please try again.'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    final UploadedDocument? upload = widget.controller.uploadFor(widget.type);
    final DocumentStatus status = widget.controller.statusFor(widget.type);
    final bool editable = status.canUpload;
    final DsTone tone = documentStatusTone(status);

    Widget side(String label, File? picked, String? existing, bool front) {
      final bool hasImage = picked != null || (existing ?? '').isNotEmpty;
      return Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsFieldLabel(label),
            DsCard.outlined(
              padding: EdgeInsets.zero,
              borderColor: hasImage ? c.brandMuted : null,
              semanticLabel: label,
              onTap: editable ? () => _pick(front) : null,
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: picked != null
                    ? Image.file(picked, fit: BoxFit.cover)
                    : (existing ?? '').isNotEmpty
                    ? DsImage(url: existing, width: double.infinity, height: 170, radius: 0, errorIcon: Icons.broken_image)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DsIconWell(icon: Icons.upload_file, tone: DsTone.brand, size: 48, circle: true),
                            const DsGap(DsSpace.sm),
                            Text('Tap to add'.tr, style: t.bodySm),
                          ],
                        ),
                      ),
              ),
            ),
            if (hasImage && editable) ...[
              const DsGap(DsSpace.sm),
              Align(
                alignment: Alignment.centerRight,
                child: DsButton.ghost(label: 'Upload again'.tr, icon: Icons.refresh_rounded, size: DsButtonSize.sm, onPressed: () => _pick(front)),
              ),
            ],
          ],
        ),
      );
    }

    return DsScaffold(
      backgroundColor: c.background,
      appBar: DsAppBar(title: widget.type.title, backgroundColor: c.background),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.xxxl),
        children: [
          DsResponsive(
            maxWidth: DsLayout.contentMax,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                // One clear verdict block at the top: state, reason, what the
                // provider can do next.
                DsInlineAlert(
                  tone: tone,
                  title: '${'Status'.tr}: ${status.label}',
                  message: status == DocumentStatus.rejected
                      ? '${'Reason'.tr}: ${upload?.rejectionReason ?? 'No reason given'.tr}'
                      : !editable
                      ? (status == DocumentStatus.approved ? 'This document is approved.'.tr : 'This document is being reviewed. You can upload it again if it is rejected.'.tr)
                      : 'Add a clear photo of the document and submit it for verification.'.tr,
                  icon: status == DocumentStatus.approved ? Icons.verified_rounded : Icons.info_outline_rounded,
                ),
                const DsGap(DsSpace.xl),
                if (widget.type.isBuiltIn) ...[
                  DsTextField(
                    label: widget.type.id == DocumentType.commercialRegisterId ? 'Commercial register number'.tr : 'Unique identification number'.tr,
                    controller: _number,
                    enabled: editable,
                    prefixIcon: Icons.numbers_rounded,
                  ),
                ],
                if (_needsFront) side(widget.type.backSide ? 'Front side'.tr : 'Document'.tr, _front, upload?.frontImage, true),
                if (widget.type.backSide) side('Back side'.tr, _back, upload?.backImage, false),
                if (widget.type.hasExpiry)
                  DsCard.outlined(
                    padding: EdgeInsets.zero,
                    child: DsListTile(
                      title: 'Expiry date'.tr,
                      leadingIcon: Icons.event,
                      leadingTone: DsTone.info,
                      showChevron: editable,
                      subtitle: _expiry != null
                          ? DateFormat('dd MMM yyyy').format(_expiry!)
                          : upload?.expireAt != null
                          ? DateFormat('dd MMM yyyy').format(upload!.expireAt!.toDate())
                          : 'Select'.tr,
                      onTap: editable
                          ? () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: DateTime(now.year + 30));
                              if (picked != null) setState(() => _expiry = picked);
                            }
                          : null,
                    ),
                  ),
                const DsGap(DsSpace.xl),
              ]),
            ),
          ),
        ],
      ),
      bottomBar: editable
          ? DsStickyBar(
              child: DsButton.primary(
                label: status == DocumentStatus.notSubmitted ? 'Submit'.tr : 'Upload again'.tr,
                icon: Icons.cloud_upload_outlined,
                expand: true,
                size: DsButtonSize.lg,
                onPressed: _submit,
              ),
            )
          : null,
    );
  }
}
