import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/owner_verification_rules.dart';
import 'package:driver/services/owner_verification_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'owner_driver_verification_screen.dart';

class OwnerDriverVerificationListScreen extends StatefulWidget {
  const OwnerDriverVerificationListScreen({super.key});

  @override
  State<OwnerDriverVerificationListScreen> createState() => _OwnerDriverVerificationListScreenState();
}

class _OwnerDriverVerificationListScreenState extends State<OwnerDriverVerificationListScreen> with SingleTickerProviderStateMixin {
  final String _ownerUid = FireStoreUtils.getCurrentUid();
  late TabController _tabController;

  List<UserModel> _drivers = [];
  Map<String, DriverDocumentModel?> _driverDocsMap = {};

  /// Each driver's required documents: what the driver app asks THAT driver
  /// to upload (`driver`, plus `vehicle` for cab / rental drivers).
  Map<String, List<DocumentModel>> _requiredMap = {};
  bool _isLoading = true;

  /// A read failed: nothing is guessed, the screen offers a retry.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFleetDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFleetDrivers() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final snap = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .where('ownerId', isEqualTo: _ownerUid)
          .get();

      final drivers = snap.docs
          .map((d) => UserModel.fromJson({...d.data(), 'id': d.id}))
          .where((d) => OwnerVerificationRules.isOwnersDriver(d, _ownerUid))
          .toList();

      final Map<String, DriverDocumentModel?> docsMap = {};
      final Map<String, List<DocumentModel>> requiredMap = {};
      // One read per distinct set of document types, not per driver.
      final Map<String, List<DocumentModel>> byTypes = {};
      for (final driver in drivers) {
        final String id = driver.id!;
        docsMap[id] = await OwnerVerificationService.getDriverDocuments(id);
        final String key = FireStoreUtils.documentTypesFor(driver).join(',');
        requiredMap[id] = byTypes[key] ??= await OwnerVerificationService.getRequiredDocuments(driver);
      }

      _drivers = drivers;
      _driverDocsMap = docsMap;
      _requiredMap = requiredMap;
    } catch (e) {
      debugPrint('Error loading fleet drivers: $e');
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DocumentModel> _requiredFor(UserModel driver) => _requiredMap[driver.id] ?? const [];

  List<Documents> _entriesFor(UserModel driver) => _driverDocsMap[driver.id]?.documents ?? const [];

  String _driverStatusCategory(UserModel driver) => OwnerVerificationRules.category(driver, _requiredFor(driver), _entriesFor(driver));

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
                DsButton.primary(label: 'Retry'.tr, icon: Icons.refresh_rounded, size: DsButtonSize.sm, onPressed: _loadFleetDrivers),
              ],
            ),
          ),
        ),
      );
    }

    final pendingDrivers = _drivers.where((d) => _driverStatusCategory(d) == 'pending').toList();
    final verifiedDrivers = _drivers.where((d) => _driverStatusCategory(d) == 'verified').toList();
    final rejectedDrivers = _drivers.where((d) => const {'rejected', 'missing', 'not_submitted'}.contains(_driverStatusCategory(d))).toList();

    return Scaffold(
      appBar: DsAppBar(
        title: 'Driver Document Verification'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh'.tr,
            onPressed: _loadFleetDrivers,
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats Card
                    DsCard(
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
                              Expanded(
                                child: _statTile('Pending Review'.tr, pendingDrivers.length.toString(), c.warning),
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: _statTile('Verified'.tr, verifiedDrivers.length.toString(), c.success),
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: _statTile('Action Required'.tr, rejectedDrivers.length.toString(), c.danger),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    TabBar(
                      controller: _tabController,
                      labelColor: c.brand,
                      unselectedLabelColor: c.textSecondary,
                      indicatorColor: c.brand,
                      tabs: [
                        Tab(text: '${'Pending'.tr} (${pendingDrivers.length})'),
                        Tab(text: '${'Verified'.tr} (${verifiedDrivers.length})'),
                        Tab(text: '${'Incomplete'.tr} (${rejectedDrivers.length})'),
                        Tab(text: '${'All'.tr} (${_drivers.length})'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDriverList(pendingDrivers),
            _buildDriverList(verifiedDrivers),
            _buildDriverList(rejectedDrivers),
            _buildDriverList(_drivers),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(
        color: context.dsColors.surfaceAlt,
        borderRadius: DsRadius.brSm,
      ),
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

  Widget _buildDriverList(List<UserModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('No company drivers in this category.'.tr, style: context.dsText.bodySecondary),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DsSpace.lg),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final driver = list[index];
        final category = _driverStatusCategory(driver);
        final required = _requiredFor(driver);

        DsTone badgeTone;
        String badgeLabel;
        if (category == 'verified') {
          badgeTone = DsTone.success;
          badgeLabel = 'Verified'.tr;
        } else if (category == 'pending') {
          badgeTone = DsTone.warning;
          badgeLabel = 'Pending Review'.tr;
        } else if (category == 'rejected') {
          badgeTone = DsTone.danger;
          badgeLabel = 'Rejected'.tr;
        } else if (category == 'missing') {
          badgeTone = DsTone.warning;
          badgeLabel = 'Documents Missing'.tr;
        } else {
          badgeTone = DsTone.neutral;
          badgeLabel = 'No Documents'.tr;
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
                    DsAvatar(
                      imageUrl: driver.profilePictureURL ?? '',
                      name: driver.fullName(),
                      size: 44,
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.fullName(), style: context.dsText.titleSm.w700),
                          Text(
                            '${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}',
                            style: context.dsText.bodySm,
                          ),
                        ],
                      ),
                    ),
                    DsBadge(label: badgeLabel, tone: badgeTone, small: true),
                  ],
                ),
                const DsDivider(spacing: DsSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Required documents: @uploaded of @count uploaded'.trParams({
                          'uploaded': OwnerVerificationRules.uploadedCount(required, _entriesFor(driver)).toString(),
                          'count': required.length.toString(),
                        }),
                        style: context.dsText.caption,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    DsButton.primary(
                      label: 'Review Documents'.tr,
                      icon: Icons.assignment_turned_in_outlined,
                      size: DsButtonSize.sm,
                      onPressed: () {
                        Get.to(() => OwnerDriverVerificationScreen(driver: driver))?.then((_) {
                          _loadFleetDrivers();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
