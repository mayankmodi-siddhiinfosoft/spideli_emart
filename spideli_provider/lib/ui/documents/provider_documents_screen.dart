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
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

Color documentStatusColor(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return Colors.green;
    case DocumentStatus.rejected:
      return Colors.red;
    case DocumentStatus.expired:
      return Colors.deepOrange;
    case DocumentStatus.pendingReview:
      return Colors.orange;
    case DocumentStatus.notSubmitted:
      return Colors.grey;
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
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final bool dark = themeChange.getTheme();
    return GetBuilder<ProviderDocumentsController>(
      init: ProviderDocumentsController(),
      global: false,
      builder: (controller) {
        final Widget body = controller.isLoading.value
            ? Center(child: CircularProgressIndicator(color: AppColors.colorPrimary))
            : RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _statusHeader(controller, dark),
                    const SizedBox(height: 16),
                    _companyCard(context, controller, dark),
                    const SizedBox(height: 16),
                    Text('Documents'.tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: dark ? Colors.white : AppColors.colorDark)),
                    const SizedBox(height: 4),
                    Text(
                      'A service provider needs a commercial register and a unique identification number. Rejected or expired documents can be uploaded again.'.tr,
                      style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: dark ? AppThemeData.grey400 : AppThemeData.grey500),
                    ),
                    const SizedBox(height: 10),
                    ...controller.types.map((type) => _documentTile(context, controller, type, dark)),
                    if (pendingMode) ...[
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () async {
                          await auth.FirebaseAuth.instance.signOut();
                          MyAppState.currentUser = null;
                          RegionService.clearProvider();
                          Get.offAll(() => AuthScreen());
                        },
                        child: Text('Back to login'.tr),
                      ),
                    ],
                  ],
                ),
              );
        if (!pendingMode) return Scaffold(backgroundColor: dark ? AppColors.DARK_BG_COLOR : AppColors.colorWhite, body: body);
        return Scaffold(
          backgroundColor: dark ? AppColors.DARK_BG_COLOR : AppColors.colorWhite,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: dark ? AppColors.colorDark : AppColors.colorWhite,
            title: Text('Verification'.tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.semiBold, fontSize: 18)),
          ),
          body: body,
        );
      },
    );
  }

  Widget _statusHeader(ProviderDocumentsController controller, bool dark) {
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
    final Color color = documentStatusColor(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(
        children: [
          Icon(status == DocumentStatus.approved ? Icons.verified : Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.label, style: TextStyle(fontFamily: AppThemeData.semiBold, color: color, fontSize: 15)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontFamily: AppThemeData.regular, color: dark ? Colors.white : AppColors.colorDark, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyCard(BuildContext context, ProviderDocumentsController controller, bool dark) {
    final region = RegionService.regionById(controller.user.value?.regionId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? AppColors.darkContainerBorderColor : AppColors.colorLightGrey, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company information'.tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: dark ? Colors.white : AppColors.colorDark)),
          const SizedBox(height: 10),
          TextField(
            controller: controller.companyName.value,
            decoration: InputDecoration(labelText: 'Company name'.tr, border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          if (controller.canPickRegion)
            DropdownButtonFormField<String>(
              initialValue: controller.selectedRegionId.value.isEmpty ? null : controller.selectedRegionId.value,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Management zone'.tr, border: const OutlineInputBorder(), isDense: true),
              items: RegionService.regions.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.displayName))).toList(),
              onChanged: (value) => controller.selectedRegionId.value = value ?? '',
            )
          else if (region != null)
            Text('${'Management zone'.tr}: ${region.displayName}', style: TextStyle(fontFamily: AppThemeData.medium, color: dark ? Colors.white : AppColors.colorDark)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorPrimary),
              onPressed: () async {
                ShowToastDialog.showLoader('Please wait...'.tr);
                final ok = await controller.saveCompanyInfo();
                ShowToastDialog.closeLoader();
                ShowToastDialog.showToast(ok ? 'Company information saved'.tr : 'Could not save. Please try again.'.tr);
              },
              child: Text('Save'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(BuildContext context, ProviderDocumentsController controller, DocumentType type, bool dark) {
    final UploadedDocument? upload = controller.uploadFor(type);
    final DocumentStatus status = controller.statusFor(type);
    final Color color = documentStatusColor(status);
    return Card(
      color: dark ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Get.to(() => DocumentUploadScreen(controller: controller, type: type));
          if (result == true) controller.update();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(type.title, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 15, color: dark ? Colors.white : AppColors.colorDark))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(status.label, style: TextStyle(color: color, fontFamily: AppThemeData.medium, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
              if ((upload?.number ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${'Number'.tr}: ${upload!.number}', style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: dark ? AppThemeData.grey300 : AppThemeData.grey600)),
              ],
              if (upload?.expireAt != null) ...[
                const SizedBox(height: 4),
                Text('${'Expires on'.tr}: ${DateFormat('dd MMM yyyy').format(upload!.expireAt!.toDate())}',
                    style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: dark ? AppThemeData.grey300 : AppThemeData.grey600)),
              ],
              if (status == DocumentStatus.rejected) ...[
                const SizedBox(height: 6),
                Text('${'Reason'.tr}: ${upload?.rejectionReason ?? 'No reason given'.tr}', style: const TextStyle(fontFamily: AppThemeData.medium, fontSize: 13, color: Colors.red)),
              ],
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
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: Text('Take a photo'.tr), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: Text('Choose from gallery'.tr), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
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
    final bool dark = Provider.of<DarkThemeProvider>(context).getTheme();
    final UploadedDocument? upload = widget.controller.uploadFor(widget.type);
    final DocumentStatus status = widget.controller.statusFor(widget.type);
    final bool editable = status.canUpload;
    final Color textColor = dark ? Colors.white : AppColors.colorDark;

    Widget side(String label, File? picked, String? existing, bool front) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontFamily: AppThemeData.medium, color: textColor)),
            const SizedBox(height: 6),
            InkWell(
              onTap: editable ? () => _pick(front) : null,
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: AppThemeData.grey400), borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: picked != null
                    ? Image.file(picked, fit: BoxFit.cover)
                    : (existing ?? '').isNotEmpty
                        ? Image.network(existing!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image)))
                        : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.upload_file, size: 36), Text('Tap to add'.tr)])),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: dark ? AppColors.DARK_BG_COLOR : AppColors.colorWhite,
      appBar: AppBar(
        backgroundColor: dark ? AppColors.colorDark : AppColors.colorWhite,
        iconTheme: IconThemeData(color: textColor),
        title: Text(widget.type.title, style: TextStyle(color: textColor, fontFamily: AppColors.semiBold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Text('${'Status'.tr}: ', style: TextStyle(fontFamily: AppThemeData.medium, color: textColor)),
            Text(status.label, style: TextStyle(fontFamily: AppThemeData.semiBold, color: documentStatusColor(status))),
          ]),
          if (status == DocumentStatus.rejected) ...[
            const SizedBox(height: 6),
            Text('${'Reason'.tr}: ${upload?.rejectionReason ?? 'No reason given'.tr}', style: const TextStyle(color: Colors.red, fontFamily: AppThemeData.medium)),
          ],
          if (!editable) ...[
            const SizedBox(height: 6),
            Text(
              status == DocumentStatus.approved ? 'This document is approved.'.tr : 'This document is being reviewed. You can upload it again if it is rejected.'.tr,
              style: TextStyle(fontFamily: AppThemeData.regular, color: dark ? AppThemeData.grey400 : AppThemeData.grey500),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.type.isBuiltIn) ...[
            TextField(
              controller: _number,
              enabled: editable,
              decoration: InputDecoration(
                labelText: widget.type.id == DocumentType.commercialRegisterId ? 'Commercial register number'.tr : 'Unique identification number'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_needsFront) side(widget.type.backSide ? 'Front side'.tr : 'Document'.tr, _front, upload?.frontImage, true),
          if (widget.type.backSide) side('Back side'.tr, _back, upload?.backImage, false),
          if (widget.type.hasExpiry)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('Expiry date'.tr, style: TextStyle(color: textColor)),
              subtitle: Text(
                _expiry != null
                    ? DateFormat('dd MMM yyyy').format(_expiry!)
                    : upload?.expireAt != null
                        ? DateFormat('dd MMM yyyy').format(upload!.expireAt!.toDate())
                        : 'Select'.tr,
              ),
              onTap: editable
                  ? () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: DateTime(now.year + 30));
                      if (picked != null) setState(() => _expiry = picked);
                    }
                  : null,
            ),
          const SizedBox(height: 20),
          if (editable)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _submit,
              child: Text(status == DocumentStatus.notSubmitted ? 'Submit'.tr : 'Upload again'.tr, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
