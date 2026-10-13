import 'dart:async';

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_card_service.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_card_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sheets open in their own route, outside [FinScaffold]: pin the finance accent there too.
Widget _finAccent(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

/// Padding of a form section: fields carry their own bottom spacing.
const EdgeInsets _form = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs);

/// "2 %", "1.5 %": no trailing ".0", left-to-right inside Arabic text.
String _percent(double v) => ltr('${v == v.roundToDouble() ? v.round() : v} %');

/// The card as a card: masked number, expiry, holder and network. Never the full number.
class CardFace extends StatelessWidget {
  final VirtualCard card;

  const CardFace({super.key, required this.card});

  /// A card that cannot pay (being created, frozen, ended) is greyed.
  static const Color _greyLight = Color(0xFF6B7585);
  static const Color _greyDark = Color(0xFF2C3544);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool dim = card.status != 'active';
    const white = Colors.white;
    final muted = white.withValues(alpha: 0.72);
    return Semantics(
      label: '${"Virtual card".tr} ${card.label} ${"ending in".tr} ${card.last4}, ${CardLabels.status(card.status).tr}',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Container(
            decoration: BoxDecoration(
              color: dim ? (c.isDark ? _greyDark : _greyLight) : FinColors.hero(context),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: white.withValues(alpha: c.isDark ? 0.10 : 0.06)),
            ),
            padding: const EdgeInsets.all(DsSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(card.label.isEmpty ? "Virtual card".tr : card.label,
                        style: DsTypography.titleSm.copyWith(color: white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (dim)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xxs),
                      decoration: BoxDecoration(color: white.withValues(alpha: 0.16), borderRadius: DsRadius.brPill),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          switch (card.status) {
                            'frozen' => Icons.ac_unit_rounded,
                            'requested' => Icons.hourglass_top_rounded,
                            _ => Icons.block_rounded,
                          },
                          color: white,
                          size: 14,
                        ),
                        const DsGap(DsSpace.xs),
                        Text(CardLabels.status(card.status).tr, style: DsTypography.labelSm.copyWith(color: white)),
                      ]),
                    ),
                ]),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  // The groups keep their order inside Arabic text.
                  child: Text(card.masked, textDirection: TextDirection.ltr, style: DsTypography.headline.copyWith(color: white, letterSpacing: 2).tabular),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(card.cardholderName.toUpperCase(), style: DsTypography.label.copyWith(color: white, letterSpacing: 0.6), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const DsGap(DsSpace.xxs),
                        Text('${"Valid thru".tr} ${ltr(card.expiry)}', style: DsTypography.caption.copyWith(color: muted).tabular),
                      ]),
                    ),
                    const DsGap(DsSpace.md),
                    Text(card.network.toUpperCase(), style: DsTypography.title.copyWith(color: white, fontStyle: FontStyle.italic, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spideli Finance > Virtual cards. `platform_settings/cards` must exist (admin).
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardConfig?>(
      future: FinanceCardService.config(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        if (cfgSnap.connectionState == ConnectionState.waiting || cfg == null) {
          return FinScaffold(
            title: "Virtual cards".tr,
            body: FinBody(children: [
              cfg == null && cfgSnap.connectionState != ConnectionState.waiting
                  ? FinState.empty(Icons.credit_card_outlined, "Virtual cards are not available yet.".tr)
                  : FinState.loading(rows: 2),
            ]),
          );
        }
        return StreamBuilder<List<VirtualCard>>(
          stream: FinanceCardService.cards(),
          builder: (context, snap) {
            final cards = snap.data ?? const <VirtualCard>[];
            final bool canCreate = snap.hasData && CardActions.canCreate(cards, cfg);
            return FinScaffold(
              title: "Virtual cards".tr,
              bottomBar: !canCreate
                  ? null
                  : DsStickyBar(
                      child: DsButton.primary(
                        label: "Get a virtual card".tr,
                        icon: Icons.add_card_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () => Get.to(() => CardCreateScreen(config: cfg)),
                      ),
                    ),
              body: FinBody(
                children: [
                  if (snap.hasError)
                    FinState.error("Could not load your cards.".tr)
                  else if (!snap.hasData)
                    FinState.loading(rows: 2)
                  else if (cards.isEmpty)
                    FinState.empty(
                      Icons.credit_card_outlined,
                      "You have no virtual card yet.".tr,
                      message: "Pay online and abroad with a virtual Visa card you top up from your wallet or Mobile Money.".tr,
                    )
                  else ...[
                    for (final (i, c) in cards.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : FinSpace.section),
                        child: _CardSummary(card: c, onTap: () => Get.to(() => CardScreen(cardId: c.id, config: cfg))),
                      ),
                    if (!canCreate) FinNotice('${"You have reached the maximum number of cards".tr} (${cfg.maxCardsPerUser}).', tone: DsTone.neutral),
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

/// A card of the list: its face (tap for the card page), its balance and status.
class _CardSummary extends StatelessWidget {
  final VirtualCard card;
  final VoidCallback onTap;

  const _CardSummary({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          child: Stack(children: [
            CardFace(card: card),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(borderRadius: const BorderRadius.all(Radius.circular(16)), onTap: onTap),
              ),
            ),
          ]),
        ),
        const DsGap(DsSpace.md),
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxs),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Balance".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(FinanceMoney.format(card.balance, card.currency), style: DsTypography.titleSm.copyWith(color: c.textPrimary).tabular),
                  ),
                ]),
              ),
              const DsGap(DsSpace.sm),
              FinStatusChip(status: card.status, label: CardLabels.status(card.status).tr, icon: true),
            ]),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- create

class CardCreateScreen extends StatefulWidget {
  final CardConfig config;

  const CardCreateScreen({super.key, required this.config});

  @override
  State<CardCreateScreen> createState() => _CardCreateScreenState();
}

class _CardCreateScreenState extends State<CardCreateScreen> {
  final _label = TextEditingController();
  late String _currency = widget.config.currencies.first;
  bool _accepted = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final cfg = widget.config;
    final int fee = cfg.feeFor(cfg.issuanceFee, _currency);
    final key = FinanceGroupService.newRequestKey();
    bool sent = false;
    Future<Map<String, dynamic>> submit(Map<String, dynamic>? payment) async {
      final r = await FinanceCardService.create(label: _label.text.trim(), currency: _currency, termsVersion: cfg.termsVersion, payment: payment, requestKey: key);
      sent = true;
      return r;
    }

    if (fee > 0) {
      await FinancePaySheet.show(context, title: "Card creation fee".tr, amount: fee, currency: _currency, methods: cfg.fundingMethods, submit: submit);
    } else {
      await FinanceUi.run(() => submit(null), success: "Your card is being created.");
    }
    if (sent && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final c = DsColors.of(context);
    String fee(Map<String, int> fees) => cfg.feeFor(fees, _currency) == 0 ? "Free".tr : FinanceMoney.format(cfg.feeFor(fees, _currency), _currency);
    Widget can(bool yes, String text) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(yes ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded, size: 18, color: yes ? c.successStrong : c.textMuted),
              const DsGap(DsSpace.md),
              Expanded(child: Text(text.tr, style: DsTypography.body.copyWith(color: yes ? c.textPrimary : c.textSecondary))),
            ]),
          ),
        );
    return FinScaffold(
      title: "Get a virtual card".tr,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(
            label: cfg.feeFor(cfg.issuanceFee, _currency) > 0 ? "${"Create my card".tr} · ${fee(cfg.issuanceFee)}" : "Create my card".tr,
            icon: Icons.add_card_rounded,
            size: DsButtonSize.lg,
            expand: true,
            onPressed: verified && _accepted ? _create : null,
          ),
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            title: "Your card".tr,
            top: 0,
            padding: _form,
            footnote: "The card is issued in the name on your verified identity.".tr,
            children: [
              DsTextField(label: "Card name (optional)".tr, hint: "Online shopping".tr, controller: _label, maxLength: 24),
              if (cfg.currencies.length > 1)
                DsDropdown<String>(
                  label: "Currency".tr,
                  value: _currency,
                  items: [for (final cur in cfg.currencies) DropdownMenuItem(value: cur, child: Text(cur))],
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
            ],
          ),
          FinSection(
            title: "Fees and limits".tr,
            children: [
              if (cfg.issuerName.isNotEmpty) FinRow("Issuer".tr, cfg.issuerName),
              FinRow("Creation fee".tr, fee(cfg.issuanceFee)),
              FinRow("Monthly fee".tr, fee(cfg.monthlyFee)),
              FinRow("Top-up fee".tr, cfg.fundingFeePercent == 0 ? "Free".tr : _percent(cfg.fundingFeePercent)),
              if (cfg.minFunding[_currency] != null) FinRow("Minimum top-up".tr, FinanceMoney.format(cfg.minFunding[_currency]!, _currency)),
              if (cfg.maxFunding[_currency] != null) FinRow("Maximum top-up".tr, FinanceMoney.format(cfg.maxFunding[_currency]!, _currency)),
              if (cfg.maxPerTransaction[_currency] != null) FinRow("Maximum per payment".tr, FinanceMoney.format(cfg.maxPerTransaction[_currency]!, _currency)),
            ],
          ),
          FinSection(
            title: "What you can do".tr,
            children: [
              can(true, "Top up from your wallet or Mobile Money"),
              can(true, "Freeze and unfreeze the card at any time"),
              can(true, "Set your own spending limits"),
              can(cfg.secureDetails != SecureDetailsMode.none, "See the full card number and security code"),
              can(cfg.canWithdraw, "Move the card balance back to your wallet"),
              can(cfg.canRenew, "Renew the card before it expires"),
            ],
          ),
          FinSection(
            title: "Card terms".tr,
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
            children: [
              Text('${"Version".tr} ${ltr('${cfg.termsVersion}')}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.sm),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(color: c.isDark ? c.surfaceAlt : FinColors.page(context), borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(DsSpace.md),
                    child: Text(cfg.terms, style: DsTypography.bodySm.copyWith(color: c.textPrimary)),
                  ),
                ),
              ),
              const DsGap(DsSpace.xs),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read the card terms and the fees, and I accept them.".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- card

/// One card: balance, top-ups, freeze, details, limits, renewal, history.
class CardScreen extends StatelessWidget {
  final String cardId;
  final CardConfig config;

  const CardScreen({super.key, required this.cardId, required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VirtualCard?>(
      stream: FinanceCardService.card(cardId),
      builder: (context, snap) {
        final c = snap.data;
        return FinScaffold(
          title: c == null || c.label.isEmpty ? "Virtual card".tr : c.label,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this card.".tr)])
              : c == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
                  : _CardBody(card: c, config: config),
        );
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  final VirtualCard card;
  final CardConfig config;

  const _CardBody({required this.card, required this.config});

  Future<void> _fund(BuildContext context) async {
    final c = card;
    final int? max = config.maxFunding[c.currency];
    final int min = config.minFunding[c.currency] ?? 1;
    final amount = await askAmount(context, title: "Top up the card".tr, currency: c.currency, max: max, hint: '${"Minimum".tr} ${FinanceMoney.format(min, c.currency)}');
    if (amount == null || !context.mounted) return;
    if (amount < min) return ShowToastDialog.showToast('${"Minimum".tr}: ${FinanceMoney.format(min, c.currency)}');
    final q = FundingQuote.of(amount, config.fundingFeePercent);
    if (q.fee > 0) {
      final ok = await finConfirm(
        title: "Top up the card".tr,
        lines: [
          ("The card receives".tr, FinanceMoney.format(q.amount, c.currency)),
          ("Top-up fee".tr, FinanceMoney.format(q.fee, c.currency)),
        ],
        total: ("You pay".tr, FinanceMoney.format(q.total, c.currency)),
        confirmLabel: "Continue".tr,
      );
      if (!ok || !context.mounted) return;
    }
    final key = FinanceGroupService.newRequestKey();
    await FinancePaySheet.show(context, title: "Top up the card".tr, amount: q.total, currency: c.currency, methods: config.fundingMethods, submit: (p) => FinanceCardService.fund(c.id, amount, p, key));
  }

  Future<void> _withdraw(BuildContext context) async {
    final c = card;
    final amount = await askAmount(context, title: "Move to my wallet".tr, currency: c.currency, max: c.balance);
    if (amount == null || !context.mounted || !await FinanceReauth.confirm() || !context.mounted) return;
    final key = FinanceGroupService.newRequestKey();
    await FinancePaySheet.show(
      context,
      title: "Move to my wallet".tr,
      amount: amount,
      currency: c.currency,
      methods: config.fundingMethods,
      payout: true,
      submit: (d) => FinanceCardService.withdraw(c.id, amount, d, key),
    );
  }

  Future<void> _details(BuildContext context) async {
    if (!await FinanceReauth.confirm()) return;
    if (config.secureDetails == SecureDetailsMode.hosted) {
      ShowToastDialog.showLoader("Please wait...".tr);
      try {
        final uri = await FinanceCardService.secureDetailsLink(card.id);
        ShowToastDialog.closeLoader();
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } on FinanceException catch (e) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast(FinanceErrors.messageKey(e.reason).tr);
      } catch (_) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
      }
      return;
    }
    Map<String, dynamic>? details;
    final ok = await FinanceUi.run(() async => details = await FinanceCardService.revealDetails(card.id));
    if (!ok || details == null || !context.mounted) return;
    await finSheet(title: "Card details".tr, child: _finAccent(_SecretDetails(details: details!, card: card)));
  }

  Future<void> _renew(BuildContext context) async {
    final c = card;
    final int fee = config.feeFor(config.renewalFee, c.currency);
    final key = FinanceGroupService.newRequestKey();
    if (fee > 0) {
      await FinancePaySheet.show(context, title: "Renew the card".tr, amount: fee, currency: c.currency, methods: config.fundingMethods, submit: (p) => FinanceCardService.renew(c.id, p, key));
    } else {
      await FinanceUi.run(() => FinanceCardService.renew(c.id, null, key), success: "Renewal requested");
    }
  }

  Future<void> _terminate() async {
    final c = card;
    final ok = await finConfirm(
      title: "Delete this card?".tr,
      message: "The card stops working for good. Subscriptions paid with it will fail.".tr,
      lines: [if (c.balance > 0) ("Its balance is returned to your wallet".tr, FinanceMoney.format(c.balance, c.currency))],
      confirmLabel: "Delete".tr,
      destructive: true,
    );
    if (!ok || !await FinanceReauth.confirm()) return;
    if (await FinanceUi.run(() => FinanceCardService.terminate(c.id), success: "Card deleted")) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = card;
    final cfg = config;
    final colors = DsColors.of(context);
    final bool renew = CardActions.canRenew(c, cfg, DateTime.now());
    final bool anyAction = CardActions.canFund(c) ||
        CardActions.canRevealDetails(c, cfg) ||
        CardActions.canFreeze(c) ||
        CardActions.canUnfreeze(c) ||
        CardActions.canSetLimits(c) ||
        CardActions.canWithdraw(c, cfg);
    return FinBody(
      children: [
        CardFace(card: c),
        const DsGap(DsSpace.lg),
        FinSurface(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MergeSemantics(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Balance".tr, style: DsTypography.caption.copyWith(color: colors.textSecondary)),
                      const DsGap(DsSpace.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(FinanceMoney.format(c.balance, c.currency), style: FinText.amount.copyWith(color: colors.textPrimary)),
                      ),
                    ]),
                  ),
                  const DsGap(DsSpace.sm),
                  FinStatusChip(status: c.status, label: CardLabels.status(c.status).tr, icon: true),
                ]),
              ),
              if (anyAction) ...[
                const DsGap(DsSpace.lg),
                FinanceKycGate(
                  builder: (context, verified) => FinActions(actions: [
                    if (CardActions.canFund(c)) FinAction(Icons.add_rounded, "Top up".tr, verified ? () => _fund(context) : null),
                    if (CardActions.canRevealDetails(c, cfg)) FinAction(Icons.visibility_outlined, "Show details".tr, () => _details(context)),
                    if (CardActions.canFreeze(c))
                      FinAction(Icons.ac_unit_rounded, "Freeze".tr, () => FinanceUi.run(() => FinanceCardService.freeze(c.id), success: "Card frozen")),
                    if (CardActions.canUnfreeze(c))
                      FinAction(Icons.lock_open_rounded, "Unfreeze".tr, () async {
                        if (await FinanceReauth.confirm()) await FinanceUi.run(() => FinanceCardService.unfreeze(c.id), success: "Card unfrozen");
                      }),
                    if (CardActions.canSetLimits(c)) FinAction(Icons.tune_rounded, "Limits".tr, () => Get.to(() => CardLimitsScreen(card: c, config: cfg))),
                    if (CardActions.canWithdraw(c, cfg)) FinAction(Icons.south_west_rounded, "Move to my wallet".tr, verified ? () => _withdraw(context) : null),
                  ]),
                ),
              ],
            ],
          ),
        ),
        if (c.status == 'requested') FinNotice("The issuer is creating your card. This page updates when it is ready.".tr, tone: DsTone.info),
        if (c.status == 'frozen' && c.frozenBy != 'user') FinNotice("This card was frozen for your security. Contact support to unfreeze it.".tr, tone: DsTone.warning),
        if (c.reason.isNotEmpty) FinNotice(c.reason, title: "Reason".tr, tone: FinStatus.tone(c.status)),
        if (renew)
          FinNotice(
            cfg.feeFor(cfg.renewalFee, c.currency) > 0
                ? '${"Renewal fee".tr}: ${FinanceMoney.format(cfg.feeFor(cfg.renewalFee, c.currency), c.currency)}'
                : "Renew it to keep paying with a new card.".tr,
            title: (c.status == 'expired' ? "This card has expired" : "This card expires soon").tr,
            tone: DsTone.warning,
            actionLabel: "Renew".tr,
            onAction: () => _renew(context),
          ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceCardService.fundingRequests(c.id),
          builder: (context, snap) {
            final pending = (snap.data ?? const []).where((r) => r['status'] == 'pending' || r['status'] == 'processing').toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "In progress".tr,
              divided: true,
              children: [
                for (final r in pending)
                  FinListTile(
                    icon: r['type'] == 'withdraw' ? Icons.south_west_rounded : Icons.north_east_rounded,
                    iconTone: DsTone.info,
                    title: (r['type'] == 'withdraw' ? "Withdrawal" : "Top-up").tr,
                    subtitle: FinanceUi.date(r['createdAt']),
                    amount: FinanceMoney.format(FinanceSummary.intOf(r['amount']), c.currency),
                    status: r['status']?.toString(),
                    statusLabel: (r['status'] == 'processing' ? "Processing" : "Pending").tr,
                  ),
              ],
            );
          },
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceCardService.transactions(c.id),
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the card transactions.".tr);
            if (!snap.hasData) return FinState.loading();
            final list = snap.data!;
            if (list.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "No transaction yet.".tr);
            return FinSection(
              title: "Transactions".tr,
              divided: true,
              children: [for (final t in list) _TransactionTile(t: t, currency: c.currency)],
            );
          },
        ),
        if (CardActions.canTerminate(c))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(label: "Delete this card".tr, icon: Icons.delete_outline_rounded, color: colors.dangerStrong, expand: true, onPressed: _terminate),
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> t;
  final String currency;

  const _TransactionTile({required this.t, required this.currency});

  @override
  Widget build(BuildContext context) {
    final String type = t['type']?.toString() ?? '';
    final String status = t['status']?.toString() ?? '';
    final bool credit = CardLabels.credit(type);
    final int amount = FinanceSummary.intOf(t['amount']);
    final int signed = credit ? amount : -amount;
    final bool noMove = status == 'declined' || status == 'reversed';
    final String? original = t['originalCurrency'] != null && t['originalCurrency'] != currency
        ? FinanceMoney.format(FinanceSummary.intOf(t['originalAmount']), t['originalCurrency'].toString())
        : null;
    return FinListTile(
      icon: credit ? Icons.south_west_rounded : Icons.shopping_bag_outlined,
      iconTone: status == 'declined' ? DsTone.danger : (credit ? DsTone.success : DsTone.neutral),
      title: (t['merchantName'] ?? '').toString().isNotEmpty ? t['merchantName'].toString() : CardLabels.transaction(type).tr,
      subtitle: [
        FinanceUi.date(t['createdAt']),
        ?original,
        if ((t['declineReason'] ?? '').toString().isNotEmpty) t['declineReason'].toString(),
      ].join(' · '),
      amount: FinanceMoney.signed(signed, currency),
      // Money in green, money out in the default color; a declined or
      // reversed line did not move money and reads muted.
      amountColor: noMove ? DsColors.of(context).textMuted : finAmountColor(context, signed),
      status: status == 'completed' ? null : status,
      statusLabel: status == 'completed' ? null : CardLabels.transactionStatus(status).tr,
    );
  }
}

