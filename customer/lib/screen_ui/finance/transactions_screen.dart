import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The user's active wallets (`financial_accounts`, kind wallet), one per currency.
List<Map<String, dynamic>> activeWallets(List<Map<String, dynamic>> accounts) =>
    accounts.where((a) => a['status'] == 'active' && (a['kind'] ?? 'wallet') == 'wallet').toList();

/// Spideli Finance > Wallet: the available balance, wallet actions and the
/// searchable, filterable history of ledger transactions (server-side
/// filters, indexed; the search narrows what is loaded).
class TransactionsScreen extends StatefulWidget {
  /// Shown as the Finance dashboard's Wallet tab (no back arrow).
  final bool asTab;

  const TransactionsScreen({super.key, this.asTab = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const List<String?> _types = [null, 'deposit', 'withdrawal', 'transfer', 'manual_adjustment', 'reversal'];
  final _search = TextEditingController();
  String? _type;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 5), lastDate: now, initialDateRange: _range);
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return FinScaffold(
      title: "Wallet".tr,
      showBack: !widget.asTab,
      body: FinBody(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceService.myAccounts(),
            builder: (context, snap) {
              final wallets = activeWallets(snap.data ?? const []);
              final first = wallets.isEmpty ? null : wallets.first;
              return FinHero(
                label: "Available balance".tr,
                amount: first == null
                    ? (snap.hasData ? FinanceMoney.format(0, 'XAF') : '…')
                    : FinanceMoney.format((first['balance'] as num?) ?? 0, first['currency']?.toString() ?? ''),
                caption: wallets.length > 1
                    ? wallets.skip(1).map((w) => FinanceMoney.format((w['balance'] as num?) ?? 0, w['currency']?.toString() ?? '')).join(' · ')
                    : (first == null && snap.hasData ? "Your wallet opens with your first deposit.".tr : "Spideli Finance wallet".tr),
                footer: FinActions(onHero: true, actions: [
                  FinAction(Icons.north_east_rounded, "Send".tr, () => Get.to(() => const TransfersScreen())),
                  FinAction(Icons.receipt_outlined, "Pay bills".tr, () => Get.to(() => const BillsScreen())),
                  FinAction(Icons.picture_as_pdf_outlined, "Statement".tr, () => shareFinanceStatement(context)),
                ]),
              );
            },
          ),
          const DsGap(FinSpace.section),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "Search by reference or description".tr,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close_rounded), tooltip: "Clear".tr, onPressed: () => setState(_search.clear)),
              filled: true,
              fillColor: c.isDark ? c.surfaceRaised : c.surface,
              border: OutlineInputBorder(borderRadius: FinSpace.br, borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: FinSpace.br, borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
            ),
          ),
          const DsGap(DsSpace.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_range == null ? "Any date".tr : '${FinanceUi.day(Timestamp.fromDate(_range!.start))} – ${FinanceUi.day(Timestamp.fromDate(_range!.end))}'),
                onPressed: _pickRange,
              ),
              if (_range != null) IconButton(icon: const Icon(Icons.close_rounded, size: 18), tooltip: "Clear".tr, onPressed: () => setState(() => _range = null)),
              const DsGap(DsSpace.sm),
              for (final t in _types)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                  child: ChoiceChip(
                    label: Text((t == null ? 'All' : LedgerView.typeLabel(t)).tr),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
                ),
            ]),
          ),
          TransactionList(
            key: ValueKey('${_type ?? 'all'}|${_range?.start}|${_range?.end}'),
            type: _type,
            from: _range?.start,
            // The end day counts in full.
            to: _range == null ? null : DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1),
            query: _search.text,
            grouped: true,
          ),
        ],
      ),
    );
  }
}

/// Asks for a period and shares the PDF statement of the user's transactions.
Future<void> shareFinanceStatement(BuildContext context) async {
  final now = DateTime.now();
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 5),
    lastDate: now,
    initialDateRange: DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now),
  );
  if (range == null) return;
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    final result = await FinanceService.statementRows(range.start, range.end);
    ShowToastDialog.closeLoader();
    if (result.rows.isEmpty) return ShowToastDialog.showToast("No transactions in this period.".tr);
    if (result.truncated) {
      ShowToastDialog.showToast("This period has too many transactions for one statement. Only the first ones are included; choose a shorter period.".tr);
    }
    await FinanceService.shareStatement(range.start, range.end, result.rows);
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Could not create the statement. Please try again.".tr);
  }
}

/// The user's transactions as rows: [paged] adds "Load more"; [grouped]
/// adds day headers; [query] narrows what is loaded (type, reference,
/// description).
class TransactionList extends StatefulWidget {
  final String? type;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final bool paged;
  final bool grouped;
  final String query;

