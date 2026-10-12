import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/owner_verification_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class OwnerDriverVerificationScreen extends StatefulWidget {
  final UserModel driver;

  const OwnerDriverVerificationScreen({super.key, required this.driver});

  @override
  State<OwnerDriverVerificationScreen> createState() => _OwnerDriverVerificationScreenState();
}

class _OwnerDriverVerificationScreenState extends State<OwnerDriverVerificationScreen> {
  late UserModel _driver;
  List<DocumentModel> _requiredDocs = [];
  DriverDocumentModel? _driverDocs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reqDocs = await OwnerVerificationService.getRequiredDocuments();
      final dDocs = await OwnerVerificationService.getDriverDocuments(_driver.id ?? '');
      _requiredDocs = reqDocs;
      _driverDocs = dDocs;
    } catch (e) {
      debugPrint('Error loading driver documents: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Documents? _getDocSubmission(String docId) {
    return _driverDocs?.documents?.firstWhereOrNull((d) => d.documentId == docId);
  }

  void _showImageDialog(String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(DsSpace.md),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DsRadius.md),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(DocumentModel reqDoc, Documents submission) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('Reject Document'.tr, style: context.dsText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'Provide reason for rejecting'.tr} "${reqDoc.title ?? 'Document'}" ${'for driver'.tr} ${_driver.fullName()}:',
              style: context.dsText.bodySm,
            ),
            const DsGap(DsSpace.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Required)'.tr,
                hintText: 'e.g. Blurred photo, expired date, details mismatch',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.dsColors.danger),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ShowToastDialog.showToast('Please enter rejection reason'.tr);
                return;
              }
              Get.back();
              ShowToastDialog.showLoader('Rejecting document...'.tr);
              final success = await OwnerVerificationService.rejectDocument(
                driverId: _driver.id ?? '',
                documentId: reqDoc.id ?? '',
                reason: reason,
                driver: _driver,
              );
              ShowToastDialog.closeLoader();
              if (success) {
                ShowToastDialog.showToast('Document marked as rejected'.tr);
                setState(() => _driver.isDocumentVerify = false);
                await _loadData();
              } else {
                ShowToastDialog.showToast('Failed to reject document'.tr);
              }
            },
            child: Text('Reject'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _approveDoc(DocumentModel reqDoc) async {
    ShowToastDialog.showLoader('Approving document...'.tr);
    final success = await OwnerVerificationService.approveDocument(
      driverId: _driver.id ?? '',
      documentId: reqDoc.id ?? '',
      driver: _driver,
    );
    ShowToastDialog.closeLoader();
    if (success) {
      await _loadData();
      final updatedUser = await FireStoreUtils.getUserProfile(_driver.id ?? '');
      if (updatedUser != null) {
        setState(() => _driver = updatedUser);
        if (_driver.isDocumentVerify == true) {
          ShowToastDialog.showToast('All driver documents approved! Driver is now verified.'.tr);
        } else {
          ShowToastDialog.showToast('Document approved. All documents must be approved before driver is verified.'.tr);
        }
      } else {
        ShowToastDialog.showToast('Document approved'.tr);
      }
    } else {
      ShowToastDialog.showToast('Failed to approve document'.tr);
    }
  }

  void _confirmApproveAll() {
    if (_requiredDocs.isEmpty) {
      ShowToastDialog.showToast('No required driver documents found.'.tr);
      return;
    }

    final int missingCount = _requiredDocs.where((req) {
      final sub = _getDocSubmission(req.id ?? '');
      return (sub?.frontImage ?? '').isEmpty && (sub?.backImage ?? '').isEmpty;
    }).length;

    if (missingCount > 0) {
      ShowToastDialog.showToast(
        'Driver has not uploaded $missingCount required document(s) yet. All documents must be submitted to verify driver.'
            .tr,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('Approve All Driver Documents'.tr, style: context.dsText.title),
        content: Text(
          'Are you sure you want to approve all required driver documents? Once all documents are approved, ${_driver.fullName()} will be verified to take deliveries.'
              .tr,
          style: context.dsText.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.dsColors.success),
            onPressed: () async {
              Get.back();
              ShowToastDialog.showLoader('Verifying all driver documents...'.tr);
              final success = await OwnerVerificationService.approveAllDocuments(
                driverId: _driver.id ?? '',
                requiredDocs: _requiredDocs,
                driver: _driver,
              );
              ShowToastDialog.closeLoader();
              if (success) {
                ShowToastDialog.showToast('All documents approved! Driver verified.'.tr);
                setState(() => _driver.isDocumentVerify = true);
                await _loadData();
              } else {
                ShowToastDialog.showToast('Failed to approve documents'.tr);
              }
            },
            child: Text('Approve All'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    final bool isVerified = _driver.isDocumentVerify == true;

    return Scaffold(
      appBar: DsAppBar(
        title: 'Driver Documents'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh'.tr,
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(DsSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Driver Info Card
                  DsCard(
                    color: c.surface,
                    padding: const EdgeInsets.all(DsSpace.lg),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            DsAvatar(
                              imageUrl: _driver.profilePictureURL ?? '',
                              name: _driver.fullName(),
                              size: 54,
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_driver.fullName(), style: t.titleSm.w700),
                                  const DsGap(DsSpace.xxs),
                                  Text(
                                    '${_driver.countryCode ?? ''} ${_driver.phoneNumber ?? ''}',
                                    style: t.bodySm,
                                  ),
                                  Text(_driver.email ?? '', style: t.caption),
                                ],
                              ),
                            ),
                            DsBadge(
                              label: isVerified ? 'Verified'.tr : 'Unverified'.tr,
                              tone: isVerified ? DsTone.success : DsTone.warning,
                              icon: isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                            ),
                          ],
                        ),
                        const DsDivider(spacing: DsSpace.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Required: ${_requiredDocs.length} ${'Documents'.tr}',
                              style: t.caption,
                            ),
                            DsButton.success(
                              label: 'Approve All'.tr,
                              icon: Icons.done_all_rounded,
                              size: DsButtonSize.sm,
                              onPressed: _confirmApproveAll,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xl),
                  Text('Document Verification Checklist'.tr, style: t.titleSm.w700),
                  const DsGap(DsSpace.sm),
                  if (_requiredDocs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DsSpace.xl),
                        child: Text('No required documents configured by administrator.'.tr, style: t.bodySecondary),
                      ),
                    )
                  else
                    ..._requiredDocs.map((reqDoc) {
                      final submission = _getDocSubmission(reqDoc.id ?? '');
                      return _buildDocumentCard(reqDoc, submission);
                    }),
                  const DsGap(DsSpace.xxl),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentCard(DocumentModel reqDoc, Documents? submission) {
    final c = context.dsColors;
    final t = context.dsText;

    final String status = submission?.verificationStatus ?? 'not_submitted';
    final bool hasFront = (submission?.frontImage ?? '').isNotEmpty;
    final bool hasBack = (submission?.backImage ?? '').isNotEmpty;
    final bool isApproved = status == 'approved';
    final bool isRejected = status == 'rejected';

    DsTone statusTone = DsTone.neutral;
    String statusText = 'Not Submitted'.tr;
    if (status == 'approved') {
      statusTone = DsTone.success;
      statusText = 'Approved'.tr;
    } else if (status == 'pending') {
      statusTone = DsTone.warning;
      statusText = 'Pending Review'.tr;
    } else if (status == 'rejected') {
      statusTone = DsTone.danger;
      statusText = 'Rejected'.tr;
    } else if (status == 'expired') {
      statusTone = DsTone.danger;
      statusText = 'Expired'.tr;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DsIconWell(
                  icon: isApproved
                      ? Icons.check_circle_outline_rounded
                      : (isRejected ? Icons.cancel_outlined : Icons.description_outlined),
                  tone: statusTone,
                  size: 38,
                  circle: true,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reqDoc.title ?? 'Document', style: t.titleSm.w600),
                      if (submission?.expiryDate != null)
                        Text(
                          '${'Expires:'.tr} ${DateFormat('dd MMM yyyy').format(submission!.expiryDate!.toDate())}',
                          style: t.caption,
                        ),
                    ],
                  ),
                ),
                DsBadge(label: statusText, tone: statusTone, small: true),
              ],
            ),
            if (submission?.rejectReason != null && submission!.rejectReason!.isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Container(
                padding: const EdgeInsets.all(DsSpace.sm),
                decoration: BoxDecoration(
                  color: c.dangerSoft,
                  borderRadius: DsRadius.brSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: c.danger),
                    const DsGap(DsSpace.xs),
                    Expanded(
                      child: Text(
                        'Rejection Reason: ${submission.rejectReason}',
                        style: t.caption.withColor(c.dangerStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const DsGap(DsSpace.md),
            // Images section
            Row(
              children: [
                if (reqDoc.frontSide == true)
                  Expanded(
                    child: _imagePreviewBox(
                      label: 'Front Side'.tr,
                      imageUrl: submission?.frontImage,
                      onTap: () => _showImageDialog(submission?.frontImage ?? '', '${reqDoc.title} (Front)'),
                    ),
                  ),
                if (reqDoc.frontSide == true && reqDoc.backSide == true) const DsGap(DsSpace.md),
                if (reqDoc.backSide == true)
                  Expanded(
                    child: _imagePreviewBox(
                      label: 'Back Side'.tr,
                      imageUrl: submission?.backImage,
                      onTap: () => _showImageDialog(submission?.backImage ?? '', '${reqDoc.title} (Back)'),
                    ),
                  ),
              ],
            ),
            const DsDivider(spacing: DsSpace.md),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: submission != null ? () => _showRejectDialog(reqDoc, submission) : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text('Reject'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: submission != null ? c.danger : c.border),
                  ),
                ),
                const DsGap(DsSpace.md),
                ElevatedButton.icon(
                  onPressed: (hasFront || hasBack) ? () => _approveDoc(reqDoc) : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Approve'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreviewBox({required String label, String? imageUrl, required VoidCallback onTap}) {
    final c = context.dsColors;
    final t = context.dsText;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return InkWell(
      onTap: hasImage ? onTap : null,
      borderRadius: DsRadius.brMd,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: DsRadius.brMd,
          border: Border.all(color: c.border),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: DsRadius.brMd,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 30),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(label, style: t.caption.copyWith(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                  const Center(child: Icon(Icons.zoom_in, color: Colors.white70, size: 28)),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file_outlined, color: c.textMuted, size: 24),
                    const DsGap(DsSpace.xxs),
                    Text(label, style: t.caption),
                    Text('No image'.tr, style: t.caption.withColor(c.textMuted)),
                  ],
                ),
              ),
      ),
    );
  }
}
