import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_transfer_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
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

String paymentDay(dynamic v) {
  final d = FinanceGroupService.toDate(v);
  return d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));
}

String paymentDate(dynamic v) {
  final d = FinanceGroupService.toDate(v);
  return d == null ? '-' : ltr(DateFormat('dd MMM yyyy, HH:mm').format(d));
}

/// The amount of a transfer or bill payment in a list: green in, default
/// out, muted when no money moved in the end (failed, cancelled, expired,
/// refunded).
Color paymentAmountColor(BuildContext context, String? status, num signed) =>
    PaymentFlow.ended(status) ? DsColors.of(context).textMuted : finAmountColor(context, signed);

/// Where a transfer or bill payment is in [PaymentFlow.steps]. An ended
/// payment (failed, cancelled, expired, refunded) shows how it ended; a
/// refund follows a completed payment, the other ends stop after the
/// request. Null for a status outside the flow.
FinTrack? paymentTrack(String status) {
  const steps = PaymentFlow.steps;
  final labels = [for (final s in steps) PaymentFlow.label(s).tr];
  if (PaymentFlow.ended(status)) {
    return FinTrack(steps: labels, current: status == 'reversed' ? steps.length - 1 : 0, ended: true, endedLabel: PaymentFlow.label(status).tr);
  }
  final int at = steps.indexOf(status);
  return at < 0 ? null : FinTrack(steps: labels, current: at);
}

/// The confirmation step: the server's verified figures, then identity
/// check (above the threshold) and the payment method.
class PaymentConfirmCard extends StatelessWidget {
  final List<(String, String)> lines;
  final int total;
  final String currency;
  final DateTime? expiresAt;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onCancel;