/// Full card details from the server relay: screenshots blocked, hidden
/// after a minute or when the app goes to the background, never stored.
class _SecretDetails extends StatefulWidget {
  final Map<String, dynamic> details;
  final VirtualCard card;

  const _SecretDetails({required this.details, required this.card});

  @override
  State<_SecretDetails> createState() => _SecretDetailsState();
}

class _SecretDetailsState extends State<_SecretDetails> with WidgetsBindingObserver {
  static const int _seconds = 60;
  int _left = _seconds;
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    FinanceSecureScreen.enable();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) return _close();
      setState(() => _left--);
    });
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FinanceSecureScreen.disable();
    super.dispose();
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    ShowToastDialog.showToast("Card number copied. It is cleared from the clipboard in one minute.".tr);
    // Clear it later unless the user copied something else since.
    Timer(const Duration(seconds: 60), () async {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == number) await Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final c = DsColors.of(context);
    final String number = (d['number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final int month = FinanceSummary.intOf(d['expiryMonth']);
    final int year = FinanceSummary.intOf(d['expiryYear']);
    Widget field(String label, String value, {Widget? trailing}) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                  const DsGap(DsSpace.xxs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    // Digit groups keep their order inside Arabic text.
                    child: Text(value, textDirection: TextDirection.ltr, style: DsTypography.title.copyWith(color: c.textPrimary, letterSpacing: 1.5).tabular),
                  ),
                ]),
              ),
              ?trailing,
            ]),
          ),
        );
    Widget divider() => Divider(height: 1, thickness: 1, color: c.divider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSurface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            field("Card number".tr, groupCardNumber(number),
                trailing: number.isEmpty ? null : DsIconButton(icon: Icons.copy_rounded, semanticLabel: "Copy the card number".tr, onPressed: () => _copyNumber(number))),
            divider(),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: field("Valid thru".tr, '${month.toString().padLeft(2, '0')}/${(year % 100).toString().padLeft(2, '0')}')),
                VerticalDivider(width: DsSpace.xxl, thickness: 1, color: c.divider),
                Expanded(child: field("Security code".tr, (d['cvv'] ?? '').toString())),
              ]),
            ),
            if ((d['cardholderName'] ?? '').toString().isNotEmpty) ...[
              divider(),
              field("Name on the card".tr, d['cardholderName'].toString().toUpperCase()),
            ],
          ]),
        ),
        const DsGap(DsSpace.lg),
        FinProgress(value: _left / _seconds, label: "Hidden in".tr, trailing: '$_left s', tone: DsTone.warning),
        FinNotice("Never share these details. Spideli will never ask you for them.".tr, tone: DsTone.warning),
        const DsGap(DsSpace.lg),
        DsButton.primary(label: "Hide".tr, expand: true, onPressed: _close),
      ],
    );
  }
}

