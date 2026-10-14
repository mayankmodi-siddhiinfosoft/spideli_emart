import 'dart:developer' show log;
import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/subscriptions/saved_payment_methods_screen.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_payment_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/saved_payment_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';

// The pay sheet's types, for the modules that call it.
export 'package:customer/service/finance_ledger.dart' show FinanceFunding;
export 'package:customer/utils/finance_payment_rules.dart' show FinancePayment, FinanceDestination;

/// Typed amounts -> integer minor units with the currency's decimals only.
abstract final class FinanceAmount {
  /// "1 500" XAF -> 1500, "12.50" USD -> 1250; null when not a positive amount.
  static int? parse(String text, String currency) {
    final int e = FinanceMoney.exponent(currency);
    final m = RegExp(r'^(\d+)(?:[.,](\d+))?$').firstMatch(text.replaceAll(RegExp(r'\s'), ''));
    if (m == null) return null;
    final String fraction = m.group(2) ?? '';
    if (fraction.length > e) return null;
    final int? major = int.tryParse(m.group(1)!);
    if (major == null) return null;
    int unit = 1;
    for (int i = 0; i < e; i++) {
      unit *= 10;
    }
    final int minor = major * unit + (fraction.isEmpty ? 0 : int.parse(fraction.padRight(e, '0')));
    return minor > 0 ? minor : null;
  }

  /// [minor] as the text of an amount field, in major units for any
  /// currency: 1500 XAF -> "1500", 1250 USD -> "12.50". Empty for null.
  static String input(num? minor, String currency) {
    if (minor == null) return '';
    final int e = FinanceMoney.exponent(currency);
    if (e == 0) return minor.round().toString();
    num unit = 1;
    for (int i = 0; i < e; i++) {
      unit *= 10;
    }
    return (minor / unit).toStringAsFixed(e);
  }

  /// What is wrong with a typed amount, translated, or null: nothing typed
  /// yet, or a valid amount within [min]..[max] (minor units).
  static String? problem(String text, String currency, {int? min, int? max}) {
    if (text.trim().isEmpty) return null;
    final int? v = parse(text, currency);
    if (v == null) {
      // A well-formed zero: say so, not that the format is wrong.
      if (RegExp(r'^0*(?:[.,]0*)?$').hasMatch(text.replaceAll(RegExp(r'\s'), ''))) return "Enter an amount greater than zero.".tr;
      final int e = FinanceMoney.exponent(currency);
      return e == 0 ? "Enter a whole amount, without decimals.".tr : "${"Enter an amount with at most".tr} $e ${"decimals".tr}.";
    }
    if (min != null && v < min) return '${"The minimum is".tr} ${FinanceMoney.format(min, currency)}.';
    if (max != null && v > max) return '${"The maximum is".tr} ${FinanceMoney.format(max, currency)}.';
    return null;
  }

  /// "500 XAF - 200 000 XAF", "At least 500 XAF", "At most ..." or null.
  static String? range(int? min, int? max, String currency) {
    if (min != null && max != null) return '${FinanceMoney.format(min, currency)} - ${FinanceMoney.format(max, currency)}';
    if (min != null) return '${"At least".tr} ${FinanceMoney.format(min, currency)}';
    if (max != null) return '${"At most".tr} ${FinanceMoney.format(max, currency)}';
    return null;
  }
}

