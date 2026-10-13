import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/card_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/financing_screens.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/intelligence_screens.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_intel_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_intel_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Opens the screen a coach suggestion points to. The coach never acts:
/// the user does, through that screen's own confirmation.
void _openTarget(String target) {
  final Widget? screen = switch (target) {
    'savings' => const SavingsListScreen(),
    'tontines' => const TontineListScreen(),
    'loans' => const LoansScreen(),
    'investments' || 'simulator' => const InvestmentsScreen(),
    'insurance' => const InsuranceScreen(),
    'cards' => const CardsScreen(),
    'transfers' => const TransfersScreen(),
    'bills' => const BillsScreen(),
    'financing' => const FinancingScreen(),
    'kyc' => const KycScreen(),
    'indicators' => const IntelligenceScreen(),
    _ => null,
  };
  if (screen != null) Get.to(() => screen);
}

/// The limits shown with the consent and on every conversation.
const List<String> _limits = [
  "The coach explains and gives general guidance. It is not personalised financial, legal or tax advice.",
  "It can be wrong. Check important information and ask a professional before a big decision.",
  "It never promises returns and never moves money: you decide and confirm every operation yourself.",
  "Do not share passwords, card numbers, PIN codes or identity documents in the chat.",
];

/// One icon per limit, in the same order.
const List<IconData> _limitIcons = [
  Icons.school_outlined,
  Icons.fact_check_outlined,
  Icons.money_off_rounded,
  Icons.lock_outline_rounded,
];

/// List sections: rows carry their own vertical padding.
const EdgeInsets _listPadding = EdgeInsets.symmetric(horizontal: DsSpace.lg);

/// Chat bubbles: restrained corners, the one nearest the sender squarer.
const Radius _bubbleRadius = Radius.circular(FinSpace.radius);
const Radius _bubbleTail = Radius.circular(DsSpace.xs);

/// Sheets open above the screen (outside its accent scope): keep them navy.
Widget _navy(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

/// Spideli Finance > Financial coach. `platform_settings/intelligence.coach` must be enabled (admin).
class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IntelligenceConfig?>(
      future: FinanceIntelService.config(),
      builder: (context, cfgSnap) {
        final coach = cfgSnap.data?.coach;
        if (cfgSnap.connectionState == ConnectionState.waiting || coach == null) {
          return FinScaffold(
            title: "Financial coach".tr,
            body: FinBody(children: [
              coach == null && cfgSnap.connectionState != ConnectionState.waiting
                  ? FinState.empty(Icons.support_agent_rounded, "The financial coach is not available yet.".tr)
                  : FinState.loading(),
            ]),
          );
        }
        return StreamBuilder<CoachConsent?>(
          stream: FinanceIntelService.consent(),
          builder: (context, cs) {
            if (cs.connectionState == ConnectionState.waiting) {
              return FinScaffold(title: "Financial coach".tr, body: FinBody(children: [FinState.loading()]));
            }
            final consent = cs.data;
            if (consent == null || !consent.validFor(coach)) return _ConsentView(config: coach, renewing: consent != null && !consent.withdrawn);
            return _Sessions(config: coach, consent: consent);
          },
        );
      },
    );
  }
}

class _ConsentView extends StatefulWidget {
  final CoachConfig config;
  final bool renewing;

  const _ConsentView({required this.config, required this.renewing});

  @override
  State<_ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends State<_ConsentView> {
  bool _accepted = false;
  bool _share = false;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return FinScaffold(
      title: "Financial coach".tr,
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Start".tr,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: !_accepted ? null : () => FinanceUi.run(() => FinanceIntelService.acceptConsent(widget.config.consentVersion, _share)),
        ),
      ),
      body: FinBody(children: [
        FinHeader(
          icon: Icons.support_agent_rounded,
          title: "Your financial coach".tr,
          subtitle: "Ask about budgeting, saving, borrowing, insurance, investing or financing a project. The coach answers with an AI service run by Spideli.".tr,
        ),
        if (widget.renewing) FinNotice("The terms of the coach changed. Please read and accept them again.".tr),
        FinSection(
          title: "Good to know".tr,
          divided: true,
          children: [
            for (final (i, l) in _limits.indexed)
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_limitIcons[i], size: 20, color: FinColors.brand(context)),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text(l.tr, style: DsTypography.body.copyWith(color: c.textPrimary))),
                  ]),
                ),
              ),
          ],
        ),
        FinSection(
          title: "Your consent".tr,
          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(color: c.isDark ? c.surfaceAlt : FinColors.page(context), borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DsSpace.md),
                  child: Text(widget.config.consentText, style: DsTypography.bodySm.copyWith(color: c.textPrimary, height: 1.5)),
                ),
              ),
            ),
            const DsGap(DsSpace.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _share,
              onChanged: (v) => setState(() => _share = v ?? false),
              title: Text("Let the coach use my Spideli Finance totals (balances, savings, loans) to tailor its answers".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              subtitle: Text(
                "Only totals are shared, never your identity documents or the details of your transactions. You can change this later.".tr,
                style: DsTypography.caption.copyWith(color: c.textSecondary),
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.divider),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: Text("I have read how the coach works and its limits, and I agree.".tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
            ),
          ],
        ),
      ]),
    );
  }
}

