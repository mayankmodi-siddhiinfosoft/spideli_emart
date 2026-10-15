import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart' show activeWallets;
import 'package:customer/screen_ui/finance/transfer_screens.dart' show financeDirectRun, PaymentReceiptButton, paymentFormPadding, paymentListPadding;
import 'package:customer/service/finance_payment_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_wallet_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_wallet_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// Spideli Finance > Wallet: add money (a payment gateway -> the wallet),
// withdraw (the wallet -> Mobile Money, Wave or a bank account, paid out by
// Spideli), convert between the user's currencies, and one operation's
// status (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.2).

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

int _balanceOf(List<Map<String, dynamic>> accounts, String currency) =>
    ((activeWallets(accounts).where((w) => w['currency'] == currency).firstOrNull?['balance'] as num?) ?? 0).toInt();

/// The configuration, or what to show instead (loading, error, not offered).
Widget _withConfig(String title, IconData icon, bool Function(WalletConfig c) offered, String unavailable, Widget Function(BuildContext context, WalletConfig c) builder) {
  return FinConfig<WalletConfig>(
    load: FinanceWalletService.config,
    builder: (context, st) {
      final cfg = st.config;
      final placeholder = st.placeholder(icon, unavailable);
      if (placeholder != null || cfg == null) return FinScaffold(title: title, body: FinBody(children: [placeholder ?? FinState.loading()]));
      if (!offered(cfg)) return FinScaffold(title: title, body: FinBody(children: [FinState.empty(icon, unavailable)]));
      return builder(context, cfg);
    },
  );
}

// ---------------------------------------------------------------- add money

/// Add money: an amount, then a payment gateway (Mobile Money, card,
/// PayPal...) charges it and the wallet is credited at once.
class WalletAddMoneyScreen extends StatelessWidget {
  /// The currency to start with (the wallet shown), when offered.
  final String? currency;

  const WalletAddMoneyScreen({super.key, this.currency});

  @override
  Widget build(BuildContext context) => _withConfig(
        "Add money".tr,
        Icons.add_card_rounded,
        (c) => c.deposit.enabled,
        "Adding money is not available yet.".tr,
        (context, cfg) => _AddMoneyForm(config: cfg, currency: currency),
      );
}

class _AddMoneyForm extends StatefulWidget {
  final WalletConfig config;
  final String? currency;

  const _AddMoneyForm({required this.config, this.currency});

  @override
  State<_AddMoneyForm> createState() => _AddMoneyFormState();
}

class _AddMoneyFormState extends State<_AddMoneyForm> {
  final _amount = TextEditingController();
  late String _currency = widget.config.currencies.contains(widget.currency) ? widget.currency! : widget.config.currencies.first;

  WalletLimits get _limits => widget.config.deposit.limits;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (amount == null || _limits.problem(amount, _currency) != null) return;
    if (!await financeDirectRun(() => FinancePaymentService.requireAllowed('wallet')) || !mounted) return;
    bool added = false;
    await FinancePaySheet.show(
      context,
      title: "Add money".tr,
      amount: amount,
      currency: _currency,
      methods: widget.config.deposit.methods,
      submit: (payment) async {
        final reply = await FinanceWalletService.deposit(currency: _currency, amount: amount, funding: payment.funding);
        added = true;
        return reply;
      },
    );
    if (added && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final bool ok = amount != null && _limits.problem(amount, _currency) == null;
    return FinScaffold(
      title: "Add money".tr,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FinMissing([if (!ok) "Amount".tr]),
            DsButton.primary(label: "Continue".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && ok ? _continue : null),
          ]),
        ),
      ),
      body: FinBody(children: [
        FinSection(
          title: "Amount".tr,
          top: 0,
          padding: paymentFormPadding,
          children: [
            FinAmountField(
              label: "Amount".tr,
              controller: _amount,
              currency: _currency,
              currencies: widget.config.currencies,
              onCurrencyChanged: (v) => setState(() => _currency = v),
              onChanged: (_) => setState(() {}),
              min: _limits.minFor(_currency),
              max: _limits.maxFor(_currency),
            ),
          ],
        ),
        FinNotice("You pay with Mobile Money, a bank card or another method offered next. The money is in your wallet as soon as the payment is confirmed.".tr),
      ]),
    );
  }
}

// ----------------------------------------------------------------- withdraw