/// An amount input with its currency: always shown as the field's suffix,
/// with a currency picker when there are several - beside the field, or
/// under it on a narrow screen or with large text (never a squeezed amount
/// box). Only digits (and a decimal mark when the currency has decimals)
/// can be typed; a wrong amount or one outside [min]..[max] is explained
/// under the field as it is typed (the parent rebuilds on [onChanged]).
class FinAmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String currency;
  final List<String> currencies;
  final ValueChanged<String>? onCurrencyChanged;
  final ValueChanged<String>? onChanged;
  final bool requiredMark;
  final String? helper;
  final String? errorText;
  final int? min;
  final int? max;
  final bool enabled;

  const FinAmountField({
    super.key,
    required this.label,
    required this.controller,
    required this.currency,
    this.currencies = const [],
    this.onCurrencyChanged,
    this.onChanged,
    this.requiredMark = true,
    this.helper,
    this.errorText,
    this.min,
    this.max,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool decimals = FinanceMoney.exponent(currency) > 0;
    final String? problem = errorText ?? FinanceAmount.problem(controller.text, currency, min: min, max: max);
    final Widget field = DsTextField(
      label: label,
      controller: controller,
      requiredMark: requiredMark,
      enabled: enabled,
      helper: problem == null ? (helper ?? FinanceAmount.range(min, max, currency)) : null,
      errorText: problem,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9.,\s]' : r'[0-9\s]'))],
      suffix: Padding(
        padding: const EdgeInsetsDirectional.only(end: DsSpace.xs),
        child: Text(currency, style: DsTypography.bodyStrong.copyWith(color: c.textSecondary)),
      ),
      onChanged: onChanged,
    );
    if (currencies.length <= 1 || onCurrencyChanged == null) return field;
    final Widget picker = DsDropdown<String>(
      label: "Currency".tr,
      value: currency,
      items: [for (final cur in currencies) DropdownMenuItem(value: cur, child: Text(cur))],
      onChanged: enabled ? (v) => v == null ? null : onCurrencyChanged!(v) : null,
    );
    return LayoutBuilder(builder: (context, box) {
      final bool narrow = box.maxWidth < 340 * MediaQuery.textScalerOf(context).scale(1);
      if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [field, picker]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: field),
        const DsGap(DsSpace.sm),
        SizedBox(width: 120, child: picker),
      ]);
    });
  }
}

/// A choice in a form: a dropdown for a short list, a searchable sheet from
/// [searchFrom] options (sectors, countries, banks, billers, members).
class FinPickerField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool requiredMark;
  final String? helper;
  final String? errorText;
  final String? searchHint;

  static const int searchFrom = 9;

  const FinPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requiredMark = false,
    this.helper,
    this.errorText,
    this.searchHint,
  });

  @override
  State<FinPickerField<T>> createState() => _FinPickerFieldState<T>();
}

class _FinPickerFieldState<T> extends State<FinPickerField<T>> {
  late final TextEditingController _text = TextEditingController(text: _labelOf(widget.value));

  String _labelOf(T? v) => v == null ? '' : (widget.options.where((o) => o.$1 == v).firstOrNull?.$2 ?? '');

