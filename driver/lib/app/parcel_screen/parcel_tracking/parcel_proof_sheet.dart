import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Delivery proof for a home delivery (spec 9 "Proof (OTP / photo / scan)"): the receiver's code or a photo.
/// Returns the `deliveryProof` map, or null when the driver cancels.
///
/// Archetype D (proof): a DS sheet with the proof type, the field or photo tile
/// and one sticky confirm action.
Future<Map<String, dynamic>?> showParcelProofSheet(BuildContext context, ParcelOrderModel order, {required bool isDark}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: DsColors.resolve(isDark).scrim,
    builder: (_) => _ParcelProofSheet(order: order),
  );
}

class _ParcelProofSheet extends StatefulWidget {
  final ParcelOrderModel order;

  const _ParcelProofSheet({required this.order});

  @override
  State<_ParcelProofSheet> createState() => _ParcelProofSheetState();
}

class _ParcelProofSheetState extends State<_ParcelProofSheet> {
  final TextEditingController _code = TextEditingController();
  late String _type;
  File? _photo;

  String? get _receiverCode => ParcelTrackingService.receiverCode(widget.order);

  @override
  void initState() {
    super.initState();
    _type = _receiverCode != null ? 'otp' : 'photo';
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 60);
      if (picked != null && mounted) setState(() => _photo = File(picked.path));
    } on PlatformException catch (e) {
      debugPrint('ParcelProofSheet camera $e');
      ShowToastDialog.showToast("Camera unavailable. Please allow camera access for the app in your phone settings.".tr);
    } catch (e) {
      debugPrint('ParcelProofSheet camera $e');
      ShowToastDialog.showToast("Could not open the camera".tr);
    }
  }

  Future<void> _confirm() async {
    final by = FireStoreUtils.getCurrentUid();
    if (_type == 'otp') {
      if (_code.text.trim() != _receiverCode) {
        ShowToastDialog.showToast("Invalid code".tr);
        return;
      }
      Navigator.of(context).pop({'type': 'otp', 'at': Timestamp.now(), 'by': by});
      return;
    }
    if (_photo == null) {
      ShowToastDialog.showToast("Please take a photo of the delivered parcel".tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final url = await Constant.uploadUserImageToFireStorage(_photo!, 'parcelDeliveryProof/${widget.order.id}', '${DateTime.now().millisecondsSinceEpoch}.jpg');
      ShowToastDialog.closeLoader();
      if (mounted) Navigator.of(context).pop({'type': 'photo', 'photoUrl': url, 'at': Timestamp.now(), 'by': by});
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Upload failed, please try again".tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsSheet(
      title: "Proof of delivery".tr,
      showClose: true,
      actions: DsButton.success(
        label: "Confirm delivery".tr,
        icon: Icons.check_circle_outline_rounded,
        size: DsButtonSize.xl,
        expand: true,
        onPressed: _confirm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ProofTypeTile(
                  icon: Icons.pin_rounded,
                  label: "Receiver code".tr,
                  selected: _type == 'otp',
                  enabled: _receiverCode != null,
                  onTap: () => setState(() => _type = 'otp'),
                ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: _ProofTypeTile(
                  icon: Icons.photo_camera_outlined,
                  label: "Photo".tr,
                  selected: _type == 'photo',
                  enabled: true,
                  onTap: () => setState(() => _type = 'photo'),
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.xl),
          AnimatedSize(
            duration: DsMotion.of(context, DsMotion.base),
            curve: DsMotion.standard,
            alignment: Alignment.topCenter,
            child: _type == 'otp'
                ? DsTextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    bottomSpacing: 0,
                    label: "Code given by the receiver".tr,
                    prefixIcon: Icons.lock_outline_rounded,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_receiverCode == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.md),
                          child: DsInlineAlert(
                            tone: DsTone.info,
                            icon: Icons.info_outline_rounded,
                            message: "This parcel has no receiver code; take a photo of the delivered parcel.".tr,
                          ),
                        ),
                      DsPressable(
                        onTap: _takePhoto,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: DsRadius.brLg,
                            border: Border.all(color: _photo == null ? c.borderStrong : c.brandMuted),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              if (_photo != null)
                                ClipRRect(
                                  borderRadius: DsRadius.brMd,
                                  child: Image.file(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(DsSpace.lg),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    DsIconWell(icon: Icons.photo_camera_outlined, tone: DsTone.brand, size: 40, circle: true),
                                    const DsGap(DsSpace.md),
                                    Flexible(
                                      child: Text(
                                        _photo == null ? "Take photo".tr : "Retake photo".tr,
                                        style: t.label.withColor(c.brandStrong),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Selectable proof type. Disabled when the parcel has no receiver code.
class _ProofTypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ProofTypeTile({required this.icon, required this.label, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color fg = !enabled
        ? c.textDisabled
        : selected
            ? c.brandStrong
            : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: DsPressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          curve: DsMotion.standard,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
          decoration: BoxDecoration(
            color: selected && enabled ? c.brandSoft : c.surfaceAlt,
            borderRadius: DsRadius.brMd,
            border: Border.all(color: selected && enabled ? c.brand : c.border, width: selected && enabled ? 1.6 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const DsGap(DsSpace.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSm.withColor(fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
