import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_chat_screens.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_chat_service.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

/// Known goal statuses; any other is shown humanized, never as a raw key.
String _statusLabel(String s) =>
    const {'active': 'Active', 'completed': 'Completed', 'cancelled': 'Cancelled', 'cancellation_requested': 'Cancellation requested'}[s] ??
    (s.trim().isEmpty ? 'Unknown' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' '));

bool _emailOk(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

/// Why an invitation was refused, naming the address when it is the reason.
String inviteRefusal(FinanceException e) {
  final String email = e.details['email']?.toString() ?? '';
  return switch (e.reason) {
    'recipient_not_found' => "No Spideli account uses this email: @email".trParams({'email': email}),
    'invite_self' => "You cannot invite yourself.".tr,
    'already_member' => "@email is already a member or invited.".trParams({'email': email}),
    'group_full' => "The group is full: nobody else can be invited.".tr,
    _ => FinanceErrors.messageKey(e.reason).tr,
  };
}

/// [FinanceUi.run] for invitations: a refusal names the address concerned.
Future<bool> runInvite(Future<void> Function() action, {required String success}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await action();
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(success.tr);
    return true;
  } on FinanceException catch (e) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(inviteRefusal(e));
    return false;
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
    return false;
  }
}

/// Form sections: room above the first label; every field brings its own
/// bottom spacing.
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs);

/// An empty line inside a section ("No contribution yet.").
Widget _quiet(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Text(text, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
    );

/// Spideli Finance > Savings goals: the user's goals and invitations.
/// `platform_settings/savings` must exist (admin), else "not available";
/// a failed read offers Retry.
class SavingsListScreen extends StatelessWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinConfig<SavingsConfig>(
      load: FinanceGroupService.savingsConfig,
      builder: (context, st) {
        final cfg = st.config;
        final Widget? placeholder = st.placeholder(Icons.savings_outlined, "Savings goals are not available yet.".tr);
        return FinScaffold(
          title: "Collective savings".tr,
          bottomBar: !st.ready
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "New savings goal".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => SavingsGoalFormScreen(config: cfg!)),
                  ),
                ),
          body: FinBody(
            children: [
              if (placeholder != null) placeholder else ...const [_SavingsHero(), _GoalInvitations(), _GoalList()],
            ],
          ),
        );
      },
    );
  }
}

/// The focal point: what the user has saved in their goals (the dashboard
/// totals, FinanceService.summary); hidden until there is a summary.
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
          footer: progress == null ? null : _HeroProgress(value: progress, label: "Progress toward your targets".tr),
        );
      },
    );
  }
}

/// A progress bar drawn for the navy hero panel (the brand bar would not show on it).
class _HeroProgress extends StatelessWidget {
  final double value;

  /// What the bar measures, for screen readers.
  final String label;

