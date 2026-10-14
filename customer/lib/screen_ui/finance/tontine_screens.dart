import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
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

/// The few tontine statuses the finance status catalogue (FinStatus) knows
/// under another name, so their chips keep their meaning.
String _st(String? s) => const {'resolved': 'completed', 'open': 'pending', 'suspended': 'restricted'}[s] ?? (s ?? '');

/// Form sections: room above the first label; every field brings its own
/// bottom spacing.
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs);

/// An empty line inside a section ("No cycle yet.").
Widget _quiet(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Text(text, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
    );

/// Spideli Finance > Tontines: invitations and the user's tontines.
/// `platform_settings/tontines` must exist (admin), else "not available".
class TontineListScreen extends StatelessWidget {
  const TontineListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TontineConfig?>(
      future: FinanceGroupService.tontineConfig(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return FinScaffold(
          title: "Tontine".tr,
          bottomBar: cfg == null
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Create a tontine".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => TontineFormScreen(config: cfg)),
                  ),
                ),
          body: FinBody(
            children: [
              if (cfgSnap.connectionState == ConnectionState.waiting)
                FinState.loading()
              else if (cfg == null)
                FinState.empty(Icons.groups_2_outlined, "Tontines are not available yet.".tr)
              else
                ...const [_TontinesHero(), _TontineInvitations(), _TontineList()],
            ],
          ),
        );
      },
    );
  }
}

/// The focal point: the next contribution the server has scheduled for the
/// user (finance_summaries/{uid}); hidden when nothing is due.
class _TontinesHero extends StatelessWidget {
  const _TontinesHero();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FinanceSummary?>(
      stream: FinanceService.summary(),
      builder: (context, snap) {
        final s = snap.data;
        final tontines = s?.tontines;
        if (s == null || tontines == null || tontines['nextContributionAmount'] == null) return const SizedBox.shrink();
        final DateTime? next = FinanceUi.toDate(tontines['nextContributionDate']);
        final int active = FinanceSummary.intOf(tontines['active']);
        return FinHero(
          label: "Next contribution".tr,
          amount: FinanceMoney.format(FinanceSummary.intOf(tontines['nextContributionAmount']), s.currency),
          caption: [
            if (next != null) '${"Due date".tr}: ${_date(next)}',
            '$active ${"active".tr}',
          ].join(' · '),
        );
      },
    );
  }
}

/// An invitation row: what it is, then decline / join.
class _Invitation extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback onJoin;

  const _Invitation({required this.title, required this.subtitle, required this.onDecline, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinListTile(icon: Icons.groups_2_outlined, iconTone: DsTone.brand, title: title, subtitle: subtitle),
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

class _TontineInvitations extends StatelessWidget {
  const _TontineInvitations();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceGroupService.tontineInvitations(),
      builder: (context, snap) {
        final invites = snap.data ?? const [];
        if (invites.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Invitations".tr,
          divided: true,
          children: [
            for (final i in invites)
              _Invitation(
                title: i['tontineName']?.toString() ?? "Tontine".tr,
                subtitle: '${"Invited by".tr} ${i['invitedByName'] ?? '-'}',
                onDecline: () => FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), false)),
                onJoin: () => FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), true), success: "You joined the tontine"),
              ),
          ],
        );
      },
    );
  }
}

class _TontineList extends StatelessWidget {
  const _TontineList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tontine>>(
      stream: FinanceGroupService.myTontines(),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load your tontines.".tr);
        if (!snap.hasData) return FinState.loading();
        if (snap.data!.isEmpty) {
          return FinState.empty(
            Icons.groups_2_outlined,
            "No tontine yet".tr,
            message: "Save as a group: every member contributes each cycle, and one member receives the pot in turn.".tr,
          );
        }
        return FinSection(
          title: "Your tontines".tr,
          divided: true,
          children: [
            for (final t in snap.data!)
              FinListTile(
                icon: Icons.groups_2_outlined,
                iconTone: DsTone.brand,
                title: t.name,
                subtitle: [
                  Frequency.label(t.frequency).tr,
                  '${t.memberIds.length} ${"members".tr}',
                  if (t.nextDueAt != null) '${"Next contribution".tr}: ${_date(t.nextDueAt)}',
                ].join(' · '),
                amount: FinanceMoney.format(t.contributionAmount, t.currency),
                status: _st(t.status),
                statusLabel: Tontine.statusLabel(t.status).tr,
                chevron: true,
                onTap: () => Get.to(() => TontineScreen(tontineId: t.id)),
              ),
          ],
        );
      },
    );
  }
}

