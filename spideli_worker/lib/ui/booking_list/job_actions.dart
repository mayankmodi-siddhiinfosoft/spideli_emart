import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/send_notification.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';

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

    // Completion proof (spec 11 "Complete (photos, signature)"): photos and
    // the customer's signature, both optional.
    final CompleteJobResult? proof = await Navigator.of(Get.context!).push<CompleteJobResult>(MaterialPageRoute(builder: (context) => const CompleteJobScreen()));
    if (proof == null) return;
    final List<File> photos = proof.photos;

    ShowToastDialog.showLoader('Please wait...'.tr);
    try {
      final List<String> urls = [];
      for (final file in photos) {
        urls.add(await FireStoreUtils.uploadCompletionPhoto(file, order.id));
      }
      String? signatureUrl;
      if (proof.signaturePng != null) {
        signatureUrl = await FireStoreUtils.uploadCompletionSignature(proof.signaturePng!, order.id);
      }
      order.status = ORDER_STATUS_COMPLETED;
      // Complete first, then pay: if anything after this fails, a retry can't
      // pay the provider again (the credit below is claimed once per booking).
      await FireStoreUtils.updateOrderFields(order.id, {
        'status': ORDER_STATUS_COMPLETED,
        if (urls.isNotEmpty) 'completionPhotos': FieldValue.arrayUnion(urls),
        'completionSignature': ?signatureUrl,
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

/// What the worker attached on "Complete".
class CompleteJobResult {
  final List<File> photos;
  final Uint8List? signaturePng;

  const CompleteJobResult(this.photos, this.signaturePng);
}

/// Last step of "Complete": optional photos of the finished work and an
/// optional customer signature. Pops with a [CompleteJobResult], or null when
/// the worker goes back.
///
/// Design: archetype L ("proof of completion"). A two-step [DsStepper] heads
/// two sections — an adaptive photo grid with a dashed "Add photo" tile and a
/// framed signature pad (deliberately white, because the exported PNG has a
/// white background) — and "Complete" sits in a [DsStickyBar].
class CompleteJobScreen extends StatefulWidget {
  const CompleteJobScreen({super.key});

  @override
  State<CompleteJobScreen> createState() => _CompleteJobScreenState();
}

class _CompleteJobScreenState extends State<CompleteJobScreen> {
  static const int maxPhotos = 6;
  final ImagePicker _picker = ImagePicker();
  final List<File> _photos = [];
  final SignatureController _signature = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    Uint8List? png;
    if (_signature.isNotEmpty) png = await _signature.toPngBytes();
    if (!mounted) return;
    Navigator.pop(context, CompleteJobResult(List<File>.from(_photos), png));
  }

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
    // Subscribes the screen to theme changes.
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    return DsScaffold(
      title: "Complete job".tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
        children: DsFadeSlideIn.stagger([
          DsStepper(steps: ['Photos'.tr, 'Signature'.tr], current: _photos.isEmpty ? 0 : 1),
          const DsGap(DsSpace.xl),
          DsFormSection(
            title: "Completion photos".tr,
            icon: Icons.photo_camera_outlined,
            children: [
              Text("Add photos of the completed work (optional).".tr, style: t.bodySecondary),
              const DsGap(DsSpace.lg),
              GridView.count(
                crossAxisCount: l.value(phone: 3, tablet: 4, desktop: 5),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: DsSpace.md,
                crossAxisSpacing: DsSpace.md,
                children: [
                  ..._photos.asMap().entries.map((entry) => Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(borderRadius: DsRadius.brMd, child: Image.file(entry.value, fit: BoxFit.cover)),
                          PositionedDirectional(
                            end: 0,
                            top: 0,
                            child: DsIconButton(
                              icon: Icons.close_rounded,
                              semanticLabel: "Remove".tr,
                              size: 32,
                              variant: DsIconButtonVariant.filled,
                              onPressed: () => setState(() => _photos.removeAt(entry.key)),
                            ),
                          ),
                        ],
                      )),
                  if (_photos.length < maxPhotos)
                      Semantics(
                        button: true,
                        label: "Add photo".tr,
                        child: InkWell(
                          borderRadius: DsRadius.brMd,
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
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              borderRadius: DsRadius.brMd,
                              border: Border.all(color: c.brandMuted),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: c.brandStrong),
                                const DsGap(DsSpace.xs),
                                Text("Add photo".tr, textAlign: TextAlign.center, style: t.labelSm.withColor(c.brandStrong)),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Customer signature (optional)".tr,
            icon: Icons.draw_outlined,
            trailing: DsButton.ghost(label: "Clear".tr, size: DsButtonSize.sm, onPressed: () => _signature.clear()),
            children: [
              DsCard.outlined(
                padding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                // The pad stays white on purpose: the exported PNG has a white
                // background.
                child: Signature(controller: _signature, height: 180, backgroundColor: Colors.white),
              ),
            ],
          ),
        ]),
      ),
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Complete".tr,
          icon: Icons.check_circle_outline_rounded,
          size: DsButtonSize.lg,
          expand: true,
          color: c.success,
          onPressed: _finish,
        ),
      ),
    );
  }
}
