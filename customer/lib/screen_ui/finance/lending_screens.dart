import 'dart:io';

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

String _date(DateTime? d) => d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

DsTone _tone(String? s) => switch (s) {
      'active' || 'repaid' || 'paid' || 'succeeded' => DsTone.success,
      'overdue' || 'defaulted' || 'rejected' || 'failed' => DsTone.danger,
      'voting' || 'funding' || 'agreement_pending' || 'due' || 'partially_paid' => DsTone.warning,
      'submitted' || 'under_review' || 'disbursing' => DsTone.info,
      _ => DsTone.neutral,
    };

/// Spideli Finance > Loans: borrow from, and lend to, the members of your
/// groups. `platform_settings/lending` must exist (admin).
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LendingConfig?>(
      future: FinanceLendingService.config(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return DsScaffold(
          title: "Loans".tr,
          maxContentWidth: DsLayout.contentMax,
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
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.handshake_outlined, title: "Loans are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsSegmentedTabs(
                          segments: [DsSegment("Borrow".tr), DsSegment("Group requests".tr), DsSegment("Lent".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const DsGap(DsSpace.lg),
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
        if (snap.hasError) return DsErrorState(message: "Could not load the loans.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        if (snap.data!.isEmpty) return DsEmptyState(icon: Icons.handshake_outlined, title: empty.tr, compact: true);
        return Column(
          children: [
            for (final l in snap.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: DsCard.outlined(
                  onTap: () => Get.to(() => LoanScreen(loanId: l.id)),
                  child: Row(
                    children: [
                      DsIconWell(icon: Icons.handshake_outlined, tone: _tone(l.status)),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(FinanceMoney.format(l.amount, l.currency), style: DsTypography.titleSm.tabular),
                            Text('${GroupLabels.purpose(l.purpose).tr} · ${l.durationMonths} ${"months".tr}${l.groupName.isEmpty ? '' : ' · ${l.groupName}'}', style: DsTypography.caption),
                          ],
                        ),
                      ),
                      DsBadge(label: LoanActions.statusLabel(l.status).tr, tone: _tone(l.status), small: true),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
    return DsScaffold(
      title: "Request a loan".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(label: "Send my request".tr, size: DsButtonSize.lg, expand: true, onPressed: verified ? _submit : null),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          StreamBuilder<List<Tontine>>(
            stream: FinanceGroupService.myTontines(),
            builder: (context, snap) {
              final groups = (snap.data ?? const <Tontine>[]).where((t) => t.isActive || t.isForming).toList();
              return DsFormSection(
                title: "Group".tr,
                subtitle: "The members of this group vote on your request and can fund it.".tr,
                icon: Icons.groups_2_outlined,
                children: [
                  if (snap.hasData && groups.isEmpty)
                    Text("You need to belong to a tontine group to borrow from its members.".tr, style: DsTypography.body)
                  else
                    DsDropdown<String>(
                      label: "Group".tr,
                      value: _groupId,
                      items: [for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                ],
              );
            },
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Loan".tr,
            icon: Icons.handshake_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DsTextField(
                      label: "Amount".tr,
                      controller: _amount,
                      requiredMark: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              Text("Duration".tr, style: DsTypography.label),
              const DsGap(DsSpace.xs),
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
            const DsGap(DsSpace.lg),
            DsFormSection(
              title: "Estimated repayments".tr,
              icon: Icons.calculate_outlined,
              children: [
                _row(context, "Each installment".tr, '${FinanceMoney.format(estimate.installmentAmount, _currency)} · ${Frequency.label(_frequency).tr}'),
                _row(context, "Number of installments".tr, '${estimate.installments.length}'),
                _row(context, "Total interest".tr, FinanceMoney.format(estimate.totalInterest, _currency)),
                _row(context, "Fee".tr, FinanceMoney.format(estimate.fee, _currency)),
                _row(context, "Total to repay".tr, FinanceMoney.format(estimate.totalRepaid, _currency)),
                _row(context, "Interest".tr, '${cfg.annualInterestPercent}% ${"a year".tr} (${(cfg.interestMethod == 'flat' ? 'flat rate' : 'on the remaining balance').tr})'),
                if (cfg.latePenaltyPercent > 0) _row(context, "Late payment penalty".tr, '${cfg.latePenaltyPercent}%'),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(
                    label: (_showSchedule ? "Hide the schedule" : "See the schedule").tr,
                    size: DsButtonSize.sm,
                    onPressed: () => setState(() => _showSchedule = !_showSchedule),
                  ),
                ),
                if (_showSchedule)
                  for (final i in estimate.installments) _row(context, '${i.number}. ${_date(i.dueDate)}', FinanceMoney.format(i.total, _currency)),
                Text("This is an estimate. The binding amounts, dates and fees are in the loan agreement you accept before any money is paid out.".tr,
                    style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
              ],
            ),
          ],
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Supporting documents (optional)".tr,
            subtitle: "Payslips, invoices, a business plan... Only the reviewers and your group's voters see them.".tr,
            icon: Icons.attach_file_rounded,
            children: [
              for (final (i, f) in _documents.indexed)
                DsListTile(
                  padding: EdgeInsets.zero,
                  leadingIcon: Icons.image_outlined,
                  title: '${"Document".tr} ${i + 1}',
                  subtitle: f.path.split('/').last,
                  trailing: DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, onPressed: () => setState(() => _documents.removeAt(i))),
                ),
              if (_documents.length < 5) Align(alignment: AlignmentDirectional.centerStart, child: DsButton.ghost(label: "Add a photo".tr, icon: Icons.add_a_photo_outlined, onPressed: _addDocument)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
          const DsGap(DsSpace.sm),
          Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(value, textAlign: TextAlign.end, style: DsTypography.bodyStrong.tabular))),
        ],
      ),
    );

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
          return DsScaffold(
            title: "Loan".tr,
            maxContentWidth: DsLayout.contentMax,
            body: snap.hasError
                ? DsErrorState(message: "Could not load this loan.".tr)
                : l == null
                    ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                    : _LoanBody(loan: l, config: cfgSnap.data),
          );
        },
      ),
    );
  }
}

class _LoanBody extends StatelessWidget {
  final Loan loan;
  final LendingConfig? config;

  const _LoanBody({required this.loan, required this.config});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final uid = FinanceService.uid;
    final bool borrower = uid == l.borrowerId;
    final methods = config?.paymentMethods ?? const ['wallet'];
    final int stepIndex = LoanActions.steps.indexOf(l.status == 'overdue' ? 'active' : l.status);
    final bool ended = const ['rejected', 'cancelled', 'defaulted'].contains(l.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: _tone(l.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(FinanceMoney.format(l.amount, l.currency), style: DsTypography.title.tabular)),
                DsBadge(label: LoanActions.statusLabel(l.status).tr, tone: _tone(l.status)),
              ]),
              Text('${GroupLabels.purpose(l.purpose).tr} · ${l.durationMonths} ${"months".tr} · ${Frequency.label(l.frequency).tr}', style: DsTypography.caption),
              if (l.groupName.isNotEmpty) Text('${"Group".tr}: ${l.groupName}', style: DsTypography.caption),
              if (l.outstandingAmount > 0) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text('${"Still to repay".tr}: ${FinanceMoney.format(l.outstandingAmount, l.currency)}', style: DsTypography.bodyStrong)),
              if ((l.reason ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: _tone(l.status), title: "Reason".tr, message: l.reason!)),
            ],
          ),
        ),
        if (l.description.isNotEmpty) ...[const DsGap(DsSpace.md), Text(l.description, style: DsTypography.body)],
        const DsGap(DsSpace.md),
        if (!ended && stepIndex >= 0)
          DsTimeline(
            steps: [
              for (final (i, s) in LoanActions.steps.indexed)
                DsTimelineStep(title: LoanActions.statusLabel(s).tr, state: i < stepIndex ? DsStepState.done : (i == stepIndex ? DsStepState.current : DsStepState.upcoming)),
            ],
          ),
        if (borrower) _Assessment(loanId: l.id),
        if (l.status == 'voting') _Voting(loan: l, config: config),
        if (l.status == 'funding' || l.lenderIds.contains(uid)) _Funding(loan: l, methods: methods),
        _Agreement(loan: l),
        _Schedule(loan: l, methods: methods),
        if (LoanActions.canCancel(l, uid))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(
              label: "Withdraw my request".tr,
              icon: Icons.close_rounded,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text("Withdraw this loan request?".tr),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text("Keep it".tr)),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text("Withdraw".tr)),
                    ],
                  ),
                );
                if (ok == true) await FinanceUi.run(() => FinanceLendingService.cancel(l.id), success: "Request withdrawn");
              },
            ),
          ),
      ],
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
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: DsFormSection(
            title: "Your credit assessment".tr,
            icon: Icons.speed_outlined,
            children: [
              _row(context, "Score".tr, '${a['score'] ?? '-'}${a['band'] == null ? '' : ' · ${a['band']}'}'),
              for (final f in factors)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: f['impact'] == 'negative' ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  leadingTone: f['impact'] == 'negative' ? DsTone.danger : DsTone.success,
                  title: f['label']?.toString() ?? '-',
                  subtitle: f['detail']?.toString(),
                ),
              Text("The main factors that shaped your score. Ask support if something looks wrong.".tr, style: DsTypography.caption),
            ],
          ),
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
    final ok = await DsBottomSheet.show<bool>(
      title: (approve ? "Approve this loan" : "Decline this loan").tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTextField(label: "Comment (optional)".tr, controller: comment, maxLines: 3),
          Text("Your vote is final and visible to the borrower as part of the result.".tr, style: DsTypography.caption),
          const DsGap(DsSpace.sm),
          DsButton.primary(label: "Confirm my vote".tr, expand: true, onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (ok == true) await FinanceUi.run(() => FinanceLendingService.vote(loan.id, approve, comment.text.trim()), success: "Vote recorded");
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final cfg = config;
    final tally = VoteTally(eligible: l.eligibleVoterIds.length, yes: l.votesYes, no: l.votesNo, quorumPercent: cfg?.quorumPercent ?? 50, approvalPercent: cfg?.approvalPercent ?? 50);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsFormSection(
        title: "Group vote".tr,
        icon: Icons.how_to_vote_outlined,
        children: [
          _row(context, "Votes".tr, '${tally.cast} / ${tally.eligible} (${"needed".tr}: ${tally.needed})'),
          _row(context, "Approve / decline".tr, '${tally.yes} / ${tally.no}'),
          _row(context, "Approval needed".tr, '${tally.approvalPercent}%'),
          if (l.votingEndsAt != null) _row(context, "Voting closes".tr, DateFormat('dd MMM yyyy, HH:mm').format(l.votingEndsAt!)),
          const DsGap(DsSpace.sm),
          StreamBuilder<Map<String, dynamic>?>(
            stream: FinanceLendingService.myVote(l.id),
            builder: (context, snap) {
              final mine = snap.data;
              if (mine != null) {
                return DsInlineAlert(tone: DsTone.info, message: (mine['approve'] == true ? "You voted to approve." : "You voted to decline.").tr);
              }
              if (!LoanActions.canVote(l, FinanceService.uid, alreadyVoted: false, now: DateTime.now())) return const SizedBox.shrink();
              return FinanceKycGate(
                builder: (context, verified) => Row(
                  children: [
                    Expanded(child: DsButton.secondary(label: "Decline".tr, onPressed: verified ? () => _vote(context, false) : null)),
                    const DsGap(DsSpace.sm),
                    Expanded(child: DsButton.primary(label: "Approve".tr, onPressed: verified ? () => _vote(context, true) : null)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsFormSection(
        title: "Funding".tr,
        icon: Icons.volunteer_activism_outlined,
        children: [
          DsProgressBar(value: l.fundingProgress, showPercent: true),
          const DsGap(DsSpace.xs),
          Text('${FinanceMoney.format(l.fundedAmount, l.currency)} / ${FinanceMoney.format(l.amount, l.currency)}', style: DsTypography.bodyStrong.tabular),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceLendingService.myFundings(l.id),
            builder: (context, snap) {
              final mine = snap.data ?? const [];
              if (mine.isEmpty) return const SizedBox.shrink();
              final int total = mine.where((f) => f['status'] == 'succeeded').fold(0, (s, f) => s + FinanceSummary.intOf(f['amount']));
              return Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text('${"You lent".tr}: ${FinanceMoney.format(total, l.currency)}', style: DsTypography.body));
            },
          ),
          if (LoanActions.canFund(l, FinanceService.uid)) ...[
            const DsGap(DsSpace.sm),
            FinanceKycGate(
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
          ],
        ],
      ),
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceLendingService.agreement(l.id),
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        final cur = a['currency']?.toString() ?? l.currency;
        final int version = FinanceSummary.intOf(a['version']);
        final bool canAccept = LoanActions.canAcceptAgreement(l, FinanceService.uid) && a['acceptedAt'] == null;
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: DsFormSection(
            title: "Loan agreement".tr,
            icon: Icons.description_outlined,
            children: [
              _row(context, "Amount".tr, FinanceMoney.format(FinanceSummary.intOf(a['principal']), cur)),
              _row(context, "Interest".tr, '${a['annualInterestPercent'] ?? '-'}% ${"a year".tr}'),
              _row(context, "Fee".tr, FinanceMoney.format(FinanceSummary.intOf(a['fee']), cur)),
              _row(context, "Total to repay".tr, FinanceMoney.format(FinanceSummary.intOf(a['totalRepayable']), cur)),
              if (a['latePenaltyPercent'] != null) _row(context, "Late payment penalty".tr, '${a['latePenaltyPercent']}%'),
              if ((a['terms'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text(a['terms'].toString(), style: DsTypography.body)),
              if (a['acceptedAt'] != null) DsInlineAlert(tone: DsTone.success, message: '${"Accepted on".tr} ${FinanceUi.date(a['acceptedAt'])}'),
              if (canAccept) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  title: Text("I have read the agreement and the repayment schedule, and I accept them.".tr),
                ),
                DsButton.primary(
                  label: "Accept the agreement".tr,
                  expand: true,
                  onPressed: !_accepted ? null : () => FinanceUi.run(() => FinanceLendingService.acceptAgreement(l.id, version), success: "Agreement accepted. The loan will be paid out."),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Schedule extends StatelessWidget {
  final Loan loan;
  final List<String> methods;

  const _Schedule({required this.loan, required this.methods});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.schedule(l.id),
      builder: (context, snap) {
        final installments = snap.data ?? const [];
        if (installments.isEmpty) return const SizedBox.shrink();
        final next = nextInstallment(installments);
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsFormSection(
                title: "Repayment schedule".tr,
                icon: Icons.event_note_outlined,
                children: [
                  for (final i in installments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text('${i['number']}. ${_date(FinanceGroupService.toDate(i['dueDate']))}', style: DsTypography.body)),
                        Text(FinanceMoney.format(FinanceSummary.intOf(i['amount']), l.currency), style: DsTypography.bodyStrong.tabular),
                        const DsGap(DsSpace.sm),
                        DsBadge(label: LoanActions.installmentLabel(i['status']?.toString()).tr, tone: _tone(i['status']?.toString()), small: true),
                      ]),
                    ),
                ],
              ),
              if (LoanActions.canRepay(l, FinanceService.uid)) ...[
                const DsGap(DsSpace.md),
                FinanceKycGate(
                  builder: (context, verified) => DsButton.primary(
                    label: next == null ? "Repay".tr : "${"Repay".tr} ${FinanceMoney.format(FinanceSummary.intOf(next['amountDue'] ?? next['amount']), l.currency)}",
                    icon: Icons.payments_outlined,
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
                ),
              ],
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: FinanceLendingService.repayments(l.id),
                builder: (context, rs) {
                  final list = rs.data ?? const [];
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: DsSpace.md),
                    child: DsFormSection(
                      title: "Repayments".tr,
                      icon: Icons.receipt_long_outlined,
                      children: [
                        for (final r in list)
                          DsListTile(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            leadingIcon: Icons.north_east_rounded,
                            leadingTone: _tone(r['status']?.toString()),
                            title: FinanceMoney.format(FinanceSummary.intOf(r['amount']), l.currency),
                            subtitle: '${FinanceUi.date(r['createdAt'])} · ${GroupLabels.contribution(r['status']?.toString()).tr}${(r['reference'] ?? '').toString().isEmpty ? '' : ' · ${r['reference']}'}',
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