/// New tontine. Choices and limits come from the admin configuration.
class TontineFormScreen extends StatefulWidget {
  final TontineConfig config;

  const TontineFormScreen({super.key, required this.config});

  @override
  State<TontineFormScreen> createState() => _TontineFormScreenState();
}

class _TontineFormScreenState extends State<TontineFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  final _amount = TextEditingController();
  late final _limit = TextEditingController(text: '${widget.config.minMembers}');
  late String _currency = widget.config.currencies.first;
  late String _frequency = widget.config.frequencies.first;
  late String _order = widget.config.payoutOrderMethods.first;
  DateTime? _start;

  @override
  void dispose() {
    for (final c in [_name, _description, _rules, _amount, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final int? limit = int.tryParse(_limit.text.trim());
    if (_name.text.trim().isEmpty) return ShowToastDialog.showToast("Please give the tontine a name.".tr);
    if (amount == null || amount < cfg.minFor(_currency)) {
      return ShowToastDialog.showToast("${"The contribution must be at least".tr} ${FinanceMoney.format(cfg.minFor(_currency), _currency)}.");
    }
    if (limit == null || limit < cfg.minMembers || limit > cfg.maxMembers) {
      return ShowToastDialog.showToast("${"Members: between".tr} ${cfg.minMembers} ${"and".tr} ${cfg.maxMembers}.");
    }
    if (_start == null) return ShowToastDialog.showToast("Please choose the first contribution date.".tr);
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceGroupService.createTontine(
        name: _name.text.trim(),
        description: _description.text.trim(),
        rules: _rules.text.trim(),
        contributionAmount: amount,
        currency: _currency,
        frequency: _frequency,
        membersLimit: limit,
        payoutOrderMethod: _order,
        startDate: _start!,
      );
    }, success: "Tontine created. Invite the members.");
    if (ok && id != null) Get.off(() => TontineScreen(tontineId: id!));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final int? limit = int.tryParse(_limit.text.trim());
    return FinScaffold(
      title: "Create a tontine".tr,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Create tontine".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: FinBody(
        children: [
          FinSection(
            title: "Tontine".tr,
            top: 0,
            padding: _formPadding,
            children: [
              DsTextField(label: "Name".tr, controller: _name, requiredMark: true),
              DsTextField(label: "Description".tr, controller: _description, maxLines: 2),
              DsTextField(label: "Rules agreed by the members".tr, hint: "Penalties for late payment, how disputes are settled...".tr, controller: _rules, maxLines: 4),
            ],
          ),
          FinSection(
            title: "Contributions".tr,
            padding: _formPadding,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DsTextField(
                      label: "Amount per member, per cycle".tr,
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
                label: "Frequency".tr,
                value: _frequency,
                items: [for (final f in cfg.frequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr))],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              DsTextField(
                label: "${"Number of members".tr} (${cfg.minMembers}-${cfg.maxMembers})",
                controller: _limit,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              DsTextField(
                label: "First contribution date".tr,
                controller: TextEditingController(text: _date(_start) == '-' ? '' : _date(_start)),
                readOnly: true,
                requiredMark: true,
                suffix: const Icon(Icons.event_outlined, size: 18),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: context, initialDate: _start ?? now.add(const Duration(days: 7)), firstDate: now, lastDate: DateTime(now.year + 2));
                  if (d != null) setState(() => _start = d);
                },
              ),
              if (cfg.payoutOrderMethods.length > 1)
                DsDropdown<String>(
                  label: "Who receives the pot first".tr,
                  value: _order,
                  items: [for (final m in cfg.payoutOrderMethods) DropdownMenuItem(value: m, child: Text(_orderLabel(m).tr))],
                  onChanged: (v) => setState(() => _order = v ?? _order),
                ),
            ],
          ),
          // What the members commit to, before the tontine is created.
          if (amount != null && limit != null)
            FinSection(
              title: "Summary".tr,
              divided: true,
              children: [
                FinRow("Amount per member, per cycle".tr, FinanceMoney.format(amount, _currency)),
                FinRow("Frequency".tr, Frequency.label(_frequency).tr),
                FinRow("Number of members".tr, '$limit'),
                FinRow("Pot per cycle".tr, FinanceMoney.format(amount * limit, _currency), strong: true),
              ],
            ),
        ],
      ),
    );
  }
}

