import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Spideli Finance > transactions: the user's ledger transactions, newest
/// first, paged, filtered by type and date range (server-side, indexed).
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const List<String?> _types = [null, 'deposit', 'withdrawal', 'transfer', 'manual_adjustment', 'reversal'];
  String? _type;
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 5), lastDate: now, initialDateRange: _range);
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "Transactions".tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in _types)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                    child: ChoiceChip(
                      label: Text((t == null ? 'All' : LedgerView.typeLabel(t)).tr),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Expanded(
                child: DsButton.secondary(
                  label: _range == null ? "Any date".tr : "${FinanceUi.date(Timestamp.fromDate(_range!.start)).split(',').first} – ${FinanceUi.date(Timestamp.fromDate(_range!.end)).split(',').first}",
                  icon: Icons.date_range_rounded,
                  size: DsButtonSize.sm,
                  onPressed: _pickRange,
                ),
              ),
              if (_range != null) DsIconButton(icon: Icons.close_rounded, semanticLabel: "Clear".tr, onPressed: () => setState(() => _range = null)),
            ],
          ),
          const DsGap(DsSpace.md),
          TransactionList(
            key: ValueKey('${_type ?? 'all'}|${_range?.start}|${_range?.end}'),
            type: _type,
            from: _range?.start,
            // The end day counts in full.
            to: _range == null ? null : DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1),
          ),
        ],
      ),
    );
  }
}

/// A list of the user's transactions; [paged] adds a "Load more" button.
class TransactionList extends StatefulWidget {
  final String? type;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final bool paged;

  const TransactionList({super.key, this.type, this.from, this.to, this.limit = 20, this.paged = true});

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final List<DocumentSnapshot<Map<String, dynamic>>> _docs = [];
  Map<String, String> _sides = {};
  bool _loading = true;
  bool _error = false;
  bool _more = true;

  @override
  void initState() {
    super.initState();
    FinanceService.myAccounts().first.then((accounts) {
      _sides = {for (final a in accounts) a['id'].toString(): a['normalSide'].toString()};
      if (mounted) setState(() {});
    }).catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await FinanceService.transactionsPage(
        after: _docs.isEmpty ? null : _docs.last,
        type: widget.type,
        from: widget.from,
        to: widget.to,
        limit: widget.limit,
      );
      _docs.addAll(page.docs);
      _more = page.docs.length == widget.limit;
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_error && _docs.isEmpty) return DsErrorState(message: "Could not load your transactions.".tr, onRetry: _load, compact: true);
    if (_loading && _docs.isEmpty) return const DsSkeletonList(itemCount: 3);
    if (_docs.isEmpty) return DsEmptyState(icon: Icons.receipt_long_outlined, title: "No transactions yet".tr, compact: true);
    return Column(
      children: [
        for (final d in _docs) _row(context, d.data() ?? const {}),
        if (widget.paged && _more)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.md),
            child: DsButton.secondary(label: "Load more".tr, loading: _loading, onPressed: _loading ? null : _load),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> t) {
    final c = DsColors.of(context);
    final lines = ((t['lines'] as List?) ?? const []).map((l) => Map<String, dynamic>.from(l as Map)).toList();
    final int signed = LedgerView.signedAmount(lines, _sides);
    final String currency = t['currency']?.toString() ?? '';
    final bool reversed = t['status'] == 'reversed';
    return DsListTile(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      leadingIcon: signed >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
      leadingTone: signed >= 0 ? DsTone.success : DsTone.neutral,
      title: LedgerView.typeLabel(t['type']?.toString()).tr,
      subtitle: '${FinanceUi.date(t['createdAt'])} · ${t['reference'] ?? ''}${reversed ? ' · ${"Reversed".tr}' : ''}',
      trailing: Text(
        '${signed > 0 ? '+' : ''}${FinanceMoney.format(signed, currency)}',
        style: DsTypography.titleSm.copyWith(color: signed >= 0 ? c.successStrong : c.textPrimary, decoration: reversed ? TextDecoration.lineThrough : null).tabular,
      ),
      onTap: () => _details(context, t, signed),
    );
  }

  void _details(BuildContext context, Map<String, dynamic> t, int signed) {
    final String currency = t['currency']?.toString() ?? '';
    DsBottomSheet.show(
      title: LedgerView.typeLabel(t['type']?.toString()).tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubUi.row(context, "Amount".tr, FinanceMoney.format(signed, currency)),
          SubUi.row(context, "Reference".tr, t['reference']?.toString() ?? '-'),
          SubUi.row(context, "Date".tr, FinanceUi.date(t['createdAt'])),
          SubUi.row(context, "Status".tr, (t['status'] == 'reversed' ? 'Reversed' : 'Completed').tr),
          if ((t['reversalOf'] ?? '').toString().isNotEmpty) SubUi.row(context, "Reverses".tr, t['reversalOf'].toString()),
          if ((t['description'] ?? '').toString().isNotEmpty) SubUi.row(context, "Description".tr, t['description'].toString()),
        ],
      ),
    );
  }
}
