import 'dart:async';

import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart' show activeWallets;
import 'package:customer/service/finance_payment_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_transfer_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ------------------------------------------------------------------- shared
// Shared by the transfer and bill screens.

/// A section of list tiles: the tiles carry their own vertical padding.
const EdgeInsets paymentListPadding = EdgeInsets.symmetric(horizontal: DsSpace.lg);

/// A section of form fields: each field carries its own bottom spacing.
const EdgeInsets paymentFormPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0);

/// The amount of a transfer or bill payment in a list: green in, default
/// out, muted when no money moved in the end (failed, cancelled, expired,
/// refunded).
Color paymentAmountColor(BuildContext context, String? status, num signed) =>
    PaymentFlow.ended(status) ? DsColors.of(context).textMuted : finAmountColor(context, signed);

/// "Total paid" once the money moved (paid, processing, completed,
/// refunded after); "Total" when it never moved.
String paymentTotalLabel(String status) => (const ['processing', 'completed', 'reversed'].contains(status) ? "Total paid" : "Total").tr;

/// Where a transfer or bill payment is in [DirectFlow.steps]: paid, then
/// processing (until Spideli pays it out), then completed. An ended
/// payment (failed, cancelled, refunded) shows how it ended after the
/// payment. Null for a status outside the flow.
FinTrack? paymentTrack(String status) {
  const steps = DirectFlow.steps;
  final labels = [for (final s in steps) DirectFlow.label(s).tr];
  if (PaymentFlow.ended(status)) return FinTrack(steps: labels, current: 1, ended: true, endedLabel: PaymentFlow.label(status).tr);
  final int at = steps.indexOf(status);
  return at < 0 ? null : FinTrack(steps: labels, current: at);
}

/// Runs [action] behind the loader; a refusal becomes its translated
/// message (the reasons the app raises itself included, [FinancePayErrors]).
Future<bool> financeDirectRun(Future<void> Function() action, {String? success}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await action();
    ShowToastDialog.closeLoader();
    if (success != null) ShowToastDialog.showToast(success.tr);
    return true;
  } catch (e) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(FinancePayErrors.messageKey(e is FinanceException ? e.reason : null).tr);
    return false;
  }
}

/// The confirmation step: the figures the app computed from the admin's
/// settings, then the identity check (above the threshold) and the payment
/// method. With [expiresAt] the price is re-checked when it comes, so
/// Confirm never stays active on an expired price; [onRestart] then leads
/// back to the form.
class PaymentConfirmCard extends StatefulWidget {
  final List<(String, String)> lines;
  final int total;
  final String currency;
  final DateTime? expiresAt;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onCancel;
  final VoidCallback? onRestart;

  const PaymentConfirmCard({
    super.key,
    required this.lines,
    required this.total,
    required this.currency,
    required this.expiresAt,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.onRestart,
  });

  @override
  State<PaymentConfirmCard> createState() => _PaymentConfirmCardState();
}

class _PaymentConfirmCardState extends State<PaymentConfirmCard> {
  Timer? _expiry;

  bool get _expired => widget.expiresAt != null && !DateTime.now().isBefore(widget.expiresAt!);

  /// Rebuilds the card the moment the request expires.
  void _arm() {
    _expiry?.cancel();
    final at = widget.expiresAt;
    if (at == null) return;
    final left = at.difference(DateTime.now());
    if (left > Duration.zero) _expiry = Timer(left, () => mounted ? setState(() {}) : null);
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(PaymentConfirmCard old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) _arm();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool expired = _expired;
    final w = widget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Check before you confirm".tr,
          children: [
            for (final (l, v) in w.lines) FinRow(l, v),
            Divider(height: DsSpace.lg, color: c.divider),
            FinRow("Total to pay".tr, FinanceMoney.format(w.total, w.currency), strong: true),
            if (w.expiresAt != null && !expired)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: c.textSecondary),
                  const DsGap(DsSpace.xs),
                  Expanded(
                    child: Text(
                      '${"Confirm before".tr} ${ltr(DateFormat('HH:mm').format(w.expiresAt!))}',
                      style: DsTypography.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ]),
              ),
          ],
        ),
        if (expired)
          FinNotice(
            "This request expired. Start again to get an up-to-date price.".tr,
            tone: DsTone.warning,
            actionLabel: w.onRestart == null ? null : "Start again".tr,
            onAction: w.onRestart,
          )
        else ...[
          const DsGap(DsSpace.lg),
          FinanceKycGate(
            builder: (context, verified) => DsButton.primary(
              label: w.confirmLabel,
              icon: Icons.lock_outline_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: verified ? w.onConfirm : null,
            ),
          ),
        ],
        const DsGap(DsSpace.xs),
        DsButton.ghost(label: "Cancel".tr, expand: true, onPressed: w.onCancel),
      ],
    );
  }
}