class _Sessions extends StatelessWidget {
  final CoachConfig config;
  final CoachConsent consent;

  const _Sessions({required this.config, required this.consent});

  Future<void> _settings(BuildContext context) async {
    await finSheet(
      title: "Coach settings".tr,
      child: _navy(StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: consent.shareSummary,
              title: Text("Use my Spideli Finance totals".tr),
              subtitle: Text("Only totals, never documents or transaction details.".tr),
              onChanged: (v) async {
                Get.back();
                await FinanceUi.run(() => FinanceIntelService.setShareSummary(v));
              },
            ),
            Divider(color: DsColors.of(context).divider),
            DsButton.ghost(
              label: "Stop using the coach".tr,
              icon: Icons.block_rounded,
              expand: true,
              color: DsColors.of(context).danger,
              onPressed: () async {
                Get.back();
                // Two ways to stop: keep the conversations, or delete them too.
                final choice = await finSheet<String>(
                  title: "Stop using the coach?".tr,
                  child: _navy(Builder(
                    builder: (context) {
                      final c = DsColors.of(context);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("You can also delete all your conversations.".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
                          const DsGap(DsSpace.lg),
                          DsButton.primary(label: "Stop".tr, expand: true, color: c.danger, onPressed: () => Get.back(result: 'keep')),
                          const DsGap(DsSpace.sm),
                          DsButton.dangerTonal(label: "Stop and delete".tr, icon: Icons.delete_outline_rounded, expand: true, onPressed: () => Get.back(result: 'delete')),
                          DsButton.ghost(label: "Cancel".tr, expand: true, onPressed: () => Get.back()),
                        ],
                      );
                    },
                  )),
                );
                if (choice != null) await FinanceUi.run(() => FinanceIntelService.withdrawConsent(deleteHistory: choice == 'delete'));
              },
            ),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Financial coach".tr,
      actions: [DsIconButton(icon: Icons.settings_outlined, semanticLabel: "Coach settings".tr, onPressed: () => _settings(context))],
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "New conversation".tr,
          icon: Icons.add_comment_outlined,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: () => Get.to(() => CoachChatScreen(config: config)),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FinanceIntelService.sessions(),
        builder: (context, snap) {
          if (snap.hasError) return FinBody(children: [FinState.error("Could not load your conversations.".tr)]);
          if (!snap.hasData) return FinBody(children: [FinState.loading()]);
          if (snap.data!.isEmpty) {
            return FinBody(children: [
              FinState.empty(
                Icons.support_agent_rounded,
                "Ask your first question".tr,
                message: "For example: how to build a monthly budget, how much to save for a goal, or how a tontine works.".tr,
              ),
            ]);
          }
          return FinBody(children: [
            FinSection(
              top: 0,
              divided: true,
              padding: _listPadding,
              footnote: "General guidance, not financial advice. The coach can be wrong and never moves money.".tr,
              children: [
                for (final s in snap.data!)
                  FinListTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconTone: DsTone.brand,
                    title: (s['title'] ?? '').toString().isEmpty ? CoachRules.topic(s['topic']?.toString() ?? 'general').tr : s['title'].toString(),
                    subtitle: [
                      if ((s['title'] ?? '').toString().isNotEmpty) CoachRules.topic(s['topic']?.toString() ?? 'general').tr,
                      FinanceUi.date(s['updatedAt']),
                    ].join(' · '),
                    chevron: true,
                    onTap: () => Get.to(() => CoachChatScreen(config: config, sessionId: s['id'].toString(), topic: s['topic']?.toString())),
                  ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

// --------------------------------------------------------------------- chat

class CoachChatScreen extends StatefulWidget {
  final CoachConfig config;
  final String? sessionId;
  final String? topic;

  const CoachChatScreen({super.key, required this.config, this.sessionId, this.topic});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late String? _sessionId = widget.sessionId;
  late String _topic = widget.config.topics.contains(widget.topic) ? widget.topic! : widget.config.topics.first;
  String? _pending;

  static const Map<String, List<String>> _starters = {
    'general': ["What can you help me with?", "How do I start managing my money better?"],
    'budget': ["How do I build a monthly budget?", "How can I reduce my expenses?"],
    'savings': ["How much should I save each month for a goal?", "What is the difference between a savings goal and a tontine?"],
    'investing': ["How do I choose a fund for my risk level?", "What does diversification mean?"],
    'loans': ["How do I know if I can afford a loan?", "What is the difference between flat and declining interest?"],
    'insurance': ["Which insurance do I need first?", "What is a deductible?"],
    'project_financing': ["What should my business plan contain?", "How do I prepare a financing application?"],
  };

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final String t = (text ?? _input.text).trim();
    final problem = CoachRules.messageProblem(t, widget.config.maxMessageLength);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    if (_pending != null) return;
    setState(() {
      _pending = t;
      _input.clear();
    });
    try {
      final id = await FinanceIntelService.send(sessionId: _sessionId, topic: _topic, text: t);
      if (mounted) setState(() => _sessionId = id);
    } on FinanceException catch (e) {
      ShowToastDialog.showToast(FinanceErrors.messageKey(e.reason).tr);
      if (mounted && _input.text.isEmpty) _input.text = t;
    } catch (_) {
      ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
      if (mounted && _input.text.isEmpty) _input.text = t;
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Financial coach".tr,
      actions: [
        if (_sessionId != null)
          DsIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: "Delete this conversation".tr,
            onPressed: () async {
              final ok = await finConfirm(title: "Delete this conversation?".tr, confirmLabel: "Delete".tr, destructive: true);
              if (ok && await FinanceUi.run(() => FinanceIntelService.deleteSession(_sessionId!))) Get.back();
            },
          ),
      ],
      body: Column(
        children: [
          _disclaimer(context),
          Expanded(
            child: _sessionId == null
                ? _starterView(context)
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FinanceIntelService.messages(_sessionId!),
                    builder: (context, snap) {
                      final list = snap.data ?? const [];
                      _toBottom();
                      return ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(FinSpace.page, DsSpace.lg, FinSpace.page, DsSpace.lg),
                        children: [
                          for (final m in list) _Bubble(message: m, sessionId: _sessionId!),
                          if (_pending != null) ...[
                            _Bubble(message: {'role': 'user', 'text': _pending}, sessionId: ''),
                            const _Typing(),
                          ],
                        ],
                      );
                    },
                  ),
          ),
          _inputBar(context),
        ],
      ),
    );
  }

  /// The standing reminder of what the coach is (and is not).
  Widget _disclaimer(BuildContext context) {
    final c = DsColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: c.isDark ? c.surfaceRaised : c.surface, border: Border(bottom: BorderSide(color: c.border))),
      padding: const EdgeInsets.symmetric(horizontal: FinSpace.page, vertical: DsSpace.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 16, color: c.textSecondary)),
        const DsGap(DsSpace.sm),
        Expanded(
          child: Text("General guidance, not financial advice. The coach can be wrong and never moves money.".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
        ),
      ]),
    );
  }

  Widget _starterView(BuildContext context) {
    final c = DsColors.of(context);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(FinSpace.page, DsSpace.lg, FinSpace.page, DsSpace.lg),
      children: [
        if (_pending != null) ...[
          _Bubble(message: {'role': 'user', 'text': _pending}, sessionId: ''),
          const _Typing(),
        ] else ...[
          Semantics(header: true, child: Text("What would you like to talk about?".tr, style: DsTypography.titleSm.copyWith(color: c.textPrimary))),
          const DsGap(DsSpace.md),
          Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
            for (final t in widget.config.topics) ChoiceChip(label: Text(CoachRules.topic(t).tr), selected: _topic == t, onSelected: (_) => setState(() => _topic = t)),
          ]),
          FinSection(
            top: DsSpace.lg,
            divided: true,
            padding: _listPadding,
            children: [
              for (final s in _starters[_topic] ?? const <String>[])
                FinListTile(icon: Icons.chat_bubble_outline_rounded, iconTone: DsTone.brand, title: s.tr, chevron: true, onTap: () => _send(s.tr)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _inputBar(BuildContext context) {
    final c = DsColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: c.isDark ? c.surfaceRaised : c.surface, border: Border(top: BorderSide(color: c.border))),
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.sm, DsSpace.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: widget.config.maxMessageLength,
              textInputAction: TextInputAction.newline,
              style: DsTypography.body.copyWith(color: c.textPrimary),
              cursorColor: FinColors.brand(context),
              decoration: InputDecoration(
                hintText: "Ask a question".tr,
                hintStyle: DsTypography.body.copyWith(color: c.textMuted),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: c.isDark ? c.surfaceAlt : FinColors.page(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
                border: OutlineInputBorder(borderRadius: FinSpace.br, borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: FinSpace.br, borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: FinSpace.br, borderSide: BorderSide(color: FinColors.brand(context), width: 1.4)),
              ),
            ),
          ),
          const DsGap(DsSpace.sm),
          DsIconButton(
            icon: Icons.send_rounded,
            semanticLabel: "Send".tr,
            variant: DsIconButtonVariant.filled,
            // While an answer is pending the button reads as disabled, not as a navy action.
            color: _pending == null ? null : c.surfaceAlt,
            onPressed: _pending == null ? () => _send() : null,
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final String sessionId;

  const _Bubble({required this.message, required this.sessionId});

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool? _rated;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final m = widget.message;
    final bool mine = m['role'] == 'user';
    final bool failed = m['status'] == 'failed';
    final actions = mine ? const <CoachAction>[] : CoachRules.actions(m['suggestedActions']);
    final DateTime? at = FinanceGroupService.toDate(m['createdAt']);
    final Color brand = FinColors.brand(context);
    final Color background = mine ? brand : (failed ? c.dangerSoft : (c.isDark ? c.surfaceRaised : c.surface));
    final Color foreground = mine ? DsColors.onColor(brand) : c.textPrimary;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.only(bottom: DsSpace.sm),
          padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadiusDirectional.only(
              topStart: _bubbleRadius,
              topEnd: _bubbleRadius,
              bottomStart: mine ? _bubbleRadius : _bubbleTail,
              bottomEnd: mine ? _bubbleTail : _bubbleRadius,
            ),
            border: mine ? null : Border.all(color: failed ? c.danger.withValues(alpha: 0.35) : c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.error_outline_rounded, size: 18, color: c.dangerStrong)),
                  const DsGap(DsSpace.sm),
                  Expanded(child: SelectableText("The coach could not answer. Please try again.".tr, style: DsTypography.body.copyWith(color: c.textPrimary))),
                ])
              else
                SelectableText(m['text']?.toString() ?? '', style: DsTypography.body.copyWith(color: foreground, height: 1.45)),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: DsButton.secondary(label: a.label, icon: Icons.open_in_new_rounded, size: DsButtonSize.sm, onPressed: () => _openTarget(a.target)),
                ),
              if (!mine && !failed && widget.sessionId.isNotEmpty && m['id'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.xs),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (at != null) Text(ltr(DateFormat('HH:mm').format(at)), style: DsTypography.caption.copyWith(color: c.textMuted).tabular),
                    const DsGap(DsSpace.sm),
                    for (final helpful in [true, false])
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: (helpful ? "Helpful" : "Not helpful").tr,
                        icon: Icon(
                          helpful ? (_rated == true ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined) : (_rated == false ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
                          size: 16,
                          color: _rated == helpful ? brand : c.textSecondary,
                        ),
                        onPressed: _rated != null
                            ? null
                            : () async {
                                setState(() => _rated = helpful);
                                try {
                                  await FinanceIntelService.feedback(widget.sessionId, m['id'].toString(), helpful);
                                } catch (_) {
                                  // Feedback is best effort.
                                }
                              },
                      ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceRaised : c.surface,
          borderRadius: const BorderRadiusDirectional.only(topStart: _bubbleRadius, topEnd: _bubbleRadius, bottomStart: _bubbleTail, bottomEnd: _bubbleRadius),
          border: Border.all(color: c.border),
        ),
        child: Semantics(
          liveRegion: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FinColors.brand(context))),
            const DsGap(DsSpace.sm),
            Text("The coach is thinking...".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