  @override
  void didUpdateWidget(FinPickerField<T> old) {
    super.didUpdateWidget(old);
    final String shown = _labelOf(widget.value);
    if (_text.text != shown) _text.text = shown;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (w.options.length < FinPickerField.searchFrom) {
      return DsDropdown<T>(
        label: w.label,
        value: w.options.any((o) => o.$1 == w.value) ? w.value : null,
        requiredMark: w.requiredMark,
        items: [for (final (v, l) in w.options) DropdownMenuItem<T>(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => v == null ? null : w.onChanged(v),
      );
    }
    return DsTextField(
      label: w.label,
      controller: _text,
      readOnly: true,
      requiredMark: w.requiredMark,
      helper: w.helper,
      errorText: w.errorText,
      suffix: const Icon(Icons.unfold_more_rounded, size: 20),
      onTap: () async {
        final T? v = await finPickOne<T>(title: w.label, options: w.options, selected: w.value, searchHint: w.searchHint);
        if (v != null) w.onChanged(v);
      },
    );
  }
}

/// Picks one of [options] in a sheet with a search field. Null when closed.
Future<T?> finPickOne<T>({required String title, required List<(T, String)> options, T? selected, String? searchHint}) =>
    finSheet<T>(title: title, child: _PickOneSheet<T>(options: options, selected: selected, searchHint: searchHint));

class _PickOneSheet<T> extends StatefulWidget {
  final List<(T, String)> options;
  final T? selected;
  final String? searchHint;

  const _PickOneSheet({required this.options, required this.selected, required this.searchHint});

  @override
  State<_PickOneSheet<T>> createState() => _PickOneSheetState<T>();
}

class _PickOneSheetState<T> extends State<_PickOneSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final String q = _query.trim().toLowerCase();
    final List<(T, String)> shown = q.isEmpty ? widget.options : widget.options.where((o) => o.$2.toLowerCase().contains(q)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSearchBar(hint: widget.searchHint ?? "Search".tr, onChanged: (v) => setState(() => _query = v), onClear: () => setState(() => _query = '')),
        const DsGap(DsSpace.sm),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xl),
                  child: Text("No match.".tr, textAlign: TextAlign.center, style: DsTypography.body.copyWith(color: c.textSecondary)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => Divider(height: 1, thickness: 1, color: c.divider),
                  itemBuilder: (context, i) {
                    final (T v, String label) = shown[i];
                    final bool on = v == widget.selected;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(v),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                          child: Row(children: [
                            Expanded(child: Text(label, style: (on ? DsTypography.bodyStrong : DsTypography.body).copyWith(color: c.textPrimary))),
                            if (on) Icon(Icons.check_rounded, color: c.brandStrong, semanticLabel: "Selected".tr),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Shows [child] with money actions enabled only when the user's identity
/// is verified (users/{uid}.kycLevel, set by the server). Otherwise a banner
/// leads to the verification; the server refuses unverified requests anyway.
class FinanceKycGate extends StatelessWidget {
  final Widget Function(BuildContext context, bool verified) builder;

  const FinanceKycGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FinanceService.myProfile(),
      builder: (context, snap) {
        final bool verified = (snap.data?['kycLevel']?.toString() ?? '').isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snap.hasData && !verified)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.md),
                child: DsInlineAlert(
                  tone: DsTone.warning,
                  message: "Verify your identity to save, pay and withdraw.".tr,
                  actionLabel: "Verify my identity".tr,
                  onAction: () => Get.to(() => const KycScreen()),
                ),
              ),
            builder(context, verified),
          ],
        );
      },
    );
  }
}