/// "Share the receipt": the PDF is written and the share sheet opened; a
/// failure (storage, share sheet) is said, never a silent tap.
class PaymentReceiptButton extends StatefulWidget {
  final String title;
  final String reference;
  final List<(String, String)> lines;
  final String? highlight;

  const PaymentReceiptButton({super.key, required this.title, required this.reference, required this.lines, this.highlight});

  @override
  State<PaymentReceiptButton> createState() => _PaymentReceiptButtonState();
}

class _PaymentReceiptButtonState extends State<PaymentReceiptButton> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await FinanceTransferService.shareReceipt(title: widget.title, reference: widget.reference, lines: widget.lines, highlight: widget.highlight);
    } catch (_) {
      ShowToastDialog.showToast("Could not share the receipt. Please try again.".tr);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => DsButton.secondary(
        label: "Share the receipt".tr,
        icon: Icons.ios_share_rounded,
        expand: true,
        loading: _busy,
        onPressed: _busy ? null : _share,
      );
}

// ------------------------------------------------------------------ overview

/// Spideli Finance > Send money. `platform_settings/transfers` must exist (admin).
class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  static IconData icon(String channel) => switch (channel) {
        TransferChannel.internal => Icons.person_outline_rounded,
        TransferChannel.mobileMoney => Icons.phone_android_rounded,
        TransferChannel.wave => Icons.waves_rounded,
        TransferChannel.bank => Icons.account_balance_outlined,
        _ => Icons.send_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return FinConfig<TransferConfig>(
      load: FinanceTransferService.config,
      builder: (context, st) {
        final cfg = st.config;
        final placeholder = st.placeholder(Icons.send_rounded, "Transfers are not available yet.".tr);
        return FinScaffold(
          title: "Money transfer".tr,
          body: FinBody(children: [
            if (placeholder != null || cfg == null)
              placeholder ?? FinState.loading()
            else ...[
              FinSection(
                title: "Send to".tr,
                top: 0,
                divided: true,
                padding: paymentListPadding,
                children: [
                  for (final c in cfg.channels.values)
                    FinListTile(
                      icon: icon(c.key),
                      iconTone: DsTone.brand,
                      title: TransferChannel.label(c.key).tr,
                      subtitle: c.delay.isEmpty ? null : c.delay,
                      chevron: true,
                      onTap: () => Get.to(() => TransferFormScreen(config: cfg, channel: c.key)),
                    ),
                ],
              ),
              _Beneficiaries(config: cfg),
              _History(config: cfg),
            ],
          ]),
        );
      },
    );
  }
}

class _Beneficiaries extends StatelessWidget {
  final TransferConfig config;

  const _Beneficiaries({required this.config});

  Future<void> _remove(Map<String, dynamic> b) async {
    final String detail = (b['detail'] ?? '').toString();
    final ok = await finConfirm(
      title: "Remove this recipient?".tr,
      message: "You can add them again with your next transfer.".tr,
      lines: [
        ("Recipient".tr, b['displayName']?.toString() ?? '-'),
        if (detail.isNotEmpty) (TransferChannel.label(b['channel'].toString()).tr, ltr(detail)),
      ],
      confirmLabel: "Remove".tr,
      destructive: true,
    );
    if (ok) await financeDirectRun(() => FinanceTransferService.deleteBeneficiary(b['id'].toString()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceTransferService.beneficiaries(),
      builder: (context, snap) {
        final list = (snap.data ?? const []).where((b) => config.channels.containsKey(b['channel'])).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Recent recipients".tr,
          divided: true,
          padding: paymentListPadding,
          children: [
            for (final b in list)
              FinListTile(
                icon: TransfersScreen.icon(b['channel'].toString()),
                title: b['displayName']?.toString() ?? '-',
                subtitle: [
                  TransferChannel.label(b['channel'].toString()).tr,
                  if ((b['detail'] ?? '').toString().isNotEmpty) ltr(b['detail'].toString()),
                ].join(' · '),
                trailing: DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, onPressed: () => _remove(b)),
                onTap: () => Get.to(() => TransferFormScreen(config: config, channel: b['channel'].toString(), beneficiary: b)),
              ),
          ],
        );
      },
    );
  }
}

