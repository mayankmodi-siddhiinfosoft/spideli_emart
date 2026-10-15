import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_payment_service.dart';
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
      'taxes' => Icons.account_balance_outlined,
      'products' => Icons.shopping_bag_outlined,
      _ => Icons.receipt_outlined,
    };

/// What a category covers, under its name (translation key), or null.
String? _about(String? category) => switch (category) {
      'electricity' => "Bills and prepaid electricity",
      'water' => "Water bills",
      'tv' => "TV subscriptions",
      'internet' => "Internet subscriptions",
      'phone' => "Airtime and data bundles",
      'gas' => "Gas bills",
      'education' => "School and university fees",
      'taxes' => "Tax payments",
      'products' => "Pay for products and services",
      _ => null,
    };

// ------------------------------------------------------------------ overview

/// Spideli Finance > Pay bills. `platform_settings/bills` must exist (admin).
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinConfig<BillsConfig>(
      load: FinanceTransferService.billsConfig,
      builder: (context, st) {
        final cfg = st.config;
        final placeholder = st.placeholder(Icons.receipt_outlined, "Bill payments are not available yet.".tr);
        return FinScaffold(
          title: "Payment".tr,
          body: FinBody(children: [
            if (placeholder != null || cfg == null)
              placeholder ?? FinState.loading()
            else ...[
              // One row per category: the full name and what it covers
              // stay readable on a small phone and in long languages.
              FinSection(
                title: "What do you want to pay?".tr,
                top: 0,
                divided: true,
                padding: paymentListPadding,
                children: [
                  for (final c in cfg.categories)
                    FinListTile(
                      icon: _icon(c),
                      iconTone: DsTone.brand,
                      title: BillLabels.category(c).tr,
                      subtitle: _about(c)?.tr,
                      chevron: true,
                      onTap: () => Get.to(() => BillerListScreen(category: c, config: cfg)),
                    ),
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

  Future<void> _remove(Map<String, dynamic> a, String title) async {
    final String account = (a['account'] ?? '').toString();
    final ok = await finConfirm(
      title: "Remove this bill?".tr,
      message: "You can save it again with your next payment.".tr,
      lines: [("Biller".tr, title), if (account.isNotEmpty) ("Account".tr, ltr(account))],
      confirmLabel: "Remove".tr,
      destructive: true,
    );
    if (ok) await financeDirectRun(() => FinanceTransferService.deleteSavedAccount(a['id'].toString()));
  }

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
                  trailing: DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, onPressed: () => _remove(a, biller)),
                  onTap: () => Get.to(() => BillPayScreen(billerId: a['billerId'].toString(), config: config, account: a['account']?.toString())),
                );
              }),
          ],
        );
      },
    );
  }
}

class _BillHistory extends StatefulWidget {
  final BillsConfig config;

  const _BillHistory({required this.config});

  @override
  State<_BillHistory> createState() => _BillHistoryState();
}

class _BillHistoryState extends State<_BillHistory> {
  late Stream<List<Map<String, dynamic>>> _stream = FinanceTransferService.billPayments();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return FinState.error("Could not load your bill payments.".tr, onRetry: () => setState(() => _stream = FinanceTransferService.billPayments()));
        }
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
                  subtitle: [if (account.isNotEmpty) ltr(account), FinanceUi.date(p['createdAt'])].join(' · '),
                  // Money out, signed as in the transfer history.
                  amount: FinanceMoney.signed(-total, p['currency']?.toString() ?? ''),
                  amountColor: paymentAmountColor(context, status, -total),
                  status: status.isEmpty ? null : status,
                  statusLabel: status.isEmpty ? null : PaymentFlow.label(status).tr,
                  onTap: () => Get.to(() => BillPaymentScreen(requestId: p['id'].toString(), config: widget.config)),
                );
              }),
          ],
        );
      },
    );
  }
}

/// The billers of a category, searchable on the phone (up to 100 are read).
class BillerListScreen extends StatefulWidget {
  final String category;
  final BillsConfig config;

  const BillerListScreen({super.key, required this.category, required this.config});

  @override
  State<BillerListScreen> createState() => _BillerListScreenState();
}

class _BillerListScreenState extends State<BillerListScreen> {
  /// From this many billers a search field is shown.
  static const int _searchFrom = 7;

