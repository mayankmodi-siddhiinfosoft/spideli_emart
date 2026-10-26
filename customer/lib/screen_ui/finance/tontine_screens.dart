import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_chat_screens.dart';
import 'package:customer/screen_ui/finance/finance_restriction.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/subscriptions/business_account_screen.dart';
import 'package:customer/service/finance_chat_service.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/business_account.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

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

/// "@count of at least @min characters" while a text is shorter than [min].
String? _minHelper(String text, int min) {
  final int n = text.trim().length;
  return n >= min ? null : "@count of at least @min characters".trParams({'count': '$n', 'min': '$min'});
}

/// Spideli Finance > Tontines: invitations and the user's tontines.
/// `finance_settings/{regionId}_tontines` must exist (admin), else "not available";
/// a failed read offers Retry.
class TontineListScreen extends StatefulWidget {
  const TontineListScreen({super.key});

  @override
  State<TontineListScreen> createState() => _TontineListScreenState();
}

class _TontineListScreenState extends State<TontineListScreen> {
  /// The user's profile, for `users/{uid}.financeRestriction` (set by
  /// Spideli): a restriction for tontines blocks creating and joining one.
  /// One subscription for the screen's life (a rebuild must not reopen it).
  late final Stream<Map<String, dynamic>> _profile = FinanceService.myProfile();

