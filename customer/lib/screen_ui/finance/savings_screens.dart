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

String _date(DateTime? d) => d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

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
        return DsScaffold(
          title: "Savings goals".tr,
          maxContentWidth: DsLayout.contentMax,
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
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.savings_outlined, title: "Savings goals are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: const [_GoalInvitations(), _GoalList()],
                    ),
        );
      },
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
        return DsFormSection(
          title: "Invitations".tr,
          icon: Icons.mail_outline_rounded,
          children: [
            for (final g in invites)
              DsListTile(
                padding: EdgeInsets.zero,
                leadingIcon: Icons.groups_outlined,
                title: g.name,
                subtitle: '${GroupLabels.purpose(g.purpose).tr} · ${FinanceMoney.format(g.targetAmount, g.currency)}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsButton.ghost(label: "Decline".tr, size: DsButtonSize.sm, onPressed: () => FinanceUi.run(() => FinanceGroupService.respondToGoalInvite(g.id, false))),
                    DsButton.tonal(label: "Join".tr, size: DsButtonSize.sm, onPressed: () => FinanceUi.run(() => FinanceGroupService.respondToGoalInvite(g.id, true), success: "You joined the goal")),
                  ],
                ),
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
        if (snap.hasError) return DsErrorState(message: "Could not load your savings goals.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        final goals = snap.data!;
        if (goals.isEmpty) {
          return DsEmptyState(
            icon: Icons.savings_outlined,
            title: "No savings goal yet".tr,
            message: "Save step by step for a home, studies, travel, health or a project.".tr,
            compact: true,
          );
        }
        return Column(
          children: [
            for (final g in goals)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: DsCard.outlined(
                  onTap: () => Get.to(() => SavingsGoalScreen(goalId: g.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(g.name, style: DsTypography.titleSm)),
                          if (!g.isActive) DsBadge(label: _statusLabel(g.status).tr, small: true),
                          if (g.isGroup) const Padding(padding: EdgeInsetsDirectional.only(start: DsSpace.xs), child: Icon(Icons.groups_outlined, size: 18)),
                        ],
                      ),
                      Text('${GroupLabels.purpose(g.purpose).tr}${g.deadline == null ? '' : ' · ${"by".tr} ${_date(g.deadline)}'}', style: DsTypography.caption),
                      const DsGap(DsSpace.sm),
                      DsProgressBar(value: g.progress),
                      const DsGap(DsSpace.xs),
                      Text('${FinanceMoney.format(g.savedAmount, g.currency)} / ${FinanceMoney.format(g.targetAmount, g.currency)}', style: DsTypography.bodyStrong.tabular),
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

String _statusLabel(String s) => const {'active': 'Active', 'completed': 'Completed', 'cancelled': 'Cancelled'}[s] ?? s;

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
    return DsScaffold(
      title: "New savings goal".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Create goal".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Goal".tr,
            icon: Icons.flag_outlined,
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
                bottomSpacing: 0,
              ),
            ],
          ),
          if (cfg.frequencies.isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(
              title: "Scheduled contributions (optional)".tr,
              subtitle: "We remind you when a contribution is due.".tr,
              icon: Icons.event_repeat_outlined,
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
                  DsTextField(label: "${"Amount each time".tr} ($_currency)", controller: _scheduleAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), bottomSpacing: 0),
              ],
            ),
          ],
          if (cfg.groupGoals) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(
              title: "Save together (optional)".tr,
              subtitle: "Invite people by the email of their Spideli account. They join when they accept.".tr,
              icon: Icons.group_add_outlined,
              children: [DsTextField(label: "Emails, separated by commas".tr, controller: _invites, keyboardType: TextInputType.emailAddress, bottomSpacing: 0)],
            ),
          ],
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
          return DsScaffold(
            title: g?.name ?? "Savings goal".tr,
            maxContentWidth: DsLayout.contentMax,
            body: snap.hasError
                ? DsErrorState(message: "Could not load this goal.".tr)
                : g == null
                    ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FinanceGroupService.goalContributions(goalId),
                        builder: (context, cSnap) {
                          final contributions = cSnap.data ?? const [];
                          return _GoalBody(goal: g, config: cfgSnap.data, contributions: contributions);
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

  const _GoalBody({required this.goal, required this.config, required this.contributions});

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: goal.status == 'completed' ? DsTone.success : DsTone.brand,
          child: Row(
            children: [
              DsProgressRing(value: goal.progress, center: Text('${(goal.progress * 100).round()}%', style: DsTypography.titleSm)),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Saved".tr, style: DsTypography.caption),
                    Text(FinanceMoney.format(goal.savedAmount, cur), style: DsTypography.title.tabular),
                    Text('${"of".tr} ${FinanceMoney.format(goal.targetAmount, cur)} · ${"remaining".tr} ${FinanceMoney.format(goal.remaining, cur)}', style: DsTypography.caption),
                    if (!goal.isActive) Padding(padding: const EdgeInsets.only(top: 4), child: DsBadge(label: _statusLabel(goal.status).tr, small: true)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Plan".tr,
          icon: Icons.insights_outlined,
          children: [
            _row(context, "Purpose".tr, GroupLabels.purpose(goal.purpose).tr),
            if (goal.deadline != null) _row(context, "Deadline".tr, _date(goal.deadline)),
            _row(context, "Schedule".tr, goal.frequency == null ? Frequency.label(null).tr : '${FinanceMoney.format(goal.scheduleAmount, cur)} · ${Frequency.label(goal.frequency).tr}'),
            _row(context, "Projected completion".tr, projected == null ? "Not enough savings yet to estimate".tr : _date(projected)),
            if (needed != null && goal.remaining > 0) _row(context, "Needed per month to meet the deadline".tr, FinanceMoney.format(needed, cur)),
            if (onTrack != null)
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.sm),
                child: DsInlineAlert(
                  tone: onTrack ? DsTone.success : DsTone.warning,
                  message: (onTrack ? "On track for your deadline." : "At this pace you will finish after your deadline.").tr,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Text("Projections are estimates from your schedule or past contributions, not a guarantee.".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
        const DsGap(DsSpace.md),
        if (goal.isActive)
          FinanceKycGate(
            builder: (context, verified) => Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: [
                DsButton.primary(
                  label: "Add money".tr,
                  icon: Icons.add_rounded,
                  onPressed: !verified
                      ? null
                      : () async {
                          final amount = await askAmount(context, title: "Add money".tr, currency: cur);
                          if (amount == null || !context.mounted) return;
                          final key = FinanceGroupService.newRequestKey();
                          await FinancePaySheet.show(
                            context,
                            title: "${"Add money to".tr} ${goal.name}",
                            amount: amount,
                            currency: cur,
                            methods: methods,
                            submit: (payment) => FinanceGroupService.contributeToGoal(goal.id, amount, payment, key),
                          );
                        },
                ),
                if (goal.savedAmount > 0 && (config?.earlyWithdrawal == true || goal.remaining == 0))
                  DsButton.secondary(
                    label: "Withdraw".tr,
                    icon: Icons.south_west_rounded,
                    onPressed: !verified
                        ? null
                        : () async {
                            final amount = await askAmount(context, title: "Withdraw".tr, currency: cur, max: goal.savedAmount);
                            if (amount == null || !context.mounted) return;
                            final key = FinanceGroupService.newRequestKey();
                            await FinancePaySheet.show(
                              context,
                              title: "Withdraw to".tr,
                              amount: amount,
                              currency: cur,
                              methods: methods,
                              submit: (destination) => FinanceGroupService.requestWithdrawal(goal.id, amount, destination, key),
                            );
                          },
                  ),
                if (isOwner && config?.groupGoals == true)
                  DsButton.ghost(
                    label: "Invite".tr,
                    icon: Icons.person_add_alt_outlined,
                    onPressed: () async {
                      final email = await _askEmail(context);
                      if (email != null) await FinanceUi.run(() => FinanceGroupService.inviteToGoal(goal.id, email), success: "Invitation sent");
                    },
                  ),
                if (isOwner)
                  DsButton.ghost(
                    label: "Cancel goal".tr,
                    icon: Icons.close_rounded,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text("Cancel this goal?".tr),
                          content: Text("The money saved is returned according to the withdrawal rules. This cannot be undone.".tr),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text("Keep it".tr)),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text("Cancel goal".tr)),
                          ],
                        ),
                      );
                      if (ok == true) await FinanceUi.run(() => FinanceGroupService.cancelGoal(goal.id), success: "Goal cancelled");
                    },
                  ),
              ],
            ),
          ),
        const DsGap(DsSpace.lg),
        DsFormSection(
          title: "Contributions".tr,
          icon: Icons.receipt_long_outlined,
          children: [
            if (contributions.isEmpty) Text("No contribution yet.".tr, style: DsTypography.body),
            for (final x in contributions)
              DsListTile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                leadingIcon: Icons.south_west_rounded,
                leadingTone: x['status'] == 'succeeded' ? DsTone.success : (x['status'] == 'failed' ? DsTone.danger : DsTone.neutral),
                title: FinanceMoney.format(FinanceSummary.intOf(x['amount']), x['currency']?.toString() ?? cur),
                subtitle: '${FinanceUi.date(x['createdAt'])} · ${GroupLabels.contribution(x['status']?.toString()).tr}${(x['reference'] ?? '').toString().isEmpty ? '' : ' · ${x['reference']}'}',
              ),
          ],
        ),
        const DsGap(DsSpace.lg),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.goalWithdrawals(goal.id),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return DsFormSection(
              title: "Withdrawals".tr,
              icon: Icons.north_east_rounded,
              children: [
                for (final w in list)
                  DsListTile(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    leadingIcon: Icons.north_east_rounded,
                    title: FinanceMoney.format(FinanceSummary.intOf(w['amount']), w['currency']?.toString() ?? cur),
                    subtitle: '${FinanceUi.date(w['createdAt'])} · ${GroupLabels.withdrawal(w['status']?.toString()).tr}${(w['reason'] ?? '').toString().isEmpty ? '' : ' · ${w['reason']}'}',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
            const DsGap(DsSpace.sm),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: DsTypography.bodyStrong.tabular)),
          ],
        ),
      );
}

Future<String?> _askEmail(BuildContext context) {
  final ctrl = TextEditingController();
  return DsBottomSheet.show<String>(
    title: "Invite by email".tr,
    child: StatefulBuilder(
      builder: (context, setState) {
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(ctrl.text.trim());
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Email of their Spideli account".tr, controller: ctrl, autofocus: true, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
            DsButton.primary(label: "Send invitation".tr, expand: true, onPressed: ok ? () => Get.back(result: ctrl.text.trim().toLowerCase()) : null),
          ],
        );
      },
    ),
  );
}

/// Shared with the tontine screens.
Future<String?> askInviteEmail(BuildContext context) => _askEmail(context);
