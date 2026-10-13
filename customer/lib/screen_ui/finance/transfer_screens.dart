import 'package:customer/constant/constant.dart';
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

/// Shared by the transfer and bill screens.
DsTone paymentTone(String? s) => switch (s) {
      'completed' => DsTone.success,
      'failed' || 'expired' => DsTone.danger,
      'awaiting_confirmation' || 'pending' => DsTone.warning,
      'processing' => DsTone.info,
      'reversed' => DsTone.info,
      _ => DsTone.neutral,
    };

Widget paymentRow(BuildContext context, String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
          const DsGap(DsSpace.sm),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: (strong ? DsTypography.titleSm : DsTypography.bodyStrong).tabular)),
        ],
      ),
    );

String paymentDate(dynamic v) {
  final d = FinanceGroupService.toDate(v);
  return d == null ? '-' : DateFormat('dd MMM yyyy, HH:mm').format(d);
}

/// The status timeline of a transfer or bill payment (none once it failed).
Widget paymentTimeline(String status) {
  if (PaymentFlow.ended(status)) return const SizedBox.shrink();
  final steps = PaymentFlow.steps;
  final int at = steps.indexOf(status);
  if (at < 0) return const SizedBox.shrink();
  return DsTimeline(
    steps: [
      for (final (i, s) in steps.indexed)
        DsTimelineStep(
          title: PaymentFlow.label(s).tr,
          state: i < at || (i == at && i == steps.length - 1) ? DsStepState.done : (i == at ? DsStepState.current : DsStepState.upcoming),
        ),
    ],
  );
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
    final bool expired = expiresAt != null && !DateTime.now().isBefore(expiresAt!);
    return DsCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Check before you confirm".tr, style: DsTypography.titleSm),
          const DsGap(DsSpace.sm),
          for (final (l, v) in lines) paymentRow(context, l, v),
          const Divider(),
          paymentRow(context, "Total to pay".tr, FinanceMoney.format(total, currency), strong: true),
          if (expiresAt != null && !expired) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text('${"Confirm before".tr} ${DateFormat('HH:mm').format(expiresAt!)}', style: DsTypography.caption)),
          const DsGap(DsSpace.md),
          if (expired)
            DsInlineAlert(tone: DsTone.warning, message: "This request expired. Start again to get an up-to-date price.".tr)
          else
            FinanceKycGate(
              builder: (context, verified) => DsButton.primary(label: confirmLabel, icon: Icons.lock_outline_rounded, expand: true, onPressed: verified ? onConfirm : null),
            ),
          DsButton.ghost(label: "Cancel".tr, expand: true, onPressed: onCancel),
        ],
      ),
    );
  }
}

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
        return DsScaffold(
          title: "Send money".tr,
          maxContentWidth: DsLayout.contentMax,
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.send_rounded, title: "Transfers are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsTileGroup(
                          title: "Send to".tr,
                          children: [
                            for (final c in cfg.channels.values)
                              DsListTile(
                                leadingIcon: icon(c.key),
                                leadingTone: DsTone.brand,
                                title: TransferChannel.label(c.key).tr,
                                subtitle: c.delay.isEmpty ? null : c.delay,
                                showChevron: true,
                                onTap: () => Get.to(() => TransferFormScreen(config: cfg, channel: c.key)),
                              ),
                          ],
                        ),
                        _Beneficiaries(config: cfg),
                        const DsGap(DsSpace.lg),
                        _History(config: cfg),
                      ],
                    ),
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
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.lg),
          child: DsFormSection(
            title: "Recent recipients".tr,
            icon: Icons.people_outline_rounded,
            children: [
              for (final b in list)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: TransfersScreen.icon(b['channel'].toString()),
                  title: b['displayName']?.toString() ?? '-',
                  subtitle: '${TransferChannel.label(b['channel'].toString()).tr} · ${b['detail'] ?? ''}',
                  trailing: DsIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: "Remove".tr,
                    onPressed: () => FinanceUi.run(() => FinanceTransferService.deleteBeneficiary(b['id'].toString())),
                  ),
                  onTap: () => Get.to(() => TransferFormScreen(config: config, channel: b['channel'].toString(), beneficiary: b)),
                ),
            ],
          ),
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
        if (snap.hasError) return DsErrorState(message: "Could not load your transfers.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        final uid = FinanceService.uid;
        return DsFormSection(
          title: "History".tr,
          icon: Icons.receipt_long_outlined,
          children: [
            if (snap.data!.isEmpty) Text("You have not sent or received money yet.".tr, style: DsTypography.body),
            for (final t in snap.data!)
              Builder(builder: (context) {
                final bool out = t['senderId'] == uid;
                final String cur = t['currency']?.toString() ?? '';
                final int amount = FinanceSummary.intOf(out ? t['amount'] : (t['receiveAmount'] ?? t['amount']));
                return DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: out ? Icons.north_east_rounded : Icons.south_west_rounded,
                  leadingTone: paymentTone(t['status']?.toString()),
                  title: out ? (t['recipientName']?.toString() ?? '-') : (t['senderName']?.toString() ?? '-'),
                  subtitle: '${paymentDate(t['createdAt'])} · ${PaymentFlow.label(t['status']?.toString()).tr}',
                  trailing: Text('${out ? '-' : '+'}${FinanceMoney.format(amount, cur)}',
                      style: DsTypography.bodyStrong.copyWith(color: out ? null : DsColors.of(context).success).tabular),
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
    final ch = _ch;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final String? amountProblem = _amountProblem(amount);
    final int fee = amount == null ? 0 : ch.fee.feeFor(amount, _currency);
    final String contact = _contact.text.trim();
    final bool contactBad = contact.isNotEmpty &&
        (widget.channel == TransferChannel.internal && _byEmail ? !RecipientCheck.email(contact) : !RecipientCheck.phone(contact));
    return DsScaffold(
      title: "${"Send to".tr}: ${TransferChannel.label(widget.channel).tr}",
      maxContentWidth: DsLayout.contentMax,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Recipient".tr,
            icon: TransfersScreen.icon(widget.channel),
            children: [
              if (widget.channel == TransferChannel.internal) ...[
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
                  items: [for (final o in ch.operators) DropdownMenuItem(value: o, child: Text(o))],
                  onChanged: (v) => setState(() => _operator = v),
                ),
              if (widget.channel == TransferChannel.bank) ...[
                DsDropdown<String>(
                  label: "Bank".tr,
                  value: _bank,
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
                  label: (widget.channel == TransferChannel.internal && _byEmail ? "Email address" : "Phone number").tr,
                  hint: widget.channel == TransferChannel.internal && _byEmail ? 'name@example.com' : '+237 6XX XX XX XX',
                  controller: _contact,
                  requiredMark: true,
                  keyboardType: widget.channel == TransferChannel.internal && _byEmail ? TextInputType.emailAddress : TextInputType.phone,
                  errorText: contactBad ? "Check this field.".tr : null,
                  onChanged: (_) => setState(() {}),
                ),
                if (widget.channel != TransferChannel.internal)
                  DsTextField(label: "Recipient name (optional)".tr, controller: _name, textCapitalization: TextCapitalization.words),
              ],
              if (widget.channel == TransferChannel.internal)
                Text("We check that this person has a Spideli account and show you their name before you confirm.".tr, style: DsTypography.caption),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Amount".tr,
            icon: Icons.payments_outlined,
            children: [
              Row(children: [
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
              if (amount != null && amountProblem == null) ...[
                paymentRow(context, "Estimated fee".tr, fee == 0 ? "Free".tr : FinanceMoney.format(fee, _currency)),
                paymentRow(context, "Estimated total".tr, FinanceMoney.format(amount + fee, _currency)),
                if (ch.delay.isNotEmpty) paymentRow(context, "Delivery".tr, ch.delay),
                Text("You see the exact fee and the recipient's name before you confirm.".tr, style: DsTypography.caption),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _save,
                onChanged: (v) => setState(() => _save = v ?? false),
                title: Text("Save this recipient".tr),
              ),
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
        return DsScaffold(
          title: "Transfer".tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this transfer.".tr)
              : t == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: paymentTone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text('${out ? '-' : '+'}${m(out ? total : (t['receiveAmount'] ?? amount))}', style: DsTypography.title.tabular)),
                DsBadge(label: PaymentFlow.label(status).tr, tone: paymentTone(status)),
              ]),
              Text('${(out ? "To" : "From").tr} $counterpart', style: DsTypography.body),
              if (t['recipientVerified'] == true && out)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.xs),
                  child: DsBadge(label: "Recipient verified".tr, tone: DsTone.success, icon: Icons.verified_rounded, small: true),
                ),
              if ((t['reason'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: paymentTone(status), title: "Reason".tr, message: t['reason'].toString())),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
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
          paymentTimeline(status),
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Details".tr,
            icon: Icons.receipt_long_outlined,
            children: [
              for (final (l, v) in details) paymentRow(context, l, v),
              if (out) paymentRow(context, "Total paid".tr, m(total)),
              paymentRow(context, "Date".tr, paymentDate(t['createdAt'])),
              if (t['completedAt'] != null) paymentRow(context, "Completed on".tr, paymentDate(t['completedAt'])),
              if ((t['reference'] ?? '').toString().isNotEmpty) paymentRow(context, "Reference".tr, t['reference'].toString()),
            ],
          ),
          if (out && status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsInlineAlert(tone: DsTone.info, message: "Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.".tr),
            ),
          if (out && PaymentFlow.canCancel(status))
            DsButton.ghost(
              label: "Cancel this transfer".tr,
              icon: Icons.close_rounded,
              onPressed: () => FinanceUi.run(() => FinanceTransferService.cancel(transferId), success: "Transfer cancelled"),
            ),
          if (status == 'completed' || status == 'reversed') ...[
            const DsGap(DsSpace.md),
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