  @override
  Widget build(BuildContext context) {
    return FinConfig<TontineConfig>(
      load: FinanceGroupService.tontineConfig,
      builder: (context, st) {
        final cfg = st.config;
        final Widget? placeholder = st.placeholder(Icons.groups_2_outlined, "Tontines are not available yet.".tr);
        return StreamBuilder<Map<String, dynamic>>(
          stream: _profile,
          builder: (context, pSnap) {
            final bool restricted = FinanceRestriction.blocks(pSnap.data, FinanceRestriction.tontines);
            return FinScaffold(
              title: "Tontine".tr,
              actions: const [FinanceChatsButton(), DsGap(DsSpace.xs)],
              bottomBar: !st.ready
                  ? null
                  : DsStickyBar(
                      child: DsButton.primary(
                        label: "Create a tontine".tr,
                        icon: Icons.add_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: restricted ? null : () => Get.to(() => TontineFormScreen(config: cfg!)),
                      ),
                    ),
              body: FinBody(
                children: [
                  if (placeholder != null)
                    placeholder
                  else ...[
                    // What is restricted, why, since when, and how to reach support.
                    if (restricted) FinanceRestrictionNotice.of(pSnap.data),
                    const _TontinesHero(),
                    _TontineInvitations(restricted: restricted),
                    const _TontineList(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The focal point: the user's next contribution (the dashboard totals,
/// FinanceService.summary); hidden when nothing is due.
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

/// An invitation row: what it is, then decline / join ([onJoin] null: the
/// user cannot join now).
class _Invitation extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback? onJoin;

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

/// The terms an invitation carries (copied from `tontines/{id}` by the
/// admin who invited, same names): an invitee cannot read the tontine
/// itself until they join. Empty when the invitation has none.
List<(String, String)> _inviteTerms(Map<String, dynamic> i) {
  final String cur = i['currency']?.toString() ?? '';
  final int amount = FinanceSummary.intOf(i['contributionAmount']);
  final String? frequency = i['frequency']?.toString();
  final int limit = FinanceSummary.intOf(i['membersLimit']);
  final List? members = i['memberIds'] is List ? i['memberIds'] as List : null;
  final DateTime? start = FinanceGroupService.toDate(i['startDate']);
  return [
    if (amount > 0 && cur.isNotEmpty) ("Amount per member, per cycle".tr, FinanceMoney.format(amount, cur)),
    if (Frequency.all.contains(frequency)) ("Frequency".tr, Frequency.label(frequency).tr),
    if (limit > 0) members == null ? ("Number of members".tr, '$limit') : ("Members".tr, '${members.length}/$limit'),
    if (start != null) ("First contribution date".tr, _date(start)),
  ];
}

class _TontineInvitations extends StatelessWidget {
  /// The user is restricted for tontines: they may decline, not join.
  final bool restricted;

  const _TontineInvitations({required this.restricted});

  /// Joining commits the user to a contribution every cycle: what is known
  /// of the commitment first.
  Future<void> _join(Map<String, dynamic> i) async {
    final String inviter = i['invitedByName']?.toString() ?? '-';
    final terms = _inviteTerms(i);
    final String rules = (i['rules'] ?? '').toString().trim();
    final String commitment = "By joining, you commit to paying the contribution every cycle until every member has received the pot.".tr;
    final ok = await finConfirm(
      title: "Join this tontine?".tr,
      message: [
        commitment,
        if (terms.isEmpty) "Ask @name for the amount, the frequency and the rules before you join.".trParams({'name': inviter}),
        if (rules.isNotEmpty) '${"Rules".tr}: $rules',
      ].join('\n\n'),
      lines: [...terms, ("Invited by".tr, inviter)],
      confirmLabel: "Join".tr,
      cancelLabel: "Not now".tr,
    );
    if (ok) await FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), true), success: "You joined the tontine");
  }

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
                subtitle: [
                  '${"Invited by".tr} ${i['invitedByName'] ?? '-'}',
                  for (final (_, value) in _inviteTerms(i).take(2)) value,
                ].join(' · '),
                onDecline: () => FinanceUi.run(() => FinanceGroupService.respondToInvite(i['tontineId'].toString(), false)),
                onJoin: restricted ? null : () => _join(i),
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
    return FinReload(
      builder: (context, retry) => StreamBuilder<List<Tontine>>(
        stream: FinanceGroupService.myTontines(),
        builder: (context, snap) {
          if (snap.hasError) return FinState.error("Could not load your tontines.".tr, onRetry: retry);
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
                    FinanceUi.count(t.memberIds.length, "member", "members"),
                    if (t.nextDueAt != null) '${"Next contribution".tr}: ${_date(t.nextDueAt)}',
                  ].join(' · '),
                  amount: "@amount per cycle".trParams({'amount': FinanceMoney.format(t.contributionAmount, t.currency)}),
                  status: _st(t.status),
                  statusLabel: Tontine.statusLabel(t.status).tr,
                  chevron: true,
                  onTap: () => Get.to(() => TontineScreen(tontineId: t.id)),
                ),
            ],
          );
        },
      ),
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
  final _startText = TextEditingController();
  late final _limit = TextEditingController(text: '${widget.config.minMembers}');
  late String _currency = widget.config.currencies.first;
  late String _frequency = widget.config.frequencies.first;
  late String _order = widget.config.payoutOrderMethods.first;
  String _type = 'group';
  DateTime? _start;

  @override
  void dispose() {
    for (final c in [_name, _description, _rules, _amount, _limit, _startText]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The contribution, when it is a valid amount of at least the minimum.
  int? get _validAmount {
    final int? v = FinanceAmount.parse(_amount.text, _currency);
    return v == null || v < widget.config.minFor(_currency) ? null : v;
  }

  /// The number of members, when within the configured range.
  int? get _validLimit {
    final int? v = int.tryParse(_limit.text.trim());
    return v == null || v < widget.config.minMembers || v > widget.config.maxMembers ? null : v;
  }

  List<String> _missing() => [
        if (_name.text.trim().isEmpty) "Name".tr,
        if (_validAmount == null) "Amount per member, per cycle".tr,
        if (_validLimit == null) "Number of members".tr,
        if (_start == null) "First contribution date".tr,
        if (_type == 'professional' && !BusinessAccount.canCreateProfessionalTontine) "Approved company account".tr,
        if (_type == 'association' && !BusinessAccount.canCreateAssociationTontine) "Approved association account".tr,
      ];

  Future<void> _save() async {
    final int? amount = _validAmount;
    final int? limit = _validLimit;
    if (_missing().isNotEmpty || amount == null || limit == null) return;
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
        type: _type,
      );
    }, success: "Tontine created. Invite the members.");
    if (ok && id != null) Get.off(() => TontineScreen(tontineId: id!));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final int? amount = _validAmount;
    final int? limit = _validLimit;
    final missing = _missing();
    final String range = "Between @min and @max members.".trParams({'min': '${cfg.minMembers}', 'max': '${cfg.maxMembers}'});
    return FinScaffold(
      title: "Create a tontine".tr,
      bottomBar: DsStickyBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinMissing(missing),
            DsButton.primary(label: "Create tontine".tr, size: DsButtonSize.lg, expand: true, onPressed: missing.isEmpty ? _save : null),
          ],
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            title: "Tontine".tr,
            top: 0,
            padding: _formPadding,
            children: [
              DsFieldLabel("Tontine Type".tr, required: true),
              Wrap(
                spacing: DsSpace.sm,
                runSpacing: DsSpace.xs,
                children: [
                  ChoiceChip(
                    label: Text("Group".tr),
                    selected: _type == 'group',
                    onSelected: (_) => setState(() => _type = 'group'),
                  ),
                  ChoiceChip(
                    label: Text("Professional (Company)".tr),
                    selected: _type == 'professional',
                    onSelected: (_) => setState(() => _type = 'professional'),
                  ),
                  ChoiceChip(
                    label: Text("Association".tr),
                    selected: _type == 'association',
                    onSelected: (_) => setState(() => _type = 'association'),
                  ),
                ],
              ),
              const DsGap(DsSpace.md),
              if (_type == 'professional' && !BusinessAccount.canCreateProfessionalTontine)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.md),
                  child: DsInlineAlert(
                    tone: DsTone.warning,
                    title: "Company Account Required".tr,
                    message: "Only verified company business accounts can create a professional tontine.".tr,
                    actionLabel: "Verify Business".tr,
                    onAction: () => Get.to(() => const BusinessAccountScreen())?.then((_) => setState(() {})),
                  ),
                ),
              if (_type == 'association' && !BusinessAccount.canCreateAssociationTontine)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.md),
                  child: DsInlineAlert(
                    tone: DsTone.warning,
                    title: "Association Account Required".tr,
                    message: "Only verified association accounts can create an association tontine.".tr,
                    actionLabel: "Verify Association".tr,
                    onAction: () => Get.to(() => const BusinessAccountScreen())?.then((_) => setState(() {})),
                  ),
                ),
              DsTextField(label: "Name".tr, controller: _name, requiredMark: true, onChanged: (_) => setState(() {})),
              DsTextField(label: "Description".tr, controller: _description, maxLines: 2),
              DsTextField(label: "Rules agreed by the members".tr, hint: "Penalties for late payment, how disputes are settled...".tr, controller: _rules, maxLines: 4),
            ],
          ),
          FinSection(
            title: "Contributions".tr,
            padding: _formPadding,
            children: [
              FinAmountField(
                label: "Amount per member, per cycle".tr,
                controller: _amount,
                currency: _currency,
                currencies: cfg.currencies,
                onCurrencyChanged: (v) => setState(() => _currency = v),
                min: cfg.minFor(_currency),
                onChanged: (_) => setState(() {}),
              ),
              DsDropdown<String>(
                label: "Frequency".tr,
                value: _frequency,
                requiredMark: true,
                items: [for (final f in cfg.frequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr))],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              DsTextField(
                label: "Number of members".tr,
                controller: _limit,
                requiredMark: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helper: _limit.text.trim().isNotEmpty && limit == null ? null : range,
                errorText: _limit.text.trim().isNotEmpty && limit == null ? range : null,
                onChanged: (_) => setState(() {}),
              ),
              DsTextField(
                label: "First contribution date".tr,
                controller: _startText,
                readOnly: true,
                requiredMark: true,
                suffix: const Icon(Icons.event_outlined, size: 18),
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final d = await showDatePicker(context: context, initialDate: _start ?? today.add(const Duration(days: 7)), firstDate: today, lastDate: DateTime(now.year + 2));
                  if (d != null) {
                    setState(() {
                      _start = d;
                      _startText.text = _date(d);
                    });
                  }
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
          // What the members commit to, once the figures are valid.
          if (amount != null && limit != null)
            FinSection(
              title: "Summary".tr,
              divided: true,
              children: [
                FinRow("Amount per member, per cycle".tr, FinanceMoney.format(amount, _currency)),
                FinRow("Frequency".tr, Frequency.label(_frequency).tr),
                FinRow("Number of members".tr, '$limit'),
                if (_start != null) FinRow("First contribution date".tr, _date(_start)),
                FinRow("Who receives the pot first".tr, _orderLabel(_order).tr),
                FinRow("Tontine type".tr, _type == 'professional' ? "Professional (Company)".tr : (_type == 'association' ? "Association".tr : "Group".tr)),
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
/// members and payout order, history, disputes. A tontine that no longer
/// exists says so; a failed read offers Retry.
class TontineScreen extends StatefulWidget {
  final String tontineId;

  const TontineScreen({super.key, required this.tontineId});

  @override
  State<TontineScreen> createState() => _TontineScreenState();
}

class _TontineScreenState extends State<TontineScreen> {
  int _tab = 0;
  late Stream<Tontine?> _tontine = FinanceGroupService.tontine(widget.tontineId);
  late final Stream<List<Map<String, dynamic>>> _members = FinanceGroupService.members(widget.tontineId);

  /// The payout order being edited, kept here so switching tabs does not
  /// lose it; null when there is no unsaved change.
  List<String>? _order;

  @override
  Widget build(BuildContext context) {
    return FinConfig<TontineConfig>(
      load: FinanceGroupService.tontineConfig,
      builder: (context, cfg) => StreamBuilder<Tontine?>(
        stream: _tontine,
        builder: (context, snap) {
          final t = snap.data;
          final Widget? state = FinState.of(
            snap,
            gone: "This tontine is no longer available.",
            onRetry: () => setState(() => _tontine = FinanceGroupService.tontine(widget.tontineId)),
          );
          final bool member = t != null && t.memberIds.contains(FinanceService.uid);
          return FinScaffold(
            title: t?.name ?? "Tontine".tr,
            // The tontine's group conversation, for its active members.
            actions: !member
                ? null
                : [
                    DsIconButton(
                      icon: Icons.forum_outlined,
                      semanticLabel: "Group chat".tr,
                      onPressed: () => Get.to(() => FinanceChatScreen(target: FinanceChatTarget.tontine(t))),
                    ),
                    const DsGap(DsSpace.xs),
                  ],
            body: state != null || t == null
                ? FinBody(children: [state ?? FinState.loading(rows: 4)])
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _members,
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
                            0 => _Overview(tontine: t, members: members, config: cfg.config, configFailed: cfg.failed, onRetryConfig: cfg.retry),
                            1 => _Members(tontine: t, members: members, order: _order, onOrderChanged: (o) => setState(() => _order = o)),
                            2 => _History(tontine: t, members: members),
                            _ => _Disputes(tontine: t, members: members),
                          },
                        ],
                      );
                    },
                  ),
          );
        },
      ),
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
    // While forming, the pot the members agreed to (every place filled), as
    // in the creation summary; once started, the pot of the actual members.
    final bool forming = t.isForming;
    return FinHero(
      label: (forming ? "Pot per cycle when full" : "Pot per cycle").tr,
      amount: FinanceMoney.format(forming ? t.contributionAmount * t.membersLimit : t.potPerCycle, t.currency),
      caption: '${"Amount per member, per cycle".tr}: ${FinanceMoney.format(t.contributionAmount, t.currency)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FinStatusChip(status: 'neutral', label: Tontine.typeLabel(t.type).tr),
          const DsGap(DsSpace.xs),
          FinStatusChip(status: _st(t.status), label: Tontine.statusLabel(t.status).tr, icon: true),
        ],
      ),
      stats: [
        FinHeroStat("Frequency".tr, Frequency.label(t.frequency).tr),
        FinHeroStat("Members".tr, '${t.memberIds.length}/${t.membersLimit}'),
        if (t.nextDueAt != null) FinHeroStat("Next payment".tr, _date(t.nextDueAt)),
      ],
    );
  }
}

