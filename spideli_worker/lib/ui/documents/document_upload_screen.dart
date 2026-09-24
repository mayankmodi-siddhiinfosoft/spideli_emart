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
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';

/// Upload (or re-upload after rejection / expiry) one worker document.
/// [readOnly] shows what was uploaded while it is pending or approved.
///
/// Design: archetype N (upload half). The rejection reason is a danger
/// [DsInlineAlert], each side is a large drop zone that previews the picked
/// image, the expiry date is a read-only picker field, and "Submit for
/// verification" lives in a [DsStickyBar].
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
  final TextEditingController _expiryController = TextEditingController();
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
    _syncExpiryText();
  }

  @override
  void dispose() {
    _expiryController.dispose();
    super.dispose();
  }

  void _syncExpiryText() {
    _expiryController.text = _expiry == null ? '' : DateFormat('dd MMM yyyy').format(_expiry!);
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
    if (picked != null) {
      setState(() => _expiry = picked);
      _syncExpiryText();
    }
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

  /// Large drop zone: dashed-looking empty slot, or the picked / uploaded
  /// image with a "Change" affordance.
  Widget _imageBox(BuildContext context, String label, String path, bool front) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool empty = path.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsFieldLabel(label.tr, required: !widget.readOnly),
        const DsGap(DsSpace.sm),
        Semantics(
          button: !widget.readOnly,
          label: label.tr,
          child: InkWell(
            borderRadius: DsRadius.brLg,
            onTap: widget.readOnly ? null : () => _pick(front),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: empty ? c.surfaceAlt : c.surface,
                borderRadius: DsRadius.brLg,
                border: Border.all(color: empty ? c.borderStrong : c.border, width: empty ? 1.4 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: empty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsIconWell(icon: Icons.add_a_photo_outlined, size: 48, circle: true),
                        const DsGap(DsSpace.md),
                        Text("Add photo".tr, style: t.label.withColor(c.brandStrong)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _isRemote(path)
                            ? DsImage(url: path, fit: BoxFit.cover, radius: 0)
                            : Image.file(File(path), fit: BoxFit.cover),
                        if (!widget.readOnly)
                          PositionedDirectional(
                            end: DsSpace.sm,
                            bottom: DsSpace.sm,
                            child: DsBadge(label: "Re-upload".tr, icon: Icons.edit_outlined, style: DsBadgeStyle.solid, tone: DsTone.brand, small: true),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        const DsGap(DsSpace.xl),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes the screen to theme changes.
    Provider.of<DarkThemeProvider>(context);
    final l = context.dsLayout;
    final String? reason = widget.existing?.rejectionReason;
    return DsScaffold(
      title: (widget.documentType.title ?? '').tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
        children: DsFadeSlideIn.stagger([
          if (widget.existing?.status == 'rejected' && (reason ?? '').isNotEmpty) ...[
            DsInlineAlert(tone: DsTone.danger, icon: Icons.gpp_bad_outlined, title: "Rejected".tr, message: reason!),
            const DsGap(DsSpace.xl),
          ],
          if (_needsFront) _imageBox(context, "Front side", _front, true),
          if (_needsBack) _imageBox(context, "Back side", _back, false),
          if (_needsExpiry)
            DsTextField(
              label: "Expiry date".tr,
              hint: "Select date".tr,
              readOnly: true,
              enabled: !widget.readOnly,
              controller: _expiryController,
              suffix: const Icon(Icons.calendar_month),
              onTap: widget.readOnly ? null : _pickExpiry,
            ),
        ]),
      ),
      bottomBar: widget.readOnly
          ? null
          : DsStickyBar(
              child: DsButton.primary(
                label: "Submit for verification".tr,
                icon: Icons.cloud_upload_outlined,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: _submit,
              ),
            ),
    );
  }
}