/// Filters of the transfer history, applied to what is loaded.
enum _HistoryFilter { all, sent, received, inProgress, completed, notCompleted }

/// The latest transfers ([FinanceTransferService.transfers] reads at most
/// [_limit]), filtered on the phone: direction or outcome.
class _History extends StatefulWidget {
  final TransferConfig config;

  const _History({required this.config});

  static const int _limit = 50;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late Stream<List<Map<String, dynamic>>> _stream = FinanceTransferService.transfers();
  _HistoryFilter _filter = _HistoryFilter.all;

  static String _label(_HistoryFilter f) => switch (f) {
        _HistoryFilter.all => "All",
        _HistoryFilter.sent => "Sent",
        _HistoryFilter.received => "Received",
        _HistoryFilter.inProgress => "In progress",
        _HistoryFilter.completed => "Completed",
        _HistoryFilter.notCompleted => "Not completed",
      };

  bool _matches(Map<String, dynamic> t, String uid) {
    final String status = t['status']?.toString() ?? '';
    return switch (_filter) {
      _HistoryFilter.all => true,
      _HistoryFilter.sent => t['senderId'] == uid,
      _HistoryFilter.received => t['senderId'] != uid,
      _HistoryFilter.inProgress => PaymentFlow.steps.contains(status) && status != 'completed',
      _HistoryFilter.completed => status == 'completed',
      _HistoryFilter.notCompleted => PaymentFlow.ended(status),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return FinState.error("Could not load your transfers.".tr, onRetry: () => setState(() => _stream = FinanceTransferService.transfers()));
        }
        if (!snap.hasData) return FinState.loading();
        final all = snap.data!;
        if (all.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "You have not sent or received money yet.".tr);
        final uid = FinanceService.uid;
        final shown = all.where((t) => _matches(t, uid)).toList();
        return Padding(
          padding: const EdgeInsets.only(top: FinSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxs),
                child: Semantics(header: true, child: Text("History".tr.toUpperCase(), style: FinText.sectionTitle(context))),
              ),
              const DsGap(DsSpace.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in _HistoryFilter.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                      child: ChoiceChip(label: Text(_label(f).tr), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                    ),
                ]),
              ),
              if (shown.isEmpty)
                FinState.empty(Icons.filter_alt_off_outlined, "No transfer matches this filter.".tr,
                    actionLabel: "Show all".tr, onAction: () => setState(() => _filter = _HistoryFilter.all))
              else
                FinSection(
                  top: DsSpace.md,
                  divided: true,
                  padding: paymentListPadding,
                  // The history reads the latest transfers only: say so
                  // rather than let the list look complete.
                  footnote: all.length >= _History._limit ? "Showing your latest @n transfers.".trParams({'n': '${_History._limit}'}) : null,
                  children: [for (final t in shown) _row(context, t, uid)],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> t, String uid) {
    final bool out = t['senderId'] == uid;
    final String cur = t['currency']?.toString() ?? '';
    // What left the sender's wallet (fee included), as on the transfer page;
    // what reached the recipient for an incoming transfer.
    final int amount = FinanceSummary.intOf(out ? (t['total'] ?? t['amount']) : (t['receiveAmount'] ?? t['amount']));
    final int signed = out ? -amount : amount;
    final String status = t['status']?.toString() ?? '';
    final String channel = t['channel']?.toString() ?? '';
    return FinListTile(
      icon: out ? Icons.north_east_rounded : Icons.south_west_rounded,
      iconTone: out ? DsTone.neutral : DsTone.success,
      title: out ? (t['recipientName']?.toString() ?? '-') : (t['senderName']?.toString() ?? '-'),
      subtitle: [if (channel.isNotEmpty) TransferChannel.label(channel).tr, FinanceUi.date(t['createdAt'])].join(' · '),
      amount: FinanceMoney.signed(signed, cur),
      amountColor: paymentAmountColor(context, status, signed),
      status: status.isEmpty ? null : status,
      statusLabel: status.isEmpty ? null : PaymentFlow.label(status).tr,
      onTap: () => Get.to(() => TransferScreen(transferId: t['id'].toString(), config: widget.config)),
    );
  }
}

// --------------------------------------------------------------------- form