  const PaymentConfirmCard({
    super.key,
    required this.lines,
    required this.total,
    required this.currency,
    required this.expiresAt,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool expired = expiresAt != null && !DateTime.now().isBefore(expiresAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Check before you confirm".tr,
          children: [
            for (final (l, v) in lines) FinRow(l, v),
            Divider(height: DsSpace.lg, color: c.divider),
            FinRow("Total to pay".tr, FinanceMoney.format(total, currency), strong: true),
            if (expiresAt != null && !expired)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: c.textSecondary),
                  const DsGap(DsSpace.xs),
                  Expanded(
                    child: Text(
                      '${"Confirm before".tr} ${ltr(DateFormat('HH:mm').format(expiresAt!))}',
                      style: DsTypography.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ]),
              ),
          ],
        ),
        if (expired)
          FinNotice("This request expired. Start again to get an up-to-date price.".tr, tone: DsTone.warning)
        else ...[
          const DsGap(DsSpace.lg),
          FinanceKycGate(
            builder: (context, verified) => DsButton.primary(
              label: confirmLabel,
              icon: Icons.lock_outline_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: verified ? onConfirm : null,
            ),
          ),
        ],
        const DsGap(DsSpace.xs),
        DsButton.ghost(label: "Cancel".tr, expand: true, onPressed: onCancel),
      ],
    );
  }
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
    return FutureBuilder<TransferConfig?>(
      future: FinanceTransferService.config(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return FinScaffold(
          title: "Money transfer".tr,
          body: FinBody(children: [
            if (cfgSnap.connectionState == ConnectionState.waiting)
              FinState.loading()
            else if (cfg == null)
              FinState.empty(Icons.send_rounded, "Transfers are not available yet.".tr)
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
                trailing: DsIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: "Remove".tr,
                  onPressed: () => FinanceUi.run(() => FinanceTransferService.deleteBeneficiary(b['id'].toString())),
                ),
                onTap: () => Get.to(() => TransferFormScreen(config: config, channel: b['channel'].toString(), beneficiary: b)),
              ),
          ],
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  final TransferConfig config;

  const _History({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceTransferService.transfers(),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load your transfers.".tr);
        if (!snap.hasData) return FinState.loading();
        if (snap.data!.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "You have not sent or received money yet.".tr);
        final uid = FinanceService.uid;
        return FinSection(
          title: "History".tr,
          divided: true,
          padding: paymentListPadding,
          children: [
            for (final t in snap.data!)
              Builder(builder: (context) {
                final bool out = t['senderId'] == uid;
                final String cur = t['currency']?.toString() ?? '';
                final int amount = FinanceSummary.intOf(out ? t['amount'] : (t['receiveAmount'] ?? t['amount']));
                final int signed = out ? -amount : amount;
                final String status = t['status']?.toString() ?? '';
                final String channel = t['channel']?.toString() ?? '';
                return FinListTile(
                  icon: out ? Icons.north_east_rounded : Icons.south_west_rounded,
                  iconTone: out ? DsTone.neutral : DsTone.success,
                  title: out ? (t['recipientName']?.toString() ?? '-') : (t['senderName']?.toString() ?? '-'),
                  subtitle: [if (channel.isNotEmpty) TransferChannel.label(channel).tr, paymentDate(t['createdAt'])].join(' · '),
                  amount: FinanceMoney.signed(signed, cur),
                  amountColor: paymentAmountColor(context, status, signed),
                  status: status.isEmpty ? null : status,
                  statusLabel: status.isEmpty ? null : PaymentFlow.label(status).tr,
                  onTap: () => Get.to(() => TransferScreen(transferId: t['id'].toString(), config: config)),
                );
              }),
          ],
        );
      },
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

  const TransferFormScreen({super.key, required this.config, required this.channel, this.beneficiary});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _contact = TextEditingController();
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _byEmail = true;
  String? _operator;
  String? _bank;
  late String _currency = widget.config.currencies.first;
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

  String? _amountProblem(int? amount) {
    if (amount == null) return null;
    if (amount < _ch.minFor(_currency)) return '${"Minimum".tr}: ${FinanceMoney.format(_ch.minFor(_currency), _currency)}';
    final max = _ch.maxFor(_currency);
    if (max != null && amount > max) return '${"Maximum".tr}: ${FinanceMoney.format(max, _currency)}';
    return null;
  }

  Future<void> _continue() async {
    final recipient = _recipient;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (recipient == null) return ShowToastDialog.showToast("Check the recipient details.".tr);
    if (amount == null || _amountProblem(amount) != null) return ShowToastDialog.showToast("Check the amount.".tr);
    if (widget.channel == TransferChannel.internal) {
      final me = Constant.userModel;
      if (recipient['email'] != null && recipient['email'] == me?.email?.toLowerCase()) return ShowToastDialog.showToast("You cannot send money to yourself.".tr);
    }
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceTransferService.create(
        channel: widget.channel,
        amount: amount,
        currency: _currency,
        recipient: recipient,
        note: _note.text.trim(),
        saveBeneficiary: _save,
      );
    });
    if (ok && id != null) Get.off(() => TransferScreen(transferId: id!, config: widget.config));
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final ch = _ch;
    final bool internal = widget.channel == TransferChannel.internal;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final String? amountProblem = _amountProblem(amount);
    final int fee = amount == null ? 0 : ch.fee.feeFor(amount, _currency);
    final String contact = _contact.text.trim();
    final bool contactBad = contact.isNotEmpty && (internal && _byEmail ? !RecipientCheck.email(contact) : !RecipientCheck.phone(contact));
    return FinScaffold(
      title: "${"Send to".tr}: ${TransferChannel.label(widget.channel).tr}",
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(
            label: "Continue".tr,
            size: DsButtonSize.lg,
            expand: true,
            onPressed: verified && _recipient != null && amount != null && amountProblem == null ? _continue : null,
          ),
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            title: "Recipient".tr,
            top: 0,
            padding: paymentFormPadding,
            footnote: internal ? "We check that this person has a Spideli account and show you their name before you confirm.".tr : null,
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
                DsDropdown<String>(
                  label: "Operator".tr,
                  value: _operator,
                  requiredMark: true,
                  items: [for (final o in ch.operators) DropdownMenuItem(value: o, child: Text(o))],
                  onChanged: (v) => setState(() => _operator = v),
                ),
              if (widget.channel == TransferChannel.bank) ...[
                DsDropdown<String>(
                  label: "Bank".tr,
                  value: _bank,
                  requiredMark: true,
                  items: [for (final b in ch.banks) DropdownMenuItem(value: b.code, child: Text(b.name))],
                  onChanged: (v) => setState(() => _bank = v),
                ),
                DsTextField(label: "Account holder".tr, controller: _name, requiredMark: true, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {})),
                DsTextField(
                  label: "Account number or IBAN".tr,
                  controller: _account,
                  requiredMark: true,
                  textCapitalization: TextCapitalization.characters,
                  errorText: _account.text.trim().isNotEmpty && !RecipientCheck.bankAccount(_account.text) ? "This account number is not valid.".tr : null,
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                DsTextField(
                  label: (internal && _byEmail ? "Email address" : "Phone number").tr,
                  hint: internal && _byEmail ? 'name@example.com' : '+237 6XX XX XX XX',
                  controller: _contact,
                  requiredMark: true,
                  keyboardType: internal && _byEmail ? TextInputType.emailAddress : TextInputType.phone,
                  errorText: contactBad ? "Check this field.".tr : null,
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
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: DsTextField(
                    label: "Amount".tr,
                    controller: _amount,
                    requiredMark: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    errorText: amountProblem,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (widget.config.currencies.length > 1) ...[
                  const DsGap(DsSpace.sm),
                  SizedBox(
                    width: 110,
                    child: DsDropdown<String>(
                      label: "Currency".tr,
                      value: _currency,
                      items: [for (final c in widget.config.currencies) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ]),
              DsTextField(label: "Note for the recipient (optional)".tr, controller: _note, maxLength: 140),
            ],
          ),
          if (amount != null && amountProblem == null)
            FinSection(
              title: "Estimate".tr,
              footnote: "You see the exact fee and the recipient's name before you confirm.".tr,
              children: [
                FinRow("Amount".tr, FinanceMoney.format(amount, _currency)),
                FinRow("Estimated fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, _currency)),
                if (ch.delay.isNotEmpty) FinRow("Delivery".tr, ch.delay),
                Divider(height: DsSpace.lg, color: c.divider),
                FinRow("Estimated total".tr, FinanceMoney.format(amount + fee, _currency), strong: true),
              ],
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- transfer

/// One transfer: confirmation (sender), status and receipt.
class TransferScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceTransferService.transfer(transferId),
      builder: (context, snap) {
        final t = snap.data;
        return FinScaffold(
          title: "Transfer".tr,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this transfer.".tr)])
              : t == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
                  : _body(context, t),
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
      if (out && recipientDetail(t).trim().isNotEmpty) ("Recipient details".tr, recipientDetail(t)),
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
                  if (reason.isNotEmpty) DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: reason),
                ]),
        ),
        if (out && PaymentFlow.canConfirm(status, null, DateTime.now()))
          PaymentConfirmCard(
            lines: details,
            total: total,
            currency: cur,
            expiresAt: FinanceGroupService.toDate(t['expiresAt']),
            confirmLabel: "Confirm and send".tr,
            onConfirm: () async {
              if (config.needsReauth(amount, cur) && !await FinanceReauth.confirm()) return;
              if (!context.mounted) return;
              final key = FinanceGroupService.newRequestKey();
              await FinancePaySheet.show(
                context,
                title: "${"Send to".tr} $counterpart",
                amount: total,
                currency: cur,
                methods: config.sourceMethods,
                submit: (p) => FinanceTransferService.confirm(transferId, p, key),
              );
            },
            onCancel: () async {
              if (await FinanceUi.run(() => FinanceTransferService.cancel(transferId), success: "Transfer cancelled")) Get.back();
            },
          )
        else ...[
          if (track != null) FinSection(title: "Status".tr, padding: const EdgeInsets.all(DsSpace.lg), children: [track]),
          if (out && status == 'pending')
            FinNotice("Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.".tr),
          FinSection(
            title: "Details".tr,
            divided: true,
            children: [
              for (final (l, v) in details) FinRow(l, v),
              if (out) FinRow("Total paid".tr, m(total), strong: true),
              FinRow("Date".tr, paymentDate(t['createdAt'])),
              if (t['completedAt'] != null) FinRow("Completed on".tr, paymentDate(t['completedAt'])),
              if (reference.isNotEmpty) FinRow("Reference".tr, ltrRef(reference)),
            ],
          ),
          if (out && PaymentFlow.canCancel(status)) ...[
            const DsGap(DsSpace.lg),
            DsButton.ghost(
              label: "Cancel this transfer".tr,
              icon: Icons.close_rounded,
              expand: true,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Cancel this transfer?".tr,
                  lines: [("To".tr, counterpart), ("Total".tr, m(total))],
                  confirmLabel: "Cancel this transfer".tr,
                  destructive: true,
                );
                if (ok) await FinanceUi.run(() => FinanceTransferService.cancel(transferId), success: "Transfer cancelled");
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
                title: "Transfer receipt".tr,
                reference: t['reference']?.toString() ?? t['id'].toString(),
                lines: [
                  ("Reference".tr, t['reference']?.toString() ?? t['id'].toString()),
                  ("Status".tr, PaymentFlow.label(status).tr),
                  ("Date".tr, paymentDate(t['completedAt'] ?? t['createdAt'])),
                  ((out ? "From" : "To").tr, out ? (t['senderName']?.toString() ?? '') : (t['recipientName']?.toString() ?? '')),
                  ...details,
                  if (out) ("Total paid".tr, m(total)),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
