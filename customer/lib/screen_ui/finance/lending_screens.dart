import 'dart:io';

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_lending_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// "12%", "2.5%" (no trailing ".0").
String _pct(num v) => '${v == v.roundToDouble() ? v.round() : v}%';

/// A percentage stored by the server ("12%", "-" when missing).
String _pctOf(dynamic v) => v is num ? _pct(v) : (v == null ? '-' : '$v%');

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

/// Inner padding of a form section (each field carries its own bottom spacing).
const EdgeInsets _formPadding = EdgeInsets.all(DsSpace.lg);

/// Spideli Finance > Loans: borrow from, and lend to, the members of your
/// groups. `platform_settings/lending` must exist (admin).
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  int _tab = 0;

  /// Read once, so switching tabs does not reload the configuration.
  late final Future<LendingConfig?> _config = FinanceLendingService.config();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LendingConfig?>(
      future: _config,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        final bool loading = cfgSnap.connectionState == ConnectionState.waiting;
        return FinScaffold(
          title: "Loans".tr,
          bottomBar: cfg == null || _tab != 0
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Request a loan".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => LoanApplyScreen(config: cfg)),
                  ),
                ),
          body: FinBody(
            children: [
              if (loading)
                FinState.loading()
              else if (cfg == null)
                FinState.empty(Icons.handshake_outlined, "Loans are not available yet.".tr)
              else ...[
                DsSegmentedTabs(
                  segments: [DsSegment("Borrow".tr), DsSegment("Group requests".tr), DsSegment("Lent".tr)],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                _LoanList(
                  key: ValueKey(_tab),
                  stream: switch (_tab) {
                    0 => FinanceLendingService.borrowed(),
                    1 => FinanceLendingService.groupRequests(),
                    _ => FinanceLendingService.lent(),
                  },
                  empty: switch (_tab) {
                    0 => "You have no loan request.",
                    1 => "No loan request in your groups.",
                    _ => "You have not funded a loan yet.",
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LoanList extends StatelessWidget {
  final Stream<List<Loan>> stream;
  final String empty;

  const _LoanList({super.key, required this.stream, required this.empty});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Loan>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the loans.".tr);
        if (!snap.hasData) return FinState.loading();
        final loans = snap.data!;
        if (loans.isEmpty) return FinState.empty(Icons.handshake_outlined, empty.tr);
        return FinSection(
          top: DsSpace.lg,
          divided: true,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
          children: [for (final l in loans) _LoanTile(loan: l)],
        );
      },
    );
  }
}

/// One loan in a list: purpose, terms, amount and status.
class _LoanTile extends StatelessWidget {
  final Loan loan;

  const _LoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final bool late = l.status == 'overdue' || l.status == 'defaulted';
    final bool closed = l.status == 'rejected' || l.status == 'cancelled';
    return FinListTile(
      icon: Icons.handshake_outlined,
      iconTone: late ? DsTone.danger : (closed ? DsTone.neutral : DsTone.brand),
      title: GroupLabels.purpose(l.purpose).tr,
      subtitle: [
        '${l.durationMonths} ${"months".tr}',
        if (l.groupName.isNotEmpty) l.groupName,
        if (l.outstandingAmount > 0) '${"Still to repay".tr} ${FinanceMoney.format(l.outstandingAmount, l.currency)}',
      ].join(' · '),
      amount: FinanceMoney.format(l.amount, l.currency),
      status: l.status,
      statusLabel: LoanActions.statusLabel(l.status).tr,
      chevron: true,
      onTap: () => Get.to(() => LoanScreen(loanId: l.id)),
    );
  }
}

/// A loan request: group, amount, terms and an estimated schedule.
class LoanApplyScreen extends StatefulWidget {
  final LendingConfig config;

  const LoanApplyScreen({super.key, required this.config});

  @override
  State<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends State<LoanApplyScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late String _currency = widget.config.currencies.first;
  late String _purpose = widget.config.purposes.first;
  late int _months = widget.config.durationsMonths.first;
  late String _frequency = widget.config.repaymentFrequencies.first;
  String? _groupId;
  bool _showSchedule = false;
  final List<File> _documents = [];

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addDocument() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
    if (picked != null) setState(() => _documents.add(File(picked.path)));
  }

  Future<void> _submit() async {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (_groupId == null) return ShowToastDialog.showToast("Choose the group whose members will vote on your request.".tr);
    if (amount == null || amount < cfg.minFor(_currency) || (cfg.maxFor(_currency) != null && amount > cfg.maxFor(_currency)!)) {
      return ShowToastDialog.showToast(
          "${"The amount must be between".tr} ${FinanceMoney.format(cfg.minFor(_currency), _currency)} ${"and".tr} ${cfg.maxFor(_currency) == null ? '-' : FinanceMoney.format(cfg.maxFor(_currency)!, _currency)}.");
    }
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceLendingService.apply(
        amount: amount,
        currency: _currency,
        purpose: _purpose,
        durationMonths: _months,
        repaymentFrequency: _frequency,
        groupId: _groupId!,
        description: _description.text.trim(),
      );
      for (int i = 0; i < _documents.length; i++) {
        await FinanceLendingService.addDocument(id!, _documents[i], '${"Document".tr} ${i + 1}');
      }
    }, success: "Loan request sent");
    if (ok && id != null) Get.off(() => LoanScreen(loanId: id!));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final int? max = cfg.maxFor(_currency);
    final now = DateTime.now();
    final estimate = amount == null
        ? null
        : LoanCalculator.estimate(
            principal: amount,
            months: _months,
            frequency: _frequency,
            method: cfg.interestMethod,
            annualPercent: cfg.annualInterestPercent,
            feePercent: cfg.feePercent,
            firstDue: Frequency.next(now, _frequency),
          );
    return FinScaffold(
      title: "Request a loan".tr,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(label: "Send my request".tr, size: DsButtonSize.lg, expand: true, onPressed: verified ? _submit : null),
        ),
      ),
      body: FinBody(
        children: [
          StreamBuilder<List<Tontine>>(
            stream: FinanceGroupService.myTontines(),
            builder: (context, snap) {
              final groups = (snap.data ?? const <Tontine>[]).where((t) => t.isActive || t.isForming).toList();
              return FinSection(
                title: "Group".tr,
                top: 0,
                padding: _formPadding,
                children: [
                  _Hint("The members of this group vote on your request and can fund it.".tr),
                  if (snap.hasData && groups.isEmpty)
                    DsInlineAlert(tone: DsTone.warning, message: "You need to belong to a tontine group to borrow from its members.".tr)
                  else
                    DsDropdown<String>(
                      label: "Group".tr,
                      requiredMark: true,
                      value: _groupId,
                      items: [for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
                      onChanged: (v) => setState(() => _groupId = v),
                      bottomSpacing: 0,
                    ),
                ],
              );
            },
          ),
          FinSection(
            title: "Loan".tr,
            padding: _formPadding,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DsTextField(
                      label: "Amount".tr,
                      controller: _amount,
                      requiredMark: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // The allowed range, before the user is refused.
                      helper: max == null ? null : '${FinanceMoney.format(cfg.minFor(_currency), _currency)} – ${FinanceMoney.format(max, _currency)}',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  SizedBox(
                    width: 110,
                    child: DsDropdown<String>(
                      label: "Currency".tr,
                      value: _currency,
                      items: [for (final c in cfg.currencies) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              DsDropdown<String>(
                label: "Purpose".tr,
                value: _purpose,
                items: [for (final p in cfg.purposes) DropdownMenuItem(value: p, child: Text(GroupLabels.purpose(p).tr))],
                onChanged: (v) => setState(() => _purpose = v ?? _purpose),
              ),
              DsFieldLabel("Duration".tr),
              Wrap(
                spacing: DsSpace.sm,
                children: [
                  for (final m in cfg.durationsMonths) ChoiceChip(label: Text('$m ${"months".tr}'), selected: _months == m, onSelected: (_) => setState(() => _months = m)),
                ],
              ),
              const DsGap(DsSpace.md),
              DsDropdown<String>(
                label: "Repayments".tr,
                value: _frequency,
                items: [for (final f in cfg.repaymentFrequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr))],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              DsTextField(label: "Why do you need this loan?".tr, controller: _description, maxLines: 3, bottomSpacing: 0),
            ],
          ),
          if (estimate != null) ...[
            FinSection(
              title: "Estimated repayments".tr,
              divided: true,
              children: [
                FinRow("Each installment".tr, FinanceMoney.format(estimate.installmentAmount, _currency), sub: Frequency.label(_frequency).tr),
                FinRow("Number of installments".tr, '${estimate.installments.length}'),
                FinRow(
                  "Interest".tr,
                  '${_pct(cfg.annualInterestPercent)} ${"a year".tr}',
                  sub: (cfg.interestMethod == 'flat' ? 'flat rate' : 'on the remaining balance').tr,
                ),
                if (cfg.latePenaltyPercent > 0) FinRow("Late payment penalty".tr, _pct(cfg.latePenaltyPercent)),
                FinRow("Total interest".tr, FinanceMoney.format(estimate.totalInterest, _currency)),
                FinRow("Fee".tr, FinanceMoney.format(estimate.fee, _currency)),
                FinRow("Total to repay".tr, FinanceMoney.format(estimate.totalRepaid, _currency), strong: true),
                _Toggle(
                  label: (_showSchedule ? "Hide the schedule" : "See the schedule").tr,
                  expanded: _showSchedule,
                  onTap: () => setState(() => _showSchedule = !_showSchedule),
                ),
                if (_showSchedule)
                  for (final i in estimate.installments) FinRow('${i.number}. ${_date(i.dueDate)}', FinanceMoney.format(i.total, _currency)),
              ],
            ),
            FinNotice(
              "This is an estimate. The binding amounts, dates and fees are in the loan agreement you accept before any money is paid out.".tr,
              title: "Estimate".tr,
            ),
          ],
          FinSection(
            title: "Supporting documents (optional)".tr,
            divided: true,
            footnote: "Payslips, invoices, a business plan... Only the reviewers and your group's voters see them.".tr,
            children: [
              for (final (i, f) in _documents.indexed)
                FinListTile(
                  icon: Icons.image_outlined,
                  iconTone: DsTone.brand,
                  title: '${"Document".tr} ${i + 1}',
                  subtitle: f.path.split('/').last,
                  trailing: DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, onPressed: () => setState(() => _documents.removeAt(i))),
                ),
              if (_documents.length < 5)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DsButton.ghost(label: "Add a photo".tr, icon: Icons.add_a_photo_outlined, onPressed: _addDocument),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One loan, for its borrower and for the members of its group.
class LoanScreen extends StatelessWidget {
  final String loanId;

  const LoanScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LendingConfig?>(
      future: FinanceLendingService.config(),
      builder: (context, cfgSnap) => StreamBuilder<Loan?>(
        stream: FinanceLendingService.loan(loanId),
        builder: (context, snap) {
          final l = snap.data;
          if (snap.hasError || l == null) {
            return FinScaffold(
              title: "Loan".tr,
              body: FinBody(children: [snap.hasError ? FinState.error("Could not load this loan.".tr) : FinState.loading(rows: 4)]),
            );
          }
          final methods = cfgSnap.data?.paymentMethods ?? const ['wallet'];
          // The binding schedule (borrower and lenders only; empty for the others).
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceLendingService.schedule(l.id),
            builder: (context, ss) {
              final installments = ss.data ?? const <Map<String, dynamic>>[];
              final bool repay = installments.isNotEmpty && LoanActions.canRepay(l, FinanceService.uid);
              return FinScaffold(
                title: "Loan".tr,
                bottomBar: repay ? DsStickyBar(child: _RepayButton(loan: l, next: nextInstallment(installments), methods: methods)) : null,
                body: _LoanBody(loan: l, config: cfgSnap.data, installments: installments),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoanBody extends StatelessWidget {
  final Loan loan;
  final LendingConfig? config;
  final List<Map<String, dynamic>> installments;

  const _LoanBody({required this.loan, required this.config, required this.installments});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final c = DsColors.of(context);
    final uid = FinanceService.uid;
    final bool borrower = uid == l.borrowerId;
    final methods = config?.paymentMethods ?? const ['wallet'];
    return FinBody(
      children: [
        _LoanHeader(loan: l, installments: installments),
        if (l.description.isNotEmpty)
          FinSection(
            title: "Description".tr,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                child: Text(l.description, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
        if (borrower) _Assessment(loanId: l.id),
        if (l.status == 'voting') _Voting(loan: l, config: config),
        if (l.status == 'funding' || l.lenderIds.contains(uid)) _Funding(loan: l, methods: methods),
        _Agreement(loan: l),
        if (installments.isNotEmpty) ...[
          _Schedule(loan: l, installments: installments),
          _Repayments(loanId: l.id, currency: l.currency),
        ],
        if (LoanActions.canCancel(l, uid))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Withdraw my request".tr,
              icon: Icons.close_rounded,
              expand: true,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Withdraw this loan request?".tr,
                  lines: [
                    ("Amount".tr, FinanceMoney.format(l.amount, l.currency)),
                    if (l.groupName.isNotEmpty) ("Group".tr, l.groupName),
                  ],
                  confirmLabel: "Withdraw".tr,
                  destructive: true,
                );
                if (ok) await FinanceUi.run(() => FinanceLendingService.cancel(l.id), success: "Request withdrawn");
              },
            ),
          ),
      ],
    );
  }
}

/// The loan's headline: amount, terms, status, where it is in its workflow
/// and, while it is being repaid, what is left (server amounts only).
class _LoanHeader extends StatelessWidget {
  final Loan loan;
  final List<Map<String, dynamic>> installments;

  const _LoanHeader({required this.loan, required this.installments});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final c = DsColors.of(context);
    final bool ended = const ['rejected', 'cancelled', 'defaulted'].contains(l.status);
    // "overdue" is the active step running late; "defaulted" ended after the pay-out.
    final int stepIndex = LoanActions.steps.indexOf(l.status == 'overdue' || l.status == 'defaulted' ? 'active' : l.status);
    final String statusLabel = LoanActions.statusLabel(l.status).tr;
    // The total of the binding schedule; the repaid share is shown only against it.
    final int scheduleTotal = installments.fold(0, (s, i) => s + FinanceSummary.intOf(i['amount']));
    final bool repaying = l.outstandingAmount > 0;
    final below = <Widget>[
      if (ended || stepIndex >= 0)
        FinTrack(
          steps: [for (final s in LoanActions.steps) LoanActions.statusLabel(s).tr],
          current: stepIndex,
          ended: ended,
          endedLabel: statusLabel,
        ),
      if (repaying) ...[
        Divider(height: DsSpace.xl, thickness: 1, color: c.divider),
        FinRow("Still to repay".tr, FinanceMoney.format(l.outstandingAmount, l.currency), strong: true),
        if (scheduleTotal > 0) ...[
          const DsGap(DsSpace.xs),
          FinProgress(value: (scheduleTotal - l.outstandingAmount) / scheduleTotal, label: "Repaid".tr),
        ],
      ],
      if ((l.reason ?? '').isNotEmpty) FinNotice(l.reason!, title: "Reason".tr, tone: FinStatus.tone(l.status)),
    ];
    return FinHeader(
      overline: "Amount".tr,
      title: FinanceMoney.format(l.amount, l.currency),
      subtitle: '${GroupLabels.purpose(l.purpose).tr} · ${l.durationMonths} ${"months".tr} · ${Frequency.label(l.frequency).tr}'
          '${l.groupName.isEmpty ? '' : '\n${"Group".tr}: ${l.groupName}'}',
      status: l.status,
      statusLabel: statusLabel,
      icon: Icons.handshake_outlined,
      below: below.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: below),
    );
  }
}

/// The borrower's credit assessment: score, band and the main factors (explained).
class _Assessment extends StatelessWidget {
  final String loanId;

  const _Assessment({required this.loanId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceLendingService.creditAssessment(loanId),
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        final factors = (a['factors'] as List?)?.whereType<Map>().toList() ?? const [];
        return FinSection(
          title: "Your credit assessment".tr,
          divided: true,
          footnote: "The main factors that shaped your score. Ask support if something looks wrong.".tr,
          children: [
            FinRow("Score".tr, '${a['score'] ?? '-'}', sub: a['band']?.toString(), strong: true),
            for (final f in factors)
              FinListTile(
                icon: f['impact'] == 'negative' ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                iconTone: f['impact'] == 'negative' ? DsTone.warning : DsTone.success,
                title: f['label']?.toString() ?? '-',
                subtitle: f['detail']?.toString(),
              ),
          ],
        );
      },
    );
  }
}

class _Voting extends StatelessWidget {
  final Loan loan;
  final LendingConfig? config;

  const _Voting({required this.loan, required this.config});

  Future<void> _vote(BuildContext context, bool approve) async {
    final comment = TextEditingController();
    final ok = await finSheet<bool>(
      title: (approve ? "Approve this loan" : "Decline this loan").tr,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Comment (optional)".tr, controller: comment, maxLines: 3),
            Text("Your vote is final and visible to the borrower as part of the result.".tr,
                style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
            const DsGap(DsSpace.lg),
            DsButton.primary(label: "Confirm my vote".tr, expand: true, onPressed: () => Get.back(result: true)),
          ],
        ),
      ),
    );
    if (ok == true) await FinanceUi.run(() => FinanceLendingService.vote(loan.id, approve, comment.text.trim()), success: "Vote recorded");
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final cfg = config;
    final tally = VoteTally(eligible: l.eligibleVoterIds.length, yes: l.votesYes, no: l.votesNo, quorumPercent: cfg?.quorumPercent ?? 50, approvalPercent: cfg?.approvalPercent ?? 50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Group vote".tr,
          divided: true,
          children: [
            FinRow("Votes".tr, '${tally.cast} / ${tally.eligible}', sub: '${"needed".tr}: ${tally.needed}'),
            FinRow("Approve / decline".tr, '${tally.yes} / ${tally.no}'),
            FinRow("Approval needed".tr, _pct(tally.approvalPercent)),
            if (l.votingEndsAt != null) FinRow("Voting closes".tr, ltr(DateFormat('dd MMM yyyy, HH:mm').format(l.votingEndsAt!))),
          ],
        ),
        StreamBuilder<Map<String, dynamic>?>(
          stream: FinanceLendingService.myVote(l.id),
          builder: (context, snap) {
            final mine = snap.data;
            if (mine != null) {
              return FinNotice((mine['approve'] == true ? "You voted to approve." : "You voted to decline.").tr);
            }
            if (!LoanActions.canVote(l, FinanceService.uid, alreadyVoted: false, now: DateTime.now())) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: FinanceKycGate(
                builder: (context, verified) => Row(
                  children: [
                    Expanded(child: DsButton.secondary(label: "Decline".tr, onPressed: verified ? () => _vote(context, false) : null)),
                    const DsGap(DsSpace.sm),
                    Expanded(child: DsButton.primary(label: "Approve".tr, onPressed: verified ? () => _vote(context, true) : null)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Funding extends StatelessWidget {
  final Loan loan;
  final List<String> methods;

  const _Funding({required this.loan, required this.methods});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.myFundings(l.id),
      builder: (context, snap) {
        final mine = snap.data ?? const [];
        final int lent = mine.where((f) => f['status'] == 'succeeded').fold(0, (s, f) => s + FinanceSummary.intOf(f['amount']));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: "Funding".tr,
              divided: true,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: FinProgress(
                    value: l.fundingProgress,
                    label: '${FinanceMoney.format(l.fundedAmount, l.currency)} / ${FinanceMoney.format(l.amount, l.currency)}',
                  ),
                ),
                if (l.status == 'funding' && l.fundingRemaining > 0) FinRow("Left to fund".tr, FinanceMoney.format(l.fundingRemaining, l.currency)),
                if (mine.isNotEmpty) FinRow("You lent".tr, FinanceMoney.format(lent, l.currency)),
              ],
            ),
            if (LoanActions.canFund(l, FinanceService.uid))
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.md),
                child: FinanceKycGate(
                  builder: (context, verified) => DsButton.primary(
                    label: "Lend to this member".tr,
                    icon: Icons.volunteer_activism_outlined,
                    expand: true,
                    onPressed: !verified
                        ? null
                        : () async {
                            final amount = await askAmount(context, title: "How much do you lend?".tr, currency: l.currency, max: l.fundingRemaining);
                            if (amount == null || !context.mounted) return;
                            final key = FinanceGroupService.newRequestKey();
                            await FinancePaySheet.show(context, title: "Lend".tr, amount: amount, currency: l.currency, methods: methods, submit: (p) => FinanceLendingService.fund(l.id, amount, p, key));
                          },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The loan agreement issued by the server, and its acceptance by the borrower.
class _Agreement extends StatefulWidget {
  final Loan loan;

  const _Agreement({required this.loan});

  @override
  State<_Agreement> createState() => _AgreementState();
}

class _AgreementState extends State<_Agreement> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final c = DsColors.of(context);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceLendingService.agreement(l.id),
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        final cur = a['currency']?.toString() ?? l.currency;
        final int version = FinanceSummary.intOf(a['version']);
        final bool canAccept = LoanActions.canAcceptAgreement(l, FinanceService.uid) && a['acceptedAt'] == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: "Loan agreement".tr,
              divided: true,
              children: [
                FinRow("Amount".tr, FinanceMoney.format(FinanceSummary.intOf(a['principal']), cur)),
                FinRow("Interest".tr, '${_pctOf(a['annualInterestPercent'])} ${"a year".tr}'),
                FinRow("Fee".tr, FinanceMoney.format(FinanceSummary.intOf(a['fee']), cur)),
                if (a['latePenaltyPercent'] != null) FinRow("Late payment penalty".tr, _pctOf(a['latePenaltyPercent'])),
                FinRow("Total to repay".tr, FinanceMoney.format(FinanceSummary.intOf(a['totalRepayable']), cur), strong: true),
                if ((a['terms'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                    child: Text(a['terms'].toString(), style: DsTypography.body.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
            if (a['acceptedAt'] != null) FinNotice('${"Accepted on".tr} ${FinanceUi.date(a['acceptedAt'])}', tone: DsTone.success),
            if (canAccept) ...[
              const DsGap(DsSpace.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read the agreement and the repayment schedule, and I accept them.".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
              const DsGap(DsSpace.xs),
              DsButton.primary(
                label: "Accept the agreement".tr,
                expand: true,
                onPressed: !_accepted ? null : () => FinanceUi.run(() => FinanceLendingService.acceptAgreement(l.id, version), success: "Agreement accepted. The loan will be paid out."),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The binding schedule: one line per installment (number, date, amount, status).
class _Schedule extends StatelessWidget {
  final Loan loan;
  final List<Map<String, dynamic>> installments;

  const _Schedule({required this.loan, required this.installments});

  @override
  Widget build(BuildContext context) {
    return FinSection(
      title: "Repayment schedule".tr,
      divided: true,
      children: [for (final i in installments) _InstallmentRow(installment: i, currency: loan.currency)],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> installment;
  final String currency;

  const _InstallmentRow({required this.installment, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final i = installment;
    final String? status = i['status']?.toString();
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${i['number'] ?? ''}', style: DsTypography.labelSm.copyWith(color: c.textSecondary).tabular),
            ),
            Expanded(child: Text(_date(FinanceGroupService.toDate(i['dueDate'])), style: DsTypography.body.copyWith(color: c.textPrimary))),
            const DsGap(DsSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(FinanceMoney.format(FinanceSummary.intOf(i['amount']), currency), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
                const DsGap(DsSpace.xxs),
                FinStatusChip(status: status ?? '', label: LoanActions.installmentLabel(status).tr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The borrower's repayment action (sticky): the next installment due, or
/// any amount up to what is outstanding.
class _RepayButton extends StatelessWidget {
  final Loan loan;
  final Map<String, dynamic>? next;
  final List<String> methods;

  const _RepayButton({required this.loan, required this.next, required this.methods});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final next = this.next;
    return FinanceKycGate(
      builder: (context, verified) => DsButton.primary(
        label: next == null ? "Repay".tr : "${"Repay".tr} ${FinanceMoney.format(FinanceSummary.intOf(next['amountDue'] ?? next['amount']), l.currency)}",
        icon: Icons.payments_outlined,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: !verified
            ? null
            : () async {
                final int suggested = next == null ? 0 : FinanceSummary.intOf(next['amountDue'] ?? next['amount']);
                final amount = await askAmount(context, title: "Repay".tr, currency: l.currency, max: l.outstandingAmount, hint: suggested > 0 ? FinanceMoney.format(suggested, l.currency) : null);
                if (amount == null || !context.mounted) return;
                final key = FinanceGroupService.newRequestKey();
                await FinancePaySheet.show(context, title: "Repay".tr, amount: amount, currency: l.currency, methods: methods, submit: (p) => FinanceLendingService.repay(l.id, amount, p, key));
              },
      ),
    );
  }
}

/// The repayments recorded by the server, newest first.
class _Repayments extends StatelessWidget {
  final String loanId;
  final String currency;

  const _Repayments({required this.loanId, required this.currency});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.repayments(loanId),
      builder: (context, rs) {
        final list = rs.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Repayments".tr,
          divided: true,
          children: [
            for (final r in list)
              FinListTile(
                icon: Icons.north_east_rounded,
                title: FinanceUi.date(r['createdAt']),
                subtitle: (r['reference'] ?? '').toString().isEmpty ? null : ltrRef(r['reference']),
                amount: FinanceMoney.format(FinanceSummary.intOf(r['amount']), currency),
                status: r['status']?.toString(),
                statusLabel: GroupLabels.contribution(r['status']?.toString()).tr,
              ),
          ],
        );
      },
    );
  }
}

/// A supporting line at the top of a form section (what its fields are for).
class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.md),
        child: Text(text, style: DsTypography.bodySm.copyWith(color: DsColors.of(context).textSecondary)),
      );
}

/// A show / hide line inside a section, at least 48 px tall.
class _Toggle extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  const _Toggle({required this.label, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = FinColors.brand(context);
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: Text(label, style: DsTypography.label.copyWith(color: brand))),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: brand, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
