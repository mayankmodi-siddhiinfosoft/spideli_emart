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
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

/// Padding of a form section: fields carry their own bottom spacing (as
/// the transfer and bill forms).
const EdgeInsets _form = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0);

/// "2 %", "1.5 %": no trailing ".0", left-to-right inside Arabic text.
String _percent(double v) => ltr('${v == v.roundToDouble() ? v.round() : v} %');

/// The card as a card: masked number, expiry, holder and network. Never the full number.
class CardFace extends StatelessWidget {
  final VirtualCard card;

  const CardFace({super.key, required this.card});

  /// A card that cannot pay (being created, frozen, ended) is greyed: dark
  /// enough for white text, and its status badge, at 4.5:1 or more.
  static const Color _greyLight = Color(0xFF4A5363);
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
                        // Full white on a greyed card: the muted tone would fall under 4.5:1.
                        Text('${"Valid thru".tr} ${ltr(card.expiry)}', style: DsTypography.caption.copyWith(color: dim ? white : muted).tabular),
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
    return FinConfig<CardConfig>(
      load: FinanceCardService.config,
      builder: (context, st) {
        final cfg = st.config;
        final placeholder = st.placeholder(Icons.credit_card_outlined, "Virtual cards are not available yet.".tr);
        if (placeholder != null || cfg == null) {
          return FinScaffold(title: "Virtual card".tr, body: FinBody(children: [placeholder ?? FinState.loading(rows: 2)]));
        }
        return StreamBuilder<List<VirtualCard>>(
          stream: FinanceCardService.cards(),
          builder: (context, snap) {
            final cards = snap.data ?? const <VirtualCard>[];
            final bool canCreate = snap.hasData && CardActions.canCreate(cards, cfg);
            return FinScaffold(
              title: "Virtual card".tr,
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
    final String label = _label.text.trim();
    bool sent = false;
    // One request per card asked for (currency, terms, name), whatever pays
    // the fee: a retry reuses its id until it is written, so it can never
    // ask for (or pay for) a second card.
    Future<Map<String, dynamic>> submit(FinanceFunding funding) async {
      final r = await FinanceRequestKeys.send(
        'card.create',
        '$_currency:${cfg.termsVersion}:$label',
        fee,
        const {},
        (key) => FinanceCardService.create(label: label, currency: _currency, termsVersion: cfg.termsVersion, funding: funding, requestKey: key),
      );
      sent = true;
      return r;
    }

    if (fee > 0) {
      await FinancePaySheet.show(context, title: "Card creation fee".tr, amount: fee, currency: _currency, methods: cfg.fundingMethods, submit: submit);
    } else {
      await FinanceUi.run(() => submit(const FinanceFunding.wallet()), success: "Your card is being created.");
    }
    if (sent && mounted) Get.back();
  }

  /// The card terms in a sheet: read in full, without a box scrolling
  /// inside the page.
  void _readTerms() {
    final cfg = widget.config;
    finSheet(
      title: "Card terms".tr,
      subtitle: '${"Version".tr} ${ltr('${cfg.termsVersion}')}',
      child: Builder(builder: (context) => Text(cfg.terms, style: DsTypography.body.copyWith(color: DsColors.of(context).textPrimary))),
    );
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
          builder: (context, verified) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinMissing([if (!_accepted) "Accept the card terms".tr]),
              DsButton.primary(
                label: cfg.feeFor(cfg.issuanceFee, _currency) > 0 ? "${"Create my card".tr} · ${fee(cfg.issuanceFee)}" : "Create my card".tr,
                icon: Icons.add_card_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: verified && _accepted ? _create : null,
              ),
            ],
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
              can(cfg.canTransfer, "Send money to another Spideli card"),
              can(cfg.canRenew, "Renew the card before it expires"),
            ],
          ),
          FinSection(
            title: "Card terms".tr,
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
            children: [
              Text('${"Version".tr} ${ltr('${cfg.termsVersion}')}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
              // The terms open in a sheet; no empty box when there are none.
              if (cfg.terms.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(label: "Read the terms".tr, icon: Icons.description_outlined, size: DsButtonSize.sm, onPressed: _readTerms),
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
class CardScreen extends StatefulWidget {
  final String cardId;
  final CardConfig config;

  const CardScreen({super.key, required this.cardId, required this.config});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  late Stream<VirtualCard?> _stream = FinanceCardService.card(widget.cardId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VirtualCard?>(
      stream: _stream,
      builder: (context, snap) {
        final c = snap.data;
        final state = FinState.of(
          snap,
          gone: "This card is no longer available.",
          onRetry: () => setState(() => _stream = FinanceCardService.card(widget.cardId)),
        );
        return FinScaffold(
          title: c == null || c.label.isEmpty ? "Virtual card".tr : c.label,
          body: state != null ? FinBody(children: [state]) : _CardBody(card: c!, config: widget.config),
        );
      },
    );
  }
}

/// Asks for a top-up between [min] and [max]: a wrong amount is explained
/// in the sheet as it is typed, and the amount stays there to correct.
Future<int?> _askTopUp({required String currency, required int min, int? max}) {
  final ctrl = TextEditingController();
  return finSheet<int>(
    title: "Top up the card".tr,
    child: StatefulBuilder(
      builder: (context, setState) {
        final int? value = FinanceAmount.parse(ctrl.text, currency);
        final bool ok = value != null && FinanceAmount.problem(ctrl.text, currency, min: min, max: max) == null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinAmountField(label: "Amount".tr, controller: ctrl, currency: currency, min: min, max: max, onChanged: (_) => setState(() {})),
            DsButton.primary(label: "Continue".tr, expand: true, onPressed: ok ? () => Get.back(result: value) : null),
          ],
        );
      },
    ),
  );
}

/// Asks who receives a card-to-card transfer (the e-mail or phone number of
/// their Spideli account) and how much, up to the card balance [max].
Future<(String, int)?> _askTransfer({required String currency, required int max}) {
  final contact = TextEditingController();
  final amount = TextEditingController();
  return finSheet<(String, int)>(
    title: "Send to another card".tr,
    child: StatefulBuilder(
      builder: (context, setState) {
        final int? value = FinanceAmount.parse(amount.text, currency);
        final bool ok = CardRecipient.query(contact.text) != null && value != null && FinanceAmount.problem(amount.text, currency, max: max) == null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(
              label: "Recipient's e-mail or phone number".tr,
              helper: "The money goes to their Spideli card in the same currency.".tr,
              controller: contact,
              requiredMark: true,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            FinAmountField(label: "Amount".tr, controller: amount, currency: currency, max: max, onChanged: (_) => setState(() {})),
            DsButton.primary(label: "Continue".tr, expand: true, onPressed: ok ? () => Get.back(result: (contact.text.trim(), value)) : null),
          ],
        );
      },
    ),
  );
}

class _CardBody extends StatelessWidget {
  final VirtualCard card;
  final CardConfig config;

  const _CardBody({required this.card, required this.config});

  Future<void> _fund(BuildContext context) async {
    final c = card;
    final int? max = config.maxFunding[c.currency];
    final int min = config.minFunding[c.currency] ?? 1;
    final amount = await _askTopUp(currency: c.currency, min: min, max: max);
    if (amount == null || !context.mounted) return;
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
    // One request per top-up of this card and amount, whatever pays it: a
    // retry reuses its id until it is written, so it never loads twice.
    await FinancePaySheet.show(
      context,
      title: "Top up the card".tr,
      amount: q.total,
      currency: c.currency,
      methods: config.fundingMethods,
      submit: (FinanceFunding funding) => FinanceRequestKeys.send('card.fund', c.id, amount, const {}, (key) => FinanceCardService.fund(c.id, amount, funding, key)),
    );
  }

  /// The card balance back to the wallet: asked here, done by the issuer.
  Future<void> _withdraw(BuildContext context) async {
    final c = card;
    final amount = await askAmount(context, title: "Move to my wallet".tr, currency: c.currency, max: c.balance);
    if (amount == null || !context.mounted) return;
    final ok = await finConfirm(
      title: "Move to my wallet".tr,
      message: "The money is sent once your request is processed. You can follow it here.".tr,
      lines: [
        ("Amount".tr, FinanceMoney.format(amount, c.currency)),
        ("Receive the money on".tr, "Spideli Finance wallet".tr),
      ],
      confirmLabel: "Confirm".tr,
    );
    if (!ok || !await FinanceReauth.confirm()) return;
    await FinanceUi.run(
      () => FinanceRequestKeys.send('card.withdraw', c.id, amount, const {}, (key) => FinanceCardService.withdraw(c.id, amount, key)),
      success: "Withdrawal requested",
    );
  }

  /// Card to card: part of the balance to another Spideli user's card,
  /// found by the e-mail or phone number of their account.
  Future<void> _transfer(BuildContext context) async {
    final c = card;
    final asked = await _askTransfer(currency: c.currency, max: c.balance);
    if (asked == null || !context.mounted) return;
    final (String contact, int amount) = asked;
    ({String id, String name})? to;
    if (!await FinanceUi.run(() async => to = await FinanceCardService.findRecipient(contact)) || to == null) return;
    final recipient = to!;
    final ok = await finConfirm(
      title: "Send to another card".tr,
      message: "Spideli moves the money to the recipient's card. This page updates when it is done.".tr,
      lines: [
        ("Recipient".tr, recipient.name.isEmpty ? contact : '${recipient.name} · $contact'),
        ("From the card".tr, ltr(c.masked)),
        ("Amount".tr, FinanceMoney.format(amount, c.currency)),
      ],
      confirmLabel: "Send".tr,
    );
    if (!ok || !await FinanceReauth.confirm()) return;
    await FinanceUi.run(
      () => FinanceRequestKeys.send(
        'card.transfer',
        '${c.id}:${recipient.id}',
        amount,
        const {},
        (key) => FinanceCardService.transfer(c.id, amount, recipientId: recipient.id, recipientName: recipient.name, contact: contact, requestKey: key),
      ),
      success: "Transfer requested",
    );
  }

  Future<void> _details(BuildContext context) async {
    // The full number needs the issuer's secure page (or a certified relay),
    // which is not connected yet: say so rather than fail.
    if (!FinanceCardService.detailsAvailable) return ShowToastDialog.showToast("Showing the full card details is not available yet.".tr);
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
    await finSheet(title: "Card details".tr, child: _SecretDetails(details: details!, card: card));
  }

  Future<void> _renew(BuildContext context) async {
    final c = card;
    final int fee = config.feeFor(config.renewalFee, c.currency);
    if (fee > 0) {
      await FinancePaySheet.show(
        context,
        title: "Renew the card".tr,
        amount: fee,
        currency: c.currency,
        methods: config.fundingMethods,
        // Idempotent on the card: a renewal already asked for is not paid again.
        submit: (FinanceFunding funding) => FinanceCardService.renew(c.id, funding),
      );
      return;
    }
    // A free renewal has no payment step: confirm it here.
    final ok = await finConfirm(
      title: "Renew the card?".tr,
      message: "The issuer prepares the renewed card. This page updates when it is ready.".tr,
      lines: [("Renewal fee".tr, "Free".tr)],
      confirmLabel: "Renew".tr,
      cancelLabel: "Not now".tr,
    );
    if (!ok) return;
    await FinanceUi.run(() => FinanceCardService.renew(c.id, const FinanceFunding.wallet()), success: "Renewal requested");
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
        CardActions.canWithdraw(c, cfg) ||
        CardActions.canTransfer(c, cfg);
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
                // Short labels, three to a row on a phone: whole words in
                // every language and at large text sizes.
                FinanceKycGate(
                  builder: (context, verified) => FinActions(actions: [
                    if (CardActions.canFund(c)) FinAction(Icons.add_rounded, "Top up".tr, verified ? () => _fund(context) : null),
                    if (CardActions.canRevealDetails(c, cfg)) FinAction(Icons.visibility_outlined, "Details".tr, () => _details(context)),
                    if (CardActions.canFreeze(c))
                      FinAction(Icons.ac_unit_rounded, "Freeze".tr, () => FinanceUi.run(() => FinanceCardService.freeze(c.id), success: "Card frozen")),
                    if (CardActions.canUnfreeze(c))
                      FinAction(Icons.lock_open_rounded, "Unfreeze".tr, () async {
                        if (await FinanceReauth.confirm()) await FinanceUi.run(() => FinanceCardService.unfreeze(c.id), success: "Card unfrozen");
                      }),
                    if (CardActions.canSetLimits(c)) FinAction(Icons.tune_rounded, "Limits".tr, () => Get.to(() => CardLimitsScreen(card: c, config: cfg))),
                    if (CardActions.canWithdraw(c, cfg)) FinAction(Icons.south_west_rounded, "To wallet".tr, verified ? () => _withdraw(context) : null),
                    if (CardActions.canTransfer(c, cfg)) FinAction(Icons.swap_horiz_rounded, "To a card".tr, verified ? () => _transfer(context) : null),
                  ]),
                ),
              ],
            ],
          ),
        ),
        if (c.status == 'requested') FinNotice("The issuer is creating your card. This page updates when it is ready.".tr, tone: DsTone.info),
        if (c.status == 'termination_requested')
          FinNotice("Your card is being deleted. Any balance left on it is returned to your wallet.".tr, tone: DsTone.info),
        if (c.renewalRequested && c.replacedBy.isEmpty)
          FinNotice("Renewal requested. Your new card appears in your cards when the issuer has made it.".tr, tone: DsTone.info),
        if (c.status == 'frozen' && c.frozenBy != 'user') FinNotice("This card was frozen for your security. Contact support to unfreeze it.".tr, tone: DsTone.warning),
        if (c.reason.isNotEmpty) FinNotice(financeReasonText(c.reason).tr, title: "Reason".tr, tone: FinStatus.tone(c.status)),
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
        _CardActivity(card: c, onTopUp: CardActions.canFund(c) ? () => _fund(context) : null),
        if (CardActions.canTerminate(c))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(label: "Delete this card".tr, icon: Icons.delete_outline_rounded, color: colors.dangerStrong, expand: true, onPressed: _terminate),
          ),
      ],
    );
  }
}
/// Top-ups in progress, then the card's transactions grouped by day (as the
/// wallet). Read once per card, not again each time the card changes.
class _CardActivity extends StatefulWidget {
  final VirtualCard card;
  final VoidCallback? onTopUp;