  const _HeroProgress({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    final String pct = '${(v * 100).round()}%';
    return Semantics(
      label: label,
      value: pct,
      child: ExcludeSemantics(
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

  /// Joining is a commitment to a shared goal: its terms first.
  Future<void> _join(SavingsGoal g) async {
    final String cur = g.currency;
    final ok = await finConfirm(
      title: "Join this savings goal?".tr,
      message: "You will see the goal's progress and can add money to it. Its members see your contributions.".tr,
      lines: [
        ("Purpose".tr, GroupLabels.purpose(g.purpose).tr),
        ("Target amount".tr, FinanceMoney.format(g.targetAmount, cur)),
        ("Saved so far".tr, FinanceMoney.format(g.savedAmount, cur)),
        if (g.deadline != null) ("Deadline".tr, _date(g.deadline)),
        if (g.frequency != null) ("Schedule".tr, '${FinanceMoney.format(g.scheduleAmount, cur)} · ${Frequency.label(g.frequency).tr}'),
        ("Members".tr, '${g.memberIds.length}'),
      ],
      confirmLabel: "Join".tr,
      cancelLabel: "Not now".tr,
    );
    if (ok) await FinanceUi.run(() => FinanceGroupService.respondToGoalInvite(g.id, true), success: "You joined the goal");
  }

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
                onJoin: () => _join(g),
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
    return FinReload(
      builder: (context, retry) => StreamBuilder<List<SavingsGoal>>(
        stream: FinanceGroupService.myGoals(),
        builder: (context, snap) {
          if (snap.hasError) return FinState.error("Could not load your savings goals.".tr, onRetry: retry);
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
      ),
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

/// New savings goal, or - with [goal] - the owner's changes to one: name,
/// description, deadline and schedule (what the owner may change).
/// Choices come from the admin configuration.
class SavingsGoalFormScreen extends StatefulWidget {
  final SavingsConfig config;
  final SavingsGoal? goal;

  const SavingsGoalFormScreen({super.key, required this.config, this.goal});

  @override
  State<SavingsGoalFormScreen> createState() => _SavingsGoalFormScreenState();
}

class _SavingsGoalFormScreenState extends State<SavingsGoalFormScreen> {
  SavingsGoal? get _goal => widget.goal;
  bool get _editing => widget.goal != null;

  late final _name = TextEditingController(text: _goal?.name ?? '');
  late final _description = TextEditingController(text: _goal?.description ?? '');
  late final _target = TextEditingController(text: _goal == null ? '' : FinanceAmount.input(_goal!.targetAmount, _goal!.currency));
  late final _scheduleAmount = TextEditingController(text: _goal?.frequency == null ? '' : FinanceAmount.input(_goal!.scheduleAmount, _goal!.currency));
  final _invites = TextEditingController();
  final _invitesFocus = FocusNode();
  late final _deadlineText = TextEditingController(text: _goal?.deadline == null ? '' : _date(_goal!.deadline));
  late String _purpose = widget.config.purposes.first;
  late String _currency = _goal?.currency ?? widget.config.currencies.first;
  late String? _frequency = _goal?.frequency;
  late DateTime? _deadline = _goal?.deadline;

  @override
  void initState() {
    super.initState();
    // The addresses are checked as a whole once the field is left.
    _invitesFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _target, _scheduleAmount, _invites, _deadlineText]) {
      c.dispose();
    }
    _invitesFocus.dispose();
    super.dispose();
  }

  List<String> get _emails => _invites.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();

  /// What is wrong with the invitations, naming the address; [typing]
  /// leaves the address being typed alone.
  String? _invitesProblem({bool typing = false}) {
    final emails = _emails;
    final bool lastDone = !typing || RegExp(r'[,;\s]$').hasMatch(_invites.text);
    final checked = lastDone ? emails : (emails.isEmpty ? emails : emails.sublist(0, emails.length - 1));
    final bad = checked.where((e) => !_emailOk(e)).toList();
    if (bad.isNotEmpty) return "This email address is not valid: @email".trParams({'email': bad.first});
    if (emails.length + 1 > widget.config.maxMembers) {
      return "A group goal has at most @max members, you included.".trParams({'max': '${widget.config.maxMembers}'});
    }
    return null;
  }

  /// What is still needed before the goal can be saved (translated).
  List<String> _missing() {
    final int? schedule = FinanceAmount.parse(_scheduleAmount.text, _currency);
    return [
      if (_name.text.trim().isEmpty) "Name".tr,
      if (!_editing && FinanceAmount.parse(_target.text, _currency) == null) "Target amount".tr,
      if (_frequency != null && schedule == null) "Amount each time".tr,
      if (!_editing && _invitesProblem() != null) "Emails, separated by commas".tr,
    ];
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime initial = _deadline != null && !_deadline!.isBefore(today) ? _deadline! : DateTime(now.year + 1, now.month, now.day);
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: today, lastDate: DateTime(now.year + 30));
    if (d != null) {
      setState(() {
        _deadline = d;
        _deadlineText.text = _date(d);
      });
    }
  }

  Future<void> _save() async {
    if (_missing().isNotEmpty) return;
    final int? schedule = _frequency == null ? null : FinanceAmount.parse(_scheduleAmount.text, _currency);
    final g = _goal;
    if (g != null) return _update(g, schedule);
    final int target = FinanceAmount.parse(_target.text, _currency)!;
    String? id;
    // An invitation to an address without a Spideli account names it.
    final ok = await runInvite(() async {
      id = await FinanceGroupService.createGoal(
        name: _name.text.trim(),
        purpose: _purpose,
        description: _description.text.trim(),
        targetAmount: target,
        currency: _currency,
        deadline: _deadline,
        frequency: _frequency,
        scheduleAmount: schedule,
        inviteEmails: _emails,
      );
    }, success: "Savings goal created");
    if (ok && id != null) Get.off(() => SavingsGoalScreen(goalId: id!));
  }

  /// Sends only what changed; a removed schedule is cleared.
  Future<void> _update(SavingsGoal g, int? schedule) async {
    final String name = _name.text.trim();
    final String description = _description.text.trim();
    final bool deadlineChanged = _deadline != null && (g.deadline == null || !DateUtils.isSameDay(_deadline, g.deadline));
    final bool scheduleChanged = _frequency != g.frequency || (_frequency != null && schedule != g.scheduleAmount);
    if (name == g.name && description == g.description && !deadlineChanged && !scheduleChanged) {
      Get.back();
      return;
    }
    final ok = await FinanceUi.run(
      () => FinanceGroupService.updateGoal(
        g.id,
        name: name == g.name ? null : name,
        description: description == g.description ? null : description,
        deadline: deadlineChanged ? _deadline : null,
        frequency: scheduleChanged ? _frequency : null,
        scheduleAmount: scheduleChanged ? schedule : null,
        clearSchedule: scheduleChanged && _frequency == null,
      ),
      success: "Savings goal updated",
    );
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final missing = _missing();
    // A saved deadline can be moved, not removed (the update has no "none").
    final bool canClearDeadline = _deadline != null && _goal?.deadline == null;
    final String? invitesError = _invitesProblem(typing: _invitesFocus.hasFocus);
    final frequencies = [...cfg.frequencies, if (_frequency != null && !cfg.frequencies.contains(_frequency)) _frequency!];
    return FinScaffold(
      title: (_editing ? "Edit the goal" : "New savings goal").tr,
      bottomBar: DsStickyBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinMissing(missing),
            DsButton.primary(
              label: (_editing ? "Save changes" : "Create goal").tr,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: missing.isEmpty ? _save : null,
            ),
          ],
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            title: "Goal".tr,
            top: 0,
            padding: _formPadding,
            children: [
              DsTextField(label: "Name".tr, controller: _name, requiredMark: true, onChanged: (_) => setState(() {})),
              if (!_editing)
                DsDropdown<String>(
                  label: "Purpose".tr,
                  value: _purpose,
                  items: [for (final p in cfg.purposes) DropdownMenuItem(value: p, child: Text(GroupLabels.purpose(p).tr))],
                  onChanged: (v) => setState(() => _purpose = v ?? _purpose),
                ),
              DsTextField(label: "Description".tr, controller: _description, maxLines: 3),
              if (!_editing)
                FinAmountField(
                  label: "Target amount".tr,
                  controller: _target,
                  currency: _currency,
                  currencies: cfg.currencies,
                  onCurrencyChanged: (v) => setState(() => _currency = v),
                  onChanged: (_) => setState(() {}),
                ),
              DsTextField(
                label: "Deadline (optional)".tr,
                controller: _deadlineText,
                readOnly: true,
                helper: _goal?.deadline != null ? "A saved deadline can be moved, not removed.".tr : null,
                suffix: canClearDeadline
                    ? IconButton(
                        tooltip: "Clear".tr,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => setState(() {
                          _deadline = null;
                          _deadlineText.clear();
                        }),
                      )
                    : const Icon(Icons.event_outlined, size: 18),
                onTap: _pickDeadline,
              ),
            ],
          ),
          if (frequencies.isNotEmpty)
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
                    for (final f in frequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr)),
                  ],
                  onChanged: (v) => setState(() => _frequency = v),
                ),
                // Once a frequency is chosen, the amount of each contribution is required.
                if (_frequency != null)
                  FinAmountField(
                    label: "Amount each time".tr,
                    controller: _scheduleAmount,
                    currency: _currency,
                    onChanged: (_) => setState(() {}),
                  ),
              ],
            ),
          if (cfg.groupGoals && !_editing)
            FinSection(
              title: "Save together (optional)".tr,
              padding: _formPadding,
              footnote: "Invite people by the email of their Spideli account. They join when they accept.".tr,
              children: [
                DsTextField(
                  label: "Emails, separated by commas".tr,
                  controller: _invites,
                  focusNode: _invitesFocus,
                  keyboardType: TextInputType.emailAddress,
                  helper: invitesError == null ? "A group goal has at most @max members, you included.".trParams({'max': '${cfg.maxMembers}'}) : null,
                  errorText: invitesError,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One savings goal: progress, projection, its chart, members, actions and
/// history. A goal that no longer exists says so; a failed read offers Retry.
class SavingsGoalScreen extends StatefulWidget {
  final String goalId;

  const SavingsGoalScreen({super.key, required this.goalId});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  late Stream<SavingsGoal?> _goal = FinanceGroupService.goal(widget.goalId);
  late Stream<List<Map<String, dynamic>>> _contributions = FinanceGroupService.goalContributions(widget.goalId);
  late Stream<List<Map<String, dynamic>>> _withdrawals = FinanceGroupService.goalWithdrawals(widget.goalId);

  /// Read once; without it the goal still shows (wallet payments only).
  late final Future<SavingsConfig?> _config = FinanceGroupService.savingsConfig().catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavingsConfig?>(
      future: _config,
      builder: (context, cfgSnap) => StreamBuilder<SavingsGoal?>(
        stream: _goal,
        builder: (context, snap) {
          final g = snap.data;
          final Widget? state = FinState.of(
            snap,
            gone: "This savings goal is no longer available.",
            onRetry: () => setState(() => _goal = FinanceGroupService.goal(widget.goalId)),
          );
          return FinScaffold(
            title: g?.name ?? "Savings goal".tr,
            body: state != null || g == null
                ? FinBody(children: [state ?? FinState.loading(rows: 4)])
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _contributions,
                    builder: (context, cSnap) => StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _withdrawals,
                      builder: (context, wSnap) => _GoalBody(
                        goal: g,
                        config: cfgSnap.data,
                        contributions: cSnap.data,
                        contributionsFailed: cSnap.hasError,
                        onRetryContributions: () => setState(() => _contributions = FinanceGroupService.goalContributions(widget.goalId)),
                        withdrawals: wSnap.data,
                        withdrawalsFailed: wSnap.hasError,
                        onRetryWithdrawals: () => setState(() => _withdrawals = FinanceGroupService.goalWithdrawals(widget.goalId)),
                      ),
                    ),
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

  /// Null until loaded (or when the read failed).
  final List<Map<String, dynamic>>? contributions;
  final bool contributionsFailed;
  final VoidCallback onRetryContributions;

  /// Null until loaded (or when the read failed).
  final List<Map<String, dynamic>>? withdrawals;
  final bool withdrawalsFailed;
  final VoidCallback onRetryWithdrawals;

  const _GoalBody({
    required this.goal,
    required this.config,
    required this.contributions,
    required this.contributionsFailed,
    required this.onRetryContributions,
    required this.withdrawals,
    required this.withdrawalsFailed,
    required this.onRetryWithdrawals,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final now = DateTime.now();
    final list = contributionsFailed ? null : contributions;
    final wList = withdrawalsFailed ? null : withdrawals;
    final String cur = goal.currency;
    final bool isOwner = goal.ownerId == FinanceService.uid;
    final methods = config?.paymentMethods ?? const ['wallet'];
    // A schedule gives the pace by itself; otherwise it comes from the
    // contributions, so there is no projection until they are read.
    final bool scheduled = goal.frequency != null && goal.scheduleAmount > 0;
    final bool canProject = scheduled || list != null;
    final received = (list ?? const <Map<String, dynamic>>[])
        .where((x) => x['status'] == 'succeeded')
        .map((x) => DatedAmount(FinanceGroupService.toDate(x['createdAt']) ?? now, FinanceSummary.intOf(x['amount'])))
        .toList();
    final double rate = SavingsProjection.monthlyRate(goal, received, now);
    final DateTime? projected = canProject ? SavingsProjection.projectedCompletion(goal, rate, now) : null;
    final bool? onTrack = canProject ? SavingsProjection.onTrack(goal, projected) : null;
    final int? needed = SavingsProjection.neededMonthly(goal, now);
    final bool showNeeded = needed != null && goal.remaining > 0;
    final bool canEdit = goal.isActive && isOwner && config != null;

    return FinBody(
      children: [
        // Money actions need a verified identity; the gate shows how to get it.
        if (goal.isActive)
          FinanceKycGate(builder: (context, verified) => _hero(context, verified: verified, isOwner: isOwner, methods: methods))
        else
          _hero(context, verified: false, isOwner: isOwner, methods: methods),
        if (goal.status == 'cancellation_requested')
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: FinNotice(
              "Spideli returns the money saved to the members according to the withdrawal rules, then closes the goal.".tr,
              title: "Cancellation requested".tr,
              tone: DsTone.warning,
            ),
          ),
        FinSection(
          title: "Plan".tr,
          divided: true,
          actionLabel: canEdit ? "Edit".tr : null,
          onAction: canEdit ? () => Get.to(() => SavingsGoalFormScreen(config: config!, goal: goal)) : null,
          children: [
            if (goal.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                child: Text(goal.description, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
            FinRow("Purpose".tr, GroupLabels.purpose(goal.purpose).tr),
            if (goal.deadline != null) FinRow("Deadline".tr, _date(goal.deadline)),
            FinRow("Schedule".tr, goal.frequency == null ? Frequency.label(null).tr : '${FinanceMoney.format(goal.scheduleAmount, cur)} · ${Frequency.label(goal.frequency).tr}'),
            if (goal.isGroup) FinRow("Members".tr, '${goal.memberIds.length}'),
          ],
        ),
        if (canProject || showNeeded)
          FinSection(
            title: "Projection".tr,
            divided: true,
            children: [
              if (canProject) FinRow("Projected completion".tr, projected == null ? "Not enough savings yet to estimate".tr : _date(projected)),
              if (showNeeded) FinRow("Needed per month to meet the deadline".tr, FinanceMoney.format(needed, cur)),
            ],
          ),
        // The projection is an estimate, and says so.
        FinNotice(
          "Projections are estimates from your schedule or past contributions, not a guarantee.".tr,
          title: onTrack == null ? null : (onTrack ? "On track for your deadline." : "At this pace you will finish after your deadline.").tr,
          tone: onTrack == null ? DsTone.info : (onTrack ? DsTone.success : DsTone.warning),
        ),
        // The chart needs both histories; it waits for them (their own states are below).
        if (list != null && wList != null) _GoalProgress(goal: goal, contributions: list, withdrawals: wList),
        if (goal.isGroup) _GoalMembers(goal: goal),
        if (contributionsFailed)
          FinState.error("Could not load the contributions.".tr, onRetry: onRetryContributions)
        else if (list == null)
          FinState.loading(rows: 2)
        else
          FinSection(
            title: "Contributions".tr,
            divided: true,
            // The query reads the latest 50.
            footnote: list.length >= 50 ? "Showing the latest 50 contributions.".tr : null,
            children: [
              if (list.isEmpty) _quiet(context, "No contribution yet.".tr),
              for (final x in list) _contribution(context, x),
            ],
          ),
        if (withdrawalsFailed)
          FinState.error("Could not load the withdrawals.".tr, onRetry: onRetryWithdrawals)
        else if (wList != null && wList.isNotEmpty)
          FinSection(
            title: "Withdrawals".tr,
            divided: true,
            children: [for (final w in wList) _withdrawal(context, w)],
          ),
        if (goal.isActive && isOwner)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Cancel goal".tr,
              icon: Icons.close_rounded,
              expand: true,
              color: c.danger,
              onPressed: () => _cancel(),
            ),
          ),
      ],
    );
  }

  /// Cancelling closes the goal for everyone: say what is saved and what
  /// happens to it. A solo goal's balance goes back to the owner's wallet at
  /// once; a group goal's cancellation is done by Spideli.
  Future<void> _cancel() async {
    final g = goal;
    final String saved = FinanceMoney.format(g.savedAmount, g.currency);
    final ok = await finConfirm(
      title: "Cancel this goal?".tr,
      message: (g.isSolo
              ? "Nobody can add money to this goal any more. The @amount saved goes back to your Spideli Finance wallet now. This cannot be undone."
              : "Spideli closes the goal for all its members and returns the @amount saved according to the withdrawal rules. Nobody can add money to it any more. This cannot be undone.")
          .trParams({'amount': saved}),
      lines: [
        ("Saved so far".tr, saved),
        ("Target amount".tr, FinanceMoney.format(g.targetAmount, g.currency)),
        if (g.isGroup) ("Members".tr, '${g.memberIds.length}'),
      ],
      confirmLabel: (g.isSolo ? "Cancel goal" : "Ask to cancel").tr,
      destructive: true,
    );
    if (!ok) return;
    String? status;
    await FinanceUi.run(() async => status = await FinanceGroupService.cancelGoal(g.id));
    if (status == null) return;
    ShowToastDialog.showToast((status == 'cancelled'
            ? (g.savedAmount > 0 ? "Goal cancelled. The money saved is back in your wallet." : "Goal cancelled")
            : "Cancellation requested. Spideli returns the money and closes the goal.")
        .tr);
  }

  Future<void> _addMoney(BuildContext context, List<String> methods) async {
    final g = goal;
    final amount = await askAmount(context, title: "Add money".tr, currency: g.currency);
    if (amount == null || !context.mounted) return;
    await FinancePaySheet.show(
      context,
      title: "${"Add money to".tr} ${g.name}",
      amount: amount,
      currency: g.currency,
      methods: methods,
      // The contribution and its posting, written at once; a retry of the same payment never pays twice.
      submit: (FinanceFunding funding) => FinanceGroupService.contributeToGoal(g.id, amount, funding),
    );
  }

  /// Withdrawing goes to the user's Spideli Finance wallet: at once from a
  /// solo goal; from a group goal, once Spideli has checked the request
  /// against the group's rules.
  Future<void> _withdraw(BuildContext context) async {
    final g = goal;
    final String cur = g.currency;
    // Before the target is reached the withdrawal is early: say what it changes.
    if (g.remaining > 0) {
      final now = DateTime.now();
      final bool ok = await finConfirm(
        title: "Withdraw before reaching the target?".tr,
        message: "This goal has not reached its target yet. Money you withdraw no longer counts toward it.".tr,
        lines: [
          ("Saved so far".tr, FinanceMoney.format(g.savedAmount, cur)),
          ("Target amount".tr, FinanceMoney.format(g.targetAmount, cur)),
          if (g.deadline != null && g.deadline!.isAfter(now)) ("Deadline".tr, _date(g.deadline)),
        ],
        confirmLabel: "Continue".tr,
      );
      if (!ok || !context.mounted) return;
    }
    // The goal's balance is the upper limit; in a group Spideli also applies
    // the group's rules, which the goal does not expose.
    final amount = await askAmount(
      context,
      title: "Withdraw".tr,
      currency: cur,
      max: g.savedAmount,
      hint: g.isGroup ? '${"At most".tr} ${FinanceMoney.format(g.savedAmount, cur)}. ${"Group rules decide how much each member may withdraw.".tr}' : null,
    );
    if (amount == null || !context.mounted) return;
    final bool confirmed = await finConfirm(
      title: (g.isSolo ? "Withdraw to your wallet?" : "Ask to withdraw?").tr,
      message: (g.isSolo
              ? "The money goes to your Spideli Finance wallet at once."
              : "Spideli checks your request against the group's rules, then sends the money to your Spideli Finance wallet. You can follow it here.")
          .tr,
      lines: [("To".tr, GroupLabels.method('wallet').tr)],
      total: ("Amount".tr, FinanceMoney.format(amount, cur)),
      confirmLabel: (g.isSolo ? "Withdraw" : "Send the request").tr,
    );
    if (!confirmed) return;
    String? status;
    await FinanceUi.run(() async => status = (await FinanceGroupService.requestWithdrawal(g.id, amount))['status']?.toString());
    if (status == null) return;
    ShowToastDialog.showToast((status == 'completed' ? "The money is in your wallet." : "Withdrawal requested. You can follow it here.").tr);
  }

  /// The focal point: what is saved, of what, the progress and the actions.
  Widget _hero(BuildContext context, {required bool verified, required bool isOwner, required List<String> methods}) {
    final g = goal;
    final String cur = g.currency;
    final actions = <FinAction>[
      if (g.isActive) ...[
        FinAction(Icons.add_rounded, "Add money".tr, !verified ? null : () => _addMoney(context, methods)),
        if (g.savedAmount > 0 && (config?.earlyWithdrawal == true || g.remaining == 0))
          FinAction(Icons.south_west_rounded, "Withdraw".tr, !verified ? null : () => _withdraw(context)),
        if (isOwner && config?.groupGoals == true)
          FinAction(Icons.person_add_alt_outlined, "Invite".tr, () async {
            final email = await _askEmail(context);
            if (email != null) await runInvite(() => FinanceGroupService.inviteToGoal(g.id, email), success: "Invitation sent");
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
          _HeroProgress(value: g.progress, label: "Progress toward the target".tr),
          if (actions.isNotEmpty) ...[const DsGap(DsSpace.lg), FinActions(onHero: true, actions: actions)],
        ],
      ),
    );
  }

  /// Who made a contribution of a group goal: "You", the member's name, else
  /// "Goal owner" / "A member" while the name is unknown.
  String _who(String? userId, String? name) {
    if (userId == FinanceService.uid) return "You".tr;
    if (name != null && name.isNotEmpty) return name;
    if (userId == goal.ownerId) return "Goal owner".tr;
    return "A member".tr;
  }

  Widget _contribution(BuildContext context, Map<String, dynamic> x) {
    final String status = x['status']?.toString() ?? '';
    final int amount = FinanceSummary.intOf(x['amount']);
    final String reference = (x['reference'] ?? '').toString();
    final String userId = x['userId']?.toString() ?? '';
    Widget tile(String? name) {
      final String subtitle = [
        if (goal.isGroup) _who(userId, name),
        if (reference.isNotEmpty) ltrRef(reference),
      ].join(' · ');
      return FinListTile(
        icon: Icons.south_west_rounded,
        iconTone: status == 'succeeded' ? DsTone.success : (status == 'failed' ? DsTone.danger : DsTone.neutral),
        title: FinanceUi.date(x['createdAt']),
        subtitle: subtitle.isEmpty ? null : subtitle,
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

    if (!goal.isGroup || userId.isEmpty || userId == FinanceService.uid) return tile(null);
    return FinancePersonName(uid: userId, builder: (context, name) => tile(name));
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

/// The goal's progress over time: what was saved at the end of each month
/// (a line), and what was added and withdrawn each month (bars, tap a month
/// to read it). Anchored on the goal's balance, so it stays right when the
/// oldest movements are not loaded.
class _GoalProgress extends StatelessWidget {
  final SavingsGoal goal;
  final List<Map<String, dynamic>> contributions;
  final List<Map<String, dynamic>> withdrawals;

  const _GoalProgress({required this.goal, required this.contributions, required this.withdrawals});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final now = DateTime.now();
    final String cur = goal.currency;
    List<DatedAmount> dated(List<Map<String, dynamic>> xs, String status) => [
          for (final x in xs)
            if (x['status'] == status) DatedAmount(FinanceGroupService.toDate(x['createdAt']) ?? now, FinanceSummary.intOf(x['amount'])),
        ];
    final months = SavingsProgress.monthly(dated(contributions, 'succeeded'), dated(withdrawals, 'completed'), goal.savedAmount, now);
    String month(DateTime m) => DateFormat('MMM yyyy').format(m);
    final saved = [for (final m in months) m.savedAtEnd.toDouble()];
    return FinSection(
      title: "Progress over time".tr,
      footnote: months.isEmpty ? null : "Saved at the end of each month, and what was added and withdrawn. Tap a month to read it.".tr,
      children: [
        if (months.isEmpty)
          _quiet(context, "Your progress appears here after the first contribution.".tr)
        else ...[
          if (months.length > 1) ...[
            const DsGap(DsSpace.sm),
            Semantics(
              container: true,
              label: '${"Saved".tr}: ${month(months.first.month)} ${FinanceMoney.format(months.first.savedAtEnd, cur)} – ${month(months.last.month)} ${FinanceMoney.format(months.last.savedAtEnd, cur)}',
              child: ExcludeSemantics(child: FinanceLineChart(values: saved, height: 96)),
            ),
            const DsGap(DsSpace.xs),
            ExcludeSemantics(
              // Under the line, which runs left to right in every language.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  Expanded(child: Text(month(months.first.month), style: DsTypography.caption.copyWith(color: c.textSecondary))),
                  Text(month(months.last.month), style: DsTypography.caption.copyWith(color: c.textSecondary)),
                ]),
              ),
            ),
            const DsGap(DsSpace.md),
          ],
          FinBarChart(
            labels: [for (final m in months) month(m.month)],
            a: [for (final m in months) m.added.toDouble()],
            b: [for (final m in months) m.withdrawn.toDouble()],
            aLabel: "Added".tr,
            bLabel: "Withdrawn".tr,
            aColor: c.success,
            bColor: FinColors.brand(context),
            format: (v) => FinanceMoney.format(v, cur),
          ),
          FinRow("Saved so far".tr, FinanceMoney.format(goal.savedAmount, cur), strong: true),
        ],
      ],
    );
  }
}

/// The members of a group goal by name, each (but the user) with "Message"
/// (a direct conversation); pending invitations are counted.
class _GoalMembers extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalMembers({required this.goal});

  @override
  Widget build(BuildContext context) {
    final String me = FinanceService.uid;
    final int invited = goal.invitedIds.length;
    return FinSection(
      title: "Members".tr,
      divided: true,
      footnote: invited == 0 ? null : "Invitations waiting for an answer: @n".trParams({'n': '$invited'}),
      children: [
        for (final uid in [goal.ownerId, ...goal.memberIds.where((m) => m != goal.ownerId)])
          if (goal.memberIds.contains(uid))
            FinancePersonName(
              uid: uid,
              builder: (context, name) => FinListTile(
                icon: uid == goal.ownerId ? Icons.star_outline_rounded : Icons.person_outline_rounded,
                iconTone: uid == me ? DsTone.brand : DsTone.neutral,
                title: uid == me ? "You".tr : (name == null || name.isEmpty ? "Member".tr : name),
                subtitle: uid == goal.ownerId ? "Goal owner".tr : null,
                trailing: uid == me
                    ? null
                    : DsButton.ghost(
                        label: "Message".tr,
                        icon: Icons.chat_bubble_outline_rounded,
                        size: DsButtonSize.sm,
                        onPressed: () => Get.to(() => FinanceChatScreen(target: FinanceChatTarget.direct(me, uid, name == null || name.isEmpty ? "Member".tr : name))),
                      ),
              ),
            ),
      ],
    );
  }
}

Future<String?> _askEmail(BuildContext context) => finSheet<String>(title: "Invite by email".tr, child: const _EmailSheet());

/// The address of one person to invite; says what is wrong with it as it is
/// typed. Owns (and disposes) its field.
class _EmailSheet extends StatefulWidget {
  const _EmailSheet();

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String email = _ctrl.text.trim();
    final bool ok = _emailOk(email);
    // An address in progress is not an error yet: only once it has an "@" and a dot after it.
    final bool judged = email.contains('@') && email.split('@').last.contains('.');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTextField(
          label: "Email of their Spideli account".tr,
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          errorText: judged && !ok ? "This email address is not valid: @email".trParams({'email': email}) : null,
          onChanged: (_) => setState(() {}),
        ),
        DsButton.primary(label: "Send invitation".tr, icon: Icons.send_rounded, expand: true, onPressed: ok ? () => Get.back(result: email.toLowerCase()) : null),
      ],
    );
  }
}

/// Shared with the tontine screens.
Future<String?> askInviteEmail(BuildContext context) => _askEmail(context);
