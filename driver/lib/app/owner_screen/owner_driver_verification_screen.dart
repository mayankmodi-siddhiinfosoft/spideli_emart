import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/services/owner_verification_service.dart';
import 'package:driver/themes/ds/ds.dart';
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

  /// The required documents or the uploads could not be read: nothing is
  /// guessed, the screen offers a retry.
  bool _loadFailed = false;

  /// Not one of the signed-in owner's company drivers: nothing to review.
  bool _notOwnDriver = false;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final UserModel? live = await OwnerVerificationService.getOwnDriver(_driver.id ?? '');
      if (live == null) {
        _notOwnDriver = true;
        _requiredDocs = [];
        _driverDocs = null;
      } else {
        _notOwnDriver = false;
        _driver = live;
        _requiredDocs = await OwnerVerificationService.getRequiredDocuments(live);
        _driverDocs = await OwnerVerificationService.getDriverDocuments(live.id ?? '');
      }
    } catch (e) {
      debugPrint('Error loading driver documents: $e');
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Documents? _getDocSubmission(String docId) {
    return _driverDocs?.documents?.firstWhereOrNull((d) => d.documentId == docId);
  }

  List<Documents> get _entries => _driverDocs?.documents ?? const [];

  /// Required documents the driver has not uploaded, or must upload again
  /// (rejected / expired): what keeps the account from being verified.
  List<DocumentModel> get _toUpload => _requiredDocs.where((r) {
    final Documents? sub = _getDocSubmission(r.id ?? '');
    return !OwnerVerificationRules.isUploaded(sub) || sub!.verificationStatus == 'rejected' || sub.verificationStatus == 'expired';
  }).toList();

  String _titles(Iterable<String> titles) => titles.where((t) => t.trim().isNotEmpty).join(', ');

  /// Tells the owner what an action did (or why it did nothing).
  void _showResult(OwnerVerificationResult result, {required String doneMessage, required String failedMessage}) {
    switch (result.outcome) {
      case OwnerVerificationOutcome.done:
        ShowToastDialog.showToast(doneMessage);
      case OwnerVerificationOutcome.incomplete:
        Get.dialog(
          AlertDialog(
            title: Text('Driver not verified yet'.tr, style: context.dsText.title),
            content: Text(
              'The uploaded documents were approved. These required documents are still missing or must be uploaded again: @documents'.trParams({'documents': _titles(result.outstanding)}),
              style: context.dsText.bodySm,
            ),
            actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'.tr))],
          ),
        );
      case OwnerVerificationOutcome.notYourDriver:
        ShowToastDialog.showToast('This driver is not part of your company.'.tr);
      case OwnerVerificationOutcome.notUploaded:
        ShowToastDialog.showToast('This document has not been uploaded, or it has expired.'.tr);
      case OwnerVerificationOutcome.noRequiredDocuments:
        ShowToastDialog.showToast('No required driver documents found.'.tr);
      case OwnerVerificationOutcome.failed:
        ShowToastDialog.showToast(failedMessage);
    }
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

  void _showRejectDialog(DocumentModel reqDoc) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('Reject Document'.tr, style: context.dsText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide the reason for rejecting "@document" for @driver:'.trParams({'document': reqDoc.title ?? '', 'driver': _driver.fullName()}), style: context.dsText.bodySm),
            const DsGap(DsSpace.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Rejection Reason (Required)'.tr, hintText: 'e.g. Blurred photo, expired date, details mismatch'.tr, border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel'.tr)),
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
              final result = await OwnerVerificationService.rejectDocument(driverId: _driver.id ?? '', documentId: reqDoc.id ?? '', reason: reason);
              ShowToastDialog.closeLoader();
              _showResult(result, doneMessage: 'Document marked as rejected'.tr, failedMessage: 'Failed to reject document'.tr);
              if (result.written) await _loadData();
            },
            child: Text('Reject'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveDoc(DocumentModel reqDoc) async {
    ShowToastDialog.showLoader('Approving document...'.tr);
    final result = await OwnerVerificationService.approveDocument(driverId: _driver.id ?? '', documentId: reqDoc.id ?? '');
    ShowToastDialog.closeLoader();
    _showResult(
      result,
      doneMessage: result.completed ? 'All driver documents approved! Driver is now verified.'.tr : 'Document approved. All documents must be approved before driver is verified.'.tr,
      failedMessage: 'Failed to approve document'.tr,
    );
    if (result.written) await _loadData();
  }

  void _confirmApproveAll() {
    if (_requiredDocs.isEmpty) {
      ShowToastDialog.showToast('No required driver documents found.'.tr);
      return;
    }
    final List<DocumentModel> toUpload = _toUpload;
    final bool anyToReview = _requiredDocs.any((r) => OwnerVerificationRules.awaitsReview(_getDocSubmission(r.id ?? '')));
    if (toUpload.isNotEmpty && !anyToReview) {
      // Nothing the owner can approve: the driver has to upload first.
      _showResult(
        OwnerVerificationResult(OwnerVerificationOutcome.incomplete, outstanding: toUpload.map((d) => d.title ?? '').toList()),
        doneMessage: '',
        failedMessage: '',
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('Approve All Driver Documents'.tr, style: context.dsText.title),
        content: Text(
          toUpload.isEmpty
              ? 'Approve every uploaded document of @driver? Once all required documents are approved, the driver is verified to take deliveries.'.trParams({'driver': _driver.fullName()})
              : 'Approve the uploaded documents of @driver? These required documents are still missing or must be uploaded again, so the driver will not be verified yet: @documents'.trParams({
                  'driver': _driver.fullName(),
                  'documents': _titles(toUpload.map((d) => d.title ?? '')),
                }),
          style: context.dsText.bodySm,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.dsColors.success),
            onPressed: () async {
              Get.back();
              ShowToastDialog.showLoader('Verifying all driver documents...'.tr);
              final result = await OwnerVerificationService.approveAllDocuments(driverId: _driver.id ?? '');
              ShowToastDialog.closeLoader();
              _showResult(result, doneMessage: 'All documents approved! Driver verified.'.tr, failedMessage: 'Failed to approve documents'.tr);
              if (result.written) await _loadData();
            },
            child: Text('Approve All'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _messageState(String message, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: context.dsText.bodySecondary, textAlign: TextAlign.center),
            if (retry) ...[const DsGap(DsSpace.md), DsButton.primary(label: 'Retry'.tr, icon: Icons.refresh_rounded, size: DsButtonSize.sm, onPressed: _loadData)],
          ],
        ),
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
          : _notOwnDriver
              ? _messageState('This driver is not part of your company.'.tr)
              : _loadFailed
                  ? _messageState('The documents could not be loaded. Please try again.'.tr, retry: true)
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
                            Expanded(
                              child: Text(
                                'Required documents: @uploaded of @count uploaded'.trParams({
                                  'uploaded': OwnerVerificationRules.uploadedCount(_requiredDocs, _entries).toString(),
                                  'count': _requiredDocs.length.toString(),
                                }),
                                style: t.caption,
                              ),
                            ),
                            const DsGap(DsSpace.sm),
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

    final String status = OwnerVerificationRules.isUploaded(submission) || submission?.verificationStatus == 'rejected' ? submission!.verificationStatus : 'not_submitted';
    final bool canApprove = OwnerVerificationRules.canApprove(submission);
    final bool canReject = OwnerVerificationRules.canReject(submission);
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
                        'Rejection reason: @reason'.trParams({'reason': submission.rejectReason ?? ''}),
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
                  onPressed: canReject ? () => _showRejectDialog(reqDoc) : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text('Reject'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: canReject ? c.danger : c.border),
                  ),
                ),
                const DsGap(DsSpace.md),
                ElevatedButton.icon(
                  onPressed: canApprove && !isApproved ? () => _approveDoc(reqDoc) : null,
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