/// Recipient, amount and note for one channel; the server then validates
/// the recipient and prices the transfer for confirmation.
class TransferFormScreen extends StatefulWidget {
  final TransferConfig config;
  final String channel;
  final Map<String, dynamic>? beneficiary;

  /// Prefilled amount (minor units) and currency: "Start again" after an
  /// expired request.
  final int? amount;
  final String? currency;

  const TransferFormScreen({super.key, required this.config, required this.channel, this.beneficiary, this.amount, this.currency});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _contact = TextEditingController();
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _accounts = FinanceService.myAccounts();
  bool _byEmail = true;
  String? _operator;
  String? _bank;
  late String _currency = widget.config.currencies.contains(widget.currency) ? widget.currency! : widget.config.currencies.first;
  bool _save = true;

  ChannelConfig get _ch => widget.config.channels[widget.channel]!;

  @override
  void initState() {
    super.initState();
    final r = widget.beneficiary?['recipient'];
    if (r is Map) {
      _byEmail = (r['email'] ?? '').toString().isNotEmpty || (r['phone'] ?? '').toString().isEmpty;
      _contact.text = (r['email'] ?? r['phone'] ?? r['number'] ?? '').toString();
      _name.text = (r['holderName'] ?? r['name'] ?? '').toString();
      _account.text = (r['accountNumber'] ?? '').toString();
      if (_ch.operators.contains(r['operator'])) _operator = r['operator'].toString();
      if (_ch.banks.any((b) => b.code == r['bankCode'])) _bank = r['bankCode'].toString();
      _save = false;
    }
    _operator ??= _ch.operators.isEmpty ? null : _ch.operators.first;
    if (widget.amount != null && widget.amount! > 0) _amount.text = FinanceAmount.input(widget.amount, _currency);
  }

