import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_transfer_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

IconData _icon(String? category) => switch (category) {
      'electricity' => Icons.bolt_rounded,
      'water' => Icons.water_drop_outlined,
      'tv' => Icons.tv_rounded,
      'internet' => Icons.wifi_rounded,
      'phone' => Icons.phone_iphone_rounded,
      'gas' => Icons.local_fire_department_outlined,
      'education' => Icons.school_outlined,
      _ => Icons.receipt_outlined,
    };

/// Spideli Finance > Pay bills. `platform_settings/bills` must exist (admin).
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BillsConfig?>(
      future: FinanceTransferService.billsConfig(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return DsScaffold(
          title: "Pay bills".tr,
          maxContentWidth: DsLayout.contentMax,
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.receipt_outlined, title: "Bill payments are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        _SavedAccounts(config: cfg),
                        Text("What do you want to pay?".tr, style: DsTypography.titleSm),
                        const DsGap(DsSpace.sm),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: DsSpace.sm,
                          crossAxisSpacing: DsSpace.sm,
                          childAspectRatio: 1.05,
                          children: [
                            for (final c in cfg.categories)
                              DsCard.outlined(
                                padding: const EdgeInsets.all(DsSpace.sm),
                                onTap: () => Get.to(() => BillerListScreen(category: c, config: cfg)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  DsIconWell(icon: _icon(c), tone: DsTone.brand),
                                  const DsGap(DsSpace.xs),
                                  Text(BillLabels.category(c).tr, textAlign: TextAlign.center, style: DsTypography.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),
                        _BillHistory(config: cfg),
                      ],
                    ),
        );
      },
    );
  }
}

class _SavedAccounts extends StatelessWidget {
  final BillsConfig config;

