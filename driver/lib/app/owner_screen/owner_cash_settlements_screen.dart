import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/company_cash_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/company_cash_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class OwnerCashSettlementsScreen extends StatefulWidget {
  const OwnerCashSettlementsScreen({super.key});

  @override
  State<OwnerCashSettlementsScreen> createState() => _OwnerCashSettlementsScreenState();
}

class _OwnerCashSettlementsScreenState extends State<OwnerCashSettlementsScreen> with SingleTickerProviderStateMixin {
  final String _ownerUid = FireStoreUtils.getCurrentUid();
  late TabController _tabController;

  List<UserModel> _companyDrivers = [];
  String? _selectedDriverId; // null = all drivers

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCompanyDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyDrivers() async {
    try {
      final snap = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .where('ownerId', isEqualTo: _ownerUid)
          .get();
      if (mounted) {
        setState(() {
          _companyDrivers = snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  void _showRejectDialog(CompanyCashTransactionModel tx) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('Reject Settlement'.tr, style: context.dsText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'Reject settlement of'.tr} ${Constant.amountShow(amount: (tx.amount ?? 0).toString())} ${'from'.tr} ${tx.driverName}?',
              style: context.dsText.bodySm,
            ),
            const DsGap(DsSpace.md),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Required)'.tr,
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
                ShowToastDialog.showToast('Please provide a reason'.tr);
                return;
              }
              Get.back();
              ShowToastDialog.showLoader('Rejecting...'.tr);
              try {
                await CompanyCashService.rejectSettlement(
                  transactionId: tx.id!,
                  reason: reason,
                );
                ShowToastDialog.closeLoader();
                ShowToastDialog.showToast('Settlement rejected'.tr);
              } catch (e) {
                ShowToastDialog.closeLoader();
                ShowToastDialog.showToast('Error: $e');
              }
            },
            child: Text('Reject'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog() {
    if (_companyDrivers.isEmpty) {
      ShowToastDialog.showToast('No drivers found in your fleet'.tr);
      return;
    }

    String selectedDriver = _companyDrivers.first.id ?? '';
    String driverName = _companyDrivers.first.fullName();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    bool isCredit = false; // default deduction/settlement adjustment

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Record Balance Adjustment'.tr, style: context.dsText.title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company owner audited adjustment to driver outstanding balance.'
                        .tr,
                    style: context.dsText.caption,
                  ),
                  const DsGap(DsSpace.md),
                  DropdownButtonFormField<String>(
                    value: selectedDriver,
                    decoration: InputDecoration(
                      labelText: 'Select Driver'.tr,
                      border: const OutlineInputBorder(),
                    ),
                    items: _companyDrivers.map((d) {
                      return DropdownMenuItem(
                        value: d.id ?? '',
                        child: Text(d.fullName()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedDriver = val;
                          final found = _companyDrivers.firstWhereOrNull((d) => d.id == val);
                          driverName = found?.fullName() ?? '';
                        });
                      }
                    },
                  ),
                  const DsGap(DsSpace.md),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Adjustment Amount'.tr,
                      prefixText: '${Constant.currencyModel?.symbol ?? ''} ',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Row(
                    children: [
                      Text('Effect:'.tr, style: context.dsText.bodySm.w600),
                      const DsGap(DsSpace.sm),
                      ChoiceChip(
                        label: Text('Reduce Balance'.tr),
                        selected: !isCredit,
                        onSelected: (val) => setDialogState(() => isCredit = false),
                      ),
                      const DsGap(DsSpace.xs),
                      ChoiceChip(
                        label: Text('Increase Balance'.tr),
                        selected: isCredit,
                        onSelected: (val) => setDialogState(() => isCredit = true),
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.md),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Auditable Reason (Required)'.tr,
                      hintText: 'e.g. Bank deposit verified, adjustment for cash discrepancy',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  final reason = reasonController.text.trim();
                  if (amt <= 0 || reason.isEmpty) {
                    ShowToastDialog.showToast('Please provide valid amount and reason'.tr);
                    return;
                  }
                  Get.back();
                  ShowToastDialog.showLoader('Recording adjustment...'.tr);
                  try {
                    await CompanyCashService.recordOwnerAdjustment(
                      driverId: selectedDriver,
                      driverName: driverName,
                      amount: amt,
                      reason: reason,
                      isCredit: isCredit,
                    );
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast('Adjustment recorded successfully'.tr);
                  } catch (e) {
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast('Error: $e');
                  }
                },
                child: Text('Save Adjustment'.tr),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    return Scaffold(
      appBar: DsAppBar(
        title: 'Company Cash Settlements'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Record Adjustment'.tr,
            onPressed: _showAdjustmentDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<CompanyCashTransactionModel>>(
        stream: CompanyCashService.streamOwnerTransactions(_ownerUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTransactions = snapshot.data ?? [];
          final filteredTransactions = _selectedDriverId == null
              ? allTransactions
              : allTransactions.where((tx) => tx.driverId == _selectedDriverId).toList();

          final summary = DriverCashSummary.fromTransactions(filteredTransactions);

          final pendingList = filteredTransactions
              .where((tx) => tx.type == CompanyCashTransactionType.settlement && tx.status == CompanyCashTransactionStatus.pending)
              .toList();
          final confirmedList = filteredTransactions
              .where((tx) => tx.status == CompanyCashTransactionStatus.confirmed)
              .toList();
          final rejectedList = filteredTransactions
              .where((tx) => tx.status == CompanyCashTransactionStatus.rejected)
              .toList();

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // KPI Cards
                        DsCard(
                          color: c.surface,
                          padding: const EdgeInsets.all(DsSpace.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fleet Outstanding Cash'.tr, style: t.overline),
                              const DsGap(DsSpace.xs),
                              Text(
                                Constant.amountShow(amount: summary.outstandingBalance.toString()),
                                style: t.metric.withColor(summary.outstandingBalance > 0 ? c.danger : c.brand),
                              ),
                              const DsGap(DsSpace.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _kpiTile('Total Collected'.tr, Constant.amountShow(amount: summary.totalCollected.toString()), c.textSecondary),
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: _kpiTile('Total Settled'.tr, Constant.amountShow(amount: summary.totalSettled.toString()), c.success),
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: _kpiTile('Pending Review'.tr, Constant.amountShow(amount: summary.pendingSettlement.toString()), c.warning),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        // Driver Filter Dropdown
                        if (_companyDrivers.isNotEmpty)
                          Row(
                            children: [
                              Text('Driver Filter:'.tr, style: t.bodySm.w600),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _selectedDriverId,
                                  hint: Text('All Drivers (${_companyDrivers.length})'.tr),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Drivers (${_companyDrivers.length})'.tr),
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
                        const DsGap(DsSpace.sm),
                        TabBar(
                          controller: _tabController,
                          labelColor: c.brand,
                          unselectedLabelColor: c.textSecondary,
                          indicatorColor: c.brand,
                          tabs: [
                            Tab(text: '${'Pending'.tr} (${pendingList.length})'),
                            Tab(text: '${'Confirmed'.tr} (${confirmedList.length})'),
                            Tab(text: '${'Rejected'.tr} (${rejectedList.length})'),
                            Tab(text: '${'All'.tr} (${filteredTransactions.length})'),
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
                _buildTransactionList(pendingList, isPendingTab: true),
                _buildTransactionList(confirmedList),
                _buildTransactionList(rejectedList),
                _buildTransactionList(filteredTransactions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color) {
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

  Widget _buildTransactionList(List<CompanyCashTransactionModel> list, {bool isPendingTab = false}) {
    if (list.isEmpty) {
      return Center(
        child: Text('No transactions found.'.tr, style: context.dsText.bodySecondary),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DsSpace.lg),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final tx = list[index];
        return _buildOwnerTxCard(tx, isPending: isPendingTab || tx.status == CompanyCashTransactionStatus.pending);
      },
    );
  }

  Widget _buildOwnerTxCard(CompanyCashTransactionModel tx, {bool isPending = false}) {
    final c = context.dsColors;
    final t = context.dsText;

    final isCollection = tx.type == CompanyCashTransactionType.collection;
    final isSettlement = tx.type == CompanyCashTransactionType.settlement;

    final dateStr = tx.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt!.toDate())
        : '-';

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
                  imageUrl: '',
                  name: tx.driverName ?? 'Driver',
                  size: 38,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.driverName ?? 'Driver', style: t.titleSm.w700),
                      Text(
                        isCollection ? 'COD Collection'.tr : (isSettlement ? 'Cash Settlement'.tr : 'Adjustment'.tr),
                        style: t.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  Constant.amountShow(amount: (tx.amount ?? 0).toString()),
                  style: t.title.withColor(isCollection ? c.danger : c.success),
                ),
              ],
            ),
            const DsGap(DsSpace.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: t.caption),
                DsStatusChip(
                  label: (tx.status ?? 'confirmed').toUpperCase().tr,
                  status: tx.status == CompanyCashTransactionStatus.confirmed ? Constant.orderCompleted : tx.status,
                ),
              ],
            ),
            if (tx.orderId != null && tx.orderId!.isNotEmpty) ...[
              const DsGap(DsSpace.xxs),
              Text('${'Order #'.tr}${tx.orderId}', style: t.bodySm.w600),
            ],
            if (tx.notes != null && tx.notes!.isNotEmpty) ...[
              const DsGap(DsSpace.xxs),
              Text(tx.notes!, style: t.caption),
            ],
            if (tx.rejectionReason != null && tx.rejectionReason!.isNotEmpty) ...[
              const DsGap(DsSpace.xxs),
              Text('Rejection reason: ${tx.rejectionReason}', style: t.caption.withColor(c.danger)),
            ],
            if (isPending) ...[
              const DsDivider(spacing: DsSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _showRejectDialog(tx),
                    child: Text('Reject'.tr, style: TextStyle(color: c.danger)),
                  ),
                  const DsGap(DsSpace.md),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: c.success),
                    onPressed: () async {
                      ShowToastDialog.showLoader('Confirming receipt...'.tr);
                      try {
                        await CompanyCashService.confirmSettlement(transactionId: tx.id!);
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast('Settlement confirmed'.tr);
                      } catch (e) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast('Error: $e');
                      }
                    },
                    child: Text('Confirm Receipt'.tr, style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