  @override
  void dispose() {
    for (final c in [_contact, _name, _account, _amount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The recipient as the server expects it, or null when incomplete.
  Map<String, dynamic>? get _recipient {
    final String contact = _contact.text.trim();
    switch (widget.channel) {
      case TransferChannel.internal:
        if (_byEmail) return RecipientCheck.email(contact) ? {'email': contact.toLowerCase()} : null;
        return RecipientCheck.phone(contact) ? {'phone': RecipientCheck.normalizePhone(contact)} : null;
      case TransferChannel.mobileMoney:
        return _operator != null && RecipientCheck.phone(contact)
            ? {'operator': _operator, 'number': RecipientCheck.normalizePhone(contact), if (_name.text.trim().isNotEmpty) 'name': _name.text.trim()}
            : null;
      case TransferChannel.wave:
        return RecipientCheck.phone(contact) ? {'number': RecipientCheck.normalizePhone(contact), if (_name.text.trim().isNotEmpty) 'name': _name.text.trim()} : null;
      case TransferChannel.bank:
        return _bank != null && RecipientCheck.holderName(_name.text) && RecipientCheck.bankAccount(_account.text)
            ? {'bankCode': _bank, 'holderName': _name.text.trim(), 'accountNumber': _account.text.replaceAll(RegExp(r'\s'), '').toUpperCase()}
            : null;
    }
    return null;
  }

  /// The user's own email typed as the recipient (refused by the server too).
  bool get _toSelf {
    if (widget.channel != TransferChannel.internal || !_byEmail) return false;
    final String mine = Constant.userModel?.email?.toLowerCase() ?? '';
    return mine.isNotEmpty && _contact.text.trim().toLowerCase() == mine;
  }

  String? _amountProblem() => FinanceAmount.problem(_amount.text, _currency, min: _ch.minFor(_currency), max: _ch.maxFor(_currency));

  /// What is still needed before Continue, in the order of the form.
  List<String> _missing(int? amount) {
    final String contact = _contact.text.trim();
    final bool internal = widget.channel == TransferChannel.internal;
    final bool contactOk = internal && _byEmail ? RecipientCheck.email(contact) && !_toSelf : RecipientCheck.phone(contact);
    return [
      if (widget.channel == TransferChannel.mobileMoney && _operator == null) "Operator".tr,
      if (widget.channel == TransferChannel.bank) ...[
        if (_bank == null) "Bank".tr,
        if (!RecipientCheck.holderName(_name.text)) "Account holder".tr,
        if (!RecipientCheck.bankAccount(_account.text)) "Account number or IBAN".tr,
      ] else if (!contactOk)
        (internal && _byEmail ? "Email address" : "Phone number").tr,
      if (amount == null || _amountProblem() != null) "Amount".tr,
    ];
  }

  /// The recipient as stored on the transfer: a bank account with its
  /// bank's name and its masked end for display.
  Map<String, dynamic> _stored(Map<String, dynamic> r) {
    if (widget.channel != TransferChannel.bank) return r;
    final String account = r['accountNumber'].toString();
    return {...r, 'bankName': _ch.banks.firstWhere((b) => b.code == r['bankCode']).name, 'accountMasked': FinanceDestination.mask(account)};
  }

  /// The name shown for an external recipient: the typed name, else the number.
  String _externalName(Map<String, dynamic> r) {
    final String typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    return (r['holderName'] ?? r['number'] ?? '-').toString();
  }

  Future<void> _continue() async {
    final recipient = _recipient;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (recipient == null) return ShowToastDialog.showToast("Check the recipient details.".tr);
    if (amount == null || _amountProblem() != null) return ShowToastDialog.showToast("Check the amount.".tr);
    if (_toSelf) return ShowToastDialog.showToast("You cannot send money to yourself.".tr);
    TransferRecipient? found;
    // An internal transfer goes to an existing Spideli account: find it and
    // show its name before anything is paid.
    if (widget.channel == TransferChannel.internal) {
      final ok = await financeDirectRun(() async {
        found = await FinanceTransferService.findRecipient(email: recipient['email']?.toString(), phone: recipient['phone']?.toString());
      });
      if (!ok || found == null) return;
    }
    final draft = TransferDraft(
      channel: widget.channel,
      currency: _currency,
      amount: amount,
      fee: _ch.fee.feeFor(amount, _currency),
      recipient: _stored(recipient),
      recipientName: found?.name ?? _externalName(recipient),
      recipientId: found?.uid,
      recipientToken: found?.fcmToken ?? '',
      note: _note.text.trim(),
      saveBeneficiary: _save,
    );
    if (mounted) Get.to(() => TransferConfirmScreen(config: widget.config, draft: draft));
  }

  /// The amount with its limits and, when the wallet can pay the transfer
  /// and holds this currency, "Available balance: 12 500 XAF".
  Widget _amountField() {
    final int min = _ch.minFor(_currency);
    final int? max = _ch.maxFor(_currency);
    Widget field(String? available) {
      final parts = [?FinanceAmount.range(min, max, _currency), ?available];
      return FinAmountField(
        label: "Amount".tr,
        controller: _amount,
        currency: _currency,
        currencies: widget.config.currencies,
        onCurrencyChanged: (v) => setState(() => _currency = v),
        onChanged: (_) => setState(() {}),
        min: min,
        max: max,
        helper: parts.isEmpty ? null : parts.join(' · '),
      );
    }

    if (!widget.config.sourceMethods.contains('wallet')) return field(null);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _accounts,
      builder: (context, snap) {
        final wallet = activeWallets(snap.data ?? const []).where((w) => w['currency'] == _currency).firstOrNull;
        return field(wallet == null ? null : '${"Available balance".tr}: ${FinanceMoney.format((wallet['balance'] as num?) ?? 0, _currency)}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final ch = _ch;
    final bool internal = widget.channel == TransferChannel.internal;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final bool amountOk = amount != null && _amountProblem() == null;
    final int fee = amount == null ? 0 : ch.fee.feeFor(amount, _currency);
    final String contact = _contact.text.trim();
    final bool byEmail = internal && _byEmail;
    final String? contactError = contact.isEmpty
        ? null
        : _toSelf
            ? "You cannot send money to yourself.".tr
            : byEmail
                ? (RecipientCheck.email(contact) ? null : "Enter a valid email address, like name@example.com.".tr)
                : (RecipientCheck.phone(contact) ? null : "Enter 8 to 15 digits, with the country code.".tr);
    final String holder = _name.text.trim();
    final String account = _account.text.trim();
    final missing = _missing(amount);
    return FinScaffold(
      title: "${"Send to".tr}: ${TransferChannel.label(widget.channel).tr}",
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
                onPressed: verified && missing.isEmpty && _recipient != null && amountOk ? _continue : null,
              ),
            ],
          ),
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            title: "Recipient".tr,
            top: 0,
            padding: paymentFormPadding,
            footnote: internal
                ? "We check that this person has a Spideli account and show you their name before you confirm.".tr
                : "Check the number: money sent to the wrong account may not be recoverable.".tr,
            children: [
              if (internal) ...[
                DsSegmentedTabs(
                  segments: [DsSegment("Email".tr), DsSegment("Phone".tr)],
                  index: _byEmail ? 0 : 1,
                  onChanged: (i) => setState(() => _byEmail = i == 0),
                ),
                const DsGap(DsSpace.md),
              ],
              if (widget.channel == TransferChannel.mobileMoney)
                FinPickerField<String>(
                  label: "Operator".tr,
                  value: _operator,
                  requiredMark: true,
                  options: [for (final o in ch.operators) (o, o)],
                  onChanged: (v) => setState(() => _operator = v),
                ),
              if (widget.channel == TransferChannel.bank) ...[
                FinPickerField<String>(
                  label: "Bank".tr,
                  value: _bank,
                  requiredMark: true,
                  searchHint: "Search for a bank".tr,
                  options: [for (final b in ch.banks) (b.code, b.name)],
                  onChanged: (v) => setState(() => _bank = v),
                ),
                DsTextField(
                  label: "Account holder".tr,
                  controller: _name,
                  requiredMark: true,
                  textCapitalization: TextCapitalization.words,
                  errorText: holder.isNotEmpty && !RecipientCheck.holderName(holder) ? "Enter the account holder's full name.".tr : null,
                  onChanged: (_) => setState(() {}),
                ),
                DsTextField(
                  label: "Account number or IBAN".tr,
                  controller: _account,
                  requiredMark: true,
                  textCapitalization: TextCapitalization.characters,
                  helper: "6 to 34 letters or digits, or an IBAN".tr,
                  errorText: account.isNotEmpty && !RecipientCheck.bankAccount(account) ? "This account number is not valid.".tr : null,
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                DsTextField(
                  label: (byEmail ? "Email address" : "Phone number").tr,
                  hint: byEmail ? null : "With the country code".tr,
                  controller: _contact,
                  requiredMark: true,
                  keyboardType: byEmail ? TextInputType.emailAddress : TextInputType.phone,
                  errorText: contactError,
                  onChanged: (_) => setState(() {}),
                ),
                if (!internal) DsTextField(label: "Recipient name (optional)".tr, controller: _name, textCapitalization: TextCapitalization.words),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _save,
                onChanged: (v) => setState(() => _save = v ?? false),
                title: Text("Save this recipient".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
          FinSection(
            title: "Amount".tr,
            padding: paymentFormPadding,
            children: [
              _amountField(),
              DsTextField(label: "Note for the recipient (optional)".tr, controller: _note, maxLength: 140),
            ],
          ),
          if (amountOk)
            FinSection(
              title: "Summary".tr,
              footnote: "You check everything, and the recipient's name, before you pay.".tr,
              children: [
                FinRow("Amount".tr, FinanceMoney.format(amount, _currency)),
                FinRow("Fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, _currency)),
                if (ch.delay.isNotEmpty) FinRow("Delivery".tr, ch.delay),
                Divider(height: DsSpace.lg, color: c.divider),
                FinRow("Total".tr, FinanceMoney.format(amount + fee, _currency), strong: true),
              ],
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ confirm

/// The transfer to confirm, with the app's own figures: the recipient (a
/// Spideli user's name as found in their account), the amount, the fee and
/// the total; then the identity check above the threshold, and the payment.
class TransferConfirmScreen extends StatefulWidget {
  final TransferConfig config;
  final TransferDraft draft;

  const TransferConfirmScreen({super.key, required this.config, required this.draft});

  @override
  State<TransferConfirmScreen> createState() => _TransferConfirmScreenState();
}

class _TransferConfirmScreenState extends State<TransferConfirmScreen> {
  TransferDraft get d => widget.draft;

  List<(String, String)> get _lines => [
        ("To".tr, d.recipientName),
        if (d.detail.trim().isNotEmpty) ("Recipient details".tr, ltr(d.detail)),
        ("Channel".tr, TransferChannel.label(d.channel).tr),
        ("Amount".tr, FinanceMoney.format(d.amount, d.currency)),
        ("Fee".tr, d.fee == 0 ? "Free".tr : FinanceMoney.format(d.fee, d.currency)),
        if ((widget.config.channels[d.channel]?.delay ?? '').isNotEmpty) ("Delivery".tr, widget.config.channels[d.channel]!.delay),
        if (d.note.isNotEmpty) ("Note".tr, d.note),
      ];

  Future<void> _confirm() async {
    // Before anything is charged: a restricted account is told now.
    if (!await financeDirectRun(() => FinancePaymentService.requireAllowed('transfers'))) return;
    if (widget.config.needsReauth(d.amount, d.currency) && !await FinanceReauth.confirm()) return;
    if (!mounted) return;
    String? transferId;
    await FinancePaySheet.show(
      context,
      title: "${"Send to".tr} ${d.recipientName}",
      amount: d.total,
      currency: d.currency,
      methods: widget.config.sourceMethods,
      // The sender sent money: say so, not "Payment received".
      doneTitle: d.channel == 'internal' ? "Money sent".tr : null,
      doneMessage: d.channel == 'internal' ? "@name received the money.".trParams({'name': d.recipientName}) : null,
      submit: (payment) async {
        final reply = await FinanceTransferService.send(widget.config, d, payment.funding);
        transferId = reply['transferId']?.toString();
        return reply;
      },
    );
    if (transferId != null && mounted) {
      // The transfer page replaces this confirmation AND the form below it:
      // Back then returns to where the user started, never to a filled form
      // that invites an accidental second send.
      Get.back();
      Get.off(() => TransferScreen(transferId: transferId!, config: widget.config));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Transfer".tr,
      body: FinBody(children: [
        FinHeader(
          overline: TransferChannel.label(d.channel).tr,
          title: FinanceMoney.format(d.total, d.currency),
          subtitle: '${"To".tr} ${d.recipientName}',
          icon: Icons.north_east_rounded,
          below: d.internal
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsBadge(label: "Spideli account found".tr, tone: DsTone.success, icon: Icons.verified_rounded, small: true),
                )
              : null,
        ),
        PaymentConfirmCard(
          lines: _lines,
          total: d.total,
          currency: d.currency,
          expiresAt: null,
          confirmLabel: "Confirm and send".tr,
          onConfirm: _confirm,
          onCancel: () async => Get.back(),
        ),
        if (!d.internal) FinNotice("The money leaves your wallet now. Spideli Finance then sends it to the recipient; you can follow it here.".tr),
      ]),
    );
  }
}

// ----------------------------------------------------------------- transfer

/// One transfer: status, details and receipt; the sender of an external
/// transfer may ask to cancel it while Spideli has not taken it yet.
class TransferScreen extends StatefulWidget {
  final String transferId;
  final TransferConfig config;

  const TransferScreen({super.key, required this.transferId, required this.config});

  static String recipientDetail(Map<String, dynamic> t) {
    final r = t['recipient'] is Map ? Map<String, dynamic>.from(t['recipient'] as Map) : const <String, dynamic>{};
    return switch (t['channel']) {
      TransferChannel.internal => (r['email'] ?? r['phone'] ?? '').toString(),
      TransferChannel.mobileMoney => '${r['operator'] ?? ''} · ${r['number'] ?? ''}',
      TransferChannel.wave => 'Wave · ${r['number'] ?? ''}',
      TransferChannel.bank => '${r['bankName'] ?? ''} · ${r['accountMasked'] ?? ''}',
      _ => '',
    };
  }

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late Stream<Map<String, dynamic>?> _stream = FinanceTransferService.transfer(widget.transferId);

  String get transferId => widget.transferId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snap) {
        final state = FinState.of(
          snap,
          gone: "This transfer is no longer available.",
          onRetry: () => setState(() => _stream = FinanceTransferService.transfer(transferId)),
        );
        return FinScaffold(
          title: "Transfer".tr,
          body: state != null ? FinBody(children: [state]) : _body(context, snap.data!),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> t) {
    final String status = t['status']?.toString() ?? '';
    final String cur = t['currency']?.toString() ?? '';
    final bool out = t['senderId'] == FinanceService.uid;
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    final int amount = FinanceSummary.intOf(t['amount']);
    final int total = FinanceSummary.intOf(t['total'] ?? amount);
    final String counterpart = out ? (t['recipientName']?.toString() ?? '-') : (t['senderName']?.toString() ?? '-');
    final details = <(String, String)>[
      ((out ? "To" : "From").tr, counterpart),
      if (out && TransferScreen.recipientDetail(t).trim().isNotEmpty) ("Recipient details".tr, ltr(TransferScreen.recipientDetail(t))),
      ("Channel".tr, TransferChannel.label(t['channel']?.toString() ?? '').tr),
      ("Amount".tr, m(out ? t['amount'] : (t['receiveAmount'] ?? t['amount']))),
      if (out) ("Fee".tr, FinanceSummary.intOf(t['fee']) == 0 ? "Free".tr : m(t['fee'])),
      if (out && t['receiveAmount'] != null && FinanceSummary.intOf(t['receiveAmount']) != amount) ("The recipient receives".tr, m(t['receiveAmount'])),
      if ((t['note'] ?? '').toString().isNotEmpty) ("Note".tr, t['note'].toString()),
    ];
    final String channel = TransferChannel.label(t['channel']?.toString() ?? '').tr;
    final String reason = (t['reason'] ?? '').toString();
    final String reference = (t['reference'] ?? '').toString();
    final bool verified = out && t['recipientVerified'] == true;
    final track = paymentTrack(status);
    final bool cancelAsked = t['cancelRequested'] == true && status == 'processing';
    return FinBody(
      children: [
        FinHeader(
          overline: channel.isEmpty ? null : channel,
          title: FinanceMoney.signed(out ? -total : FinanceSummary.intOf(t['receiveAmount'] ?? amount), cur),
          subtitle: '${(out ? "To" : "From").tr} $counterpart',
          status: status.isEmpty ? null : status,
          statusLabel: PaymentFlow.label(status).tr,
          icon: out ? Icons.north_east_rounded : Icons.south_west_rounded,
          titleColor: out ? null : finAmountColor(context, 1),
          below: !verified && reason.isEmpty
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (verified)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DsBadge(label: "Recipient verified".tr, tone: DsTone.success, icon: Icons.verified_rounded, small: true),
                    ),
                  if (verified && reason.isNotEmpty) const DsGap(DsSpace.sm),
                  if (reason.isNotEmpty) DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: financeReasonText(reason).tr),
                ]),
        ),
        if (track != null) FinSection(title: "Status".tr, padding: const EdgeInsets.all(DsSpace.lg), children: [track]),
        if (out && (status == 'reversed' || status == 'cancelled'))
          FinNotice("This transfer was not sent: the money is back in your wallet.".tr, tone: DsTone.info),
        if (out && status == 'processing')
          FinNotice(
            (cancelAsked
                    ? "You asked to cancel this transfer. Spideli Finance refunds it if it was not sent yet."
                    : "Your payment was received. Spideli Finance is sending the money; this page updates when it is done.")
                .tr,
            tone: cancelAsked ? DsTone.warning : DsTone.info,
          ),
        FinSection(
          title: "Details".tr,
          divided: true,
          children: [
            for (final (l, v) in details) FinRow(l, v),
            if (out) FinRow(paymentTotalLabel(status), m(total), strong: true),
            FinRow("Date".tr, FinanceUi.date(t['createdAt'])),
            if (t['completedAt'] != null) FinRow("Completed on".tr, FinanceUi.date(t['completedAt'])),
            if (reference.isNotEmpty) FinRow("Reference".tr, ltrRef(reference)),
          ],
        ),
        if (TransferPlans.canRequestCancel(t, FinanceService.uid)) ...[
          const DsGap(DsSpace.lg),
          DsButton.ghost(
            label: "Cancel this transfer".tr,
            icon: Icons.close_rounded,
            expand: true,
            onPressed: () async {
              final ok = await finConfirm(
                title: "Cancel this transfer?".tr,
                message: "Spideli Finance cancels it and refunds your wallet if the money was not sent yet.".tr,
                lines: [("To".tr, counterpart), ("Total".tr, m(total))],
                confirmLabel: "Cancel this transfer".tr,
                destructive: true,
              );
              if (ok) await financeDirectRun(() => FinanceTransferService.requestCancel(transferId), success: "Cancellation requested");
            },
          ),
        ],
        if (status == 'completed' || status == 'reversed') ...[
          const DsGap(FinSpace.section),
          PaymentReceiptButton(
            title: "Transfer receipt".tr,
            reference: t['reference']?.toString() ?? t['id'].toString(),
            lines: [
              ("Reference".tr, t['reference']?.toString() ?? t['id'].toString()),
              ("Status".tr, PaymentFlow.label(status).tr),
              ("Date".tr, FinanceUi.date(t['completedAt'] ?? t['createdAt'])),
              ((out ? "From" : "To").tr, out ? (t['senderName']?.toString() ?? '') : (t['recipientName']?.toString() ?? '')),
              ...details,
              if (out) ("Total paid".tr, m(total)),
            ],
          ),
        ],
      ],
    );
  }
}
