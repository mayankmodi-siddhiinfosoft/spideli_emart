import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/card_screens.dart';
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
          return DsScaffold(
            title: "Financial coach".tr,
            maxContentWidth: DsLayout.contentMax,
            body: coach == null && cfgSnap.connectionState != ConnectionState.waiting
                ? DsEmptyState(icon: Icons.support_agent_rounded, title: "The financial coach is not available yet.".tr)
                : const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3)),
          );
        }
        return StreamBuilder<CoachConsent?>(
          stream: FinanceIntelService.consent(),
          builder: (context, cs) {
            if (cs.connectionState == ConnectionState.waiting) {
              return DsScaffold(title: "Financial coach".tr, body: const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3)));
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
    return DsScaffold(
      title: "Financial coach".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Start".tr,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: !_accepted ? null : () => FinanceUi.run(() => FinanceIntelService.acceptConsent(widget.config.consentVersion, _share)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          const DsIconWell(icon: Icons.support_agent_rounded, tone: DsTone.brand, size: 56),
          const DsGap(DsSpace.md),
          Text("Your financial coach".tr, style: DsTypography.title),
          const DsGap(DsSpace.xs),
          Text("Ask about budgeting, saving, borrowing, insurance, investing or financing a project. The coach answers with an AI service run by Spideli.".tr,
              style: DsTypography.body),
          if (widget.renewing) ...[
            const DsGap(DsSpace.md),
            DsInlineAlert(tone: DsTone.info, message: "The terms of the coach changed. Please read and accept them again.".tr),
          ],
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Good to know".tr,
            icon: Icons.info_outline_rounded,
            children: [
              for (final l in _limits) DsListTile(padding: const EdgeInsets.symmetric(vertical: 2), leadingIcon: Icons.check_rounded, title: l.tr, subtitleMaxLines: 4),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Your consent".tr,
            icon: Icons.privacy_tip_outlined,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Scrollbar(child: SingleChildScrollView(child: Text(widget.config.consentText, style: DsTypography.body))),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _share,
                onChanged: (v) => setState(() => _share = v ?? false),
                title: Text("Let the coach use my Spideli Finance totals (balances, savings, loans) to tailor its answers".tr),
                subtitle: Text("Only totals are shared, never your identity documents or the details of your transactions. You can change this later.".tr),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read how the coach works and its limits, and I agree.".tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sessions extends StatelessWidget {
  final CoachConfig config;
  final CoachConsent consent;

  const _Sessions({required this.config, required this.consent});

  Future<void> _settings(BuildContext context) async {
    await DsBottomSheet.show(
      title: "Coach settings".tr,
      child: StatefulBuilder(
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
            const Divider(),
            DsButton.ghost(
              label: "Stop using the coach".tr,
              icon: Icons.block_rounded,
              expand: true,
              onPressed: () async {
                Get.back();
                final choice = await showDialog<String>(
                  context: Get.context!,
                  builder: (d) => AlertDialog(
                    title: Text("Stop using the coach?".tr),
                    content: Text("You can also delete all your conversations.".tr),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: Text("Cancel".tr)),
                      TextButton(onPressed: () => Navigator.pop(d, 'keep'), child: Text("Stop".tr)),
                      TextButton(onPressed: () => Navigator.pop(d, 'delete'), child: Text("Stop and delete".tr)),
                    ],
                  ),
                );
                if (choice != null) await FinanceUi.run(() => FinanceIntelService.withdrawConsent(deleteHistory: choice == 'delete'));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "Financial coach".tr,
      maxContentWidth: DsLayout.contentMax,
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
          if (snap.hasError) return DsErrorState(message: "Could not load your conversations.".tr);
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3));
          if (snap.data!.isEmpty) {
            return DsEmptyState(
              icon: Icons.support_agent_rounded,
              title: "Ask your first question".tr,
              message: "For example: how to build a monthly budget, how much to save for a goal, or how a tontine works.".tr,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            children: [
              DsTileGroup(children: [
                for (final s in snap.data!)
                  DsListTile(
                    leadingIcon: Icons.chat_bubble_outline_rounded,
                    leadingTone: DsTone.brand,
                    title: (s['title'] ?? '').toString().isEmpty ? CoachRules.topic(s['topic']?.toString() ?? 'general').tr : s['title'].toString(),
                    subtitle: FinanceUi.date(s['updatedAt']),
                    showChevron: true,
                    onTap: () => Get.to(() => CoachChatScreen(config: config, sessionId: s['id'].toString(), topic: s['topic']?.toString())),
                  ),
              ]),
            ],
          );
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
    final c = DsColors.of(context);
    return DsScaffold(
      title: "Financial coach".tr,
      maxContentWidth: DsLayout.contentMax,
      actions: [
        if (_sessionId != null)
          DsIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: "Delete this conversation".tr,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text("Delete this conversation?".tr),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: Text("Keep it".tr)),
                    TextButton(onPressed: () => Navigator.pop(d, true), child: Text("Delete".tr)),
                  ],
                ),
              );
              if (ok == true && await FinanceUi.run(() => FinanceIntelService.deleteSession(_sessionId!))) Get.back();
            },
          ),
      ],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: c.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
            child: Text("General guidance, not financial advice. The coach can be wrong and never moves money.".tr,
                style: DsTypography.caption.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          ),
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
                        padding: const EdgeInsets.all(DsSpace.lg),
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

  Widget _starterView(BuildContext context) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(DsSpace.lg),
      children: [
        if (_pending != null) ...[
          _Bubble(message: {'role': 'user', 'text': _pending}, sessionId: ''),
          const _Typing(),
        ] else ...[
          Text("What would you like to talk about?".tr, style: DsTypography.titleSm),
          const DsGap(DsSpace.sm),
          Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
            for (final t in widget.config.topics) ChoiceChip(label: Text(CoachRules.topic(t).tr), selected: _topic == t, onSelected: (_) => setState(() => _topic = t)),
          ]),
          const DsGap(DsSpace.lg),
          for (final s in _starters[_topic] ?? const <String>[])
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: DsCard.outlined(
                onTap: () => _send(s.tr),
                child: Row(children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text(s.tr, style: DsTypography.body)),
                ]),
              ),
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
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.sm, DsSpace.sm),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: widget.config.maxMessageLength,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: "Ask a question".tr, border: InputBorder.none, counterText: ''),
            ),
          ),
          DsIconButton(
            icon: Icons.send_rounded,
            semanticLabel: "Send".tr,
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
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.only(bottom: DsSpace.sm),
          padding: const EdgeInsets.all(DsSpace.md),
          decoration: BoxDecoration(
            color: mine ? c.brand : (failed ? c.dangerSoft : c.surfaceAlt),
            borderRadius: BorderRadius.circular(DsRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                failed ? "The coach could not answer. Please try again.".tr : (m['text']?.toString() ?? ''),
                style: DsTypography.body.copyWith(color: mine ? c.onBrand : c.textPrimary),
              ),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.xs),
                  child: DsButton.secondary(label: a.label, icon: Icons.open_in_new_rounded, size: DsButtonSize.sm, onPressed: () => _openTarget(a.target)),
                ),
              if (!mine && !failed && widget.sessionId.isNotEmpty && m['id'] != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (at != null) Text(DateFormat('HH:mm').format(at), style: DsTypography.caption.copyWith(color: c.textMuted)),
                  const DsGap(DsSpace.sm),
                  for (final helpful in [true, false])
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: (helpful ? "Helpful" : "Not helpful").tr,
                      icon: Icon(
                        helpful ? (_rated == true ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined) : (_rated == false ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
                        size: 16,
                        color: c.textSecondary,
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
        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(DsRadius.lg)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary)),
          const DsGap(DsSpace.sm),
          Text("The coach is thinking...".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}
