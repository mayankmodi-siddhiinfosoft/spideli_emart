import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/document_service.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:spideliworker/widgets/network_image_widget.dart';

/// Upload (or re-upload after rejection / expiry) one worker document.
/// [readOnly] shows what was uploaded while it is pending or approved.
class DocumentUploadScreen extends StatefulWidget {
  final DocumentModel documentType;
  final Documents? existing;
  final bool readOnly;

  const DocumentUploadScreen({super.key, required this.documentType, this.existing, this.readOnly = false});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  String _front = '';
  String _back = '';
  DateTime? _expiry;

  bool get _needsFront => widget.documentType.frontSide == true || widget.documentType.backSide != true;

  bool get _needsBack => widget.documentType.backSide == true;

  bool get _needsExpiry => widget.documentType.expireAt == true;

  @override
  void initState() {
    super.initState();
    _front = widget.existing?.frontImage ?? '';
    _back = widget.existing?.backImage ?? '';
    // A rejected / expired document needs a new expiry date.
    if (widget.readOnly) _expiry = widget.existing?.expiryDate?.toDate();
  }

  bool _isRemote(String path) => path.startsWith('http');

  Future<void> _pick(bool front) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: Text("Take a picture".tr), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: Text("Choose Image From Gallery".tr), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;
      setState(() => front ? _front = image.path : _back = image.path);
    } catch (e) {
      ShowToastDialog.showToast("Could not open the camera or gallery. Please check the permission.".tr);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _expiry ?? now.add(const Duration(days: 1)), firstDate: now, lastDate: DateTime(now.year + 30));
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _submit() async {
    if (_needsFront && _front.isEmpty) {
      ShowToastDialog.showToast("Please add the front side.".tr);
      return;
    }
    if (_needsBack && _back.isEmpty) {
      ShowToastDialog.showToast("Please add the back side.".tr);
      return;
    }
    if (_needsExpiry && (_expiry == null || !_expiry!.isAfter(DateTime.now()))) {
      ShowToastDialog.showToast("Please select a valid expiry date.".tr);
      return;
    }
    final String uid = MyAppState.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final String front = (_front.isNotEmpty && !_isRemote(_front)) ? await DocumentService.uploadFile(File(_front), uid) : _front;
      final String back = (_back.isNotEmpty && !_isRemote(_back)) ? await DocumentService.uploadFile(File(_back), uid) : _back;
      final Documents document = Documents(
        documentId: widget.documentType.id,
        frontImage: front,
        backImage: back,
        expiryDate: _needsExpiry && _expiry != null ? Timestamp.fromDate(_expiry!) : null,
        extra: widget.existing == null ? null : Map<String, dynamic>.from(widget.existing!.extra),
      );
      await DocumentService.submitDocument(uid, document);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Document uploaded. It is now pending review.".tr);
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Upload failed, please try again.".tr);
    }
  }

  Widget _imageBox(String label, String path, bool front, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.semiBold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.readOnly ? null : () => _pick(front),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: dark ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade400),
            ),
            clipBehavior: Clip.antiAlias,
            child: path.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add_a_photo, color: Colors.grey), const SizedBox(height: 6), Text("Add photo".tr)]))
                : _isRemote(path)
                    ? NetworkImageWidget(imageUrl: path, fit: BoxFit.cover)
                    : Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Provider.of<DarkThemeProvider>(context).getTheme();
    final String? reason = widget.existing?.rejectionReason;
    return Scaffold(
      backgroundColor: dark ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
      appBar: CommonUI.customAppBar(
        context,
        title: Text((widget.documentType.title ?? '').tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.existing?.status == 'rejected' && (reason ?? '').isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.colorLightDeepOrange, borderRadius: BorderRadius.circular(10)),
              child: Text("${"Rejected".tr}: $reason", style: const TextStyle(color: AppColors.colorDeepOrange)),
            ),
          if (_needsFront) _imageBox("Front side", _front, true, dark),
          if (_needsBack) _imageBox("Back side", _back, false, dark),
          if (_needsExpiry)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Expiry date".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.semiBold)),
              subtitle: Text(_expiry == null ? "Select date".tr : DateFormat('dd MMM yyyy').format(_expiry!)),
              trailing: const Icon(Icons.calendar_month),
              onTap: widget.readOnly ? null : _pickExpiry,
            ),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorPrimary, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _submit,
                  child: Text("Submit for verification".tr, style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold)),
                ),
              ),
            ),
    );
  }
}