String _orderLabel(String m) => const {'fixed': 'An order set by the administrator', 'random': 'A random draw when the tontine starts'}[m] ?? m;

/// One tontine: overview with the current cycle (group transparency),
/// members and payout order, history, disputes.
class TontineScreen extends StatefulWidget {
  final String tontineId;

  const TontineScreen({super.key, required this.tontineId});

  @override
  State<TontineScreen> createState() => _TontineScreenState();
}

class _TontineScreenState extends State<TontineScreen> {
  int _tab = 0;
  TontineConfig? _config;

  @override
  void initState() {
    super.initState();
    FinanceGroupService.tontineConfig().then((c) {
      if (mounted) setState(() => _config = c);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tontine?>(
      stream: FinanceGroupService.tontine(widget.tontineId),
      builder: (context, snap) {
        final t = snap.data;
        return FinScaffold(
          title: t?.name ?? "Tontine".tr,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this tontine.".tr)])
              : t == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FinanceGroupService.members(t.id),
                      builder: (context, mSnap) {
                        final members = mSnap.data ?? const [];
                        return FinBody(
                          children: [
                            _TontineHero(tontine: t),
                            const DsGap(FinSpace.section),
                            DsSegmentedTabs(
                              scrollable: true,
                              segments: [DsSegment("Overview".tr), DsSegment("Members".tr), DsSegment("History".tr), DsSegment("Disputes".tr)],
                              index: _tab,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                            switch (_tab) {
                              0 => _Overview(tontine: t, members: members, config: _config),
                              1 => _Members(tontine: t, members: members, config: _config),
                              2 => _History(tontine: t, members: members),
                              _ => _Disputes(tontine: t, members: members),
                            },
                          ],
                        );
                      },
                    ),
        );
      },
    );
  }
}

/// The focal point of a tontine: the pot one member receives each cycle,
/// how it is made up, and the status.
class _TontineHero extends StatelessWidget {
  final Tontine tontine;

  const _TontineHero({required this.tontine});

  @override
  Widget build(BuildContext context) {
    final t = tontine;
    return FinHero(
      label: "Pot per cycle".tr,
      amount: FinanceMoney.format(t.potPerCycle, t.currency),
      caption: '${"Amount per member, per cycle".tr}: ${FinanceMoney.format(t.contributionAmount, t.currency)}',
      trailing: FinStatusChip(status: _st(t.status), label: Tontine.statusLabel(t.status).tr, icon: true),
      stats: [
        FinHeroStat("Frequency".tr, Frequency.label(t.frequency).tr),
        FinHeroStat("Members".tr, '${t.memberIds.length}/${t.membersLimit}'),
        if (t.nextDueAt != null) FinHeroStat("Next payment".tr, _date(t.nextDueAt)),
      ],
    );
  }
}

String _nameOf(List<Map<String, dynamic>> members, String? uid) {
  final m = members.where((x) => x['userId'] == uid).toList();
  if (uid == FinanceService.uid) return "You".tr;
  return m.isEmpty ? (uid ?? '-') : (m.first['displayName']?.toString() ?? uid!);
}

/// A name with a status chip (who has paid, member statuses).
class _StatusLine extends StatelessWidget {
  final String label;
  final String status;
  final String statusLabel;

  const _StatusLine({required this.label, required this.status, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Row(
          children: [
            Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textPrimary))),
            const DsGap(DsSpace.sm),
            FinStatusChip(status: status, label: statusLabel),
          ],
        ),
      ),
    );
  }
}

/// A payout position, in the finance tint.
class _Position extends StatelessWidget {
  final Object? value;

  const _Position(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: FinColors.soft(context), shape: BoxShape.circle),
      child: Text('${value ?? '-'}', style: DsTypography.labelSm.copyWith(color: FinColors.brand(context)).tabular),
    );
  }
}

