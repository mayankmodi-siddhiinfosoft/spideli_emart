import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

String _statusLabel(String s) => const {'active': 'Active', 'completed': 'Completed', 'cancelled': 'Cancelled'}[s] ?? s;

/// Form sections: room above the first label; every field brings its own
/// bottom spacing.
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs);

/// An empty line inside a section ("No contribution yet.").
Widget _quiet(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Text(text, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
    );

/// Spideli Finance > Savings goals: the user's goals and invitations.
/// `platform_settings/savings` must exist (admin), else "not available".
class SavingsListScreen extends StatelessWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavingsConfig?>(
      future: FinanceGroupService.savingsConfig(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return FinScaffold(
          title: "Savings goals".tr,
          bottomBar: cfg == null
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "New savings goal".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => SavingsGoalFormScreen(config: cfg)),
                  ),
                ),
          body: FinBody(
            children: [
              if (cfgSnap.connectionState == ConnectionState.waiting)
                FinState.loading()
              else if (cfg == null)
                FinState.empty(Icons.savings_outlined, "Savings goals are not available yet.".tr)
              else
                ...const [_SavingsHero(), _GoalInvitations(), _GoalList()],
            ],
          ),
        );
      },
    );
  }
}

/// The focal point: what the user has saved in their goals, as the server
/// totals it (finance_summaries/{uid}); hidden until there is a summary.
class _SavingsHero extends StatelessWidget {
  const _SavingsHero();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FinanceSummary?>(
      stream: FinanceService.summary(),
      builder: (context, snap) {
        final s = snap.data;
        final savings = s?.savings;
        if (s == null || savings == null) return const SizedBox.shrink();
        String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s.currency);
        final double? progress = s.savingsProgress;
        return FinHero(
          label: "Saved so far".tr,
          amount: m(savings['savedAmount']),
          caption: '${FinanceSummary.intOf(savings['activeGoals'])} ${"active".tr} · ${"Target amount".tr} ${m(savings['targetAmount'])}',
          footer: progress == null ? null : _HeroProgress(value: progress),
        );
      },
    );
  }
}

/// A progress bar drawn for the navy hero panel (the brand bar would not show on it).
class _HeroProgress extends StatelessWidget {
  final double value;

  const _HeroProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    final String pct = '${(v * 100).round()}%';
    return Semantics(
      value: pct,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: DsRadius.brPill,
              child: SizedBox(
                height: 6,
                child: Stack(children: [
                  Container(color: Colors.white.withValues(alpha: 0.16)),
                  FractionallySizedBox(alignment: AlignmentDirectional.centerStart, widthFactor: v, child: Container(color: Colors.white)),
                ]),
              ),
            ),
          ),
          const DsGap(DsSpace.sm),
          Text(pct, style: DsTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600).tabular),
        ],
      ),
    );
  }
}

/// An invitation row: what it is, then decline / join.
class _Invitation extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback onJoin;

  const _Invitation({required this.icon, required this.title, required this.subtitle, required this.onDecline, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinListTile(icon: icon, iconTone: DsTone.brand, title: title, subtitle: subtitle),
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DsButton.ghost(label: "Decline".tr, size: DsButtonSize.sm, onPressed: onDecline),
              const DsGap(DsSpace.sm),
              DsButton.tonal(label: "Join".tr, icon: Icons.check_rounded, size: DsButtonSize.sm, onPressed: onJoin),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalInvitations extends StatelessWidget {
  const _GoalInvitations();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsGoal>>(
      stream: FinanceGroupService.goalInvitations(),
      builder: (context, snap) {
        final invites = snap.data ?? const [];
        if (invites.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Invitations".tr,
          divided: true,
          children: [
            for (final g in invites)
              _Invitation(
                icon: Icons.groups_outlined,
                title: g.name,
                subtitle: '${GroupLabels.purpose(g.purpose).tr} · ${FinanceMoney.format(g.targetAmount, g.currency)}',
                onDecline: () => FinanceUi.run(() => FinanceGroupService.respondToGoalInvite(g.id, false)),
                onJoin: () => FinanceUi.run(() => FinanceGroupService.respondToGoalInvite(g.id, true), success: "You joined the goal"),
              ),
          ],
        );
      },
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsGoal>>(
      stream: FinanceGroupService.myGoals(),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load your savings goals.".tr);
        if (!snap.hasData) return FinState.loading();
        final goals = snap.data!;
        if (goals.isEmpty) {
          return FinState.empty(
            Icons.savings_outlined,
            "No savings goal yet".tr,
            message: "Save step by step for a home, studies, travel, health or a project.".tr,
          );
        }
        final active = goals.where((g) => g.isActive).toList();
        final closed = goals.where((g) => !g.isActive).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active.isNotEmpty) FinSection(title: "Active goals".tr, divided: true, children: [for (final g in active) _GoalTile(goal: g)]),
            if (closed.isNotEmpty) FinSection(title: "Closed".tr, divided: true, children: [for (final g in closed) _GoalTile(goal: g)]),
          ],
        );
      },
    );
  }
}