/// A member's name: "You", their display name or email, else "Member 3"
/// (their place in [ids]) while the member list loads or when it failed -
/// never a raw account id.
String _nameOf(List<Map<String, dynamic>> members, String? uid, [List<String> ids = const []]) {
  if (uid != null && uid == FinanceService.uid) return "You".tr;
  final m = members.where((x) => x['userId'] == uid).firstOrNull;
  final String name = (m?['displayName'] ?? m?['email'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  if (uid == null || uid.isEmpty) return '-';
  final int i = ids.indexOf(uid);
  return i < 0 ? "Member".tr : '${"Member".tr} ${i + 1}';
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

  /// The configuration could not be read (offline...): Retry, not "not available".
  final bool configFailed;
  final VoidCallback onRetryConfig;

  const _Overview({required this.tontine, required this.members, required this.config, required this.configFailed, required this.onRetryConfig});

  @override
  Widget build(BuildContext context) {
    final t = tontine;
    final uid = FinanceService.uid;
    final schedule = t.schedule();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t.isForming) ...[
          _formingActions(context),
          if (schedule.isNotEmpty) _schedule(context, schedule, const []),
        ] else
          FinReload(
            builder: (context, retry) => StreamBuilder<List<Map<String, dynamic>>>(
              stream: FinanceGroupService.cycles(t.id),
              builder: (context, cSnap) {
                if (cSnap.hasError) return FinState.error("Could not load the cycles.".tr, onRetry: retry);
                if (!cSnap.hasData) return FinState.loading(rows: 2);
                final cycles = cSnap.data!;
                final current = cycles.where((c) => c['number'] == t.currentCycle).firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (current == null)
                      FinNotice("The first cycle starts on the first contribution date.".tr)
                    else
                      _CurrentCycle(tontine: t, cycle: current, members: members, config: config),
                    if (t.isActive && t.memberIds.contains(uid)) _PendingPayouts(tontine: t, members: members),
                    if (schedule.isNotEmpty) _schedule(context, schedule, cycles),
                  ],
                );
              },
            ),
          ),
        if (t.isProfessional) _ProfessionalSalaryCard(tontine: t),
        _TontineBlacklistCard(tontine: t),
        FinSection(
          title: "Details".tr,
          divided: true,
          children: [
            FinRow("Type".tr, Tontine.typeLabel(t.type).tr),
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

  /// One cycle per member: where the rotation is, then who receives the pot
  /// when, and what became of each cycle opened at the start ([cycles]).
  Widget _schedule(BuildContext context, List<DateTime> schedule, List<Map<String, dynamic>> cycles) {
    final t = tontine;
    final int n = schedule.length;
    final bool started = !t.isForming;
    final int current = t.status == 'completed' ? n - 1 : (t.currentCycle - 1).clamp(0, n - 1).toInt();
    String beneficiary(int i) => _nameOf(members, _beneficiaryAt(i + 1), t.memberIds);
    String? cycleStatus(int i) {
      final c = cycles.where((c) => c['number'] == i + 1).firstOrNull;
      return c == null ? null : GroupLabels.cycle(c['status']?.toString()).tr;
    }

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
        for (final (i, d) in schedule.indexed) FinRow('${"Cycle".tr} ${i + 1} · ${_date(d)}', beneficiary(i), sub: cycleStatus(i), strong: t.isActive && i == current),
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
    final String? blocker = cfg == null ? null : TontineActions.startBlocker(t, uid, cfg, order);
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
          if (cfg == null && configFailed)
            FinNotice("Could not load the tontine settings.".tr, tone: DsTone.danger, actionLabel: "Try again".tr, onAction: onRetryConfig)
          else if (blocker != null)
            FinNotice(blocker.tr, tone: DsTone.warning),
          const DsGap(DsSpace.md),
          DsButton.primary(
            label: "Start the tontine".tr,
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: cfg == null || blocker != null
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

  /// A payment the user has started and the provider has not confirmed yet:
  /// `processing`, or `pending` with a payment attached (a pending record
  /// without one is only a contribution still to pay).
  static bool _started(Map<String, dynamic> x) {
    final String status = x['status']?.toString() ?? '';
    if (status == 'processing') return true;
    return status == 'pending' && ((x['paymentId'] ?? '').toString().isNotEmpty || (x['reference'] ?? '').toString().isNotEmpty);
  }

  Future<void> _pay(BuildContext context, String cycleId) {
    final t = tontine;
    final int amount = t.contributionAmount;
    return FinancePaySheet.show(
      context,
      title: '${t.name} · ${"Cycle".tr} ${cycle['number']}',
      amount: amount,
      currency: t.currency,
      methods: config?.paymentMethods ?? const ['wallet'],
      // One contribution per cycle and member (`{cycleId}_{uid}`): a retry finds it instead of paying twice.
      submit: (FinanceFunding funding) => FinanceGroupService.contributeToTontine(t.id, cycleId, funding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tontine;
    final c = DsColors.of(context);
    final String cycleId = cycle['id'].toString();
    final DateTime? due = FinanceGroupService.toDate(cycle['dueDate']);
    final String me = FinanceService.uid;
    return FinReload(
      builder: (context, retry) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: FinanceGroupService.cycleContributions(t.id, cycleId),
        builder: (context, snap) {
          if (snap.hasError) return FinState.error("Could not load the contributions of this cycle.".tr, onRetry: retry);
          // Nobody's status (the user's included) is known until the contributions are read.
          if (!snap.hasData) return FinState.loading(rows: 3);
          final contributions = snap.data!;
          final summary = CycleSummary.of(contributions, t.memberIds, t.contributionAmount, due, DateTime.now());
          final String mine = summary.statusByMember[me] ?? 'pending';
          final bool inProgress = mine != 'paid' && contributions.any((x) => x['userId'] == me && _started(x));
          final bool canPay = cycle['status'] == 'collecting' && t.memberIds.contains(me) && mine != 'paid';
          final int processing = summary.statusByMember.values.where((s) => s == 'processing').length;
          final double collected = summary.expected == 0 ? 0 : (summary.collected / summary.expected).clamp(0, 1).toDouble();
          final counts = [
            "@paid of @total members have paid".trParams({'paid': '${summary.paid}', 'total': '${t.memberIds.length}'}),
            if (processing > 0) "Being confirmed: @n".trParams({'n': '$processing'}),
            if (summary.pending > 0) "Not paid yet: @n".trParams({'n': '${summary.pending}'}),
            if (summary.overdue > 0) "Overdue: @n".trParams({'n': '${summary.overdue}'}),
          ];
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
                                  Text(_nameOf(members, cycle['beneficiaryUserId']?.toString(), t.memberIds), style: DsTypography.titleSm.copyWith(color: c.textPrimary)),
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
                        Text(counts.join(' · '), style: DsTypography.caption.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  FinRow("Due date".tr, _date(due)),
                  if (canPay && inProgress)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                      child: FinNotice("Your payment is being confirmed. This page updates as soon as it is.".tr, title: "Payment in progress".tr),
                    )
                  else if (canPay)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                      child: FinanceKycGate(
                        builder: (context, verified) => DsButton.primary(
                          label: "${"Pay my contribution".tr} ${FinanceMoney.format(t.contributionAmount, t.currency)}",
                          icon: Icons.payments_outlined,
                          expand: true,
                          onPressed: !verified ? null : () => _pay(context, cycleId),
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
                      label: _nameOf(members, uid, t.memberIds),
                      status: _st(summary.statusByMember[uid]),
                      statusLabel: GroupLabels.contribution(summary.statusByMember[uid]).tr,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Admins approve each payout; the approval pays the beneficiary's wallet
/// from the pot. Nobody approves their own payout: another admin does, or
/// Spideli when the beneficiary is the only admin.
class _PendingPayouts extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _PendingPayouts({required this.tontine, required this.members});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceGroupService.payouts(tontine.id),
      builder: (context, snap) {
        final String me = FinanceService.uid;
        final bool admin = tontine.isAdmin(me);
        // An admin sees every payout awaiting approval; a member only their own.
        final pending = (snap.data ?? const []).where((p) => p['status'] == 'pending_approval' && (admin || p['beneficiaryUserId'] == me)).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: (admin ? "Payouts to approve" : "Your payout").tr,
          divided: true,
          children: [for (final p in pending) _approval(context, p)],
        );
      },
    );
  }

  Widget _approval(BuildContext context, Map<String, dynamic> p) {
    final String name = _nameOf(members, p['beneficiaryUserId']?.toString(), tontine.memberIds);
    final String amount = FinanceMoney.format(FinanceSummary.intOf(p['amount']), tontine.currency);
    final String cycle = '${p['cycleNumber'] ?? '-'}';
    final bool own = p['beneficiaryUserId'] == FinanceService.uid;
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
        if (own)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: FinNotice(
              (!tontine.isAdmin(FinanceService.uid)
                      ? "An administrator of the tontine approves your payout. The pot is paid to your wallet once they have."
                      : TontineWrites.waitsForSpideli(tontine, p)
                      ? "You are the only administrator: Spideli approves your own payout. The pot is paid to your wallet once it has."
                      : "Another administrator approves your own payout. The pot is paid to your wallet once they have.")
                  .tr,
              title: "Waiting for approval".tr,
            ),
          )
        else
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

/// Members and payout order. While the tontine is forming its admin drags
/// members (by the handle, or a long press on the row) into the payout
/// order; the unsaved order lives in [TontineScreen] so it survives a tab
/// switch.
class _Members extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;
  final List<String>? order;
  final ValueChanged<List<String>?> onOrderChanged;

  const _Members({required this.tontine, required this.members, required this.order, required this.onOrderChanged});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = tontine;
    final uid = FinanceService.uid;
    final active = members.where((m) => m['status'] == 'active').toList();
    final others = members.where((m) => m['status'] != 'active').toList();
    final bool editOrder = t.isAdmin(uid) && t.isForming && t.payoutOrderMethod == 'fixed';
    final saved = active.map((m) => m['userId'].toString()).toList();
    // A member who joined has no position yet: the order must be saved once.
    final bool incomplete = active.any((m) => m['payoutPosition'] is! num);
    // A draft made before someone joined or left no longer matches: start again from the saved order.
    final draft = order;
    final bool draftValid = draft != null && draft.length == saved.length && saved.every(draft.contains);
    final current = draftValid ? draft : saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (TontineActions.canInvite(t, uid, members.where((m) => m['status'] == 'active' || m['status'] == 'invited').length))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.secondary(
              label: "Invite a member".tr,
              icon: Icons.person_add_alt_outlined,
              expand: true,
              onPressed: () async {
                final email = await askInviteEmail(context);
                if (email != null) await runInvite(() => FinanceGroupService.invite(t.id, email), success: "Invitation sent");
              },
            ),
          ),
        FinSection(
          title: (editOrder ? "Payout order (drag to change)" : "Members and payout order").tr,
          top: DsSpace.lg,
          divided: !editOrder,
          children: [
            if (editOrder)
              // Scrolls by itself (and while dragging) when the members do not fit.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: ReorderableListView(
                  primary: false,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) {
                    final list = [...current];
                    list.insert(to, list.removeAt(from));
                    onOrderChanged(list);
                  },
                  children: [
                    for (final (i, id) in current.indexed)
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(id),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                          child: Row(
                            children: [
                              _Position(i + 1),
                              const DsGap(DsSpace.md),
                              Expanded(child: Text(_nameOf(members, id, t.memberIds), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary))),
                              ReorderableDragStartListener(
                                index: i,
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.drag_handle_rounded, color: c.textMuted, semanticLabel: "Drag to change the order".tr),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
                              Text(_nameOf(members, m['userId']?.toString(), t.memberIds), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                              if (m['role'] == 'admin') Text("Administrator".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                        if (t.isAssociation && t.isAdmin(uid) && m['userId'] != uid)
                          DsButton.ghost(
                            label: "Remove".tr,
                            icon: Icons.person_remove_outlined,
                            size: DsButtonSize.sm,
                            color: c.dangerStrong,
                            onPressed: () => _confirmRemoveMember(context, t.id, m['userId'].toString(), _nameOf(members, m['userId']?.toString(), t.memberIds)),
                          ),
                        // A direct conversation with another member.
                        if (m['userId'] != uid && (m['userId'] ?? '').toString().isNotEmpty)
                          DsButton.ghost(
                            label: "Message".tr,
                            icon: Icons.chat_bubble_outline_rounded,
                            size: DsButtonSize.sm,
                            onPressed: () => Get.to(
                              () => FinanceChatScreen(target: FinanceChatTarget.direct(uid, m['userId'].toString(), _nameOf(members, m['userId']?.toString(), t.memberIds))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            if (editOrder && (draftValid || incomplete))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DsButton.primary(
                      label: "Save payout order".tr,
                      expand: true,
                      onPressed: () async {
                        if (await FinanceUi.run(() => FinanceGroupService.setPayoutOrder(t.id, current), success: "Payout order saved")) onOrderChanged(null);
                      },
                    ),
                    if (draftValid) DsButton.ghost(label: "Discard changes".tr, expand: true, onPressed: () => onOrderChanged(null)),
                  ],
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
                  title: m['displayName']?.toString() ?? m['email']?.toString() ?? "Member".tr,
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
        FinReload(
          builder: (context, retry) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceGroupService.cycles(tontine.id),
            builder: (context, snap) {
              if (snap.hasError) return FinState.error("Could not load the cycles.".tr, onRetry: retry);
              if (!snap.hasData) return FinState.loading(rows: 2);
              final cycles = snap.data!;
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
                      subtitle:
                          '${_date(FinanceGroupService.toDate(cy['dueDate']))} · ${"Receives the pot".tr}: ${_nameOf(members, cy['beneficiaryUserId']?.toString(), tontine.memberIds)}',
                      status: _st(cy['status']?.toString()),
                      statusLabel: GroupLabels.cycle(cy['status']?.toString()).tr,
                    ),
                ],
              );
            },
          ),
        ),
        FinReload(
          builder: (context, retry) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceGroupService.payouts(tontine.id),
            builder: (context, snap) {
              if (snap.hasError) return FinState.error("Could not load the payouts.".tr, onRetry: retry);
              if (!snap.hasData) return FinState.loading(rows: 2);
              final payouts = snap.data!;
              return FinSection(
                title: "Payouts".tr,
                divided: true,
                children: [
                  if (payouts.isEmpty) _quiet(context, "No payout yet.".tr),
                  for (final p in payouts)
                    FinListTile(
                      icon: Icons.north_east_rounded,
                      title: _nameOf(members, p['beneficiaryUserId']?.toString(), tontine.memberIds),
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
        ),
      ],
    );
  }
}

class _Disputes extends StatelessWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _Disputes({required this.tontine, required this.members});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.lg),
          child: DsButton.secondary(
            label: "Raise a dispute".tr,
            icon: Icons.report_outlined,
            expand: true,
            onPressed: () => finSheet<void>(title: "Raise a dispute".tr, child: _DisputeSheet(tontine: tontine, members: members)),
          ),
        ),
        FinReload(
          builder: (context, retry) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: FinanceGroupService.disputes(tontine.id),
            builder: (context, snap) {
              if (snap.hasError) return FinState.error("Could not load the disputes.".tr, onRetry: retry);
              if (!snap.hasData) return FinState.loading(rows: 2);
              final list = snap.data!;
              if (list.isEmpty) return FinState.empty(Icons.verified_outlined, "No dispute.".tr);
              return FinSection(
                title: "Disputes".tr,
                divided: true,
                children: [for (final d in list) _dispute(context, d)],
              );
            },
          ),
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
          Text('${"Raised by".tr} ${_nameOf(members, d['raisedBy']?.toString(), tontine.memberIds)} · ${FinanceUi.date(d['createdAt'])}',
              style: DsTypography.caption.copyWith(color: c.textSecondary)),
          const DsGap(DsSpace.sm),
          Text(d['description']?.toString() ?? '', style: DsTypography.body.copyWith(color: c.textPrimary)),
          if ((d['resolution'] ?? '').toString().isNotEmpty) FinNotice(d['resolution'].toString(), title: "Resolution".tr, tone: DsTone.info),
        ],
      ),
    );
  }
}

/// A dispute: subject, what happened, and optionally the member concerned
/// (searchable in a large tontine). It is sent from the sheet, which stays
/// open with what was typed if the request fails.
class _DisputeSheet extends StatefulWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> members;

  const _DisputeSheet({required this.tontine, required this.members});

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  static const int _subjectMin = 3;
  static const int _descriptionMin = 10;

  final _subject = TextEditingController();
  final _description = TextEditingController();

  /// The member concerned; empty for the tontine in general.
  String _against = '';

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = widget.tontine;
    final ok = await FinanceUi.run(
      () => FinanceGroupService.raiseDispute(t.id, subject: _subject.text.trim(), description: _description.text.trim(), againstUserId: _against.isEmpty ? null : _against),
      success: "Dispute sent",
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tontine;
    final bool ready = _subject.text.trim().length >= _subjectMin && _description.text.trim().length >= _descriptionMin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTextField(
          label: "Subject".tr,
          controller: _subject,
          requiredMark: true,
          helper: _minHelper(_subject.text, _subjectMin),
          onChanged: (_) => setState(() {}),
        ),
        DsTextField(
          label: "What happened".tr,
          controller: _description,
          requiredMark: true,
          maxLines: 4,
          helper: _minHelper(_description.text, _descriptionMin),
          onChanged: (_) => setState(() {}),
        ),
        FinPickerField<String>(
          label: "Concerning a member (optional)".tr,
          value: _against,
          options: [
            ('', "The tontine in general".tr),
            for (final id in t.memberIds.where((id) => id != FinanceService.uid)) (id, _nameOf(widget.members, id, t.memberIds)),
          ],
          onChanged: (v) => setState(() => _against = v),
        ),
        Text(
          "Disputes are reviewed by the administrators; nobody is restricted without a review.".tr,
          style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary),
        ),
        const DsGap(DsSpace.md),
        DsButton.primary(label: "Send".tr, expand: true, onPressed: ready ? _send : null),
      ],
    );
  }
}

