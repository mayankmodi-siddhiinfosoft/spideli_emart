import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/ui/documents/document_upload_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';

Color verificationStatusColor(VerificationStatus status) {
  switch (status) {
    case VerificationStatus.approved:
      return Colors.green;
    case VerificationStatus.pending:
      return Colors.orange;
    case VerificationStatus.rejected:
    case VerificationStatus.expired:
      return AppColors.colorDeepOrange;
    case VerificationStatus.notSubmitted:
      return Colors.grey;
  }
}

class VerificationStatusChip extends StatelessWidget {
  final VerificationStatus status;

  const VerificationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = verificationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(status.label.tr, style: TextStyle(color: color, fontFamily: AppColors.medium, fontSize: 13)),
    );
  }
}

/// Spec 11 "Documents": each required document with its status, the
/// rejection reason, the expiry date, and upload / re-upload.
class DocumentsScreen extends StatelessWidget {
  final bool isBack;

  const DocumentsScreen({super.key, this.isBack = false});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final bool dark = themeChange.getTheme();
    final VerificationController controller = Get.find<VerificationController>();
    return Scaffold(
      backgroundColor: dark ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
      appBar: CommonUI.customAppBar(
        context,
        title: Text("Documents".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold)),
        isBack: isBack,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator(color: AppColors.colorPrimary));
        }
        final overall = controller.overallStatus;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VerificationSummaryCard(status: overall, required: controller.verificationRequired.value, dark: dark),
              const SizedBox(height: 16),
              ...controller.documentTypes.map((type) {
                final uploaded = controller.uploaded.value?.documentFor(type.id);
                final status = controller.statusOf(type);
                final bool canUpload = status == VerificationStatus.notSubmitted || status == VerificationStatus.rejected || status == VerificationStatus.expired;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    onTap: () => Get.to(() => DocumentUploadScreen(documentType: type, existing: uploaded, readOnly: !canUpload)),
                    title: Text((type.title ?? '').tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.semiBold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        VerificationStatusChip(status: status),
                        if (status == VerificationStatus.rejected && (uploaded?.rejectionReason ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text("${"Reason".tr}: ${uploaded!.rejectionReason}", style: const TextStyle(color: AppColors.colorDeepOrange)),
                          ),
                        if (uploaded?.expiryDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text("${"Expires on".tr}: ${DateFormat('dd MMM yyyy').format(uploaded!.expiryDate!.toDate())}"),
                          ),
                      ],
                    ),
                    trailing: Text(
                      canUpload ? (status == VerificationStatus.notSubmitted ? "Upload".tr : "Re-upload".tr) : "View".tr,
                      style: TextStyle(color: AppColors.colorPrimary, fontFamily: AppColors.semiBold),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}

class VerificationSummaryCard extends StatelessWidget {
  final VerificationStatus status;
  final bool required;
  final bool dark;

  const VerificationSummaryCard({super.key, required this.status, required this.required, required this.dark});

  String get _message {
    switch (status) {
      case VerificationStatus.approved:
        return "Your documents are approved. You can receive jobs.";
      case VerificationStatus.pending:
        return "Your documents are pending review by the administrator.";
      case VerificationStatus.rejected:
        return "A document was rejected. Please check the reason and upload it again.";
      case VerificationStatus.expired:
        return "A document has expired. Please upload a valid one.";
      case VerificationStatus.notSubmitted:
        return "Please upload your documents for verification.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = verificationStatusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Verification status".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.semiBold, fontSize: 16)),
              const Spacer(),
              VerificationStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(_message.tr, style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
          if (required && status != VerificationStatus.approved)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("You will not receive jobs until your documents are approved.".tr, style: const TextStyle(color: AppColors.colorDeepOrange)),
            ),
        ],
      ),
    );
  }
}
