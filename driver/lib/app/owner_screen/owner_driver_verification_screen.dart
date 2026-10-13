import 'dart:async';

import 'package:driver/app/verification_screen/document_status_widgets.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/services/driver_document_status_service.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/services/owner_verification_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The company owner reviews ONE of its own drivers' documents: each
/// required document (`driver`, plus `vehicle` for a cab / rental driver)
/// with its file(s), status and Approve / Reject (reason mandatory), and the
/// driver's overall status ([DriverDocumentStatus.overall]). Live: the
/// driver's `users/{id}` and `documents_verify/{id}` are followed.
class OwnerDriverVerificationScreen extends StatefulWidget {
  final UserModel driver;

  const OwnerDriverVerificationScreen({super.key, required this.driver});

  @override
  State<OwnerDriverVerificationScreen> createState() => _OwnerDriverVerificationScreenState();
}

class _OwnerDriverVerificationScreenState extends State<OwnerDriverVerificationScreen> {
  late UserModel _driver;
  List<DocumentModel> _requiredDocs = [];
  List<Documents> _entries = const [];
  DocumentOverallStatus _overall = DocumentOverallStatus.notSubmitted;

  /// `documents_verify/{id}` belongs to another holder type (a worker's):
  /// shown as nothing uploaded, never reviewed.
  bool _foreignRecord = false;
  StreamSubscription<DriverDocumentsView>? _sub;
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Checks the driver is one of the owner's, then follows its documents.
  Future<void> _loadData() async {
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final UserModel? live = await OwnerVerificationService.getOwnDriver(_driver.id ?? '');
      if (live == null) {
        _notOwnDriver = true;
        _requiredDocs = [];
        _entries = const [];
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _notOwnDriver = false;
      _driver = live;
    } catch (e) {
      debugPrint('Error loading driver documents: $e');
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
      return;
    }
    final String ownerUid = FireStoreUtils.getCurrentUid();
    _sub = DriverDocumentStatusService.watch(_driver.id ?? '').listen(
      (view) {
        if (!mounted) return;
        setState(() {
          final UserModel? user = view.user;
          // Moved to another company (or deleted) meanwhile: nothing to review.
          _notOwnDriver = user == null || !OwnerVerificationRules.isOwnersDriver(user, ownerUid);
          if (user != null) _driver = user;
          _requiredDocs = _notOwnDriver ? [] : view.required;
          _entries = _notOwnDriver ? const [] : view.docs;
          _overall = view.overall;
          _foreignRecord = view.foreignRecord;
          _loadFailed = false;
          _isLoading = false;
        });
      },
      onError: (Object e) {
        debugPrint('Error loading driver documents: $e');
        if (mounted) {
          setState(() {
            _loadFailed = true;
            _isLoading = false;
          });
        }
      },
    );
  }

  Documents? _getDocSubmission(String docId) => OwnerVerificationRules.entryFor(_entries, docId);

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
                            DocumentOverallStatusChip(status: _overall, small: false),
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
                  if (_foreignRecord) ...[
                    const DsGap(DsSpace.md),
                    DsInlineAlert(tone: DsTone.warning, message: 'These documents belong to another account type and cannot be reviewed here.'.tr),
                  ],
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

    final String status = DriverDocumentStatus.entryStatus(submission);
    final bool canApprove = !_foreignRecord && OwnerVerificationRules.canApprove(submission);
    final bool canReject = !_foreignRecord && OwnerVerificationRules.canReject(submission);
    final bool isApproved = status == DocumentEntryStatus.approved;
    final bool isRejected = status == DocumentEntryStatus.rejected;
    final DsTone statusTone = entryStatusTone(status);

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
                      const DsGap(DsSpace.xxs),
                      DocumentTypeBadge(type: reqDoc.type),
                      if (submission?.expiryDate != null)
                        Text(
                          '${'Expires:'.tr} ${DateFormat('dd MMM yyyy').format(submission!.expiryDate!.toDate())}',
                          style: t.caption,
                        ),
                    ],
                  ),
                ),
                DocumentEntryStatusChip(status: status),
              ],
            ),
            if (isRejected && (submission?.rejectReason ?? '').isNotEmpty) ...[
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
                        'Rejection reason: @reason'.trParams({'reason': submission?.rejectReason ?? ''}),
                        style: t.caption.withColor(c.dangerStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const DsGap(DsSpace.md),
            // The uploaded file(s): a tap opens them full screen.
            DocumentFilesRow(
              frontImage: submission?.frontImage,
              backImage: submission?.backImage,
              frontSide: reqDoc.frontSide == true,
              backSide: reqDoc.backSide == true,
              title: reqDoc.title ?? '',
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
}