  const _SavedAccounts({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceTransferService.savedAccounts(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.lg),
          child: DsFormSection(
            title: "My bills".tr,
            icon: Icons.bookmark_outline_rounded,
            children: [
              for (final a in list)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: _icon(a['category']?.toString()),
                  title: a['nickname']?.toString().isNotEmpty == true ? a['nickname'].toString() : (a['billerName']?.toString() ?? '-'),
                  subtitle: '${a['billerName'] ?? ''} · ${a['account'] ?? ''}',
                  trailing: DsIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: "Remove".tr,
                    onPressed: () => FinanceUi.run(() => FinanceTransferService.deleteSavedAccount(a['id'].toString())),
                  ),
                  onTap: () => Get.to(() => BillPayScreen(billerId: a['billerId'].toString(), config: config, account: a['account']?.toString())),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BillHistory extends StatelessWidget {
  final BillsConfig config;

  const _BillHistory({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceTransferService.billPayments(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load your bill payments.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        return DsFormSection(
          title: "History".tr,
          icon: Icons.receipt_long_outlined,
          children: [
            if (snap.data!.isEmpty) Text("You have not paid a bill yet.".tr, style: DsTypography.body),
            for (final p in snap.data!)
              DsListTile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                leadingIcon: _icon(p['category']?.toString()),
                leadingTone: paymentTone(p['status']?.toString()),
                title: p['billerName']?.toString() ?? '-',
                subtitle: '${paymentDate(p['createdAt'])} · ${PaymentFlow.label(p['status']?.toString()).tr}',
                trailing: Text(FinanceMoney.format(FinanceSummary.intOf(p['total'] ?? p['amount']), p['currency']?.toString() ?? ''), style: DsTypography.bodyStrong.tabular),
                onTap: () => Get.to(() => BillPaymentScreen(requestId: p['id'].toString(), config: config)),
              ),
          ],
        );
      },
    );
  }
}

class BillerListScreen extends StatelessWidget {
  final String category;
  final BillsConfig config;

  const BillerListScreen({super.key, required this.category, required this.config});

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: BillLabels.category(category).tr,
      maxContentWidth: DsLayout.contentMax,
      body: StreamBuilder<List<Biller>>(
        stream: FinanceTransferService.billers(category),
        builder: (context, snap) {
          if (snap.hasError) return DsErrorState(message: "Could not load the billers.".tr);
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3));
          final list = snap.data!.where((b) => config.currencies.contains(b.currency)).toList();
          if (list.isEmpty) return DsEmptyState(icon: _icon(category), title: "No biller is available in this category yet.".tr);
          return ListView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            children: [
              DsTileGroup(
                children: [
                  for (final b in list)
                    DsListTile(
                      leadingIcon: _icon(b.category),
                      leadingTone: DsTone.brand,
                      title: b.name,
                      subtitle: b.country.isEmpty ? null : b.country,
                      showChevron: true,
                      onTap: () => Get.to(() => BillPayScreen(billerId: b.id, config: config)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------- pay

/// Account, (lookup), amount or package; the server then prices the payment for confirmation.
class BillPayScreen extends StatefulWidget {
  final String billerId;
  final BillsConfig config;
  final String? account;

  const BillPayScreen({super.key, required this.billerId, required this.config, this.account});

  @override
  State<BillPayScreen> createState() => _BillPayScreenState();
}

class _BillPayScreenState extends State<BillPayScreen> {
  late final _account = TextEditingController(text: widget.account ?? '');
  final _amount = TextEditingController();
  Map<String, dynamic>? _lookup;
  String? _package;
  bool _save = true;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) _save = false;
  }

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  int? _amountOf(Biller b) {
    if (b.amountType == 'packages') return b.packages.where((p) => p.code == _package).firstOrNull?.amount;
    if (b.amountType == 'due' && !b.partialPayment) return _due;
    return FinanceAmount.parse(_amount.text, b.currency);
  }

  int? get _due => _lookup == null ? null : FinanceSummary.intOf(_lookup!['amountDue']);

  Future<void> _check(Biller b) async {
    Map<String, dynamic>? r;
    final ok = await FinanceUi.run(() async => r = await FinanceTransferService.lookup(b.id, _account.text.trim()));
    if (ok && r != null) {
      setState(() {
        _lookup = r;
        if (b.partialPayment && _due != null && FinanceMoney.exponent(b.currency) == 0) _amount.text = '$_due';
      });
    }
  }

  Future<void> _continue(Biller b) async {
    final int? amount = _amountOf(b);
    final problem = b.amountProblem(amount, due: _due);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceTransferService.createPayment(
        billerId: b.id,
        account: _account.text.trim(),
        amount: amount!,
        packageCode: b.amountType == 'packages' ? _package : null,
        lookupId: _lookup?['lookupId']?.toString(),
        save: _save,
      );
    });
    if (ok && id != null) Get.off(() => BillPaymentScreen(requestId: id!, config: widget.config));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Biller?>(
      stream: FinanceTransferService.biller(widget.billerId),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return DsScaffold(
            title: "Pay a bill".tr,
            maxContentWidth: DsLayout.contentMax,
            body: snap.connectionState == ConnectionState.waiting
                ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 3))
                : DsErrorState(message: "This biller is not available.".tr),
          );
        }
        final bool accountOk = b.accountValid(_account.text);
        final bool needsLookup = b.lookup && _lookup == null;
        final int? amount = _amountOf(b);
        final String? problem = needsLookup || amount == null ? null : b.amountProblem(amount, due: _due);
        final int fee = amount == null ? 0 : b.fee.feeFor(amount, b.currency);
        return DsScaffold(
          title: b.name,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: DsStickyBar(
            child: FinanceKycGate(
              builder: (context, verified) => needsLookup
                  ? DsButton.primary(label: "Check the account".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && accountOk ? () => _check(b) : null)
                  : DsButton.primary(label: "Continue".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && accountOk && amount != null && problem == null ? () => _continue(b) : null),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            children: [
              DsFormSection(
                title: BillLabels.category(b.category).tr,
                icon: _icon(b.category),
                children: [
                  DsTextField(
                    label: b.accountLabel.isEmpty ? "Account or contract number".tr : b.accountLabel,
                    hint: b.accountHint.isEmpty ? null : b.accountHint,
                    controller: _account,
                    requiredMark: true,
                    errorText: _account.text.trim().isNotEmpty && !accountOk ? "Check this number.".tr : null,
                    onChanged: (_) => setState(() => _lookup = null),
                    bottomSpacing: 0,
                  ),
                ],
              ),
              if (_lookup != null) ...[
                const DsGap(DsSpace.md),
                DsCard.tinted(
                  tone: DsTone.success,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if ((_lookup!['customerName'] ?? '').toString().isNotEmpty) paymentRow(context, "Customer".tr, _lookup!['customerName'].toString()),
                    if (_lookup!['amountDue'] != null) paymentRow(context, "Amount due".tr, FinanceMoney.format(_due ?? 0, b.currency), strong: true),
                    if (_lookup!['dueDate'] != null) paymentRow(context, "Due date".tr, paymentDay(_lookup!['dueDate'])),
                  ]),
                ),
              ],
              if (!needsLookup) ...[
                const DsGap(DsSpace.lg),
                DsFormSection(
                  title: (b.amountType == 'packages' ? "Package" : "Amount").tr,
                  icon: Icons.payments_outlined,
                  children: [
                    if (b.amountType == 'packages')
                      RadioGroup<String>(
                        groupValue: _package,
                        onChanged: (v) => setState(() => _package = v),
                        child: Column(children: [
                          for (final p in b.packages)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: p.code,
                              title: Text(p.name),
                              secondary: Text(FinanceMoney.format(p.amount, b.currency), style: DsTypography.bodyStrong.tabular),
                            ),
                        ]),
                      )
                    else if (b.amountType == 'due' && !b.partialPayment)
                      paymentRow(context, "Amount".tr, FinanceMoney.format(_due ?? 0, b.currency))
                    else
                      DsTextField(
                        label: "${"Amount".tr} (${b.currency})",
                        controller: _amount,
                        requiredMark: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        helper: b.amountType == 'open'
                            ? '${FinanceMoney.format(b.min, b.currency)}${b.max == null ? '' : ' - ${FinanceMoney.format(b.max!, b.currency)}'}'
                            : null,
                        errorText: problem?.tr,
                        onChanged: (_) => setState(() {}),
                      ),
                    if (amount != null && problem == null) ...[
                      paymentRow(context, "Estimated fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, b.currency)),
                      paymentRow(context, "Estimated total".tr, FinanceMoney.format(amount + fee, b.currency)),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _save,
                      onChanged: (v) => setState(() => _save = v ?? false),
                      title: Text("Save this account for next time".tr),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ payment

/// One bill payment: confirmation, status, the biller's token and receipt.
class BillPaymentScreen extends StatelessWidget {
  final String requestId;
  final BillsConfig config;

  const BillPaymentScreen({super.key, required this.requestId, required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceTransferService.billPayment(requestId),
      builder: (context, snap) {
        final p = snap.data;
        return DsScaffold(
          title: "Bill payment".tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this payment.".tr)
              : p == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : _body(context, p),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> p) {
    final String status = p['status']?.toString() ?? '';
    final String cur = p['currency']?.toString() ?? '';
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    final int total = FinanceSummary.intOf(p['total'] ?? p['amount']);
    final String token = (p['token'] ?? '').toString();
    final details = <(String, String)>[
      ("Biller".tr, p['billerName']?.toString() ?? '-'),
      ("Account".tr, p['account']?.toString() ?? '-'),
      if ((p['customerName'] ?? '').toString().isNotEmpty) ("Customer".tr, p['customerName'].toString()),
      if ((p['packageName'] ?? '').toString().isNotEmpty) ("Package".tr, p['packageName'].toString()),
      ("Amount".tr, m(p['amount'])),
      ("Fee".tr, FinanceSummary.intOf(p['fee']) == 0 ? "Free".tr : m(p['fee'])),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: paymentTone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(m(total), style: DsTypography.title.tabular)),
                DsBadge(label: PaymentFlow.label(status).tr, tone: paymentTone(status)),
              ]),
              Text('${p['billerName'] ?? ''} · ${p['account'] ?? ''}', style: DsTypography.body),
              if ((p['reason'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: paymentTone(status), title: "Reason".tr, message: p['reason'].toString())),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        if (PaymentFlow.canConfirm(status, null, DateTime.now()))
          PaymentConfirmCard(
            lines: details,
            total: total,
            currency: cur,
            expiresAt: FinanceGroupService.toDate(p['expiresAt']),
            confirmLabel: "Confirm and pay".tr,
            onConfirm: () async {
              if (config.needsReauth(total, cur) && !await FinanceReauth.confirm()) return;
              if (!context.mounted) return;
              final key = FinanceGroupService.newRequestKey();
              await FinancePaySheet.show(
                context,
                title: p['billerName']?.toString() ?? "Bill payment".tr,
                amount: total,
                currency: cur,
                methods: config.paymentMethods,
                submit: (pay) => FinanceTransferService.confirmBill(requestId, pay, key),
              );
            },
            onCancel: () async {
              if (await FinanceUi.run(() => FinanceTransferService.cancelBill(requestId), success: "Payment cancelled")) Get.back();
            },
          )
        else ...[
          if (status == 'completed' && token.isNotEmpty) ...[
            DsCard.outlined(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p['tokenLabel']?.toString() ?? "Your code".tr, style: DsTypography.label),
                const DsGap(DsSpace.xs),
                Row(children: [
                  Expanded(child: SelectableText(token, style: DsTypography.title.copyWith(letterSpacing: 2, fontFeatures: const [FontFeature.tabularFigures()]))),
                  DsIconButton(
                    icon: Icons.copy_rounded,
                    semanticLabel: "Copy".tr,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token));
                      ShowToastDialog.showToast("Copied".tr);
                    },
                  ),
                ]),
                if ((p['units'] ?? '').toString().isNotEmpty) Text('${"Units".tr}: ${p['units']}', style: DsTypography.caption),
              ]),
            ),
            const DsGap(DsSpace.md),
          ],
          paymentTimeline(status),
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Details".tr,
            icon: Icons.receipt_long_outlined,
            children: [
              for (final (l, v) in details) paymentRow(context, l, v),
              paymentRow(context, "Total paid".tr, m(total)),
              paymentRow(context, "Date".tr, paymentDate(p['createdAt'])),
              if (p['completedAt'] != null) paymentRow(context, "Completed on".tr, paymentDate(p['completedAt'])),
              if ((p['reference'] ?? '').toString().isNotEmpty) paymentRow(context, "Reference".tr, p['reference'].toString()),
              if ((p['billerReference'] ?? '').toString().isNotEmpty) paymentRow(context, "Biller reference".tr, p['billerReference'].toString()),
            ],
          ),
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsInlineAlert(tone: DsTone.info, message: "Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.".tr),
            ),
          if (PaymentFlow.canCancel(status))
            DsButton.ghost(label: "Cancel this payment".tr, icon: Icons.close_rounded, onPressed: () => FinanceUi.run(() => FinanceTransferService.cancelBill(requestId), success: "Payment cancelled")),
          if (status == 'completed' || status == 'reversed') ...[
            const DsGap(DsSpace.md),
            DsButton.secondary(
              label: "Share the receipt".tr,
              icon: Icons.ios_share_rounded,
              expand: true,
              onPressed: () => FinanceTransferService.shareReceipt(
                title: "Bill payment receipt".tr,
                reference: p['reference']?.toString() ?? p['id'].toString(),
                highlight: token.isEmpty ? null : token,
                lines: [
                  ("Reference".tr, p['reference']?.toString() ?? p['id'].toString()),
                  ("Status".tr, PaymentFlow.label(status).tr),
                  ("Date".tr, paymentDate(p['completedAt'] ?? p['createdAt'])),
                  ...details,
                  ("Total paid".tr, m(total)),
                  if ((p['billerReference'] ?? '').toString().isNotEmpty) ("Biller reference".tr, p['billerReference'].toString()),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
