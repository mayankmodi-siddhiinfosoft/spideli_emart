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

DsTone _statusTone(String? s) => switch (s) {
      'paid' || 'succeeded' || 'resolved' || 'completed' => DsTone.success,
      'overdue' || 'failed' || 'rejected' || 'restricted' || 'suspended' => DsTone.danger,
      'pending' || 'pending_approval' || 'invited' || 'open' || 'under_review' => DsTone.warning,
      'active' || 'collecting' => DsTone.info,
      _ => DsTone.neutral,
    };

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
        return DsScaffold(
          title: "Tontines".tr,
          maxContentWidth: DsLayout.contentMax,
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
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.groups_2_outlined, title: "Tontines are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: const [_TontineInvitations(), _TontineList()],
                    ),
        );
      },
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
        return DsFormSection(
          title: "Invitations".tr,
          icon: Icons.mail_outline_rounded,
          children: [
            for (final i in invites)
              DsListTile(
                padding: EdgeInsets.zero,
                leadingIcon: Icons.groups_2_outlined,
                title: i['tontineName']?.toString() ?? "Tontine".tr,
                subtitle: '${"Invited by".tr} ${i['invitedByName'] ?? '-'}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsButton.ghost(label: "Decline".tr, size: DsButtonSize.sm, onPressed: () => FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), false))),
                    DsButton.tonal(
                      label: "Join".tr,
                      size: DsButtonSize.sm,
                      onPressed: () => FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), true), success: "You joined the tontine"),
                    ),
                  ],
                ),
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
        if (snap.hasError) return DsErrorState(message: "Could not load your tontines.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        if (snap.data!.isEmpty) {
          return DsEmptyState(
            icon: Icons.groups_2_outlined,
            title: "No tontine yet".tr,
            message: "Save as a group: every member contributes each cycle, and one member receives the pot in turn.".tr,
            compact: true,
          );
        }
        return Column(
          children: [
            for (final t in snap.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: DsCard.outlined(
                  onTap: () => Get.to(() => TontineScreen(tontineId: t.id)),
                  child: Row(
                    children: [
                      const DsIconWell(icon: Icons.groups_2_outlined, tone: DsTone.brand),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: DsTypography.titleSm),
                            Text('${FinanceMoney.format(t.contributionAmount, t.currency)} · ${Frequency.label(t.frequency).tr} · ${t.memberIds.length} ${"members".tr}', style: DsTypography.caption),
                            if (t.nextDueAt != null) Text('${"Next contribution".tr}: ${_date(t.nextDueAt)}', style: DsTypography.caption),
                          ],
                        ),
                      ),
                      DsBadge(label: Tontine.statusLabel(t.status).tr, tone: _statusTone(t.status), small: true),
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
    return DsScaffold(
      title: "Create a tontine".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Create tontine".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Tontine".tr,
            icon: Icons.groups_2_outlined,
            children: [
              DsTextField(label: "Name".tr, controller: _name, requiredMark: true),
              DsTextField(label: "Description".tr, controller: _description, maxLines: 2),
              DsTextField(label: "Rules agreed by the members".tr, hint: "Penalties for late payment, how disputes are settled...".tr, controller: _rules, maxLines: 4, bottomSpacing: 0),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Contributions".tr,
            icon: Icons.payments_outlined,
            children: [
              Row(
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
              if (amount != null && limit != null)
                DsInlineAlert(
                  tone: DsTone.info,
                  message: "${"Each cycle, one member receives".tr} ${FinanceMoney.format(amount * limit, _currency)} (${FinanceMoney.format(amount, _currency)} x $limit).",
                ),
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
        return DsScaffold(
          title: t?.name ?? "Tontine".tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this tontine.".tr)
              : t == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FinanceGroupService.members(t.id),
                      builder: (context, mSnap) {
                        final members = mSnap.data ?? const [];
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                          children: [
                            DsSegmentedTabs(
                              scrollable: true,
                              segments: [DsSegment("Overview".tr), DsSegment("Members".tr), DsSegment("History".tr), DsSegment("Disputes".tr)],
                              index: _tab,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                            const DsGap(DsSpace.lg),
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

String _nameOf(List<Map<String, dynamic>> members, String? uid) {
  final m = members.where((x) => x['userId'] == uid).toList();
  if (uid == FinanceService.uid) return "You".tr;
  return m.isEmpty ? (uid ?? '-') : (m.first['displayName']?.toString() ?? uid!);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsCard.tinted(
          tone: DsTone.brand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(FinanceMoney.format(t.contributionAmount, t.currency), style: DsTypography.title.tabular)),
                DsBadge(label: Tontine.statusLabel(t.status).tr, tone: _statusTone(t.status)),
              ]),
              Text('${Frequency.label(t.frequency).tr} · ${t.memberIds.length}/${t.membersLimit} ${"members".tr}', style: DsTypography.caption),
              const DsGap(DsSpace.sm),
              Text('${"Pot per cycle".tr}: ${FinanceMoney.format(t.potPerCycle, t.currency)}', style: DsTypography.bodyStrong),
              if (t.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text(t.description, style: DsTypography.body)),
            ],
          ),
        ),
        if (t.rules.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(title: "Rules".tr, icon: Icons.rule_rounded, children: [Text(t.rules, style: DsTypography.body)]),
        ],
        const DsGap(DsSpace.md),
        if (t.isForming) _formingActions(context),
        if (!t.isForming)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceGroupService.cycles(t.id),
            builder: (context, cSnap) {
              final cycles = cSnap.data ?? const [];
              final current = cycles.where((c) => c['number'] == t.currentCycle).toList();
              if (current.isEmpty) return Text("The first cycle starts on the first contribution date.".tr, style: DsTypography.body);
              return _CurrentCycle(tontine: t, cycle: current.first, members: members, config: config);
            },
          ),
        const DsGap(DsSpace.md),
        if (t.schedule().isNotEmpty)
          DsFormSection(
            title: "Schedule".tr,
            icon: Icons.calendar_month_outlined,
            children: [
              for (final (i, d) in t.schedule().indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text('${"Cycle".tr} ${i + 1} · ${_date(d)}', style: DsTypography.body)),
                    Text(_nameOf(members, _beneficiaryAt(i + 1)), style: DsTypography.bodyStrong),
                  ]),
                ),
            ],
          ),
        if (t.isAdmin(uid) && t.isActive)
          Padding(padding: const EdgeInsets.only(top: DsSpace.md), child: _PendingPayouts(tontine: t, members: members)),
      ],
    );
  }

  String? _beneficiaryAt(int position) {
    final m = members.where((x) => x['status'] == 'active' && x['payoutPosition'] == position).toList();
    return m.isEmpty ? null : m.first['userId']?.toString();
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
    return DsCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Getting ready".tr, style: DsTypography.titleSm),
          Text("Invite the members. The tontine starts when an administrator starts it; contributions are collected from then on.".tr, style: DsTypography.body),
          if (t.isAdmin(uid)) ...[
            const DsGap(DsSpace.md),
            if (blocker != null) Text(blocker.tr, style: DsTypography.caption),
            const DsGap(DsSpace.sm),
            DsButton.primary(
              label: "Start the tontine".tr,
              icon: Icons.play_arrow_rounded,
              expand: true,
              onPressed: blocker != null
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text("Start the tontine?".tr),
                          content: Text("Members, amount and payout order are then fixed for every cycle.".tr),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text("Not yet".tr)),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text("Start".tr)),
                          ],
                        ),
                      );
                      if (ok == true) await FinanceUi.run(() => FinanceGroupService.start(t.id), success: "The tontine has started");
                    },
            ),
          ],
        ],
      ),
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
    final String cycleId = cycle['id'].toString();
    final DateTime? due = FinanceGroupService.toDate(cycle['dueDate']);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceGroupService.cycleContributions(t.id, cycleId),
      builder: (context, snap) {
        final summary = CycleSummary.of(snap.data ?? const [], t.memberIds, t.contributionAmount, due, DateTime.now());
        final String mine = summary.statusByMember[FinanceService.uid] ?? 'pending';
        return DsFormSection(
          title: '${"Cycle".tr} ${cycle['number']} · ${GroupLabels.cycle(cycle['status']?.toString()).tr}',
          icon: Icons.autorenew_rounded,
          children: [
            Text('${"Due".tr} ${_date(due)} · ${"Receives the pot".tr}: ${_nameOf(members, cycle['beneficiaryUserId']?.toString())}', style: DsTypography.body),
            const DsGap(DsSpace.sm),
            DsProgressBar(value: summary.expected == 0 ? 0 : (summary.collected / summary.expected).clamp(0, 1).toDouble()),
            const DsGap(DsSpace.xs),
            Text('${FinanceMoney.format(summary.collected, t.currency)} / ${FinanceMoney.format(summary.expected, t.currency)} · ${summary.paid} ${"paid".tr}, ${summary.pending} ${"pending".tr}, ${summary.overdue} ${"overdue".tr}', style: DsTypography.caption),
            const DsGap(DsSpace.sm),
            for (final uid in t.memberIds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(_nameOf(members, uid), style: DsTypography.body)),
                  DsBadge(label: GroupLabels.contribution(summary.statusByMember[uid]).tr, tone: _statusTone(summary.statusByMember[uid]), small: true),
                ]),
              ),
            if (mine != 'paid' && cycle['status'] == 'collecting') ...[
              const DsGap(DsSpace.md),
              FinanceKycGate(
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
            ],
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
        return DsFormSection(
          title: "Payouts to approve".tr,
          icon: Icons.approval_outlined,
          children: [
            for (final p in pending)
              DsListTile(
                padding: EdgeInsets.zero,
                leadingIcon: Icons.north_east_rounded,
                title: '${FinanceMoney.format(FinanceSummary.intOf(p['amount']), tontine.currency)} → ${_nameOf(members, p['beneficiaryUserId']?.toString())}',
                subtitle: '${"Cycle".tr} ${p['cycleNumber'] ?? '-'}',
                trailing: DsButton.tonal(
                  label: "Approve".tr,
                  size: DsButtonSize.sm,
                  onPressed: () => FinanceUi.run(() => FinanceGroupService.approvePayout(p['id'].toString()), success: "Payout approved"),
                ),
              ),
          ],
        );
      },
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
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: DsButton.secondary(
              label: "Invite a member".tr,
              icon: Icons.person_add_alt_outlined,
              onPressed: () async {
                final email = await askInviteEmail(context);
                if (email != null) await FinanceUi.run(() => FinanceGroupService.invite(t.id, email), success: "Invitation sent");
              },
            ),
          ),
        DsFormSection(
          title: (editOrder ? "Payout order (drag to change)" : "Members and payout order").tr,
          icon: Icons.format_list_numbered_rounded,
          children: [
            if (editOrder)
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (from, to) => setState(() {
                  final list = [...order];
                  final item = list.removeAt(from);
                  list.insert(to > from ? to - 1 : to, item);
                  _order = list;
                }),
                children: [
                  for (final (i, id) in order.indexed)
                    ListTile(key: ValueKey(id), leading: CircleAvatar(radius: 14, child: Text('${i + 1}')), title: Text(_nameOf(widget.members, id)), trailing: const Icon(Icons.drag_handle)),
                ],
              )
            else
              for (final m in active)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leading: CircleAvatar(radius: 14, child: Text('${m['payoutPosition'] ?? '-'}')),
                  title: _nameOf(widget.members, m['userId']?.toString()),
                  subtitle: m['role'] == 'admin' ? "Administrator".tr : null,
                ),
            if (editOrder && _order != null)
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.sm),
                child: DsButton.primary(
                  label: "Save payout order".tr,
                  onPressed: () async {
                    if (await FinanceUi.run(() => FinanceGroupService.setPayoutOrder(t.id, _order!), success: "Payout order saved")) setState(() => _order = null);
                  },
                ),
              ),
          ],
        ),
        if (others.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Invited and former members".tr,
            icon: Icons.people_outline,
            children: [
              for (final m in others)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(m['displayName']?.toString() ?? m['email']?.toString() ?? '-', style: DsTypography.body)),
                    DsBadge(label: GroupLabels.member(m['status']?.toString()).tr, tone: _statusTone(m['status']?.toString()), small: true),
                  ]),
                ),
            ],
          ),
        ],
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
          builder: (context, snap) => DsFormSection(
            title: "Cycles".tr,
            icon: Icons.autorenew_rounded,
            children: [
              if ((snap.data ?? const []).isEmpty) Text("No cycle yet.".tr, style: DsTypography.body),
              for (final c in snap.data ?? const <Map<String, dynamic>>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text('${"Cycle".tr} ${c['number']} · ${_date(FinanceGroupService.toDate(c['dueDate']))} · ${_nameOf(members, c['beneficiaryUserId']?.toString())}', style: DsTypography.body)),
                    DsBadge(label: GroupLabels.cycle(c['status']?.toString()).tr, tone: _statusTone(c['status']?.toString()), small: true),
                  ]),
                ),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.payouts(tontine.id),
          builder: (context, snap) => DsFormSection(
            title: "Payouts".tr,
            icon: Icons.north_east_rounded,
            children: [
              if ((snap.data ?? const []).isEmpty) Text("No payout yet.".tr, style: DsTypography.body),
              for (final p in snap.data ?? const <Map<String, dynamic>>[])
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: Icons.north_east_rounded,
                  leadingTone: _statusTone(p['status']?.toString()),
                  title: '${FinanceMoney.format(FinanceSummary.intOf(p['amount']), tontine.currency)} → ${_nameOf(members, p['beneficiaryUserId']?.toString())}',
                  subtitle: '${"Cycle".tr} ${p['cycleNumber'] ?? '-'} · ${GroupLabels.payout(p['status']?.toString()).tr}${(p['reference'] ?? '').toString().isEmpty ? '' : ' · ${ltrRef(p['reference'])}'}',
                ),
            ],
          ),
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
    final ok = await DsBottomSheet.show<bool>(
      title: "Raise a dispute".tr,
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Subject".tr, controller: subject, onChanged: (_) => setState(() {})),
            DsTextField(label: "What happened".tr, controller: description, maxLines: 4, onChanged: (_) => setState(() {})),
            DsDropdown<String?>(
              label: "Concerning a member (optional)".tr,
              value: against,
              items: [
                DropdownMenuItem(value: null, child: Text("The tontine in general".tr)),
                for (final id in tontine.memberIds.where((id) => id != FinanceService.uid)) DropdownMenuItem(value: id, child: Text(_nameOf(members, id))),
              ],
              onChanged: (v) => setState(() => against = v),
            ),
            Text("Disputes are reviewed by the administrators; nobody is restricted without a review.".tr, style: DsTypography.caption),
            const DsGap(DsSpace.sm),
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
        DsButton.secondary(label: "Raise a dispute".tr, icon: Icons.report_outlined, onPressed: () => _raise(context)),
        const DsGap(DsSpace.md),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceGroupService.disputes(tontine.id),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return DsEmptyState(icon: Icons.verified_outlined, title: "No dispute.".tr, compact: true);
            return Column(
              children: [
                for (final d in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.sm),
                    child: DsCard.outlined(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(child: Text(d['subject']?.toString() ?? '-', style: DsTypography.titleSm)),
                            DsBadge(label: GroupLabels.dispute(d['status']?.toString()).tr, tone: _statusTone(d['status']?.toString()), small: true),
                          ]),
                          Text('${"Raised by".tr} ${_nameOf(members, d['raisedBy']?.toString())} · ${FinanceUi.date(d['createdAt'])}', style: DsTypography.caption),
                          const DsGap(DsSpace.xs),
                          Text(d['description']?.toString() ?? '', style: DsTypography.body),
                          if ((d['resolution'] ?? '').toString().isNotEmpty) ...[
                            const DsGap(DsSpace.xs),
                            DsInlineAlert(tone: DsTone.info, title: "Resolution".tr, message: d['resolution'].toString()),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
