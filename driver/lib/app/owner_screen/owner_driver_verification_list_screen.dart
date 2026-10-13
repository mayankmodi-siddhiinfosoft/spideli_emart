import 'dart:async';

import 'package:driver/app/verification_screen/document_status_widgets.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/services/driver_document_status_service.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'owner_driver_verification_screen.dart';

/// The company owner's drivers with the overall status of their documents
/// ([DriverDocumentStatus.overall]: not submitted / pending / action
/// required / verified), counts per status and a filter. Live: the owner's
/// drivers (`users` where `ownerId` == owner) and each driver's
/// `users/{id}` + `documents_verify/{id}` are followed, so a review or an
/// upload shows at once. Only the owner's own company drivers are listed.
class OwnerDriverVerificationListScreen extends StatefulWidget {
  const OwnerDriverVerificationListScreen({super.key});

  @override
  State<OwnerDriverVerificationListScreen> createState() => _OwnerDriverVerificationListScreenState();
}

class _OwnerDriverVerificationListScreenState extends State<OwnerDriverVerificationListScreen> {
  final String _ownerUid = FireStoreUtils.getCurrentUid();

  /// Filter: null = all drivers.
  DocumentOverallStatus? _filter;

  List<UserModel> _drivers = [];
  final Map<String, DriverDocumentsView> _views = {};
  final Map<String, StreamSubscription<DriverDocumentsView>> _subs = {};
  final Set<String> _failed = {};
  StreamSubscription? _driversSub;
  bool _isLoading = true;

  /// The driver list could not be read: nothing is guessed, the screen
  /// offers a retry.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _driversSub?.cancel();
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  void _listen() {
    _driversSub?.cancel();
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _driversSub = FireStoreUtils.fireStore.collection(CollectionName.users).where('ownerId', isEqualTo: _ownerUid).snapshots().listen(
      (snap) {
        final drivers = snap.docs
            .map((d) => UserModel.fromJson({...d.data(), 'id': d.id}))
            .where((d) => OwnerVerificationRules.isOwnersDriver(d, _ownerUid))
            .toList()
          ..sort((a, b) => a.fullName().toLowerCase().compareTo(b.fullName().toLowerCase()));
        final Set<String> ids = drivers.map((d) => d.id!).toSet();
        for (final String gone in _subs.keys.where((id) => !ids.contains(id)).toList()) {
          _subs.remove(gone)?.cancel();
          _views.remove(gone);
        }
        for (final String id in ids) {
          _subs[id] ??= DriverDocumentStatusService.watch(id).listen(
            (view) {
              if (!mounted) return;
              setState(() {
                _views[id] = view;
                _failed.remove(id);
              });
            },
            onError: (Object e) {
              debugPrint('Documents of $id not loaded: $e');
              if (mounted) setState(() => _failed.add(id));
            },
          );
        }
        if (!mounted) return;
        setState(() {
          _drivers = drivers;
          _isLoading = false;
        });
      },
      onError: (Object e) {
        debugPrint('Error loading fleet drivers: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadFailed = true;
          });
        }
      },
    );
  }

  void _retry() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _views.clear();
    _failed.clear();
    _listen();
  }

  /// The driver's status; null while its documents are loading.
  DocumentOverallStatus? _statusOf(UserModel driver) => _views[driver.id]?.overall;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    if (_isLoading) {
      return Scaffold(
        appBar: DsAppBar(title: 'Driver Document Verification'.tr),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadFailed) {
      return Scaffold(
        appBar: DsAppBar(title: 'Driver Document Verification'.tr),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DsSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('The documents could not be loaded. Please try again.'.tr, style: t.bodySecondary, textAlign: TextAlign.center),
                const DsGap(DsSpace.md),
                DsButton.primary(label: 'Retry'.tr, icon: Icons.refresh_rounded, size: DsButtonSize.sm, onPressed: _retry),
              ],
            ),
          ),
        ),
      );
    }

    final Map<DocumentOverallStatus, int> counts = DriverDocumentStatus.counts(_drivers.map(_statusOf).whereType<DocumentOverallStatus>());
    final List<UserModel> shown = _filter == null ? _drivers : _drivers.where((d) => _statusOf(d) == _filter).toList();

    return Scaffold(
      appBar: DsAppBar(
        title: 'Driver Document Verification'.tr,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'.tr, onPressed: _retry),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
              child: DsCard(
                color: c.surface,
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fleet Verification Overview'.tr, style: t.overline),
                    const DsGap(DsSpace.xs),
                    Text('${_drivers.length} ${'Company Drivers'.tr}', style: t.headline),
                    const DsGap(DsSpace.lg),
                    Row(
                      children: [
                        for (final s in const [DocumentOverallStatus.pending, DocumentOverallStatus.actionRequired, DocumentOverallStatus.verified, DocumentOverallStatus.notSubmitted]) ...[
                          if (s != DocumentOverallStatus.pending) const DsGap(DsSpace.sm),
                          Expanded(child: _statTile(s.label.tr, counts[s].toString(), c.tone(overallStatusTone(s)).main)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
              child: Row(
                children: [
                  _filterChip(null, '${'All'.tr} (${_drivers.length})'),
                  for (final s in DocumentOverallStatus.values) ...[
                    const DsGap(DsSpace.sm),
                    _filterChip(s, '${s.label.tr} (${counts[s]})'),
                  ],
                ],
              ),
            ),
          ),
          if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No company drivers in this category.'.tr, style: t.bodySecondary)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xl),
              sliver: SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) => _driverCard(shown[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(DocumentOverallStatus? status, String label) {
    return ChoiceChip(
      key: ValueKey('owner-documents-filter-${status?.key ?? 'all'}'),
      label: Text(label),
      selected: _filter == status,
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(color: context.dsColors.surfaceAlt, borderRadius: DsRadius.brSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.dsText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const DsGap(DsSpace.xxs),
          Text(value, style: context.dsText.titleSm.w700.withColor(color)),
        ],
      ),
    );
  }

  Widget _driverCard(UserModel driver) {
    final DriverDocumentsView? view = _views[driver.id];
    final DocumentOverallStatus? status = view?.overall;
    final bool failed = _failed.contains(driver.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        borderColor: status == DocumentOverallStatus.actionRequired ? context.dsColors.danger : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DsAvatar(imageUrl: driver.profilePictureURL ?? '', name: driver.fullName(), size: 44),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName(), style: context.dsText.titleSm.w700),
                      Text('${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}', style: context.dsText.bodySm),
                    ],
                  ),
                ),
                if (status != null)
                  DocumentOverallStatusChip(status: status)
                else if (failed)
                  DsBadge(label: 'Not loaded'.tr, tone: DsTone.neutral, small: true)
                else
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const DsDivider(spacing: DsSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    view == null
                        ? ''
                        : 'Required documents: @uploaded of @count uploaded'.trParams({
                            'uploaded': view.uploadedCount.toString(),
                            'count': view.required.length.toString(),
                          }),
                    style: context.dsText.caption,
                  ),
                ),
                const DsGap(DsSpace.sm),
                DsButton.primary(
                  label: 'Review Documents'.tr,
                  icon: Icons.assignment_turned_in_outlined,
                  size: DsButtonSize.sm,
                  onPressed: () => Get.to(() => OwnerDriverVerificationScreen(driver: driver)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