/// Sheets open in their own route, outside [FinScaffold]: pin the finance
/// accent there too so buttons and selections stay navy.
Widget _finAccent(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

/// Asks for an amount in [currency]; returns minor units or null.
Future<int?> askAmount(BuildContext context, {required String title, required String currency, int? max, String? hint}) {
  final ctrl = TextEditingController();
  return finSheet<int>(
    title: title,
    child: _finAccent(
      StatefulBuilder(
        builder: (context, setState) {
          final c = DsColors.of(context);
          final int? value = FinanceAmount.parse(ctrl.text, currency);
          final bool tooMuch = value != null && max != null && value > max;
          final String? error = tooMuch ? "${"At most".tr} ${FinanceMoney.format(max, currency)}" : null;
          final String? helper = error ?? hint ?? (max == null ? null : "${"At most".tr} ${FinanceMoney.format(max, currency)}");
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Amount".tr.toUpperCase(), style: FinText.sectionTitle(context)),
              const DsGap(DsSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                decoration: BoxDecoration(
                  color: c.isDark ? c.surfaceAlt : FinColors.page(context),
                  borderRadius: FinSpace.br,
                  border: Border.all(color: error != null ? c.danger : c.border, width: error != null ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: "${"Amount".tr} ($currency)",
                        textField: true,
                        child: TextField(
                          controller: ctrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          // Digits and group spaces stay in order inside Arabic text.
                          textDirection: TextDirection.ltr,
                          cursorColor: FinColors.brand(context),
                          style: FinText.amount.copyWith(color: c.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: '0',
                            hintStyle: FinText.amount.copyWith(color: c.textMuted),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(currency, style: DsTypography.titleSm.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              if (helper != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
                  child: Text(helper, style: DsTypography.caption.copyWith(color: error != null ? c.danger : c.textSecondary)),
                ),
              const DsGap(DsSpace.xl),
              DsButton.primary(
                label: "Continue".tr,
                expand: true,
                onPressed: value == null || tooMuch ? null : () => Get.back(result: value),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// The payment step of a Spideli Finance operation
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 2.3).
///
/// Paying: the user picks the Spideli Finance wallet (when [methods] has
/// `wallet`; its balance is shown and too low a balance is refused) or one
/// of the app's payment gateways enabled for their region that serves
/// [methods] and [currency] ([FinanceGateways]). A gateway's checkout runs
/// for [amount] first; only once it succeeded is [submit] called, with
/// [FinancePayment] = `FinanceFunding.gateway(method, reference)` (the
/// wallet: `FinanceFunding.wallet()`). [submit] writes the operation (one
/// batch) and returns its reply (`status`, `reference`, `instructions`).
///
/// With [payout] the user chooses where to RECEIVE [amount] instead: the
/// wallet, a saved Mobile Money number, Wave account or bank account
/// (`FinancePayment.destination`).
///
/// "Try again" after a failed [submit] sends the SAME payment again: a
/// gateway is never charged twice; the module's deterministic request id
/// keeps a retried batch from posting twice.
abstract final class FinancePaySheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required int amount,
    required String currency,
    required List<String> methods,
    required Future<Map<String, dynamic>> Function(FinancePayment payment) submit,
    bool payout = false,
  }) async {
    // One payment step at a time: a second tap while it opens does nothing.
    if (_busy) return;
    _busy = true;
    FinanceCheckout? checkout;
    try {
      // What the sheet offers, read together.
      ShowToastDialog.showLoader("Please wait...".tr);
      final Future<List<SavedPaymentMethod>> savedF =
          payout ? SavedPaymentMethods.load().catchError((_) => <SavedPaymentMethod>[]) : Future.value(const <SavedPaymentMethod>[]);
      final Future<int?> balanceF = !payout && methods.contains('wallet') ? _balance(currency) : Future<int?>.value();
      final Future<FinanceCheckout?> checkoutF = !payout && FinanceGateways.wantsGateways(methods) ? FinanceCheckout.open() : Future<FinanceCheckout?>.value();
      final saved = await savedF;
      final int? balance = await balanceF;
      checkout = await checkoutF;
      ShowToastDialog.closeLoader();
      if (!context.mounted) return;
      final options = payout ? _payoutOptions(methods, saved) : _payOptions(methods, amount, currency, balance, checkout);
      await _show(context, title: title, amount: amount, currency: currency, methods: methods, options: options, checkout: checkout, submit: submit, payout: payout);
    } finally {
      ShowToastDialog.closeLoader();
      checkout?.close();
      _busy = false;
    }
  }

  static bool _busy = false;

  /// The wallet balance in [currency] (0 without a wallet), or null when it cannot be read.
  static Future<int?> _balance(String currency) async {
    try {
      final w = await FinanceLedger.wallet(FinanceService.uid, currency);
      return w.exists ? w.balance : 0;
    } catch (_) {
      return null;
    }
  }

  static List<_PayOption> _payOptions(List<String> methods, int amount, String currency, int? balance, FinanceCheckout? checkout) => [
        if (methods.contains('wallet'))
          _PayOption(
            title: "Spideli Finance wallet".tr,
            detail: balance == null ? null : '${"Balance".tr}: ${FinanceMoney.format(balance, currency)}',
            icon: Icons.account_balance_wallet_outlined,
            // The posting re-checks the balance; the sheet says it before.
            unavailable: balance != null && balance < amount ? "Insufficient balance.".tr : null,
            payment: FinancePayment.of(const FinanceFunding.wallet()),
          ),
        for (final g in FinanceGateways.offered(methods, checkout?.enabled ?? const {}, currency))
          _PayOption(
            title: g.label,
            detail: _familyLabel(g, methods),
            icon: g.families.contains('card') && !g.families.contains('mobile_money')
                ? Icons.credit_card_rounded
                : (g.key == FinanceGateways.paypal ? Icons.account_balance_outlined : Icons.phone_iphone_rounded),
            unavailable: FinanceGateways.units(g.key, amount, currency) == null ? "This amount cannot be paid with this method.".tr : null,
            gateway: g.key,
          ),
      ];

  /// What a gateway is used for here: "Mobile Money", "Card", "Mobile Money or card"...
  static String _familyLabel(FinanceGateway g, List<String> methods) {
    final bool mm = g.families.contains('mobile_money') && methods.contains('mobile_money') || g.families.contains('wave') && methods.contains('wave');
    final bool card = g.families.contains('card') && methods.contains('card');
    if (g.key == FinanceGateways.paypal) return "PayPal account".tr;
    if (mm && card) return "Mobile Money or card".tr;
    return (mm ? "Mobile Money" : "Bank card").tr;
  }

  static List<_PayOption> _payoutOptions(List<String> methods, List<SavedPaymentMethod> saved) => [
        if (methods.contains('wallet'))
          _PayOption(title: "Spideli Finance wallet".tr, icon: Icons.account_balance_wallet_outlined, payment: FinancePayment.payout(FinanceDestination.wallet())),
        for (final m in saved)
          if (methods.contains(m.type))
            _PayOption(
              title: (m.label ?? '').isNotEmpty ? m.label! : m.title.tr,
              detail: m.isBank ? '${m.bankName ?? ''} · ${ltr(m.masked)}' : ltr(m.number),
              icon: m.isBank ? Icons.account_balance_outlined : (m.type == SavedPaymentMethod.typeWave ? Icons.waves_rounded : Icons.phone_iphone_rounded),
              payment: FinancePayment.payout(m.destination),
            ),
      ];

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required int amount,
    required String currency,
    required List<String> methods,
    required List<_PayOption> options,
    required FinanceCheckout? checkout,
    required Future<Map<String, dynamic>> Function(FinancePayment payment) submit,
    required bool payout,
  }) async {
    int? selected = options.indexWhere((o) => o.unavailable == null);
    if (selected < 0) selected = null;
    final bool manage = payout && methods.any((m) => m != 'wallet');
    final confirmed = await finSheet<bool>(
      title: title,
      child: _finAccent(
        StatefulBuilder(
          builder: (context, setState) {
            final c = DsColors.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // What is paid (or received): the focal figure of the sheet.
                Semantics(
                  container: true,
                  label: '${(payout ? "Amount" : "You pay").tr}: ${FinanceMoney.format(amount, currency)}',
                  child: ExcludeSemantics(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((payout ? "Amount" : "You pay").tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                      const DsGap(DsSpace.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(FinanceMoney.format(amount, currency), style: FinText.amount.copyWith(color: c.textPrimary)),
                      ),
                    ]),
                  ),
                ),
                const DsGap(DsSpace.xl),
                Semantics(
                  header: true,
                  child: Text((payout ? "Receive the money on" : "Pay with").tr.toUpperCase(), style: FinText.sectionTitle(context)),
                ),
                const DsGap(DsSpace.sm),
                if (options.isEmpty)
                  DsInlineAlert(
                    tone: DsTone.warning,
                    message: (payout
                            ? "Add a Mobile Money number, a Wave account or a bank account to receive the money."
                            : "No payment method is available for this currency right now.")
                        .tr,
                  )
                else
                  FinSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < options.length; i++) ...[
                          if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
                          _MethodRow(
                            title: options[i].title,
                            number: options[i].detail,
                            icon: options[i].icon,
                            note: options[i].unavailable,
                            selected: selected == i,
                            first: i == 0,
                            last: i == options.length - 1,
                            onTap: options[i].unavailable != null ? null : () => setState(() => selected = i),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (manage)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DsButton.ghost(
                      label: "Manage payment methods".tr,
                      icon: Icons.add_rounded,
                      size: DsButtonSize.sm,
                      onPressed: () {
                        Get.back(result: false);
                        Get.to(() => const SavedPaymentMethodsScreen());
                      },
                    ),
                  ),
                const DsGap(DsSpace.md),
                Text(
                  (payout ? "Check the amount and where you receive it." : "Check the amount and the payment method. You confirm the payment next.").tr,
                  style: DsTypography.caption.copyWith(color: c.textSecondary),
                ),
                const DsGap(DsSpace.md),
                DsButton.primary(
                  label: payout ? "Confirm".tr : "${"Confirm and pay".tr} ${FinanceMoney.format(amount, currency)}",
                  icon: payout ? Icons.check_rounded : Icons.lock_outline_rounded,
                  expand: true,
                  onPressed: selected == null ? null : () => Get.back(result: true),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true || selected == null || !context.mounted) return;
    final option = options[selected!];
    // The gateway takes the money first; a failed or cancelled checkout
    // charged nothing, so trying again runs it again.
    FinancePayment? payment = option.payment;
    while (payment == null) {
      try {
        if (!context.mounted || checkout == null) throw const FinanceException('gateway_unavailable');
        payment = FinancePayment.of(await checkout.pay(context, gateway: option.gateway!, amount: amount, currency: currency));
      } catch (e) {
        if (!await _failed(_message(e), payout: false)) return;
      }
    }
    // Then the operation; a retry sends the same payment (never a new charge).
    while (true) {
      ShowToastDialog.showLoader("Please wait...".tr);
      try {
        final reply = await submit(payment);
        ShowToastDialog.closeLoader();
        await _result(reply, amount: amount, currency: currency, payout: payout);
        return;
      } catch (e) {
        ShowToastDialog.closeLoader();
        final bool charged = !payout && !payment.isWallet;
        if (charged) log('finance: ${payment.method} payment ${payment.reference} not recorded yet: $e');
        if (!await _failed(_message(e), payout: payout, charged: charged ? payment : null, amount: amount, currency: currency)) return;
      }
    }
  }

  /// The translated message of a failure, with the gateway's own words when it gave some.
  static String _message(Object e) {
    if (e is! FinanceException) return FinancePayErrors.messageKey(null).tr;
    final String own = (e.details['message'] ?? '').toString().trim();
    final String message = FinancePayErrors.messageKey(e.reason).tr;
    return own.isEmpty ? message : '$message ($own)';
  }

  /// The answer: received, sent for processing, started (approve on the phone) or a payout requested.
  static Future<void> _result(Map<String, dynamic> reply, {required int amount, required String currency, required bool payout}) async {
    final String instructions = reply['instructions']?.toString() ?? '';
    final bool received = !payout && FinancePayReply.succeeded(reply);
    final bool processing = !payout && FinancePayReply.processing(reply);
    await finSheet(
      title: (payout ? "Request sent" : (received || processing ? "Payment received" : "Payment started")).tr,
      child: _finAccent(
        Builder(
          builder: (context) {
            final c = DsColors.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  DsIconWell(
                    icon: received || processing ? Icons.check_circle_rounded : (payout ? Icons.schedule_send_rounded : Icons.hourglass_top_rounded),
                    tone: received || processing ? DsTone.success : DsTone.info,
                    size: 44,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(FinanceMoney.format(amount, currency), style: FinText.amount.copyWith(color: c.textPrimary)),
                    ),
                  ),
                ]),
                const DsGap(DsSpace.lg),
                Text(
                  instructions.isNotEmpty
                      ? instructions
                      : (payout
                              ? "The money is sent once your request is processed. You can follow it here."
                              : received
                                  ? "Your payment was received."
                                  : processing
                                      ? "Your payment was received. Spideli Finance now completes your request; you can follow it here."
                                      : "Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.")
                          .tr,
                  style: DsTypography.body.copyWith(color: c.textPrimary),
                ),
                if ((reply['reference'] ?? '').toString().isNotEmpty) ...[
                  const DsGap(DsSpace.sm),
                  Divider(height: DsSpace.lg, color: c.divider),
                  FinRow("Reference".tr, ltrRef(reply['reference'])),
                ],
                const DsGap(DsSpace.lg),
                DsButton.primary(label: "OK".tr, expand: true, onPressed: () => Get.back()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// It did not go through: why, and whether to try again. [charged]: a
  /// gateway already took the money, the operation is not recorded yet -
  /// say so, and confirm before leaving without it.
  static Future<bool> _failed(String message, {required bool payout, FinancePayment? charged, int amount = 0, String currency = ''}) async {
    while (true) {
      final bool? again = await finSheet<bool>(
        title: (payout ? "Request not sent" : (charged != null ? "Payment not recorded yet" : "Payment not completed")).tr,
        isDismissible: charged == null,
        enableDrag: charged == null,
        child: _finAccent(
          Builder(
            builder: (context) {
              final c = DsColors.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const DsIconWell(icon: Icons.error_outline_rounded, tone: DsTone.danger, size: 44),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text(message, style: DsTypography.body.copyWith(color: c.textPrimary))),
                  ]),
                  if (charged != null) ...[
                    const DsGap(DsSpace.md),
                    DsInlineAlert(
                      tone: DsTone.warning,
                      message: "Your payment was received but the operation is not recorded yet. Try again to finish it: you will not be charged again.".tr,
                    ),
                    const DsGap(DsSpace.sm),
                    FinRow(FinanceGateways.label(charged.method), FinanceMoney.format(amount, currency)),
                    FinRow("Payment reference".tr, ltrRef(charged.reference)),
                  ],
                  const DsGap(DsSpace.lg),
                  DsButton.primary(label: "Try again".tr, icon: Icons.refresh_rounded, expand: true, onPressed: () => Get.back(result: true)),
                  const DsGap(DsSpace.sm),
                  DsButton.ghost(label: "Close".tr, expand: true, onPressed: () => Get.back(result: false)),
                ],
              );
            },
          ),
        ),
      );
      if (again == true) return true;
      if (charged == null) return false;
      // Leaving a taken payment unrecorded: only on purpose, with its reference.
      final bool leave = await finConfirm(
        title: "Leave without finishing?".tr,
        message: "Keep this reference: contact support with it to have the payment recorded or refunded.".tr,
        lines: [("Payment reference".tr, ltrRef(charged.reference)), (FinanceGateways.label(charged.method), FinanceMoney.format(amount, currency))],
        confirmLabel: "Leave".tr,
        cancelLabel: "Try again".tr,
        destructive: true,
      );
      if (leave) return false;
      return true;
    }
  }
}

/// One choice of the pay sheet.
class _PayOption {
  final String title;
  final String? detail;
  final IconData icon;

  /// Why it cannot be chosen (too low a balance...), or null.
  final String? unavailable;

  /// The wallet or a payout destination; null for a gateway (charged on confirm).
  final FinancePayment? payment;
  final String? gateway;

  const _PayOption({required this.title, this.detail, required this.icon, this.unavailable, this.payment, this.gateway});
}

/// One payment method of the pay sheet: a clear, full-width selectable row
/// ([onTap] null: shown with [note], not selectable).
class _MethodRow extends StatelessWidget {
  final String title;
  final String? number;
  final IconData icon;
  final String? note;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  const _MethodRow({required this.title, required this.number, required this.icon, this.note, required this.selected, required this.first, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final Color brand = FinColors.brand(context);
    final bool enabled = onTap != null;
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(FinSpace.radius - 1) : Radius.zero,
      bottom: last ? const Radius.circular(FinSpace.radius - 1) : Radius.zero,
    );
    return Semantics(
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: [title, if (number != null && number!.isNotEmpty) number!, ?note].join(', '),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? c.brandSoft : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: selected ? c.surface : c.surfaceAlt, borderRadius: DsRadius.brSm),
                      child: Icon(icon, size: 20, color: selected ? brand : c.textSecondary),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (number != null && number!.isNotEmpty) Text(number!, style: DsTypography.caption.copyWith(color: c.textSecondary).tabular),
                        if (note != null) Text(note!, style: DsTypography.caption.copyWith(color: c.danger)),
                      ]),
                    ),
                    const DsGap(DsSpace.sm),
                    Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? brand : c.textMuted, size: 22),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple line of [values] over time (unit prices, indicators, rates).
class FinanceLineChart extends StatelessWidget {
  final List<double> values;
  final double height;

  const FinanceLineChart({super.key, required this.values, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    if (values.isEmpty) return SizedBox(height: height);
    // Time runs left to right in every language, as on the dates under it.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(height: height, child: CustomPaint(painter: _LinePainter(values, c.brand, c.border))),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color line;
  final Color grid;

  _LinePainter(this.values, this.line, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final double lo = values.reduce(math.min);
    final double hi = values.reduce(math.max);
    final double span = hi - lo == 0 ? 1 : hi - lo;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final y in [0.0, size.height / 2, size.height]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = values.length == 1 ? 0 : i * size.width / (values.length - 1);
      final double y = size.height - (values[i] - lo) / span * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.line != line;
}

