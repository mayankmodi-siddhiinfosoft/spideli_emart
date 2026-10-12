import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/user_model.dart';
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
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    try {
      final snap = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .where('ownerId', isEqualTo: _ownerUid)
          .get();

      final drivers = snap.docs.map((d) => UserModel.fromJson(d.data())).toList();

      final Map<String, DriverDocumentModel?> docsMap = {};
      for (final driver in drivers) {
        if ((driver.id ?? '').isNotEmpty) {
          final docs = await OwnerVerificationService.getDriverDocuments(driver.id!);
          docsMap[driver.id!] = docs;
        }
      }

      _drivers = drivers;
      _driverDocsMap = docsMap;
    } catch (e) {
      debugPrint('Error loading fleet drivers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _driverStatusCategory(UserModel driver) {
    if (driver.isDocumentVerify == true) return 'verified';

    final docs = _driverDocsMap[driver.id]?.documents ?? [];
    if (docs.isEmpty) return 'not_submitted';

    final hasRejected = docs.any((d) => d.verificationStatus == 'rejected');
    if (hasRejected) return 'rejected';

    final hasPending = docs.any((d) => d.verificationStatus == 'pending');
    if (hasPending) return 'pending';

    return 'pending';
  }

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

    final pendingDrivers = _drivers.where((d) => _driverStatusCategory(d) == 'pending').toList();
    final verifiedDrivers = _drivers.where((d) => _driverStatusCategory(d) == 'verified').toList();
    final rejectedDrivers = _drivers.where((d) => _driverStatusCategory(d) == 'rejected' || _driverStatusCategory(d) == 'not_submitted').toList();

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
        final docs = _driverDocsMap[driver.id]?.documents ?? [];

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
                    Text(
                      '${docs.length} ${'Documents Submitted'.tr}',
                      style: context.dsText.caption,
                    ),
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