class _Overview extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;
  final TontineConfig? config;

  const _Overview({required this.tontine, required this.members, required this.config});

  @override
  Widget build(BuildContext context) {
    final t = tontine;
    final uid = FinanceService.uid;
    final schedule = t.schedule();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t.isForming) _formingActions(context),
        if (!t.isForming)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceGroupService.cycles(t.id),
            builder: (context, cSnap) {
              if (!cSnap.hasData && !cSnap.hasError) return FinState.loading(rows: 2);
              final cycles = cSnap.data ?? const [];
              final current = cycles.where((c) => c['number'] == t.currentCycle).toList();
              if (current.isEmpty) return FinNotice("The first cycle starts on the first contribution date.".tr);
              return _CurrentCycle(tontine: t, cycle: current.first, members: members, config: config);
            },
          ),
        if (t.isAdmin(uid) && t.isActive) _PendingPayouts(tontine: t, members: members),
        if (schedule.isNotEmpty) _schedule(context, schedule),
        FinSection(
          title: "Details".tr,
          divided: true,
          children: [
            if (t.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                child: Text(t.description, style: DsTypography.body.copyWith(color: DsColors.of(context).textPrimary)),
              ),
            FinRow("Who receives the pot first".tr, _orderLabel(t.payoutOrderMethod).tr),
            if (t.startDate != null) FinRow("First contribution date".tr, _date(t.startDate)),
          ],
        ),
        if (t.rules.isNotEmpty)
          FinSection(
            title: "Rules".tr,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                child: Text(t.rules, style: DsTypography.body.copyWith(color: DsColors.of(context).textPrimary)),
              ),
            ],
          ),
      ],
    );
  }

  String? _beneficiaryAt(int position) {
    final m = members.where((x) => x['status'] == 'active' && x['payoutPosition'] == position).toList();
    return m.isEmpty ? null : m.first['userId']?.toString();
  }

  /// One cycle per member: where the rotation is, then who receives the pot when.
  Widget _schedule(BuildContext context, List<DateTime> schedule) {
    final t = tontine;
    final int n = schedule.length;
    final bool started = !t.isForming;
    final int current = t.status == 'completed' ? n - 1 : (t.currentCycle - 1).clamp(0, n - 1).toInt();
    String beneficiary(int i) => _nameOf(members, _beneficiaryAt(i + 1));
    return FinSection(
      title: "Schedule".tr,
      divided: true,
      children: [
        if (started)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
            child: FinTrack(
              steps: [for (int i = 0; i < n; i++) '${"Cycle".tr} ${i + 1} · ${beneficiary(i)}'],
              current: current,
              ended: t.status == 'suspended',
              endedLabel: Tontine.statusLabel(t.status).tr,
            ),
          ),
        for (final (i, d) in schedule.indexed) FinRow('${"Cycle".tr} ${i + 1} · ${_date(d)}', beneficiary(i), strong: t.isActive && i == current),
      ],
    );
  }

  Widget _formingActions(BuildContext context) {
    final t = tontine;
    final uid = FinanceService.uid;
    final cfg = config;
    final order = (members.where((m) => m['status'] == 'active' && m['payoutPosition'] != null).toList()
          ..sort((a, b) => (a['payoutPosition'] as num).compareTo(b['payoutPosition'] as num)))
        .map((m) => m['userId'].toString())
        .toList();
    final blocker = cfg == null ? "Tontines are not available yet." : TontineActions.startBlocker(t, uid, cfg, order);
    return FinSection(
      title: "Getting ready".tr,
      top: DsSpace.lg,
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
      children: [
        Text(
          "Invite the members. The tontine starts when an administrator starts it; contributions are collected from then on.".tr,
          style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary),
        ),
        const DsGap(DsSpace.md),
        FinProgress(
          value: t.membersLimit <= 0 ? 0 : t.memberIds.length / t.membersLimit,
          label: "Members".tr,
          trailing: '${t.memberIds.length}/${t.membersLimit}',
        ),
        if (t.isAdmin(uid)) ...[
          if (blocker != null) FinNotice(blocker.tr, tone: DsTone.warning),
          const DsGap(DsSpace.md),
          DsButton.primary(
            label: "Start the tontine".tr,
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: blocker != null
                ? null
                : () async {
                    final ok = await finConfirm(
                      title: "Start the tontine?".tr,
                      message: "Members, amount and payout order are then fixed for every cycle.".tr,
                      lines: [
                        ("Amount per member, per cycle".tr, FinanceMoney.format(t.contributionAmount, t.currency)),
                        ("Frequency".tr, Frequency.label(t.frequency).tr),
                        ("Members".tr, '${t.memberIds.length}'),
                      ],
                      total: ("Pot per cycle".tr, FinanceMoney.format(t.potPerCycle, t.currency)),
                      confirmLabel: "Start".tr,
                    );
                    if (ok) await FinanceUi.run(() => FinanceGroupService.start(t.id), success: "The tontine has started");
                  },
          ),
        ],
      ],
    );
  }
}