  const TransactionList({super.key, this.type, this.from, this.to, this.limit = 20, this.paged = true, this.grouped = false, this.query = ''});

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

  bool _matches(Map<String, dynamic> t) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [t['reference'], t['description'], LedgerView.typeLabel(t['type']?.toString()).tr].any((v) => '${v ?? ''}'.toLowerCase().contains(q));
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return "Today".tr;
    if (day == today.subtract(const Duration(days: 1))) return "Yesterday".tr;
    return ltr(DateFormat('dd MMM yyyy').format(d));
  }

  @override
  Widget build(BuildContext context) {
    if (_error && _docs.isEmpty) return FinState.error("Could not load your transactions.".tr, onRetry: _load);
    if (_loading && _docs.isEmpty) return FinState.loading();
    final items = _docs.map((d) => d.data() ?? const <String, dynamic>{}).where(_matches).toList();
    if (items.isEmpty) {
      return FinState.empty(Icons.receipt_long_outlined, (_docs.isEmpty ? "No transactions yet" : "No transaction matches your search.").tr);
    }
    final List<Widget> children = [];
    if (widget.grouped) {
      String? current;
      final List<Widget> group = [];
      void flush() {
        if (current == null || group.isEmpty) return;
        children.add(FinSection(title: current, divided: true, top: DsSpace.xl, children: List.of(group)));
        group.clear();
      }

      for (final t in items) {
        final d = FinanceGroupService.toDate(t['createdAt']);
        final label = d == null ? '-' : _dayLabel(d);
        if (label != current) {
          flush();
          current = label;
        }
        group.add(_row(context, t));
      }
      flush();
    } else {
      children.add(FinSurface(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
        child: Column(children: [
          for (final (i, t) in items.indexed) ...[
            if (i > 0) Divider(height: 1, color: DsColors.of(context).divider),
            _row(context, t),
          ],
        ]),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (widget.paged && _more)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.secondary(label: "Load more".tr, loading: _loading, onPressed: _loading ? null : _load),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> t) {
    final lines = ((t['lines'] as List?) ?? const []).map((l) => Map<String, dynamic>.from(l as Map)).toList();
    final int signed = LedgerView.signedAmount(lines, _sides);
    final String currency = t['currency']?.toString() ?? '';
    final bool reversed = t['status'] == 'reversed';
    final String description = (t['description'] ?? '').toString();
    final d = FinanceGroupService.toDate(t['createdAt']);
    return FinListTile(
      icon: signed >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
      iconTone: signed >= 0 ? DsTone.success : DsTone.neutral,
      title: description.isNotEmpty ? description : LedgerView.typeLabel(t['type']?.toString()).tr,
      subtitle: [
        if (description.isNotEmpty) LedgerView.typeLabel(t['type']?.toString()).tr,
        if (d != null) ltr(DateFormat(widget.grouped ? 'HH:mm' : 'dd MMM, HH:mm').format(d)),
        ltrRef(t['reference']),
      ].join(' · '),
      amount: FinanceMoney.signed(signed, currency),
      amountColor: reversed ? DsColors.of(context).textMuted : finAmountColor(context, signed),
      status: reversed ? 'reversed' : null,
      statusLabel: reversed ? "Reversed".tr : null,
      onTap: () => _details(context, t, signed),
    );
  }

  void _details(BuildContext context, Map<String, dynamic> t, int signed) {
    final String currency = t['currency']?.toString() ?? '';
    final bool reversed = t['status'] == 'reversed';
    finSheet(
      title: LedgerView.typeLabel(t['type']?.toString()).tr,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(FinanceMoney.signed(signed, currency), style: FinText.amount.copyWith(color: finAmountColor(context, signed)))),
              FinStatusChip(status: reversed ? 'reversed' : 'posted', label: (reversed ? "Reversed" : "Completed").tr, icon: true),
            ]),
            const DsGap(DsSpace.md),
            if ((t['description'] ?? '').toString().isNotEmpty) FinRow("Description".tr, t['description'].toString()),
            FinRow("Type".tr, LedgerView.typeLabel(t['type']?.toString()).tr),
            FinRow("Date".tr, FinanceUi.date(t['createdAt'])),
            FinRow("Reference".tr, ltrRef(t['reference'] ?? '-')),
            if ((t['reversalOf'] ?? '').toString().isNotEmpty) FinRow("Reverses".tr, ltrRef(t['reversalOf'])),
            const DsGap(DsSpace.md),
          ],
        ),
      ),
    );
  }
}
