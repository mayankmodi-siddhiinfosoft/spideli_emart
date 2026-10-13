import 'dart:async';

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

DsTone _tone(String? s) => switch (s) {
      'active' || 'completed' || 'succeeded' => DsTone.success,
      'frozen' || 'pending' || 'processing' || 'requested' => DsTone.info,
      'declined' || 'failed' || 'terminated' => DsTone.danger,
      'expired' || 'reversed' => DsTone.warning,
      _ => DsTone.neutral,
    };

Widget _row(BuildContext context, String label, String value) => Padding(
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

Widget _caption(BuildContext context, String text) => Text(text, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary));

/// The card as a card: masked number, expiry, holder and network. Never the full number.
class CardFace extends StatelessWidget {
  final VirtualCard card;

  const CardFace({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool dim = card.status != 'active';
    const white = Colors.white;
    return Semantics(
      label: '${"Virtual card".tr} ${card.label} ${"ending in".tr} ${card.last4}, ${CardLabels.status(card.status).tr}',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DsRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dim ? [c.textMuted, c.textSecondary] : [c.brand, c.brandStrong],
              ),
            ),
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text(card.label.isEmpty ? "Virtual card".tr : card.label, style: DsTypography.titleSm.copyWith(color: white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (card.status == 'frozen') const Icon(Icons.ac_unit_rounded, color: white, size: 20),
                  if (card.status != 'active' && card.status != 'frozen')
                    Text(CardLabels.status(card.status).tr, style: DsTypography.label.copyWith(color: white)),
                ]),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(card.masked, style: DsTypography.title.copyWith(color: white, letterSpacing: 2, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(card.cardholderName.toUpperCase(), style: DsTypography.label.copyWith(color: white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${"Valid thru".tr} ${card.expiry}', style: DsTypography.caption.copyWith(color: white.withValues(alpha: 0.85))),
                      ]),
                    ),
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
          return DsScaffold(
            title: "Virtual cards".tr,
            maxContentWidth: DsLayout.contentMax,
            body: cfg == null && cfgSnap.connectionState != ConnectionState.waiting
                ? DsEmptyState(icon: Icons.credit_card_outlined, title: "Virtual cards are not available yet.".tr)
                : const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 2)),
          );
        }
        return StreamBuilder<List<VirtualCard>>(
          stream: FinanceCardService.cards(),
          builder: (context, snap) {
            final cards = snap.data ?? const <VirtualCard>[];
            final bool canCreate = snap.hasData && CardActions.canCreate(cards, cfg);
            return DsScaffold(
              title: "Virtual cards".tr,
              maxContentWidth: DsLayout.contentMax,
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
              body: snap.hasError
                  ? DsErrorState(message: "Could not load your cards.".tr)
                  : !snap.hasData
                      ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 2))
                      : cards.isEmpty
                          ? DsEmptyState(
                              icon: Icons.credit_card_outlined,
                              title: "You have no virtual card yet.".tr,
                              message: "Pay online and abroad with a virtual Visa card you top up from your wallet or Mobile Money.".tr,
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                              children: [
                                for (final c in cards) ...[
                                  GestureDetector(onTap: () => Get.to(() => CardScreen(cardId: c.id, config: cfg)), child: CardFace(card: c)),
                                  const DsGap(DsSpace.xs),
                                  Row(children: [
                                    Expanded(child: Text('${"Balance".tr}: ${FinanceMoney.format(c.balance, c.currency)}', style: DsTypography.bodyStrong.tabular)),
                                    DsBadge(label: CardLabels.status(c.status).tr, tone: _tone(c.status), small: true),
                                  ]),
                                  const DsGap(DsSpace.lg),
                                ],
                                if (!canCreate) _caption(context, '${"You have reached the maximum number of cards".tr} (${cfg.maxCardsPerUser}).'),
                              ],
                            ),
            );
          },
        );
      },
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
    String fee(Map<String, int> fees) => cfg.feeFor(fees, _currency) == 0 ? "Free".tr : FinanceMoney.format(cfg.feeFor(fees, _currency), _currency);
    Widget can(bool yes, String text) => DsListTile(
          padding: const EdgeInsets.symmetric(vertical: 2),
          leadingIcon: yes ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded,
          leadingTone: yes ? DsTone.success : DsTone.neutral,
          title: text.tr,
        );
    return DsScaffold(
      title: "Get a virtual card".tr,
      maxContentWidth: DsLayout.contentMax,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Your card".tr,
            subtitle: "The card is issued in the name on your verified identity.".tr,
            icon: Icons.credit_card_outlined,
            children: [
              DsTextField(label: "Card name (optional)".tr, hint: "Online shopping".tr, controller: _label, maxLength: 24),
              if (cfg.currencies.length > 1)
                DsDropdown<String>(
                  label: "Currency".tr,
                  value: _currency,
                  items: [for (final c in cfg.currencies) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Fees and limits".tr,
            icon: Icons.receipt_long_outlined,
            children: [
              if (cfg.issuerName.isNotEmpty) _row(context, "Issuer".tr, cfg.issuerName),
              _row(context, "Creation fee".tr, fee(cfg.issuanceFee)),
              _row(context, "Monthly fee".tr, fee(cfg.monthlyFee)),
              _row(context, "Top-up fee".tr, cfg.fundingFeePercent == 0 ? "Free".tr : '${cfg.fundingFeePercent} %'),
              if (cfg.minFunding[_currency] != null) _row(context, "Minimum top-up".tr, FinanceMoney.format(cfg.minFunding[_currency]!, _currency)),
              if (cfg.maxFunding[_currency] != null) _row(context, "Maximum top-up".tr, FinanceMoney.format(cfg.maxFunding[_currency]!, _currency)),
              if (cfg.maxPerTransaction[_currency] != null) _row(context, "Maximum per payment".tr, FinanceMoney.format(cfg.maxPerTransaction[_currency]!, _currency)),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "What you can do".tr,
            icon: Icons.checklist_rounded,
            children: [
              can(true, "Top up from your wallet or Mobile Money"),
              can(true, "Freeze and unfreeze the card at any time"),
              can(true, "Set your own spending limits"),
              can(cfg.secureDetails != SecureDetailsMode.none, "See the full card number and security code"),
              can(cfg.canWithdraw, "Move the card balance back to your wallet"),
              can(cfg.canRenew, "Renew the card before it expires"),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Card terms".tr,
            subtitle: '${"Version".tr} ${cfg.termsVersion}',
            icon: Icons.gavel_rounded,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Scrollbar(child: SingleChildScrollView(child: Text(cfg.terms, style: DsTypography.body))),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read the card terms and the fees, and I accept them.".tr),
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
        return DsScaffold(
          title: c == null || c.label.isEmpty ? "Virtual card".tr : c.label,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this card.".tr)
              : c == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
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
      final ok = await DsBottomSheet.show<bool>(
        title: "Top up the card".tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(context, "The card receives".tr, FinanceMoney.format(q.amount, c.currency)),
            _row(context, "Top-up fee".tr, FinanceMoney.format(q.fee, c.currency)),
            _row(context, "You pay".tr, FinanceMoney.format(q.total, c.currency)),
            const DsGap(DsSpace.md),
            DsButton.primary(label: "Continue".tr, expand: true, onPressed: () => Get.back(result: true)),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
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
      title: "Receive the money on".tr,
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
    await DsBottomSheet.show(title: "Card details".tr, child: _SecretDetails(details: details!, card: card));
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

  Future<void> _terminate(BuildContext context) async {
    final c = card;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text("Delete this card?".tr),
        content: Text(
          '${"The card stops working for good. Subscriptions paid with it will fail.".tr}${c.balance > 0 ? ' ${"Its balance is returned to your wallet".tr} (${FinanceMoney.format(c.balance, c.currency)}).' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text("Keep it".tr)),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text("Delete".tr)),
        ],
      ),
    );
    if (ok != true || !await FinanceReauth.confirm()) return;
    if (await FinanceUi.run(() => FinanceCardService.terminate(c.id), success: "Card deleted")) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = card;
    final cfg = config;
    final bool renew = CardActions.canRenew(c, cfg, DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        CardFace(card: c),
        const DsGap(DsSpace.md),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _caption(context, "Balance".tr),
              Text(FinanceMoney.format(c.balance, c.currency), style: DsTypography.title.tabular),
            ]),
          ),
          DsBadge(label: CardLabels.status(c.status).tr, tone: _tone(c.status)),
        ]),
        if (c.status == 'requested') ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.info, message: "The issuer is creating your card. This page updates when it is ready.".tr),
        ],
        if (c.status == 'frozen' && c.frozenBy != 'user') ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.warning, message: "This card was frozen for your security. Contact support to unfreeze it.".tr),
        ],
        if (c.reason.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: _tone(c.status), title: "Reason".tr, message: c.reason),
        ],
        const DsGap(DsSpace.md),
        FinanceKycGate(
          builder: (context, verified) => Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: [
              if (CardActions.canFund(c)) DsButton.primary(label: "Top up".tr, icon: Icons.add_rounded, onPressed: verified ? () => _fund(context) : null),
              if (CardActions.canRevealDetails(c, cfg)) DsButton.secondary(label: "Show details".tr, icon: Icons.visibility_outlined, onPressed: () => _details(context)),
              if (CardActions.canFreeze(c))
                DsButton.secondary(
                  label: "Freeze".tr,
                  icon: Icons.ac_unit_rounded,
                  onPressed: () => FinanceUi.run(() => FinanceCardService.freeze(c.id), success: "Card frozen"),
                ),
              if (CardActions.canUnfreeze(c))
                DsButton.secondary(
                  label: "Unfreeze".tr,
                  icon: Icons.lock_open_rounded,
                  onPressed: () async {
                    if (await FinanceReauth.confirm()) await FinanceUi.run(() => FinanceCardService.unfreeze(c.id), success: "Card unfrozen");
                  },
                ),
              if (CardActions.canWithdraw(c, cfg))
                DsButton.secondary(label: "Move to my wallet".tr, icon: Icons.south_west_rounded, onPressed: verified ? () => _withdraw(context) : null),
              if (CardActions.canSetLimits(c))
                DsButton.ghost(label: "Limits".tr, icon: Icons.tune_rounded, onPressed: () => Get.to(() => CardLimitsScreen(card: c, config: cfg))),
            ],
          ),
        ),
        if (renew) ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(
            tone: DsTone.warning,
            title: (c.status == 'expired' ? "This card has expired" : "This card expires soon").tr,
            message: cfg.feeFor(cfg.renewalFee, c.currency) > 0
                ? '${"Renewal fee".tr}: ${FinanceMoney.format(cfg.feeFor(cfg.renewalFee, c.currency), c.currency)}'
                : "Renew it to keep paying with a new card.".tr,
            actionLabel: "Renew".tr,
            onAction: () => _renew(context),
          ),
        ],
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceCardService.fundingRequests(c.id),
          builder: (context, snap) {
            final pending = (snap.data ?? const []).where((r) => r['status'] == 'pending' || r['status'] == 'processing').toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsFormSection(
                title: "In progress".tr,
                icon: Icons.hourglass_top_rounded,
                children: [
                  for (final r in pending)
                    DsListTile(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      leadingIcon: r['type'] == 'withdraw' ? Icons.south_west_rounded : Icons.north_east_rounded,
                      leadingTone: DsTone.info,
                      title: '${(r['type'] == 'withdraw' ? "Withdrawal" : "Top-up").tr} · ${FinanceMoney.format(FinanceSummary.intOf(r['amount']), c.currency)}',
                      subtitle: FinanceUi.date(r['createdAt']),
                    ),
                ],
              ),
            );
          },
        ),
        const DsGap(DsSpace.md),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceCardService.transactions(c.id),
          builder: (context, snap) {
            if (snap.hasError) return DsErrorState(message: "Could not load the card transactions.".tr, compact: true);
            if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
            final list = snap.data!;
            return DsFormSection(
              title: "Transactions".tr,
              icon: Icons.receipt_long_outlined,
              children: [
                if (list.isEmpty) _caption(context, "No transaction yet.".tr),
                for (final t in list) _TransactionTile(t: t, currency: c.currency),
              ],
            );
          },
        ),
        if (CardActions.canTerminate(c))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(label: "Delete this card".tr, icon: Icons.delete_outline_rounded, onPressed: () => _terminate(context)),
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
    final String original = t['originalCurrency'] != null && t['originalCurrency'] != currency
        ? ' · ${FinanceMoney.format(FinanceSummary.intOf(t['originalAmount']), t['originalCurrency'].toString())}'
        : '';
    return DsListTile(
      padding: const EdgeInsets.symmetric(vertical: 2),
      leadingIcon: credit ? Icons.south_west_rounded : Icons.shopping_bag_outlined,
      leadingTone: status == 'declined' ? DsTone.danger : (credit ? DsTone.success : DsTone.neutral),
      title: (t['merchantName'] ?? '').toString().isNotEmpty ? t['merchantName'].toString() : CardLabels.transaction(type).tr,
      subtitle: [
        FinanceUi.date(t['createdAt']),
        if (status != 'completed') CardLabels.transactionStatus(status).tr,
        if ((t['declineReason'] ?? '').toString().isNotEmpty) t['declineReason'].toString(),
      ].join(' · '),
      trailing: Text(
        '${credit ? '+' : '-'}${FinanceMoney.format(amount, currency)}$original',
        style: DsTypography.bodyStrong.copyWith(
          color: status == 'declined' ? DsColors.of(context).textMuted : (credit ? DsColors.of(context).success : null),
          decoration: status == 'declined' || status == 'reversed' ? TextDecoration.lineThrough : null,
        ).tabular,
      ),
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
    final String number = (d['number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final int month = FinanceSummary.intOf(d['expiryMonth']);
    final int year = FinanceSummary.intOf(d['expiryYear']);
    Widget field(String label, String value, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _caption(context, label),
                Text(value, style: DsTypography.title.copyWith(letterSpacing: 1.5, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            ?trailing,
          ]),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field("Card number".tr, groupCardNumber(number),
            trailing: number.isEmpty ? null : DsIconButton(icon: Icons.copy_rounded, semanticLabel: "Copy the card number".tr, onPressed: () => _copyNumber(number))),
        Row(children: [
          Expanded(child: field("Valid thru".tr, '${month.toString().padLeft(2, '0')}/${(year % 100).toString().padLeft(2, '0')}')),
          Expanded(child: field("Security code".tr, (d['cvv'] ?? '').toString())),
        ]),
        if ((d['cardholderName'] ?? '').toString().isNotEmpty) field("Name on the card".tr, d['cardholderName'].toString().toUpperCase()),
        const DsGap(DsSpace.sm),
        DsInlineAlert(tone: DsTone.warning, message: "Never share these details. Spideli will never ask you for them.".tr),
        const DsGap(DsSpace.sm),
        _caption(context, '${"Hidden in".tr} $_left s'),
        const DsGap(DsSpace.sm),
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
        return DsScaffold(
          title: "Card limits".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: problem == null && _loaded ? _save : null)),
          body: !_loaded
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 3))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  children: [
                    if (snap.data?['status'] == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: DsInlineAlert(tone: DsTone.info, message: "Your last change is waiting for the issuer.".tr),
                      ),
                    DsFormSection(
                      title: "Spending limits".tr,
                      subtitle: "Leave a field empty to use the maximum allowed.".tr,
                      icon: Icons.tune_rounded,
                      children: [
                        for (final (label, ctrl, m) in [
                          ("Per payment", _tx, cfg.maxPerTransaction),
                          ("Per day", _day, cfg.maxDaily),
                          ("Per month", _month, cfg.maxMonthly),
                        ])
                          DsTextField(
                            label: '${label.tr} ($_cur)',
                            helper: max(m),
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        if (problem != null) DsInlineAlert(tone: DsTone.danger, message: problem.tr),
                      ],
                    ),
                    if (cfg.canToggleOnline || cfg.canToggleInternational) ...[
                      const DsGap(DsSpace.lg),
                      DsFormSection(
                        title: "Where the card works".tr,
                        icon: Icons.public_rounded,
                        children: [
                          if (cfg.canToggleOnline)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _online ?? true,
                              title: Text("Online payments".tr),
                              onChanged: (v) => setState(() => _online = v),
                            ),
                          if (cfg.canToggleInternational)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _international ?? true,
                              title: Text("Payments abroad".tr),
                              onChanged: (v) => setState(() => _international = v),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