  late Stream<List<Biller>> _stream = FinanceTransferService.billers(widget.category);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: BillLabels.category(widget.category).tr,
      body: StreamBuilder<List<Biller>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return FinBody(children: [
              FinState.error("Could not load the billers.".tr, onRetry: () => setState(() => _stream = FinanceTransferService.billers(widget.category))),
            ]);
          }
          if (!snap.hasData) return FinBody(children: [FinState.loading()]);
          final list = snap.data!.where((b) => widget.config.currencies.contains(b.currency)).toList();
          if (list.isEmpty) return FinBody(children: [FinState.empty(_icon(widget.category), "No biller is available in this category yet.".tr)]);
          final String q = _query.trim().toLowerCase();
          final shown = q.isEmpty ? list : list.where((b) => b.name.toLowerCase().contains(q) || b.country.toLowerCase().contains(q)).toList();
          return FinBody(
            children: [
              if (list.length >= _searchFrom) ...[
                DsSearchBar(
                  hint: "Search for a biller".tr,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() => _query = ''),
                ),
                const DsGap(DsSpace.md),
              ],
              if (shown.isEmpty)
                FinState.empty(Icons.search_off_rounded, "No biller matches your search.".tr)
              else
                FinSection(
                  top: 0,
                  divided: true,
                  padding: paymentListPadding,
                  children: [
                    for (final b in shown)
                      FinListTile(
                        icon: _icon(b.category),
                        iconTone: DsTone.brand,
                        title: b.name,
                        subtitle: b.country.isEmpty ? null : b.country,
                        chevron: true,
                        onTap: () => Get.to(() => BillPayScreen(billerId: b.id, config: widget.config)),
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

/// What a biller's account pattern tells the user: digits only (a number
/// keyboard) and, for a simple pattern, how many ("10 digits").
({bool numeric, String? length}) _accountFormat(Biller b) {
  final String? src = b.accountPattern?.pattern;
  if (src == null) return (numeric: false, length: null);
  // Biller.fromMap wraps the admin's pattern as ^(?:pattern)$.
  final String p = src.startsWith('^(?:') && src.endsWith(r')$') ? src.substring(4, src.length - 2) : src;
  final bool numeric = RegExp(r'^(?:\\d|\[0-9\]|\{\d+(?:,\d*)?\}|[()|?+*])+$').hasMatch(p);
  final m = RegExp(r'^(?:\\d|\[0-9\])\{(\d+)(?:(,)(\d*))?\}$').firstMatch(p);
  if (m == null) return (numeric: numeric, length: null);
  final int from = int.parse(m.group(1)!);
  final String? to = m.group(3);
  final String length = m.group(2) == null
      ? FinanceUi.count(from, "digit", "digits")
      : (to == null || to.isEmpty)
          ? '${"At least".tr} ${FinanceUi.count(from, "digit", "digits")}'
          : '${ltr('$from-$to')} ${"digits".tr}';
  return (numeric: numeric, length: length);
}

/// Account, then the amount (typed from the bill: the biller cannot be
/// asked without a partner connection) or a package; then the confirmation.
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
  late Stream<Biller?> _stream = FinanceTransferService.biller(widget.billerId);
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

  BillPackage? _packageOf(Biller b) => b.packages.where((p) => p.code == _package).firstOrNull;

  int? _amountOf(Biller b) => b.amountType == 'packages' ? _packageOf(b)?.amount : FinanceAmount.parse(_amount.text, b.currency);

  void _continue(Biller b) {
    final int? amount = _amountOf(b);
    final problem = BillPlans.amountProblem(b, amount);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    final draft = BillDraft(
      biller: b,
      account: _account.text.trim(),
      amount: amount!,
      package: b.amountType == 'packages' ? _packageOf(b) : null,
      saveAccount: _save,
    );
    Get.to(() => BillConfirmScreen(config: widget.config, draft: draft));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Biller?>(
      stream: _stream,
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return FinScaffold(
            title: "Pay a bill".tr,
            body: FinBody(children: [
              if (snap.hasError)
                FinState.error("Could not load this biller.".tr, onRetry: () => setState(() => _stream = FinanceTransferService.biller(widget.billerId)))
              else if (snap.connectionState == ConnectionState.waiting)
                FinState.loading(rows: 3)
              else
                FinState.empty(Icons.search_off_rounded, "This biller is not available.".tr),
            ]),
          );
        }
        final c = DsColors.of(context);
        final format = _accountFormat(b);
        final String typed = _account.text.trim();
        final bool accountOk = b.accountValid(_account.text);
        final int? amount = _amountOf(b);
        final String? problem = amount == null ? null : BillPlans.amountProblem(b, amount);
        final int fee = amount == null ? 0 : b.fee.feeFor(amount, b.currency);
        final bool packages = b.amountType == 'packages';
        final bool longPackages = packages && b.packages.length > 8;
        final String? accountError = typed.isEmpty || accountOk
            ? null
            : [
                "This number is not in the expected format.".tr,
                if (format.length != null) '${"Expected".tr}: ${format.length}.',
              ].join(' ');
        final String accountLabel = b.accountLabel.isEmpty ? "Account or contract number".tr : b.accountLabel;
        final helperParts = [if (b.accountHint.isNotEmpty) b.accountHint, ?format.length];
        final missing = <String>[
          if (!accountOk) accountLabel,
          if (packages && amount == null) "Package".tr,
          if (!packages && (amount == null || problem != null)) "Amount".tr,
        ];
        return FinScaffold(
          title: b.name,
          bottomBar: DsStickyBar(
            child: FinanceKycGate(
              builder: (context, verified) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinMissing(missing),
                  DsButton.primary(
                    label: "Continue".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: verified && accountOk && amount != null && problem == null ? () => _continue(b) : null,
                  ),
                ],
              ),
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
                    label: accountLabel,
                    controller: _account,
                    requiredMark: true,
                    keyboardType: format.numeric ? TextInputType.number : TextInputType.text,
                    helper: accountError == null && helperParts.isNotEmpty ? helperParts.join(' · ') : null,
                    errorText: accountError,
                    onChanged: (_) => setState(() {}),
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
              FinSection(
                title: (packages ? "Package" : "Amount").tr,
                padding: !packages || longPackages ? paymentFormPadding : null,
                children: [
                  if (longPackages)
                    // A long list: a searchable picker instead of radio rows.
                    FinPickerField<String>(
                      label: "Package".tr,
                      value: _package,
                      requiredMark: true,
                      searchHint: "Search for a package".tr,
                      options: [for (final p in b.packages) (p.code, '${p.name} · ${FinanceMoney.format(p.amount, b.currency)}')],
                      onChanged: (v) => setState(() => _package = v),
                    )
                  else if (packages)
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
                  else
                    FinAmountField(
                      label: "Amount".tr,
                      controller: _amount,
                      currency: b.currency,
                      min: b.min,
                      max: b.max,
                      // The field explains the format and the bounds; any
                      // other rule of the biller is said here.
                      errorText: FinanceAmount.problem(_amount.text, b.currency, min: b.min, max: b.max) == null ? problem?.tr : null,
                      onChanged: (_) => setState(() {}),
                    ),
                ],
              ),
              // Without a connection to the biller, the amount comes from the bill itself.
              if (b.amountType == 'due' || b.lookup)
                FinNotice("Enter the amount shown on your bill. Spideli Finance pays the biller this amount for this account.".tr),
              if (amount != null && problem == null)
                FinSection(
                  title: "Summary".tr,
                  children: [
                    FinRow("Amount".tr, FinanceMoney.format(amount, b.currency)),
                    FinRow("Fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, b.currency)),
                    Divider(height: DsSpace.lg, color: c.divider),
                    FinRow("Total".tr, FinanceMoney.format(amount + fee, b.currency), strong: true),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The bill payment to confirm: biller, account, amount, fee and total;
/// then the identity check above the threshold, and the payment.
class BillConfirmScreen extends StatelessWidget {
  final BillsConfig config;
  final BillDraft draft;

  const BillConfirmScreen({super.key, required this.config, required this.draft});

  Future<void> _confirm(BuildContext context) async {
    final d = draft;
    final String cur = d.biller.currency;
    // Before anything is charged: a restricted account is told now.
    if (!await financeDirectRun(() => FinancePaymentService.requireAllowed('payments'))) return;
    if (config.needsReauth(d.total, cur) && !await FinanceReauth.confirm()) return;
    if (!context.mounted) return;
    String? requestId;
    await FinancePaySheet.show(
      context,
      title: d.biller.name,
      amount: d.total,
      currency: cur,
      methods: config.paymentMethods,
      submit: (payment) async {
        final reply = await FinanceTransferService.payBill(config, d, payment.funding);
        requestId = reply['requestId']?.toString();
        return reply;
      },
    );
    if (requestId != null) {
      // The payment page replaces this confirmation AND the form below it:
      // Back returns to the bills page, never to a filled form that invites
      // paying the same bill twice.
      Get.back();
      Get.off(() => BillPaymentScreen(requestId: requestId!, config: config));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final b = d.biller;
    String m(int v) => FinanceMoney.format(v, b.currency);
    return FinScaffold(
      title: "Bill payment".tr,
      body: FinBody(children: [
        FinHeader(
          overline: BillLabels.category(b.category).tr,
          title: m(d.total),
          subtitle: '${b.name} · ${ltr(d.account)}',
          icon: _icon(b.category),
        ),
        PaymentConfirmCard(
          lines: [
            ("Biller".tr, b.name),
            ("Account".tr, ltr(d.account)),
            if (d.package != null) ("Package".tr, d.package!.name),
            ("Amount".tr, m(d.amount)),
            ("Fee".tr, d.fee == 0 ? "Free".tr : m(d.fee)),
          ],
          total: d.total,
          currency: b.currency,
          expiresAt: null,
          confirmLabel: "Confirm and pay".tr,
          onConfirm: () => _confirm(context),
          onCancel: () async => Get.back(),
        ),
        FinNotice("Check the account number: Spideli Finance pays the biller for this account. You can follow the payment here.".tr),
      ]),
    );
  }
}

// ------------------------------------------------------------------ payment

/// One bill payment: status, the biller's token and receipt.
class BillPaymentScreen extends StatefulWidget {
  final String requestId;
  final BillsConfig config;

  const BillPaymentScreen({super.key, required this.requestId, required this.config});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  late Stream<Map<String, dynamic>?> _stream = FinanceTransferService.billPayment(widget.requestId);

  String get requestId => widget.requestId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snap) {
        final state = FinState.of(
          snap,
          gone: "This payment is no longer available.",
          onRetry: () => setState(() => _stream = FinanceTransferService.billPayment(requestId)),
        );
        return FinScaffold(
          title: "Bill payment".tr,
          body: state != null ? FinBody(children: [state]) : _body(context, snap.data!),
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
          below: reason.isEmpty ? null : DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: financeReasonText(reason).tr),
        ),
        if (status == 'completed' && token.isNotEmpty)
          _TokenCard(label: tokenLabel.isEmpty ? "Your code".tr : tokenLabel, token: token, units: (p['units'] ?? '').toString()),
        if (track != null) FinSection(title: "Status".tr, padding: const EdgeInsets.all(DsSpace.lg), children: [track]),
        if (status == 'processing') FinNotice("Your payment was received. Spideli Finance is paying the biller; this page updates when it is done.".tr),
        if (status == 'reversed') FinNotice("This bill was not paid: the money is back in your wallet.".tr),
        FinSection(
          title: "Details".tr,
          divided: true,
          children: [
            for (final (l, v) in details) FinRow(l, v),
            FinRow(paymentTotalLabel(status), m(total), strong: true),
            FinRow("Date".tr, FinanceUi.date(p['createdAt'])),
            if (p['completedAt'] != null) FinRow("Completed on".tr, FinanceUi.date(p['completedAt'])),
            if (reference.isNotEmpty) FinRow("Reference".tr, ltrRef(reference)),
            if (billerReference.isNotEmpty) FinRow("Biller reference".tr, ltrRef(billerReference)),
          ],
        ),
        if (status == 'completed' || status == 'reversed') ...[
          const DsGap(FinSpace.section),
          PaymentReceiptButton(
            title: "Bill payment receipt".tr,
            reference: p['reference']?.toString() ?? p['id'].toString(),
            highlight: token.isEmpty ? null : token,
            lines: [
              ("Reference".tr, p['reference']?.toString() ?? p['id'].toString()),
              ("Status".tr, PaymentFlow.label(status).tr),
              ("Date".tr, FinanceUi.date(p['completedAt'] ?? p['createdAt'])),
              ...details,
              ("Total paid".tr, m(total)),
              if ((p['billerReference'] ?? '').toString().isNotEmpty) ("Biller reference".tr, p['billerReference'].toString()),
            ],
          ),
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