/// A goal in the list: name, purpose and deadline, what is saved, and the
/// progress toward the target.
class _GoalTile extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final bool completed = g.status == 'completed';
    return MergeSemantics(
      child: InkWell(
        onTap: () => Get.to(() => SavingsGoalScreen(goalId: g.id)),
        borderRadius: DsRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinListTile(
                icon: g.isGroup ? Icons.groups_outlined : Icons.savings_outlined,
                iconTone: completed ? DsTone.success : (g.isActive ? DsTone.brand : DsTone.neutral),
                title: g.name,
                subtitle: '${GroupLabels.purpose(g.purpose).tr}${g.deadline == null ? '' : ' · ${"by".tr} ${_date(g.deadline)}'}',
                amount: FinanceMoney.format(g.savedAmount, g.currency),
                status: g.isActive ? null : g.status,
                statusLabel: g.isActive ? null : _statusLabel(g.status).tr,
                chevron: true,
              ),
              Padding(
                // Aligned with the text, after the 40 px icon and its gap.
                padding: const EdgeInsetsDirectional.only(start: 40 + DsSpace.md),
                child: FinProgress(
                  value: g.progress,
                  label: '${"Target amount".tr} ${FinanceMoney.format(g.targetAmount, g.currency)}',
                  tone: completed ? DsTone.success : DsTone.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// New savings goal. Choices come from the admin configuration.
class SavingsGoalFormScreen extends StatefulWidget {
  final SavingsConfig config;

  const SavingsGoalFormScreen({super.key, required this.config});

  @override
  State<SavingsGoalFormScreen> createState() => _SavingsGoalFormScreenState();
}

class _SavingsGoalFormScreenState extends State<SavingsGoalFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _target = TextEditingController();
  final _scheduleAmount = TextEditingController();
  final _invites = TextEditingController();
  late String _purpose = widget.config.purposes.first;
  late String _currency = widget.config.currencies.first;
  String? _frequency;
  DateTime? _deadline;

  @override
  void dispose() {
    for (final c in [_name, _description, _target, _scheduleAmount, _invites]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final int? target = FinanceAmount.parse(_target.text, _currency);
    final int? schedule = _frequency == null ? null : FinanceAmount.parse(_scheduleAmount.text, _currency);
    if (_name.text.trim().isEmpty) return ShowToastDialog.showToast("Please give the goal a name.".tr);
    if (target == null) return ShowToastDialog.showToast("Please enter a valid target amount.".tr);
    if (_frequency != null && schedule == null) return ShowToastDialog.showToast("Please enter the amount of each scheduled contribution.".tr);
    final emails = _invites.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    if (emails.any((e) => !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e))) return ShowToastDialog.showToast("Please check the email addresses.".tr);
    if (emails.length + 1 > widget.config.maxMembers) return ShowToastDialog.showToast("${"A group goal has at most".tr} ${widget.config.maxMembers} ${"members".tr}.");
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceGroupService.createGoal(
        name: _name.text.trim(),
        purpose: _purpose,
        description: _description.text.trim(),
        targetAmount: target,
        currency: _currency,
        deadline: _deadline,
        frequency: _frequency,
        scheduleAmount: schedule,
        inviteEmails: emails,
      );
    }, success: "Savings goal created");
    if (ok && id != null) Get.off(() => SavingsGoalScreen(goalId: id!));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return FinScaffold(
      title: "New savings goal".tr,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Create goal".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: FinBody(
        children: [
          FinSection(
            title: "Goal".tr,
            top: 0,
            padding: _formPadding,
            children: [
              DsTextField(label: "Name".tr, controller: _name, requiredMark: true),
              DsDropdown<String>(
                label: "Purpose".tr,
                value: _purpose,
                items: [for (final p in cfg.purposes) DropdownMenuItem(value: p, child: Text(GroupLabels.purpose(p).tr))],
                onChanged: (v) => setState(() => _purpose = v ?? _purpose),
              ),
              DsTextField(label: "Description".tr, controller: _description, maxLines: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: DsTextField(label: "Target amount".tr, controller: _target, requiredMark: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
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
              DsTextField(
                label: "Deadline (optional)".tr,
                controller: TextEditingController(text: _deadline == null ? '' : _date(_deadline)),
                readOnly: true,
                suffix: const Icon(Icons.event_outlined, size: 18),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: context, initialDate: _deadline ?? DateTime(now.year + 1, now.month, now.day), firstDate: now, lastDate: DateTime(now.year + 30));
                  if (d != null) setState(() => _deadline = d);
                },
              ),
            ],
          ),
          if (cfg.frequencies.isNotEmpty)
            FinSection(
              title: "Scheduled contributions (optional)".tr,
              padding: _formPadding,
              footnote: "We remind you when a contribution is due.".tr,
              children: [
                DsDropdown<String?>(
                  label: "Frequency".tr,
                  value: _frequency,
                  items: [
                    DropdownMenuItem(value: null, child: Text("No schedule".tr)),
                    for (final f in cfg.frequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr)),
                  ],
                  onChanged: (v) => setState(() => _frequency = v),
                ),
                if (_frequency != null)
                  DsTextField(label: "${"Amount each time".tr} ($_currency)", controller: _scheduleAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          if (cfg.groupGoals)
            FinSection(
              title: "Save together (optional)".tr,
              padding: _formPadding,
              footnote: "Invite people by the email of their Spideli account. They join when they accept.".tr,
              children: [DsTextField(label: "Emails, separated by commas".tr, controller: _invites, keyboardType: TextInputType.emailAddress)],
            ),
        ],
      ),
    );
  }
}

/// One savings goal: progress, projection, actions and history.
class SavingsGoalScreen extends StatelessWidget {
  final String goalId;

  const SavingsGoalScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavingsConfig?>(
      future: FinanceGroupService.savingsConfig(),
      builder: (context, cfgSnap) => StreamBuilder<SavingsGoal?>(
        stream: FinanceGroupService.goal(goalId),
        builder: (context, snap) {
          final g = snap.data;
          return FinScaffold(
            title: g?.name ?? "Savings goal".tr,
            body: snap.hasError
                ? FinBody(children: [FinState.error("Could not load this goal.".tr)])
                : g == null
                    ? FinBody(children: [FinState.loading(rows: 4)])
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FinanceGroupService.goalContributions(goalId),
                        builder: (context, cSnap) {
                          final contributions = cSnap.data ?? const [];
                          return _GoalBody(
                            goal: g,
                            config: cfgSnap.data,
                            contributions: contributions,
                            loadingContributions: !cSnap.hasData && !cSnap.hasError,
                          );
                        },
                      ),
          );
        },
      ),
    );
  }
}

