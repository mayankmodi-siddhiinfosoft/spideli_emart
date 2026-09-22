import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/send_notification.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';

/// Job status flow (spec 11), shared by the job list and the job detail:
/// Assigned ("Order Assigned" / "Order Accepted") -> Start -> In progress
/// ("Order Ongoing") -> [Stop Time for hourly jobs] -> Complete (OTP, photos)
/// -> Completed ("Order Completed"). These are the status strings the
/// Provider and Customer apps already use; no new status is introduced.
///
/// Every write is a targeted update of the changed fields only
/// (FireStoreUtils.updateOrderFields), so `regionId` and panel fields survive.
class JobActions {
  JobActions._();

  static bool _verifiedOrWarn() {
    if (Get.isRegistered<VerificationController>() && !Get.find<VerificationController>().canReceiveJobs) {
      ShowToastDialog.showToast("Your documents must be approved before you can work on jobs.".tr);
      return false;
    }
    return true;
  }

  static Map<String, dynamic> _payload(OnProviderOrderModel order) => <String, dynamic>{"type": "provider_order", "orderId": order.id};

  static Future<void> start(OnProviderOrderModel order) async {
    if (!_verifiedOrWarn()) return;
    final Timestamp schedule = order.newScheduleDateTime ?? order.scheduleDateTime ?? Timestamp.now();
    if (!schedule.toDate().isBefore(DateTime.now())) {
      Get.showSnackbar(GetSnackBar(message: '${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(schedule.toDate())}.', duration: 5.seconds));
      return;
    }
    ShowToastDialog.showLoader('Please wait...'.tr);
    try {
      final Map<String, dynamic> data = {'status': ORDER_STATUS_ONGOING};
      if (order.provider.priceUnit == "Hourly") data['startTime'] = Timestamp.now();
      await FireStoreUtils.updateOrderFields(order.id, data);
      await SendNotification.sendFcmMessage(providerServiceInTransit, order.author.fcmToken, _payload(order));
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  /// Hourly jobs: stop the clock; the customer then pays the final amount.
  static Future<void> stopTime(OnProviderOrderModel order) async {
    ShowToastDialog.showLoader('Please wait...'.tr);
    try {
      final Timestamp end = Timestamp.now();
      final DateTime start = (order.startTime ?? end).toDate();
      final int minutes = end.toDate().difference(start).inMinutes;
      final double quantity = minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
      await FireStoreUtils.updateOrderFields(order.id, {'endTime': end, 'paymentStatus': false, 'quantity': quantity});
      await SendNotification.sendFcmMessage(providerStopTime, order.author.fcmToken, _payload(order));
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  static Future<void> complete(OnProviderOrderModel order) async {
    if (order.extraPaymentStatus == false || (order.paymentStatus == false && order.payment_method != "cod")) {
      ShowToastDialog.showToast('Payment is pending.'.tr);
      return;
    }
    final isComplete = await Navigator.of(Get.context!).push(MaterialPageRoute(builder: (context) => VerifyOtpScreen(otp: order.otp)));
    if (isComplete != true) return;

    // Completion proof: photos (optional). No signature capture -- no
    // signature package is a dependency of this app.
    final List<File>? photos = await Navigator.of(Get.context!).push<List<File>>(MaterialPageRoute(builder: (context) => const CompleteJobScreen()));
    if (photos == null) return;

    ShowToastDialog.showLoader('Please wait...'.tr);
    try {
      final List<String> urls = [];
      for (final file in photos) {
        urls.add(await FireStoreUtils.uploadCompletionPhoto(file, order.id));
      }
      order.status = ORDER_STATUS_COMPLETED;
      // Complete first, then pay: if anything after this fails, a retry can't
      // pay the provider again (the credit below is claimed once per booking).
      await FireStoreUtils.updateOrderFields(order.id, {
        'status': ORDER_STATUS_COMPLETED,
        if (urls.isNotEmpty) 'completionPhotos': FieldValue.arrayUnion(urls),
      });
      if (order.provider.priceUnit != "Fixed") {
        await FireStoreUtils.providerWalletSet(order, true);
      }
      try {
        await FireStoreUtils.getFirestOrderOrNOt(order).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateReferralAmount(order);
          }
        });
      } catch (e) {
        // The referral bonus must never block or repeat the completion.
        debugPrint('JobActions.complete: referral credit skipped: $e');
      }
      await SendNotification.sendFcmMessage(providerServiceCompleted, order.author.fcmToken, _payload(order));
    } catch (e) {
      ShowToastDialog.showToast("Something went wrong, please try again.".tr);
    } finally {
      ShowToastDialog.closeLoader();
    }
  }
}

/// Last step of "Complete": optional photos of the finished work. Pops with
/// the picked files (possibly empty), or null when the worker goes back.
class CompleteJobScreen extends StatefulWidget {
  const CompleteJobScreen({super.key});

  @override
  State<CompleteJobScreen> createState() => _CompleteJobScreenState();
}

class _CompleteJobScreenState extends State<CompleteJobScreen> {
  static const int maxPhotos = 6;
  final ImagePicker _picker = ImagePicker();
  final List<File> _photos = [];

  Future<void> _add(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image != null) setState(() => _photos.add(File(image.path)));
    } catch (e) {
      ShowToastDialog.showToast("Could not open the camera or gallery. Please check the permission.".tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Provider.of<DarkThemeProvider>(context).getTheme();
    return Scaffold(
      backgroundColor: dark ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
      appBar: CommonUI.customAppBar(
        context,
        title: Text("Complete job".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Add photos of the completed work (optional).".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              ..._photos.asMap().entries.map((entry) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(entry.value, fit: BoxFit.cover)),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () => setState(() => _photos.removeAt(entry.key)),
                          child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                        ),
                      ),
                    ],
                  )),
              if (_photos.length < maxPhotos)
                InkWell(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Wrap(children: [
                        ListTile(
                            leading: const Icon(Icons.photo_camera),
                            title: Text("Take a picture".tr),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _add(ImageSource.camera);
                            }),
                        ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: Text("Choose Image From Gallery".tr),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _add(ImageSource.gallery);
                            }),
                      ]),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorPrimary, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, List<File>.from(_photos)),
            child: Text("Complete".tr, style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold)),
          ),
        ),
      ),
    );
  }
}