/// The current cycle, transparent to every member: beneficiary, collected
/// vs expected, and who has paid.
class _CurrentCycle extends StatelessWidget {
  final Tontine tontine;
  final Map<String, dynamic> cycle;
  final List<Map<String, dynamic>> members;
  final TontineConfig? config;

  const _CurrentCycle({required this.tontine, required this.cycle, required this.members, required this.config});

  @override
  Widget build(BuildContext context) {
    final t = tontine;
    final c = DsColors.of(context);
    final String cycleId = cycle['id'].toString();
    final DateTime? due = FinanceGroupService.toDate(cycle['dueDate']);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceGroupService.cycleContributions(t.id, cycleId),
      builder: (context, snap) {
        final summary = CycleSummary.of(snap.data ?? const [], t.memberIds, t.contributionAmount, due, DateTime.now());
        final String mine = summary.statusByMember[FinanceService.uid] ?? 'pending';
        final double collected = summary.expected == 0 ? 0 : (summary.collected / summary.expected).clamp(0, 1).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: '${"Cycle".tr} ${cycle['number']}',
              top: DsSpace.lg,
              divided: true,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Receives the pot".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                                const DsGap(DsSpace.xxs),
                                Text(_nameOf(members, cycle['beneficiaryUserId']?.toString()), style: DsTypography.titleSm.copyWith(color: c.textPrimary)),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.sm),
                          FinStatusChip(status: _st(cycle['status']?.toString()), label: GroupLabels.cycle(cycle['status']?.toString()).tr, icon: true),
                        ],
                      ),
                      const DsGap(DsSpace.lg),
                      FinProgress(
                        value: collected,
                        label: '${"Collected".tr} ${FinanceMoney.format(summary.collected, t.currency)} / ${FinanceMoney.format(summary.expected, t.currency)}',
                      ),
                      const DsGap(DsSpace.xs),
                      Text(
                        '${summary.paid} ${"paid".tr} · ${summary.pending} ${"pending".tr} · ${summary.overdue} ${"overdue".tr}',
                        style: DsTypography.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                FinRow("Due date".tr, _date(due)),
                if (mine != 'paid' && cycle['status'] == 'collecting')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                    child: FinanceKycGate(
                      builder: (context, verified) => DsButton.primary(
                        label: "${"Pay my contribution".tr} ${FinanceMoney.format(t.contributionAmount, t.currency)}",
                        icon: Icons.payments_outlined,
                        expand: true,
                        onPressed: !verified
                            ? null
                            : () {
                                final key = FinanceGroupService.newRequestKey();
                                FinancePaySheet.show(
                                  context,
                                  title: '${t.name} · ${"Cycle".tr} ${cycle['number']}',
                                  amount: t.contributionAmount,
                                  currency: t.currency,
                                  methods: config?.paymentMethods ?? const ['wallet'],
                                  submit: (payment) => FinanceGroupService.contributeToTontine(t.id, cycleId, payment, key),
                                );
                              },
                      ),
                    ),
                  ),
              ],
            ),
            FinSection(
              title: "Contributions".tr,
              divided: true,
              children: [
                for (final uid in t.memberIds)
                  _StatusLine(
                    label: _nameOf(members, uid),
                    status: _st(summary.statusByMember[uid]),
                    statusLabel: GroupLabels.contribution(summary.statusByMember[uid]).tr,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Admins approve each payout before the server disburses it.
class _PendingPayouts extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _PendingPayouts({required this.tontine, required this.members});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceGroupService.payouts(tontine.id),
      builder: (context, snap) {
        final pending = (snap.data ?? const []).where((p) => p['status'] == 'pending_approval').toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Payouts to approve".tr,
          divided: true,
          children: [for (final p in pending) _approval(context, p)],
        );
      },
    );
  }

  Widget _approval(BuildContext context, Map<String, dynamic> p) {
    final String name = _nameOf(members, p['beneficiaryUserId']?.toString());
    final String amount = FinanceMoney.format(FinanceSummary.intOf(p['amount']), tontine.currency);
    final String cycle = '${p['cycleNumber'] ?? '-'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinListTile(
          icon: Icons.north_east_rounded,
          iconTone: DsTone.warning,
          title: name,
          subtitle: '${"Cycle".tr} $cycle',
          amount: amount,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DsButton.tonal(
                label: "Approve".tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.sm,
                onPressed: () async {
                  // Releasing a payout cannot be taken back: confirm the figures first.
                  final ok = await finConfirm(
                    title: "Approve this payout?".tr,
                    lines: [("Receives the pot".tr, name), ("Cycle".tr, cycle)],
                    total: ("Amount".tr, amount),
                    confirmLabel: "Approve".tr,
                  );
                  if (ok) await FinanceUi.run(() => FinanceGroupService.approvePayout(p['id'].toString()), success: "Payout approved");
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Members extends StatefulWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;
  final TontineConfig? config;

  const _Members({required this.tontine, required this.members, required this.config});

  @override
  State<_Members> createState() => _MembersState();
}

class _MembersState extends State<_Members> {
  List<String>? _order;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = widget.tontine;
    final uid = FinanceService.uid;
    final active = widget.members.where((m) => m['status'] == 'active').toList();
    final others = widget.members.where((m) => m['status'] != 'active').toList();
    final bool editOrder = t.isAdmin(uid) && t.isForming && t.payoutOrderMethod == 'fixed';
    final order = _order ?? active.map((m) => m['userId'].toString()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (TontineActions.canInvite(t, uid, widget.members.where((m) => m['status'] == 'active' || m['status'] == 'invited').length))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.secondary(
              label: "Invite a member".tr,
              icon: Icons.person_add_alt_outlined,
              expand: true,
              onPressed: () async {
                final email = await askInviteEmail(context);
                if (email != null) await FinanceUi.run(() => FinanceGroupService.invite(t.id, email), success: "Invitation sent");
              },
            ),
          ),
        FinSection(
          title: (editOrder ? "Payout order (drag to change)" : "Members and payout order").tr,
          top: DsSpace.lg,
          divided: !editOrder,
          children: [
            if (editOrder)
              ReorderableListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (from, to) => setState(() {
                  final list = [...order];
                  final item = list.removeAt(from);
                  list.insert(to > from ? to - 1 : to, item);
                  _order = list;
                }),
                children: [
                  for (final (i, id) in order.indexed)
                    Padding(
                      key: ValueKey(id),
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                      child: Row(
                        children: [
                          _Position(i + 1),
                          const DsGap(DsSpace.md),
                          Expanded(child: Text(_nameOf(widget.members, id), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary))),
                          Icon(Icons.drag_handle_rounded, color: c.textMuted),
                        ],
                      ),
                    ),
                ],
              )
            else
              for (final m in active)
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                    child: Row(
                      children: [
                        _Position(m['payoutPosition']),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_nameOf(widget.members, m['userId']?.toString()), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                              if (m['role'] == 'admin') Text("Administrator".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (editOrder && _order != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                child: DsButton.primary(
                  label: "Save payout order".tr,
                  expand: true,
                  onPressed: () async {
                    if (await FinanceUi.run(() => FinanceGroupService.setPayoutOrder(t.id, _order!), success: "Payout order saved")) setState(() => _order = null);
                  },
                ),
              ),
          ],
        ),
        if (others.isNotEmpty)
          FinSection(
            title: "Invited and former members".tr,
            divided: true,
            children: [
              for (final m in others)
                FinListTile(
                  icon: Icons.person_outline_rounded,
                  title: m['displayName']?.toString() ?? m['email']?.toString() ?? '-',
                  status: _st(m['status']?.toString()),
                  statusLabel: GroupLabels.member(m['status']?.toString()).tr,
                ),
            ],
          ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _History({required this.tontine, required this.members});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.cycles(tontine.id),
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) return FinState.loading(rows: 2);
            final cycles = snap.data ?? const <Map<String, dynamic>>[];
            return FinSection(
              title: "Cycles".tr,
              top: DsSpace.lg,
              divided: true,
              children: [
                if (cycles.isEmpty) _quiet(context, "No cycle yet.".tr),
                for (final cy in cycles)
                  FinListTile(
                    icon: Icons.autorenew_rounded,
                    iconTone: tontine.isActive && cy['number'] == tontine.currentCycle ? DsTone.brand : DsTone.neutral,
                    title: '${"Cycle".tr} ${cy['number']}',
                    subtitle: '${_date(FinanceGroupService.toDate(cy['dueDate']))} · ${"Receives the pot".tr}: ${_nameOf(members, cy['beneficiaryUserId']?.toString())}',
                    status: _st(cy['status']?.toString()),
                    statusLabel: GroupLabels.cycle(cy['status']?.toString()).tr,
                  ),
              ],
            );
          },
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.payouts(tontine.id),
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) return FinState.loading(rows: 2);
            final payouts = snap.data ?? const <Map<String, dynamic>>[];
            return FinSection(
              title: "Payouts".tr,
              divided: true,
              children: [
                if (payouts.isEmpty) _quiet(context, "No payout yet.".tr),
                for (final p in payouts)
                  FinListTile(
                    icon: Icons.north_east_rounded,
                    title: _nameOf(members, p['beneficiaryUserId']?.toString()),
                    subtitle: [
                      '${"Cycle".tr} ${p['cycleNumber'] ?? '-'}',
                      if ((p['reference'] ?? '').toString().isNotEmpty) ltrRef(p['reference']),
                    ].join(' · '),
                    amount: FinanceMoney.format(FinanceSummary.intOf(p['amount']), tontine.currency),
                    status: _st(p['status']?.toString()),
                    statusLabel: GroupLabels.payout(p['status']?.toString()).tr,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Disputes extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _Disputes({required this.tontine, required this.members});

  Future<void> _raise(BuildContext context) async {
    final subject = TextEditingController();
    final description = TextEditingController();
    String? against;
    final ok = await finSheet<bool>(
      title: "Raise a dispute".tr,
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Subject".tr, controller: subject, requiredMark: true, onChanged: (_) => setState(() {})),
            DsTextField(label: "What happened".tr, controller: description, requiredMark: true, maxLines: 4, onChanged: (_) => setState(() {})),
            DsDropdown<String?>(
              label: "Concerning a member (optional)".tr,
              value: against,
              items: [
                DropdownMenuItem(value: null, child: Text("The tontine in general".tr)),
                for (final id in tontine.memberIds.where((id) => id != FinanceService.uid)) DropdownMenuItem(value: id, child: Text(_nameOf(members, id))),
              ],
              onChanged: (v) => setState(() => against = v),
            ),
            Text(
              "Disputes are reviewed by the administrators; nobody is restricted without a review.".tr,
              style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary),
            ),
            const DsGap(DsSpace.md),
            DsButton.primary(
              label: "Send".tr,
              expand: true,
              onPressed: subject.text.trim().length < 3 || description.text.trim().length < 10 ? null : () => Get.back(result: true),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await FinanceUi.run(() => FinanceGroupService.raiseDispute(tontine.id, subject: subject.text.trim(), description: description.text.trim(), againstUserId: against), success: "Dispute sent");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.lg),
          child: DsButton.secondary(label: "Raise a dispute".tr, icon: Icons.report_outlined, expand: true, onPressed: () => _raise(context)),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.disputes(tontine.id),
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) return FinState.loading(rows: 2);
            final list = snap.data ?? const [];
            if (list.isEmpty) return FinState.empty(Icons.verified_outlined, "No dispute.".tr);
            return FinSection(
              title: "Disputes".tr,
              divided: true,
              children: [for (final d in list) _dispute(context, d)],
            );
          },
        ),
      ],
    );
  }

  Widget _dispute(BuildContext context, Map<String, dynamic> d) {
    final c = DsColors.of(context);
    final String status = d['status']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(d['subject']?.toString() ?? '-', style: DsTypography.bodyStrong.copyWith(color: c.textPrimary))),
              const DsGap(DsSpace.sm),
              FinStatusChip(status: _st(status), label: GroupLabels.dispute(d['status']?.toString()).tr),
            ],
          ),
          const DsGap(DsSpace.xxs),
          Text('${"Raised by".tr} ${_nameOf(members, d['raisedBy']?.toString())} · ${FinanceUi.date(d['createdAt'])}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
          const DsGap(DsSpace.sm),
          Text(d['description']?.toString() ?? '', style: DsTypography.body.copyWith(color: c.textPrimary)),
          if ((d['resolution'] ?? '').toString().isNotEmpty) FinNotice(d['resolution'].toString(), title: "Resolution".tr, tone: DsTone.info),
        ],
      ),
    );
  }
}