// ------------------------------------------------------------------- limits

class CardLimitsScreen extends StatefulWidget {
  final VirtualCard card;
  final CardConfig config;

  const CardLimitsScreen({super.key, required this.card, required this.config});

  @override
  State<CardLimitsScreen> createState() => _CardLimitsScreenState();
}

class _CardLimitsScreenState extends State<CardLimitsScreen> {
  final _tx = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  bool? _online;
  bool? _international;
  bool _loaded = false;

  @override
  void dispose() {
    _tx.dispose();
    _day.dispose();
    _month.dispose();
    super.dispose();
  }

  String get _cur => widget.card.currency;

  /// Empty = the issuer's maximum; -1 = not a valid amount.
  int? _value(TextEditingController c) => c.text.trim().isEmpty ? null : (FinanceAmount.parse(c.text, _cur) ?? -1);

  CardLimits get _limits => CardLimits(perTransaction: _value(_tx), daily: _value(_day), monthly: _value(_month));

  void _load(Map<String, dynamic>? l) {
    if (_loaded) return;
    _loaded = true;
    String text(dynamic v) => v is num && v > 0 ? '${v.round()}' : '';
    if (FinanceMoney.exponent(_cur) == 0) {
      _tx.text = text(l?['perTransaction']);
      _day.text = text(l?['daily']);
      _month.text = text(l?['monthly']);
    }
    _online = l?['allowOnline'] is bool ? l!['allowOnline'] as bool : true;
    _international = l?['allowInternational'] is bool ? l!['allowInternational'] as bool : true;
  }

