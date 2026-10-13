import 'package:customer/screen_ui/finance/fin_ds.dart';
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

// ------------------------------------------------------------------ overview

/// Spideli Finance > Pay bills. `platform_settings/bills` must exist (admin).
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BillsConfig?>(
      future: FinanceTransferService.billsConfig(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return FinScaffold(
          title: "Pay bills".tr,
          body: FinBody(children: [
            if (cfgSnap.connectionState == ConnectionState.waiting)
              FinState.loading()
            else if (cfg == null)
              FinState.empty(Icons.receipt_outlined, "Bill payments are not available yet.".tr)
            else ...[
              FinSection(
                title: "What do you want to pay?".tr,
                top: 0,
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.md),
                children: [
                  FinActions(actions: [
                    for (final c in cfg.categories) FinAction(_icon(c), BillLabels.category(c).tr, () => Get.to(() => BillerListScreen(category: c, config: cfg))),
                  ]),
                ],
              ),
              _SavedAccounts(config: cfg),
              _BillHistory(config: cfg),
            ],
          ]),
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
        return FinSection(
          title: "My bills".tr,
          divided: true,
          padding: paymentListPadding,
          children: [
            for (final a in list)
              Builder(builder: (context) {
                final String nickname = (a['nickname'] ?? '').toString();
                final String biller = a['billerName']?.toString() ?? '-';
                final String account = (a['account'] ?? '').toString();
                return FinListTile(
                  icon: _icon(a['category']?.toString()),
                  iconTone: DsTone.brand,
                  title: nickname.isNotEmpty ? nickname : biller,
                  subtitle: [if (nickname.isNotEmpty) biller, if (account.isNotEmpty) ltr(account)].join(' · '),
                  trailing: DsIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: "Remove".tr,
                    onPressed: () => FinanceUi.run(() => FinanceTransferService.deleteSavedAccount(a['id'].toString())),
                  ),
                  onTap: () => Get.to(() => BillPayScreen(billerId: a['billerId'].toString(), config: config, account: a['account']?.toString())),
                );
              }),
          ],
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
        if (snap.hasError) return FinState.error("Could not load your bill payments.".tr);
        if (!snap.hasData) return FinState.loading();
        if (snap.data!.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "You have not paid a bill yet.".tr);
        return FinSection(
          title: "History".tr,
          divided: true,
          padding: paymentListPadding,
          children: [
            for (final p in snap.data!)
              Builder(builder: (context) {
                final String status = p['status']?.toString() ?? '';
                final String account = (p['account'] ?? '').toString();
                final int total = FinanceSummary.intOf(p['total'] ?? p['amount']);
                return FinListTile(
                  icon: _icon(p['category']?.toString()),
                  title: p['billerName']?.toString() ?? '-',
                  subtitle: [if (account.isNotEmpty) ltr(account), paymentDate(p['createdAt'])].join(' · '),
                  amount: FinanceMoney.format(total, p['currency']?.toString() ?? ''),
                  amountColor: paymentAmountColor(context, status, -total),
                  status: status.isEmpty ? null : status,
                  statusLabel: status.isEmpty ? null : PaymentFlow.label(status).tr,
                  onTap: () => Get.to(() => BillPaymentScreen(requestId: p['id'].toString(), config: config)),
                );
              }),
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
    return FinScaffold(
      title: BillLabels.category(category).tr,
      body: StreamBuilder<List<Biller>>(
        stream: FinanceTransferService.billers(category),
        builder: (context, snap) {
          if (snap.hasError) return FinBody(children: [FinState.error("Could not load the billers.".tr)]);
          if (!snap.hasData) return FinBody(children: [FinState.loading()]);
          final list = snap.data!.where((b) => config.currencies.contains(b.currency)).toList();
          if (list.isEmpty) return FinBody(children: [FinState.empty(_icon(category), "No biller is available in this category yet.".tr)]);
          return FinBody(
            children: [
              FinSection(
                top: 0,
                divided: true,
                padding: paymentListPadding,
                children: [
                  for (final b in list)
                    FinListTile(
                      icon: _icon(b.category),
                      iconTone: DsTone.brand,
                      title: b.name,
                      subtitle: b.country.isEmpty ? null : b.country,
                      chevron: true,
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
          return FinScaffold(
            title: "Pay a bill".tr,
            body: FinBody(children: [
              snap.connectionState == ConnectionState.waiting ? FinState.loading(rows: 3) : FinState.error("This biller is not available.".tr),
            ]),
          );
        }
        final c = DsColors.of(context);
        final bool accountOk = b.accountValid(_account.text);
        final bool needsLookup = b.lookup && _lookup == null;
        final int? amount = _amountOf(b);
        final String? problem = needsLookup || amount == null ? null : b.amountProblem(amount, due: _due);
        final int fee = amount == null ? 0 : b.fee.feeFor(amount, b.currency);
        final bool packages = b.amountType == 'packages';
        final bool fixedDue = b.amountType == 'due' && !b.partialPayment;
        final l = _lookup;
        final lookupRows = <Widget>[
          if (l != null && (l['customerName'] ?? '').toString().isNotEmpty)
            FinRow(
              "Customer".tr,
              l['customerName'].toString(),
              trailing: Icon(Icons.verified_rounded, size: 18, color: c.successStrong, semanticLabel: "Verified".tr),
            ),
          if (l != null && l['amountDue'] != null) FinRow("Amount due".tr, FinanceMoney.format(_due ?? 0, b.currency), strong: true),
          if (l != null && l['dueDate'] != null) FinRow("Due date".tr, paymentDay(l['dueDate'])),
        ];
        return FinScaffold(
          title: b.name,
          bottomBar: DsStickyBar(
            child: FinanceKycGate(
              builder: (context, verified) => needsLookup
                  ? DsButton.primary(label: "Check the account".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && accountOk ? () => _check(b) : null)
                  : DsButton.primary(label: "Continue".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && accountOk && amount != null && problem == null ? () => _continue(b) : null),
            ),
          ),
          body: FinBody(
            children: [
              FinSection(
                title: "Account".tr,
                top: 0,
                padding: paymentFormPadding,
                children: [
                  DsTextField(
                    label: b.accountLabel.isEmpty ? "Account or contract number".tr : b.accountLabel,
                    hint: b.accountHint.isEmpty ? null : b.accountHint,
                    controller: _account,
                    requiredMark: true,
                    errorText: _account.text.trim().isNotEmpty && !accountOk ? "Check this number.".tr : null,
                    onChanged: (_) => setState(() => _lookup = null),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _save,
                    onChanged: (v) => setState(() => _save = v ?? false),
                    title: Text("Save this account for next time".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
              if (lookupRows.isNotEmpty) FinSection(title: "Bill details".tr, divided: true, children: lookupRows),
              if (!needsLookup) ...[
                FinSection(
                  title: (packages ? "Package" : "Amount").tr,
                  padding: packages || fixedDue ? null : paymentFormPadding,
                  children: [
                    if (packages)
                      RadioGroup<String>(
                        groupValue: _package,
                        onChanged: (v) => setState(() => _package = v),
                        child: Column(children: [
                          for (final p in b.packages)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: p.code,
                              title: Text(p.name, style: DsTypography.body.copyWith(color: c.textPrimary)),
                              secondary: Text(FinanceMoney.format(p.amount, b.currency), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
                            ),
                        ]),
                      )
                    else if (fixedDue)
                      FinRow("Amount".tr, FinanceMoney.format(_due ?? 0, b.currency))
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
                  ],
                ),
                if (amount != null && problem == null)
                  FinSection(
                    title: "Estimate".tr,
                    children: [
                      FinRow("Amount".tr, FinanceMoney.format(amount, b.currency)),
                      FinRow("Estimated fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, b.currency)),
                      Divider(height: DsSpace.lg, color: c.divider),
                      FinRow("Estimated total".tr, FinanceMoney.format(amount + fee, b.currency), strong: true),
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
        return FinScaffold(
          title: "Bill payment".tr,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this payment.".tr)])
              : p == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
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
    final String? category = p['category']?.toString();
    final String biller = (p['billerName'] ?? '').toString();
    final String account = (p['account'] ?? '').toString();
    final String reason = (p['reason'] ?? '').toString();
    final String reference = (p['reference'] ?? '').toString();
    final String billerReference = (p['billerReference'] ?? '').toString();
    final String tokenLabel = (p['tokenLabel'] ?? '').toString();
    final track = paymentTrack(status);
    return FinBody(
      children: [
        FinHeader(
          overline: category == null || category.isEmpty ? null : BillLabels.category(category).tr,
          title: m(total),
          subtitle: [if (biller.isNotEmpty) biller, if (account.isNotEmpty) ltr(account)].join(' · '),
          status: status.isEmpty ? null : status,
          statusLabel: PaymentFlow.label(status).tr,
          icon: _icon(category),
          below: reason.isEmpty ? null : DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: reason),
        ),
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
          if (status == 'completed' && token.isNotEmpty)
            _TokenCard(label: tokenLabel.isEmpty ? "Your code".tr : tokenLabel, token: token, units: (p['units'] ?? '').toString()),
          if (track != null) FinSection(title: "Status".tr, padding: const EdgeInsets.all(DsSpace.lg), children: [track]),
          if (status == 'pending')
            FinNotice("Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.".tr),
          FinSection(
            title: "Details".tr,
            divided: true,
            children: [
              for (final (l, v) in details) FinRow(l, v),
              FinRow("Total paid".tr, m(total), strong: true),
              FinRow("Date".tr, paymentDate(p['createdAt'])),
              if (p['completedAt'] != null) FinRow("Completed on".tr, paymentDate(p['completedAt'])),
              if (reference.isNotEmpty) FinRow("Reference".tr, ltrRef(reference)),
              if (billerReference.isNotEmpty) FinRow("Biller reference".tr, ltrRef(billerReference)),
            ],
          ),
          if (PaymentFlow.canCancel(status)) ...[
            const DsGap(DsSpace.lg),
            DsButton.ghost(
              label: "Cancel this payment".tr,
              icon: Icons.close_rounded,
              expand: true,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Cancel this payment?".tr,
                  lines: [("Biller".tr, p['billerName']?.toString() ?? '-'), ("Total".tr, m(total))],
                  confirmLabel: "Cancel this payment".tr,
                  destructive: true,
                );
                if (ok) await FinanceUi.run(() => FinanceTransferService.cancelBill(requestId), success: "Payment cancelled");
              },
            ),
          ],
          if (status == 'completed' || status == 'reversed') ...[
            const DsGap(FinSpace.section),
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

/// The biller's code (a prepaid electricity token...): what the user came
/// for, so it stands alone, large, left-to-right and one tap from the clipboard.
class _TokenCard extends StatelessWidget {
  final String label;
  final String token;
  final String units;

  const _TokenCard({required this.label, required this.token, required this.units});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: FinSpace.section),
      child: FinSurface(
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.key_rounded, size: 18, color: FinColors.brand(context)),
              const DsGap(DsSpace.xs),
              Expanded(child: Semantics(header: true, child: Text(label, style: DsTypography.labelSm.copyWith(color: c.textSecondary)))),
            ]),
            const DsGap(DsSpace.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.lg),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm),
              child: SelectableText(
                token,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: FinText.amount.copyWith(color: c.textPrimary, letterSpacing: 2),
              ),
            ),
            if (units.isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Text('${"Units".tr}: ${ltr(units)}', textAlign: TextAlign.center, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
            ],
            const DsGap(DsSpace.md),
            DsButton.secondary(
              label: "Copy".tr,
              icon: Icons.copy_rounded,
              expand: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                ShowToastDialog.showToast("Copied".tr);
              },
            ),
          ],
        ),
      ),
    );
  }
}