  const _CardActivity({required this.card, required this.onTopUp});

  @override
  State<_CardActivity> createState() => _CardActivityState();
}

class _CardActivityState extends State<_CardActivity> {
  late final Stream<List<Map<String, dynamic>>> _requests = FinanceCardService.fundingRequests(widget.card.id);
  late Stream<List<Map<String, dynamic>>> _transactions = FinanceCardService.transactions(widget.card.id);

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return "Today".tr;
    if (day == today.subtract(const Duration(days: 1))) return "Yesterday".tr;
    return ltr(DateFormat('dd MMM yyyy').format(d));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requests,
          builder: (context, snap) {
            final pending = (snap.data ?? const []).where((r) => r['status'] == 'pending' || r['status'] == 'processing').toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "In progress".tr,
              divided: true,
              children: [
                for (final r in pending)
                  FinListTile(
                    icon: switch (r['type']) {
                      'withdraw' => Icons.south_west_rounded,
                      'transfer' => Icons.swap_horiz_rounded,
                      _ => Icons.north_east_rounded,
                    },
                    iconTone: DsTone.info,
                    title: CardLabels.request(r['type']?.toString()).tr,
                    subtitle: [
                      FinanceUi.date(r['createdAt']),
                      if (r['recipient'] is Map && '${(r['recipient'] as Map)['name'] ?? ''}'.isNotEmpty) '${(r['recipient'] as Map)['name']}',
                    ].join(' · '),
                    amount: FinanceMoney.format(FinanceSummary.intOf(r['amount']), c.currency),
                    status: r['status']?.toString(),
                    statusLabel: (r['status'] == 'processing' ? "Processing" : "Pending").tr,
                  ),
              ],
            );
          },
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _transactions,
          builder: (context, snap) {
            if (snap.hasError) {
              return FinState.error(
                "Could not load the card transactions.".tr,
                onRetry: () => setState(() => _transactions = FinanceCardService.transactions(c.id)),
              );
            }
            if (!snap.hasData) return FinState.loading();
            final list = snap.data!;
            if (list.isEmpty) {
              return _NoTransaction(onTopUp: widget.onTopUp);
            }
            // One section per day, newest first (the list is).
            final sections = <(String, List<Map<String, dynamic>>)>[];
            for (final t in list) {
              final d = FinanceGroupService.toDate(t['createdAt']);
              final String label = d == null ? '-' : _dayLabel(d);
              if (sections.isEmpty || sections.last.$1 != label) sections.add((label, []));
              sections.last.$2.add(t);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (label, items)) in sections.indexed)
                  FinSection(
                    title: i == 0 ? '${"Transactions".tr} · $label' : label,
                    top: i == 0 ? FinSpace.section : DsSpace.xl,
                    divided: true,
                    children: [for (final t in items) _TransactionTile(t: t, currency: c.currency, timeOnly: true)],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// No transaction yet: the next step is a top-up (when the card can take
/// one and the identity is verified).
class _NoTransaction extends StatelessWidget {
  final VoidCallback? onTopUp;

  const _NoTransaction({required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    Widget empty(bool canTopUp) => FinState.empty(
          Icons.receipt_long_outlined,
          "No transaction yet.".tr,
          message: canTopUp ? "Top up the card to start paying with it.".tr : null,
          actionLabel: canTopUp ? "Top up".tr : null,
          onAction: canTopUp ? onTopUp : null,
        );
    if (onTopUp == null) return empty(false);
    return StreamBuilder<Map<String, dynamic>>(
      stream: FinanceService.myProfile(),
      builder: (context, snap) => empty((snap.data?['kycLevel']?.toString() ?? '').isNotEmpty),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> t;
  final String currency;

  /// Under a day's title: the time only.
  final bool timeOnly;

  const _TransactionTile({required this.t, required this.currency, this.timeOnly = false});

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
    final DateTime? at = FinanceGroupService.toDate(t['createdAt']);
    return FinListTile(
      // A purchase shows a bag; money moved off the card (to the wallet, to
      // another card) or a fee shows an outgoing arrow.
      icon: credit ? Icons.south_west_rounded : (type == 'purchase' || type == 'authorization' ? Icons.shopping_bag_outlined : Icons.north_east_rounded),
      iconTone: status == 'declined' ? DsTone.danger : (credit ? DsTone.success : DsTone.neutral),
      title: (t['merchantName'] ?? '').toString().isNotEmpty ? t['merchantName'].toString() : CardLabels.transaction(type).tr,
      subtitle: [
        timeOnly && at != null ? ltr(DateFormat('HH:mm').format(at)) : FinanceUi.date(t['createdAt']),
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
  late Stream<Map<String, dynamic>?> _stream = FinanceCardService.limits(widget.card.id);
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

  /// The saved settings, once: the fields in major units for any currency.
  /// Only a real answer loads them - never a failed read, which would show
  /// (and could save) the defaults instead of the user's choices.
  void _load(Map<String, dynamic>? l) {
    if (_loaded) return;
    _loaded = true;
    String text(dynamic v) => v is num && v > 0 ? FinanceAmount.input(v, _cur) : '';
    _tx.text = text(l?['perTransaction']);
    _day.text = text(l?['daily']);
    _month.text = text(l?['monthly']);
    _online = l?['allowOnline'] is bool ? l!['allowOnline'] as bool : true;
    _international = l?['allowInternational'] is bool ? l!['allowInternational'] as bool : true;
  }

  /// What is wrong with one limit beyond what its field explains itself (a
  /// wrong amount, above the maximum): zero, or the rule of [problem] when
  /// it is about this field ([own]).
  String? _fieldError(TextEditingController ctrl, String? problem, String? own) {
    final String t = ctrl.text.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^[0\s.,]+$').hasMatch(t)) return "Limits must be more than zero.".tr;
    return problem != null && problem == own ? problem.tr : null;
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snap) {
        final bool waiting = snap.connectionState == ConnectionState.waiting;
        if (!waiting && !snap.hasError) _load(snap.data);
        final String? problem = _limits.problem(cfg, _cur);
        final c = DsColors.of(context);
        Widget? state;
        if (!_loaded) {
          state = waiting || !snap.hasError
              ? const DsSkeletonForm(fields: 3)
              : FinState.error(
                  "Could not load your card limits. Check your connection and try again.".tr,
                  onRetry: () => setState(() => _stream = FinanceCardService.limits(widget.card.id)),
                );
        }
        // (field, its controller, its maximum, the cross-field rule about it)
        final fields = <(String, TextEditingController, int?, String?)>[
          ("Per payment", _tx, cfg.maxPerTransaction[_cur], 'The limit per payment cannot be above the daily limit.'),
          ("Per day", _day, cfg.maxDaily[_cur], 'The daily limit cannot be above the monthly limit.'),
          ("Per month", _month, cfg.maxMonthly[_cur], null),
        ];
        final errors = [for (final (_, ctrl, _, own) in fields) _fieldError(ctrl, problem, own)];
        // A rule no field shows (should not happen) is said under them.
        final bool shown = [
          for (final (i, (_, ctrl, max, _)) in fields.indexed) errors[i] != null || FinanceAmount.problem(ctrl.text, _cur, max: max) != null,
        ].any((e) => e);
        return FinScaffold(
          title: "Card limits".tr,
          subtitle: widget.card.label.isEmpty ? null : widget.card.label,
          bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: problem == null && _loaded ? _save : null)),
          body: state != null
              ? Padding(padding: FinSpace.pagePadding, child: state)
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
                        for (final (i, (label, ctrl, max, _)) in fields.indexed)
                          FinAmountField(
                            label: label.tr,
                            controller: ctrl,
                            currency: _cur,
                            requiredMark: false,
                            max: max,
                            errorText: errors[i],
                            onChanged: (_) => setState(() {}),
                          ),
                        if (problem != null && !shown)
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