class _GoalBody extends StatelessWidget {
  final SavingsGoal goal;
  final SavingsConfig? config;
  final List<Map<String, dynamic>> contributions;
  final bool loadingContributions;

  const _GoalBody({required this.goal, required this.config, required this.contributions, this.loadingContributions = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final now = DateTime.now();
    final received = contributions
        .where((x) => x['status'] == 'succeeded')
        .map((x) => DatedAmount(FinanceGroupService.toDate(x['createdAt']) ?? now, FinanceSummary.intOf(x['amount'])))
        .toList();
    final double rate = SavingsProjection.monthlyRate(goal, received, now);
    final DateTime? projected = SavingsProjection.projectedCompletion(goal, rate, now);
    final bool? onTrack = SavingsProjection.onTrack(goal, projected);
    final int? needed = SavingsProjection.neededMonthly(goal, now);
    final String cur = goal.currency;
    final bool isOwner = goal.ownerId == FinanceService.uid;
    final methods = config?.paymentMethods ?? const ['wallet'];

    return FinBody(
      children: [
        // Money actions need a verified identity; the gate shows how to get it.
        if (goal.isActive)
          FinanceKycGate(builder: (context, verified) => _hero(context, verified: verified, isOwner: isOwner, methods: methods))
        else
          _hero(context, verified: false, isOwner: isOwner, methods: methods),
        FinSection(
          title: "Plan".tr,
          divided: true,
          children: [
            FinRow("Purpose".tr, GroupLabels.purpose(goal.purpose).tr),
            if (goal.deadline != null) FinRow("Deadline".tr, _date(goal.deadline)),
            FinRow("Schedule".tr, goal.frequency == null ? Frequency.label(null).tr : '${FinanceMoney.format(goal.scheduleAmount, cur)} · ${Frequency.label(goal.frequency).tr}'),
            if (goal.isGroup) FinRow("Members".tr, '${goal.memberIds.length}'),
          ],
        ),
        FinSection(
          title: "Projection".tr,
          divided: true,
          children: [
            FinRow("Projected completion".tr, projected == null ? "Not enough savings yet to estimate".tr : _date(projected)),
            if (needed != null && goal.remaining > 0) FinRow("Needed per month to meet the deadline".tr, FinanceMoney.format(needed, cur)),
          ],
        ),
        // The projection is an estimate, and says so.
        FinNotice(
          "Projections are estimates from your schedule or past contributions, not a guarantee.".tr,
          title: onTrack == null ? null : (onTrack ? "On track for your deadline." : "At this pace you will finish after your deadline.").tr,
          tone: onTrack == null ? DsTone.info : (onTrack ? DsTone.success : DsTone.warning),
        ),
        if (loadingContributions)
          FinState.loading(rows: 2)
        else
          FinSection(
            title: "Contributions".tr,
            divided: true,
            children: [
              if (contributions.isEmpty) _quiet(context, "No contribution yet.".tr),
              for (final x in contributions) _contribution(context, x),
            ],
          ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.goalWithdrawals(goal.id),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "Withdrawals".tr,
              divided: true,
              children: [for (final w in list) _withdrawal(context, w)],
            );
          },
        ),
        if (goal.isActive && isOwner)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Cancel goal".tr,
              icon: Icons.close_rounded,
              expand: true,
              color: c.danger,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Cancel this goal?".tr,
                  message: "The money saved is returned according to the withdrawal rules. This cannot be undone.".tr,
                  lines: [("Saved so far".tr, FinanceMoney.format(goal.savedAmount, cur))],
                  confirmLabel: "Cancel goal".tr,
                  destructive: true,
                );
                if (ok) await FinanceUi.run(() => FinanceGroupService.cancelGoal(goal.id), success: "Goal cancelled");
              },
            ),
          ),
      ],
    );
  }

  /// The focal point: what is saved, of what, the progress and the actions.
  Widget _hero(BuildContext context, {required bool verified, required bool isOwner, required List<String> methods}) {
    final g = goal;
    final String cur = g.currency;
    final actions = <FinAction>[
      if (g.isActive) ...[
        FinAction(
          Icons.add_rounded,
          "Add money".tr,
          !verified
              ? null
              : () async {
                  final amount = await askAmount(context, title: "Add money".tr, currency: cur);
                  if (amount == null || !context.mounted) return;
                  final key = FinanceGroupService.newRequestKey();
                  await FinancePaySheet.show(
                    context,
                    title: "${"Add money to".tr} ${g.name}",
                    amount: amount,
                    currency: cur,
                    methods: methods,
                    submit: (payment) => FinanceGroupService.contributeToGoal(g.id, amount, payment, key),
                  );
                },
        ),
        if (g.savedAmount > 0 && (config?.earlyWithdrawal == true || g.remaining == 0))
          FinAction(
            Icons.south_west_rounded,
            "Withdraw".tr,
            !verified
                ? null
                : () async {
                    final amount = await askAmount(context, title: "Withdraw".tr, currency: cur, max: g.savedAmount);
                    if (amount == null || !context.mounted) return;
                    final key = FinanceGroupService.newRequestKey();
                    await FinancePaySheet.show(
                      context,
                      title: "Withdraw to".tr,
                      amount: amount,
                      currency: cur,
                      methods: methods,
                      submit: (destination) => FinanceGroupService.requestWithdrawal(g.id, amount, destination, key),
                      payout: true,
                    );
                  },
          ),
        if (isOwner && config?.groupGoals == true)
          FinAction(Icons.person_add_alt_outlined, "Invite".tr, () async {
            final email = await _askEmail(context);
            if (email != null) await FinanceUi.run(() => FinanceGroupService.inviteToGoal(g.id, email), success: "Invitation sent");
          }),
      ],
    ];
    return FinHero(
      label: "Saved so far".tr,
      amount: FinanceMoney.format(g.savedAmount, cur),
      caption: '${"of".tr} ${FinanceMoney.format(g.targetAmount, cur)} · ${"remaining".tr} ${FinanceMoney.format(g.remaining, cur)}',
      trailing: g.isActive ? null : FinStatusChip(status: g.status, label: _statusLabel(g.status).tr, icon: true),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroProgress(value: g.progress),
          if (actions.isNotEmpty) ...[const DsGap(DsSpace.lg), FinActions(onHero: true, actions: actions)],
        ],
      ),
    );
  }

  Widget _contribution(BuildContext context, Map<String, dynamic> x) {
    final String status = x['status']?.toString() ?? '';
    final int amount = FinanceSummary.intOf(x['amount']);
    final String reference = (x['reference'] ?? '').toString();
    return FinListTile(
      icon: Icons.south_west_rounded,
      iconTone: status == 'succeeded' ? DsTone.success : (status == 'failed' ? DsTone.danger : DsTone.neutral),
      title: FinanceUi.date(x['createdAt']),
      subtitle: reference.isEmpty ? null : ltrRef(reference),
      amount: FinanceMoney.signed(amount, x['currency']?.toString() ?? goal.currency),
      // Money in once received; a failed or refunded one is shown muted.
      amountColor: switch (status) {
        'succeeded' => finAmountColor(context, amount),
        'failed' || 'refunded' => DsColors.of(context).textMuted,
        _ => null,
      },
      status: status,
      statusLabel: GroupLabels.contribution(x['status']?.toString()).tr,
    );
  }

  Widget _withdrawal(BuildContext context, Map<String, dynamic> w) {
    final String status = w['status']?.toString() ?? '';
    final String reason = (w['reason'] ?? '').toString();
    return FinListTile(
      icon: Icons.north_east_rounded,
      title: FinanceUi.date(w['createdAt']),
      subtitle: reason.isEmpty ? null : reason,
      amount: FinanceMoney.signed(-FinanceSummary.intOf(w['amount']), w['currency']?.toString() ?? goal.currency),
      amountColor: status == 'rejected' ? DsColors.of(context).textMuted : null,
      status: status,
      statusLabel: GroupLabels.withdrawal(w['status']?.toString()).tr,
    );
  }
}

Future<String?> _askEmail(BuildContext context) {
  final ctrl = TextEditingController();
  return finSheet<String>(
    title: "Invite by email".tr,
    child: StatefulBuilder(
      builder: (context, setState) {
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(ctrl.text.trim());
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Email of their Spideli account".tr, controller: ctrl, autofocus: true, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
            DsButton.primary(label: "Send invitation".tr, icon: Icons.send_rounded, expand: true, onPressed: ok ? () => Get.back(result: ctrl.text.trim().toLowerCase()) : null),
          ],
        );
      },
    ),
  );
}

/// Shared with the tontine screens.
Future<String?> askInviteEmail(BuildContext context) => _askEmail(context);