  Future<void> _save() async {
    final problem = _limits.problem(widget.config, _cur);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    if (!await FinanceReauth.confirm()) return;
    final ok = await FinanceUi.run(
      () => FinanceCardService.setLimits(
        widget.card.id,
        _limits,
        allowOnline: widget.config.canToggleOnline ? _online : null,
        allowInternational: widget.config.canToggleInternational ? _international : null,
      ),
      success: "Limits sent to the issuer",
    );
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    String max(Map<String, int> m) => m[_cur] == null ? '' : '${"Maximum".tr}: ${FinanceMoney.format(m[_cur]!, _cur)}';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceCardService.limits(widget.card.id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.waiting) _load(snap.data);
        final String? problem = _limits.problem(cfg, _cur);
        final c = DsColors.of(context);
        return FinScaffold(
          title: "Card limits".tr,
          subtitle: widget.card.label.isEmpty ? null : widget.card.label,
          bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: problem == null && _loaded ? _save : null)),
          body: !_loaded
              ? const Padding(padding: FinSpace.pagePadding, child: DsSkeletonForm(fields: 3))
              : FinBody(
                  children: [
                    if (snap.data?['status'] == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.lg),
                        child: DsInlineAlert(tone: DsTone.info, message: "Your last change is waiting for the issuer.".tr),
                      ),
                    FinSection(
                      title: "Spending limits".tr,
                      top: 0,
                      padding: _form,
                      footnote: "Leave a field empty to use the maximum allowed.".tr,
                      children: [
                        for (final (label, ctrl, m) in [
                          ("Per payment", _tx, cfg.maxPerTransaction),
                          ("Per day", _day, cfg.maxDaily),
                          ("Per month", _month, cfg.maxMonthly),
                        ])
                          DsTextField(
                            label: '${label.tr} ($_cur)',
                            helper: max(m).isEmpty ? null : max(m),
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        if (problem != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: DsInlineAlert(tone: DsTone.danger, message: problem.tr),
                          ),
                      ],
                    ),
                    if (cfg.canToggleOnline || cfg.canToggleInternational)
                      FinSection(
                        title: "Where the card works".tr,
                        divided: true,
                        children: [
                          if (cfg.canToggleOnline)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _online ?? true,
                              secondary: Icon(Icons.language_rounded, color: c.textSecondary),
                              title: Text("Online payments".tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                              onChanged: (v) => setState(() => _online = v),
                            ),
                          if (cfg.canToggleInternational)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _international ?? true,
                              secondary: Icon(Icons.flight_takeoff_rounded, color: c.textSecondary),
                              title: Text("Payments abroad".tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                              onChanged: (v) => setState(() => _international = v),
                            ),
                        ],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