void _confirmRemoveMember(BuildContext context, String tontineId, String memberUid, String name) {
  Get.dialog(
    AlertDialog(
      title: Text("Remove Member".tr),
      content: Text("Are you sure you want to remove @name from this association tontine?".trParams({'name': name})),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text("Cancel".tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            await FinanceUi.run(
              () => FinanceGroupService.removeMember(tontineId, memberUid),
              success: "Member removed from tontine.".tr,
            );
          },
          child: Text("Remove".tr, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

class _ProfessionalSalaryCard extends StatelessWidget {
  final Tontine tontine;

  const _ProfessionalSalaryCard({required this.tontine});

  @override
  Widget build(BuildContext context) {
    final uid = FinanceService.uid;
    final isHr = tontine.isAdmin(uid);
    final isEmployee = tontine.memberIds.contains(uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEmployee)
          StreamBuilder<MemberSalary?>(
            stream: FinanceGroupService.mySalary(tontine.id),
            builder: (context, snap) {
              final s = snap.data;
              return FinSection(
                title: "My Salary & Loan Cap".tr,
                divided: true,
                children: [
                  if (s == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Declare your monthly salary to enable salary-capped loans (up to ⅓ of salary).".tr,
                              style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
                          const DsGap(DsSpace.sm),
                          DsButton.secondary(
                            label: "Declare monthly salary".tr,
                            icon: Icons.payments_outlined,
                            size: DsButtonSize.sm,
                            onPressed: () => _showDeclareSalaryDialog(context, tontine),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    FinRow("Declared salary".tr, FinanceMoney.format(s.monthlySalary, s.currency)),
                    FinRow("Status".tr, s.isConfirmed ? "Confirmed by HR".tr : "Pending HR confirmation".tr,
                        sub: s.confirmedAt != null ? _date(s.confirmedAt) : null),
                    FinRow("Maximum loan cap (⅓)".tr, FinanceMoney.format(s.loanCap, s.currency), strong: true),
                    if (!s.isConfirmed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                        child: DsButton.ghost(
                          label: "Update declared salary".tr,
                          size: DsButtonSize.sm,
                          onPressed: () => _showDeclareSalaryDialog(context, tontine, initialAmount: s.monthlySalary),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        if (isHr)
          StreamBuilder<List<MemberSalary>>(
            stream: FinanceGroupService.tontineSalaries(tontine.id),
            builder: (context, snap) {
              final salaries = snap.data ?? const [];
              if (salaries.isEmpty) return const SizedBox.shrink();
              return FinSection(
                title: "Employee Salaries (HR)".tr,
                divided: true,
                children: [
                  for (final s in salaries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.userId == uid ? "You".tr : 'Employee (${s.userId.substring(0, math.min(6, s.userId.length))})',
                                    style: DsTypography.bodyStrong.copyWith(color: DsColors.of(context).textPrimary)),
                                Text('${FinanceMoney.format(s.monthlySalary, s.currency)} · Cap: ${FinanceMoney.format(s.loanCap, s.currency)}',
                                    style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
                              ],
                            ),
                          ),
                          if (s.isConfirmed)
                            FinStatusChip(status: 'completed', label: "Confirmed".tr)
                          else
                            DsButton.primary(
                              label: "Confirm".tr,
                              size: DsButtonSize.sm,
                              onPressed: () async {
                                await FinanceUi.run(
                                  () => FinanceGroupService.confirmSalary(tontineId: tontine.id, employeeUid: s.userId),
                                  success: "Salary confirmed".tr,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  static void _showDeclareSalaryDialog(BuildContext context, Tontine tontine, {int? initialAmount}) {
    final controller = TextEditingController(text: initialAmount != null ? '$initialAmount' : '');
    Get.dialog(
      AlertDialog(
        title: Text("Declare Monthly Salary".tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Enter your net monthly salary. In professional tontines, loans are capped at ⅓ of this confirmed salary.".tr,
                style: DsTypography.bodySm),
            const DsGap(DsSpace.md),
            DsTextField(
              label: "Monthly Salary (@curr)".trParams({'curr': tontine.currency}),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("Cancel".tr)),
          TextButton(
            onPressed: () async {
              final int? val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Get.back();
                await FinanceUi.run(
                  () => FinanceGroupService.declareSalary(tontineId: tontine.id, monthlySalary: val, currency: tontine.currency),
                  success: "Salary declared. Awaiting HR confirmation.".tr,
                );
              }
            },
            child: Text("Save".tr),
          ),
        ],
      ),
    );
  }
}

class _TontineBlacklistCard extends StatelessWidget {
  final Tontine tontine;

  const _TontineBlacklistCard({required this.tontine});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TontineBlacklistEntry>>(
      stream: FinanceGroupService.blacklist(tontine.id),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Tontine Blacklist (Unpaid Debt)".tr,
          divided: true,
          children: [
            for (final b in list)
              FinListTile(
                icon: Icons.block_rounded,
                iconTone: DsTone.danger,
                title: b.displayName.isNotEmpty ? b.displayName : "Member".tr,
                subtitle: "Defaulted loan · restricted since @date".trParams({'date': _date(b.since)}),
                status: 'restricted',
                statusLabel: "Blacklisted".tr,
              ),
          ],
        );
      },
    );
  }
}

