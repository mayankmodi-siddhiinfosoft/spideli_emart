import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliworker/controller/dashboard_controller.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/documents/documents_screen.dart';

/// Whether the dashboard shows the verification notice: once the state is
/// known, while the jobs gate is closed and the documents are not Verified
/// (verification off, or nothing to upload: the gate is open, no notice).
bool showVerificationNotice({required bool loading, required bool canReceiveJobs, required WorkerOverallStatus status}) =>
    !loading && !canReceiveJobs && status != WorkerOverallStatus.verified;

/// The button of the notice (a translation key): upload when nothing was
/// sent, re-upload when a document was rejected or expired, otherwise view.
String verificationNoticeAction(WorkerOverallStatus status) {
  switch (status) {
    case WorkerOverallStatus.notSubmitted:
      return "Upload documents";
    case WorkerOverallStatus.actionRequired:
      return "Re-upload documents";
    case WorkerOverallStatus.pending:
    case WorkerOverallStatus.verified:
      return "View documents";
  }
}

/// The dashboard's "documents not verified" notice: the overall status, why
/// no jobs arrive, and a button to the Documents tab. Live: it follows the
/// [VerificationController] and hides itself once the worker is Verified.
class VerificationNoticeBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const VerificationNoticeBanner({super.key, this.padding = EdgeInsets.zero});

  /// The Documents tab of the dashboard, or the Documents screen when this
  /// banner is shown outside it.
  static void openDocuments() {
    if (Get.isRegistered<DashBoardController>()) {
      Get.find<DashBoardController>().onItemTapped(1);
    } else {
      Get.to(() => const DocumentsScreen(isBack: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final VerificationController verification = VerificationController.ensure();
    return Obx(() {
      final WorkerOverallStatus status = verification.overallStatus;
      final bool show = showVerificationNotice(loading: verification.isLoading.value, canReceiveJobs: verification.canReceiveJobs, status: status);
      return AnimatedSize(
        duration: DsMotion.of(context, DsMotion.base),
        curve: DsMotion.standard,
        alignment: Alignment.topCenter,
        child: show ? Padding(padding: padding, child: DsFadeSlideIn(child: _card(context, status))) : const SizedBox(width: double.infinity),
      );
    });
  }

  Widget _card(BuildContext context, WorkerOverallStatus status) {
    final c = context.dsColors;
    final t = context.dsText;
    final DsTone tone = overallStatusTone(status);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DsCard.tinted(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIconWell(icon: overallStatusIcon(status), tone: tone, size: 40, circle: true),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text("Document verification".tr, style: t.titleSm)),
                          DsBadge(label: status.label.tr, tone: tone, small: true),
                        ],
                      ),
                      const DsGap(DsSpace.xs),
                      Text(overallStatusMessage(status).tr, style: t.bodySecondary),
                      const DsGap(DsSpace.xs),
                      Text("You will not receive jobs until your documents are approved.".tr, style: t.bodySm.withColor(c.dangerStrong)),
                    ],
                  ),
                ),
              ],
            ),
            const DsGap(DsSpace.md),
            DsButton.primary(
              label: verificationNoticeAction(status).tr,
              icon: status == WorkerOverallStatus.pending ? Icons.badge_outlined : Icons.upload_file_rounded,
              expand: true,
              onPressed: openDocuments,
            ),
          ],
        ),
      ),
    );
  }
}
