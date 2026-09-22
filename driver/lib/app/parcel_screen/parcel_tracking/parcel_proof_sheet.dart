import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Delivery proof for a home delivery (spec 9 "Proof (OTP / photo / scan)"): the receiver's code or a photo.
/// Returns the `deliveryProof` map, or null when the driver cancels.
Future<Map<String, dynamic>?> showParcelProofSheet(BuildContext context, ParcelOrderModel order, {required bool isDark}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ParcelProofSheet(order: order, isDark: isDark),
    ),
  );
}

class _ParcelProofSheet extends StatefulWidget {
  final ParcelOrderModel order;
  final bool isDark;

  const _ParcelProofSheet({required this.order, required this.isDark});

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
    final isDark = widget.isDark;
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Proof of delivery".tr, style: TextStyle(fontSize: 18, fontFamily: AppThemeData.semiBold, color: textColor)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'otp', label: Text("Receiver code".tr), enabled: _receiverCode != null),
                ButtonSegment(value: 'photo', label: Text("Photo".tr)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            if (_type == 'otp')
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(labelText: "Code given by the receiver".tr, border: const OutlineInputBorder()),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_receiverCode == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text("This parcel has no receiver code; take a photo of the delivered parcel.".tr,
                          style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600)),
                    ),
                  if (_photo != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover)),
                  TextButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera_outlined), label: Text(_photo == null ? "Take photo".tr : "Retake photo".tr)),
                ],
              ),
            const SizedBox(height: 12),
            RoundedButtonFill(
              title: "Confirm delivery".tr,
              height: 5.5,
              color: AppThemeData.success400,
              textColor: AppThemeData.grey50,
              onPress: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}