/// Withdraw: an amount and its fee from the wallet, then where to receive
/// it (a saved Mobile Money number, Wave account or bank account); Spideli
/// Finance pays it out.
class WalletWithdrawScreen extends StatelessWidget {
  final String? currency;

  const WalletWithdrawScreen({super.key, this.currency});

  @override
  Widget build(BuildContext context) => _withConfig(
        "Withdraw".tr,
        Icons.account_balance_outlined,
        (c) => c.withdraw.enabled,
        "Withdrawals are not available yet.".tr,
        (context, cfg) => _WithdrawForm(config: cfg, currency: currency),
      );
}

class _WithdrawForm extends StatefulWidget {
  final WalletConfig config;
  final String? currency;

  const _WithdrawForm({required this.config, this.currency});

  @override
  State<_WithdrawForm> createState() => _WithdrawFormState();
}

class _WithdrawFormState extends State<_WithdrawForm> {
  final _amount = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _accounts = FinanceService.myAccounts();
  late String _currency = widget.config.currencies.contains(widget.currency) ? widget.currency! : widget.config.currencies.first;

  WalletConfig get cfg => widget.config;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue(int amount) async {
    if (!await financeDirectRun(() => FinancePaymentService.requireAllowed('wallet'))) return;
    if (cfg.needsReauth(amount, _currency) && !await FinanceReauth.confirm()) return;
    if (!mounted) return;
    String? id;
    await FinancePaySheet.show(
      context,
      title: "Withdraw to".tr,
      amount: amount,
      currency: _currency,
      methods: cfg.withdraw.methods,
      payout: true,
      submit: (payment) async {
        final reply = await FinanceWalletService.withdraw(config: cfg, currency: _currency, amount: amount, destination: payment.destination!);
        id = reply['operationId']?.toString();
        return reply;
      },
    );
    if (id != null && mounted) Get.off(() => WalletOperationScreen(operationId: id!));
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _accounts,
      builder: (context, snap) {
        final int balance = _balanceOf(snap.data ?? const [], _currency);
        final int? amount = FinanceAmount.parse(_amount.text, _currency);
        final limits = cfg.withdraw.limits;
        final int fee = amount == null ? 0 : WalletRules.withdrawFee(cfg, amount, _currency);
        final bool tooMuch = amount != null && snap.hasData && amount + fee > balance;
        final bool ok = amount != null && limits.problem(amount, _currency) == null && snap.hasData && !tooMuch;
        return FinScaffold(
          title: "Withdraw".tr,
          bottomBar: DsStickyBar(
            child: FinanceKycGate(
              builder: (context, verified) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FinMissing([if (!ok) "Amount".tr]),
                DsButton.primary(label: "Continue".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && ok ? () => _continue(amount) : null),
              ]),
            ),
          ),
          body: FinBody(children: [
            FinSection(
              title: "Amount".tr,
              top: 0,
              padding: paymentFormPadding,
              children: [
                FinAmountField(
                  label: "Amount".tr,
                  controller: _amount,
                  currency: _currency,
                  currencies: cfg.currencies,
                  onCurrencyChanged: (v) => setState(() => _currency = v),
                  onChanged: (_) => setState(() {}),
                  min: limits.minFor(_currency),
                  max: limits.maxFor(_currency),
                  errorText: tooMuch ? "The amount and its fee are more than your balance.".tr : null,
                  helper: [
                    ?FinanceAmount.range(limits.minFor(_currency), limits.maxFor(_currency), _currency),
                    if (snap.hasData) '${"Available balance".tr}: ${FinanceMoney.format(balance, _currency)}',
                  ].join(' · ').ifEmptyNull,
                ),
              ],
            ),
            if (amount != null && limits.problem(amount, _currency) == null)
              FinSection(
                title: "Summary".tr,
                children: [
                  FinRow("You receive".tr, FinanceMoney.format(amount, _currency)),
                  FinRow("Fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, _currency)),
                  if (cfg.withdraw.delay.isNotEmpty) FinRow("Delivery".tr, cfg.withdraw.delay),
                  Divider(height: DsSpace.lg, color: c.divider),
                  FinRow("Taken from your wallet".tr, FinanceMoney.format(amount + fee, _currency), strong: true),
                ],
              ),
            FinNotice("The money leaves your wallet now. Spideli Finance then pays it out to the account you choose next; if it cannot, your wallet is refunded.".tr),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ convert

/// Convert: from one wallet to another currency, at the latest rate
/// published by Spideli, with its fee.
class WalletConvertScreen extends StatelessWidget {
  final String? from;

  const WalletConvertScreen({super.key, this.from});

  @override
  Widget build(BuildContext context) => _withConfig(
        "Convert".tr,
        Icons.currency_exchange_rounded,
        (c) => c.convert.enabled,
        "Currency conversion is not available yet.".tr,
        (context, cfg) => _ConvertForm(config: cfg, from: from),
      );
}

class _ConvertForm extends StatefulWidget {
  final WalletConfig config;
  final String? from;

  const _ConvertForm({required this.config, this.from});

  @override
  State<_ConvertForm> createState() => _ConvertFormState();
}

class _ConvertFormState extends State<_ConvertForm> {
  final _amount = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _accounts = FinanceService.myAccounts();
  late String _from = widget.config.convert.currencies.contains(widget.from) ? widget.from! : widget.config.convert.currencies.first;
  late String _to = widget.config.convert.currencies.firstWhere((c) => c != _from);
  late Future<({double rate, DateTime observedAt, String source, String id})?> _rate = _loadRate();

  WalletConvertConfig get cc => widget.config.convert;

  Future<({double rate, DateTime observedAt, String source, String id})?> _loadRate() => FinanceWalletService.rate(_from, _to, cc.maxRateAge);

  void _pair(String from, String to) => setState(() {
        _from = from;
        _to = to == from ? cc.currencies.firstWhere((c) => c != from) : to;
        _rate = _loadRate();
      });

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _convert(WalletConversion c, ({double rate, DateTime observedAt, String source, String id}) r) async {
    final ok = await finConfirm(
      title: "Convert?".tr,
      lines: [
        ("From".tr, FinanceMoney.format(c.amount, c.from)),
        ("Fee".tr, c.fee == 0 ? "Free".tr : FinanceMoney.format(c.fee, c.from)),
        ("Rate".tr, _rateText(c.from, c.to, r.rate)),
      ],
      total: ("You receive".tr, FinanceMoney.format(c.receive, c.to)),
      confirmLabel: "Convert".tr,
      cancelLabel: "Not now".tr,
    );
    if (!ok) return;
    String? id;
    final done = await financeDirectRun(() async {
      final reply = await FinanceWalletService.convert(config: widget.config, from: c.from, to: c.to, amount: c.amount, expected: c);
      id = reply['operationId']?.toString();
    });
    if (done && id != null && mounted) Get.off(() => WalletOperationScreen(operationId: id!));
    // The rate moved: show the new one.
    if (!done && mounted) setState(() => _rate = _loadRate());
  }

  static String _rateText(String from, String to, double rate) => ltr('1 $from = ${NumberFormat('#,##0.######').format(rate)} $to');

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _accounts,
      builder: (context, snap) {
        final int balance = _balanceOf(snap.data ?? const [], _from);
        final int? amount = FinanceAmount.parse(_amount.text, _from);
        return FutureBuilder<({double rate, DateTime observedAt, String source, String id})?>(
          future: _rate,
          builder: (context, rateSnap) {
            final r = rateSnap.data;
            final conversion = amount == null || r == null ? null : WalletRules.conversion(amount: amount, from: _from, to: _to, rate: r.rate, feePercent: cc.feePercent);
            final bool tooMuch = amount != null && snap.hasData && amount > balance;
            final bool ok = conversion != null && !tooMuch && snap.hasData;
            return FinScaffold(
              title: "Convert".tr,
              bottomBar: DsStickyBar(
                child: FinanceKycGate(
                  builder: (context, verified) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    FinMissing([if (amount == null || tooMuch) "Amount".tr, if (r == null && rateSnap.connectionState == ConnectionState.done) "Rate".tr]),
                    DsButton.primary(
                      label: "Convert".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: verified && ok ? () => _convert(conversion, r!) : null,
                    ),
                  ]),
                ),
              ),
              body: FinBody(children: [
                FinSection(
                  title: "Currencies".tr,
                  top: 0,
                  padding: paymentFormPadding,
                  children: [
                    FinPickerField<String>(label: "From".tr, value: _from, requiredMark: true, options: [for (final x in cc.currencies) (x, x)], onChanged: (v) => _pair(v, _to)),
                    FinPickerField<String>(
                      label: "To".tr,
                      value: _to,
                      requiredMark: true,
                      options: [for (final x in cc.currencies) if (x != _from) (x, x)],
                      onChanged: (v) => _pair(_from, v),
                    ),
                    FinAmountField(
                      label: "Amount".tr,
                      controller: _amount,
                      currency: _from,
                      onChanged: (_) => setState(() {}),
                      errorText: tooMuch ? "This is more than your balance.".tr : null,
                      helper: snap.hasData ? '${"Available balance".tr}: ${FinanceMoney.format(balance, _from)}' : null,
                    ),
                  ],
                ),
                if (rateSnap.connectionState != ConnectionState.done)
                  FinState.loading(rows: 1)
                else if (rateSnap.hasError)
                  FinState.error("Could not load the exchange rate.".tr, onRetry: () => setState(() => _rate = _loadRate()))
                else if (r == null)
                  FinNotice("No exchange rate is available for these currencies right now.".tr, tone: DsTone.warning)
                else
                  FinSection(
                    title: "Summary".tr,
                    footnote: '${"Rate published".tr}: ${FinanceUi.date(r.observedAt)}${r.source.isEmpty ? '' : ' · ${r.source}'}',
                    children: [
                      FinRow("Rate".tr, _rateText(_from, _to, r.rate)),
                      FinRow(
                        "Fee".tr,
                        conversion == null
                            ? ltr('${NumberFormat('#,##0.##').format(cc.feePercent)} %')
                            : (conversion.fee == 0 ? "Free".tr : FinanceMoney.format(conversion.fee, _from)),
                      ),
                      if (conversion != null) ...[
                        Divider(height: DsSpace.lg, color: c.divider),
                        FinRow("You receive".tr, FinanceMoney.format(conversion.receive, _to), strong: true),
                      ],
                    ],
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------- operation

/// The user's wallet operations still in progress (withdrawals waiting for
/// their payout); nothing when there are none.
class WalletInProgress extends StatelessWidget {
  const WalletInProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceWalletService.pendingOperations(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "In progress".tr,
          divided: true,
          padding: paymentListPadding,
          children: [for (final op in list) walletOperationTile(context, op)],
        );
      },
    );
  }
}

IconData _opIcon(String? type) => switch (type) {
      WalletOps.deposit => Icons.add_card_rounded,
      WalletOps.withdrawal => Icons.account_balance_outlined,
      WalletOps.conversion => Icons.currency_exchange_rounded,
      _ => Icons.swap_horiz_rounded,
    };

/// One operation as a list row.
Widget walletOperationTile(BuildContext context, Map<String, dynamic> op) {
  final String type = op['type']?.toString() ?? '';
  final String status = op['status']?.toString() ?? '';
  final String cur = op['currency']?.toString() ?? '';
  final int total = FinanceSummary.intOf(op['total'] ?? op['amount']);
  final int signed = type == WalletOps.deposit ? total : -total;
  final String detail = FinanceWalletService.describe(op);
  return FinListTile(
    icon: _opIcon(type),
    iconTone: DsTone.brand,
    title: WalletOps.typeLabel(type).tr,
    subtitle: [if (detail.isNotEmpty) ltr(detail), FinanceUi.date(op['createdAt'])].join(' · '),
    amount: FinanceMoney.signed(signed, cur),
    amountColor: WalletOps.ended(status) ? DsColors.of(context).textMuted : finAmountColor(context, signed),
    status: status.isEmpty ? null : status,
    statusLabel: status.isEmpty ? null : WalletOps.statusLabel(status).tr,
    onTap: () => Get.to(() => WalletOperationScreen(operationId: op['id'].toString())),
  );
}

/// One wallet operation, live: what moved, where, and where it is.
class WalletOperationScreen extends StatefulWidget {
  final String operationId;

  const WalletOperationScreen({super.key, required this.operationId});

  @override
  State<WalletOperationScreen> createState() => _WalletOperationScreenState();
}

class _WalletOperationScreenState extends State<WalletOperationScreen> {
  late Stream<Map<String, dynamic>?> _stream = FinanceWalletService.operation(widget.operationId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snap) {
        final state = FinState.of(
          snap,
          gone: "This operation is no longer available.",
          onRetry: () => setState(() => _stream = FinanceWalletService.operation(widget.operationId)),
        );
        final String type = snap.data?['type']?.toString() ?? '';
        return FinScaffold(
          title: type.isEmpty ? "Wallet".tr : WalletOps.typeLabel(type).tr,
          body: state != null ? FinBody(children: [state]) : _body(context, snap.data!),
        );
      },
    );
  }

  /// Requested -> in progress -> completed (a withdrawal); refunded or failed ends it.
  static FinTrack? _track(String type, String status) {
    if (type != WalletOps.withdrawal) return null;
    final labels = ["Requested".tr, "In progress".tr, "Completed".tr];
    if (WalletOps.ended(status)) return FinTrack(steps: labels, current: 1, ended: true, endedLabel: WalletOps.statusLabel(status).tr);
    return FinTrack(steps: labels, current: status == 'completed' ? 2 : 1);
  }

  Widget _body(BuildContext context, Map<String, dynamic> op) {
    final String type = op['type']?.toString() ?? '';
    final String status = op['status']?.toString() ?? '';
    final String cur = op['currency']?.toString() ?? '';
    String m(dynamic v, [String? currency]) => FinanceMoney.format(FinanceSummary.intOf(v), currency ?? cur);
    final int total = FinanceSummary.intOf(op['total'] ?? op['amount']);
    final bool deposit = type == WalletOps.deposit;
    final String reason = (op['reason'] ?? '').toString();
    final String reference = (op['reference'] ?? '').toString();
    final String payoutReference = (op['payoutReference'] ?? op['providerReference'] ?? '').toString();
    final Map<String, dynamic>? destination = op['destination'] is Map ? Map<String, dynamic>.from(op['destination'] as Map) : null;
    final Map<String, dynamic>? gateway = op['gateway'] is Map ? Map<String, dynamic>.from(op['gateway'] as Map) : null;
    final details = <(String, String)>[
      ("Type".tr, WalletOps.typeLabel(type).tr),
      ((deposit ? "Amount" : (type == WalletOps.conversion ? "From" : "You receive")).tr, m(op['amount'])),
      if (!deposit) ("Fee".tr, FinanceSummary.intOf(op['fee']) == 0 ? "Free".tr : m(op['fee'])),
      if (type == WalletOps.withdrawal) ("Taken from your wallet".tr, m(total)),
      if (destination != null) ("To".tr, ltr(FinanceDestination.describe(destination))),
      if (destination?['holderName'] != null) ("Account holder".tr, destination!['holderName'].toString()),
      if (gateway != null) ("Paid with".tr, FinanceGateways.label('${gateway['method'] ?? ''}')),
      if (gateway?['reference'] != null) ("Payment reference".tr, ltrRef(gateway!['reference'])),
      if (type == WalletOps.conversion && op['rate'] is num)
        ("Rate".tr, ltr('1 $cur = ${NumberFormat('#,##0.######').format(op['rate'])} ${op['toCurrency'] ?? ''}')),
      if (type == WalletOps.conversion) ("You receive".tr, m(op['receiveAmount'], op['toCurrency']?.toString())),
      ("Date".tr, FinanceUi.date(op['createdAt'])),
      if (op['completedAt'] != null) ("Completed on".tr, FinanceUi.date(op['completedAt'])),
      if (reference.isNotEmpty) ("Reference".tr, ltrRef(reference)),
      if (payoutReference.isNotEmpty) ("Payout reference".tr, ltrRef(payoutReference)),
    ];
    final track = _track(type, status);
    return FinBody(children: [
      FinHeader(
        overline: WalletOps.typeLabel(type).tr,
        title: FinanceMoney.signed(deposit ? total : -total, cur),
        subtitle: FinanceWalletService.describe(op).isEmpty ? null : ltr(FinanceWalletService.describe(op)),
        status: status.isEmpty ? null : status,
        statusLabel: WalletOps.statusLabel(status).tr,
        icon: _opIcon(type),
        titleColor: deposit ? finAmountColor(context, 1) : null,
        below: reason.isEmpty ? null : DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: financeReasonText(reason).tr),
      ),
      if (track != null) FinSection(title: "Status".tr, padding: const EdgeInsets.all(DsSpace.lg), children: [track]),
      if (type == WalletOps.withdrawal && status == 'pending')
        FinNotice("Spideli Finance is paying out this withdrawal. If it cannot, your wallet is refunded. This page updates by itself.".tr),
      if (status == 'reversed') FinNotice("This withdrawal could not be paid out: the money is back in your wallet.".tr, tone: DsTone.warning),
      FinSection(title: "Details".tr, divided: true, children: [for (final (l, v) in details) FinRow(l, v)]),
      if (status == 'completed' && reference.isNotEmpty) ...[
        const DsGap(FinSpace.section),
        PaymentReceiptButton(title: "${WalletOps.typeLabel(type).tr} · ${"Receipt".tr}", reference: reference, lines: details),
      ],
    ]);
  }
}
