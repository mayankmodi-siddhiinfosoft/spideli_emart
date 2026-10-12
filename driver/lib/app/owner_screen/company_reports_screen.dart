import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

enum ReportPeriod { daily, monthly, yearly }

class CompanyReportsScreen extends StatefulWidget {
  const CompanyReportsScreen({super.key});

  @override
  State<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends State<CompanyReportsScreen> with SingleTickerProviderStateMixin {
  final String _ownerUid = FireStoreUtils.getCurrentUid();
  late TabController _tabController;

  ReportPeriod _period = ReportPeriod.monthly;
  DateTime _selectedDate = DateTime.now();

  List<UserModel> _companyDrivers = [];
  String? _selectedDriverId; // null = all drivers
  bool _isLoading = true;

  List<ParcelOrderModel> _completedOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load fleet drivers
      final driverSnap = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .where('ownerId', isEqualTo: _ownerUid)
          .get();
      _companyDrivers = driverSnap.docs.map((d) => UserModel.fromJson(d.data())).toList();

      // 2. Load completed parcel orders for company
      await _loadOrders();
    } catch (e) {
      debugPrint('CompanyReportsScreen._loadInitialData error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrders() async {
    final List<ParcelOrderModel> orders = [];
    final Set<String> seenIds = {};

    // Orders where carrierOwnerId == ownerUid
    final carrierQuery = await FireStoreUtils.fireStore
        .collection(CollectionName.parcelOrders)
        .where('carrierOwnerId', isEqualTo: _ownerUid)
        .where('status', isEqualTo: Constant.orderCompleted)
        .get();

    for (final doc in carrierQuery.docs) {
      if (seenIds.add(doc.id)) {
        orders.add(ParcelOrderModel.fromJson(doc.data()));
      }
    }

    // Orders where companyOwnerId == ownerUid
    final companyQuery = await FireStoreUtils.fireStore
        .collection(CollectionName.parcelOrders)
        .where('companyOwnerId', isEqualTo: _ownerUid)
        .where('status', isEqualTo: Constant.orderCompleted)
        .get();

    for (final doc in companyQuery.docs) {
      if (seenIds.add(doc.id)) {
        orders.add(ParcelOrderModel.fromJson(doc.data()));
      }
    }

    // Orders handled by any company driver
    if (_companyDrivers.isNotEmpty) {
      final driverIds = _companyDrivers.map((d) => d.id ?? '').where((id) => id.isNotEmpty).toList();
      for (var i = 0; i < driverIds.length; i += 30) {
        final chunk = driverIds.sublist(i, (i + 30 > driverIds.length) ? driverIds.length : i + 30);
        final driverOrders = await FireStoreUtils.fireStore
            .collection(CollectionName.parcelOrders)
            .where('driverId', whereIn: chunk)
            .where('status', isEqualTo: Constant.orderCompleted)
            .get();
        for (final doc in driverOrders.docs) {
          if (seenIds.add(doc.id)) {
            orders.add(ParcelOrderModel.fromJson(doc.data()));
          }
        }
      }
    }

    _completedOrders = orders;
  }

  bool _matchesDateFilter(ParcelOrderModel o) {
    final Timestamp? ts = o.createdAt;
    if (ts == null) return false;
    final dt = ts.toDate();

    switch (_period) {
      case ReportPeriod.daily:
        return dt.year == _selectedDate.year &&
            dt.month == _selectedDate.month &&
            dt.day == _selectedDate.day;
      case ReportPeriod.monthly:
        return dt.year == _selectedDate.year && dt.month == _selectedDate.month;
      case ReportPeriod.yearly:
        return dt.year == _selectedDate.year;
    }
  }

  List<ParcelOrderModel> get _filteredOrders {
    return _completedOrders.where((o) {
      if (!_matchesDateFilter(o)) return false;
      if (_selectedDriverId != null && _selectedDriverId!.isNotEmpty) {
        return o.driverId == _selectedDriverId;
      }
      return true;
    }).toList();
  }

  void _pickDate() async {
    if (_period == ReportPeriod.daily) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
      }
    } else if (_period == ReportPeriod.monthly) {
      // Pick month/year
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, 1));
      }
    } else {
      // Pick year
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, 1, 1));
      }
    }
  }

  String get _dateLabel {
    switch (_period) {
      case ReportPeriod.daily:
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
      case ReportPeriod.monthly:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case ReportPeriod.yearly:
        return DateFormat('yyyy').format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    if (_isLoading) {
      return Scaffold(
        appBar: DsAppBar(title: 'Revenue & Performance'.tr),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filtered = _filteredOrders;

    // Financial aggregates
    double grossRevenue = 0.0;
    double totalDeliveryCharges = 0.0;
    double totalCommissions = 0.0;
    double totalCodCollected = 0.0;

    for (final o in filtered) {
      final amounts = ParcelAmounts.of(o);
      grossRevenue += amounts.total;
      totalDeliveryCharges += amounts.subTotal + amounts.options;

      final double comm = Constant.calculateAdminCommission(
        amount: (amounts.subTotal - amounts.discount).toString(),
        adminCommissionType: o.adminCommissionType.toString(),
        adminCommission: o.adminCommission ?? '0',
      );
      // Everything the courier does not keep: the commission and the
      // platform's share (platform fee + its taxes, fixed tax, receiver-SMS
      // fee) - exactly what its wallet is debited / not credited.
      totalCommissions += amounts.total - amounts.courierNet(comm);

      if (o.paymentMethod == 'cod') {
        totalCodCollected += amounts.total;
      }
    }

    final double netCompanyRevenue = (grossRevenue - totalCommissions).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: DsAppBar(
        title: 'Company Reports'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh'.tr,
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadOrders();
              setState(() => _isLoading = false);
            },
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
                    // Period Selector & Date Picker Bar
                    Row(
                      children: [
                        SegmentedButton<ReportPeriod>(
                          segments: [
                            ButtonSegment(value: ReportPeriod.daily, label: Text('Daily'.tr)),
                            ButtonSegment(value: ReportPeriod.monthly, label: Text('Monthly'.tr)),
                            ButtonSegment(value: ReportPeriod.yearly, label: Text('Yearly'.tr)),
                          ],
                          selected: {_period},
                          onSelectionChanged: (set) {
                            setState(() => _period = set.first);
                          },
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: DsRadius.brSm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: DsRadius.brSm,
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16),
                                const DsGap(DsSpace.xs),
                                Text(_dateLabel, style: t.bodySm.w600),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.md),
                    // Driver Filter
                    if (_companyDrivers.isNotEmpty)
                      Row(
                        children: [
                          Text('Driver Filter:'.tr, style: t.bodySm.w600),
                          const DsGap(DsSpace.sm),
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedDriverId,
                              hint: Text('All Fleet Drivers (${_companyDrivers.length})'.tr),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Fleet Drivers (${_companyDrivers.length})'.tr),
                                ),
                                ..._companyDrivers.map((d) {
                                  return DropdownMenuItem<String?>(
                                    value: d.id,
                                    child: Text(d.fullName()),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedDriverId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    const DsGap(DsSpace.lg),
                    // Revenue Overview Cards
                    DsCard(
                      color: c.surface,
                      padding: const EdgeInsets.all(DsSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Company Revenue'.tr, style: t.overline),
                          const DsGap(DsSpace.xs),
                          Text(
                            Constant.amountShow(amount: netCompanyRevenue.toString()),
                            style: t.metric.withColor(c.brand),
                          ),
                          const DsGap(DsSpace.xs),
                          Text(
                            'Gross Revenue minus commissions, scope taxes & deductions'.tr,
                            style: t.caption,
                          ),
                          const DsGap(DsSpace.lg),
                          Row(
                            children: [
                              Expanded(
                                child: _kpiBox(
                                  label: 'Completed Orders'.tr,
                                  value: filtered.length.toString(),
                                  color: c.textSecondary,
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: _kpiBox(
                                  label: 'Gross Revenue'.tr,
                                  value: Constant.amountShow(amount: grossRevenue.toString()),
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const DsGap(DsSpace.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _kpiBox(
                                  label: 'Delivery Charges'.tr,
                                  value: Constant.amountShow(amount: totalDeliveryCharges.toString()),
                                  color: c.textSecondary,
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: _kpiBox(
                                  label: 'COD Cash Collected'.tr,
                                  value: Constant.amountShow(amount: totalCodCollected.toString()),
                                  color: c.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    TabBar(
                      controller: _tabController,
                      labelColor: c.brand,
                      unselectedLabelColor: c.textSecondary,
                      indicatorColor: c.brand,
                      tabs: [
                        Tab(text: '${'Order Breakdown'.tr} (${filtered.length})'),
                        Tab(text: 'Driver Performance'.tr),
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
            _buildOrderBreakdownList(filtered),
            _buildDriverPerformanceList(filtered),
          ],
        ),
      ),
    );
  }

  Widget _kpiBox({required String label, required String value, required Color color}) {
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
          Text(value, style: context.dsText.titleSm.w700, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildOrderBreakdownList(List<ParcelOrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No completed orders found for this period.'.tr, style: context.dsText.bodySecondary),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DsSpace.lg),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        final amounts = ParcelAmounts.of(o);
        final dateStr = o.createdAt != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt!.toDate())
            : '-';
        final isCod = o.paymentMethod == 'cod';

        final double comm = Constant.calculateAdminCommission(
          amount: (amounts.subTotal - amounts.discount).toString(),
          adminCommissionType: o.adminCommissionType.toString(),
          adminCommission: o.adminCommission ?? '0',
        );
        final double deductions = amounts.total - amounts.courierNet(comm);
        final double net = amounts.courierNet(comm).clamp(0.0, double.infinity);

        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.md),
          child: DsCard.outlined(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${'Order #'.tr}${o.id}', style: context.dsText.titleSm.w700),
                    Text(dateStr, style: context.dsText.caption),
                  ],
                ),
                const DsGap(DsSpace.xs),
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 16),
                    const DsGap(DsSpace.xs),
                    Expanded(
                      child: Text(
                        'Driver: ${o.driver?.fullName() ?? o.driverId ?? "Unassigned"}',
                        style: context.dsText.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DsStatusChip(
                      label: (o.paymentMethod ?? 'online').toUpperCase(),
                      status: isCod ? Constant.orderShipped : Constant.orderCompleted,
                    ),
                  ],
                ),
                const DsDivider(spacing: DsSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order Total:'.tr, style: context.dsText.caption),
                    Text(Constant.amountShow(amount: amounts.total.toString()), style: context.dsText.bodySm.w600),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Charges:'.tr, style: context.dsText.caption),
                    Text(
                      Constant.amountShow(
                          amount: (amounts.subTotal + amounts.options).toString()),
                      style: context.dsText.bodySm,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Platform Deductions & Tax:'.tr, style: context.dsText.caption),
                    Text('-${Constant.amountShow(amount: deductions.toString())}', style: context.dsText.bodySm.withColor(context.dsColors.danger)),
                  ],
                ),
                const DsGap(DsSpace.xxs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Company Revenue:'.tr, style: context.dsText.bodySm.w700),
                    Text(Constant.amountShow(amount: net.toString()), style: context.dsText.titleSm.w700.withColor(context.dsColors.brand)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriverPerformanceList(List<ParcelOrderModel> orders) {
    if (_companyDrivers.isEmpty) {
      return Center(
        child: Text('No company drivers in fleet.'.tr, style: context.dsText.bodySecondary),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DsSpace.lg),
      itemCount: _companyDrivers.length,
      itemBuilder: (context, index) {
        final driver = _companyDrivers[index];
        final driverOrders = orders.where((o) => o.driverId == driver.id).toList();

        double driverGross = 0.0;
        double driverCod = 0.0;
        for (final o in driverOrders) {
          final amt = ParcelAmounts.of(o).total;
          driverGross += amt;
          if (o.paymentMethod == 'cod') driverCod += amt;
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
                    DsAvatar(imageUrl: driver.profilePictureURL ?? '', name: driver.fullName(), size: 40),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.fullName(), style: context.dsText.titleSm.w700),
                          Text(driver.phoneNumber ?? '', style: context.dsText.caption),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${driverOrders.length} ${'Orders'.tr}', style: context.dsText.titleSm.w700),
                        Text('Completed'.tr, style: context.dsText.caption),
                      ],
                    ),
                  ],
                ),
                const DsDivider(spacing: DsSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gross Revenue Delivered:'.tr, style: context.dsText.bodySm),
                    Text(Constant.amountShow(amount: driverGross.toString()), style: context.dsText.bodySm.w700),
                  ],
                ),
                const DsGap(DsSpace.xxs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COD Cash Handled:'.tr, style: context.dsText.bodySm),
                    Text(Constant.amountShow(amount: driverCod.toString()), style: context.dsText.bodySm.w700.withColor(context.dsColors.warning)),
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
