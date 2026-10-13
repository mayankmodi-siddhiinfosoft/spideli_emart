import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/subscriptions/saved_payment_methods_screen.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/saved_payment_methods.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

/// The payment step of a contribution: method (from the admin's
/// `paymentMethods`), a confirmation summary, then the server's request.
/// [submit] receives the chosen payment and returns the server's reply
/// (`status`, `instructions`, `reference`). With [payout] the user chooses
/// where to RECEIVE [amount] (withdrawals, redemptions) instead.
abstract final class FinancePaySheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required int amount,
    required String currency,
    required List<String> methods,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic> payment) submit,
    bool payout = false,
  }) async {
    final saved = await SavedPaymentMethods.load().catchError((_) => <SavedPaymentMethod>[]);
    // The options: the wallet, then each saved number of an allowed type.
    // (title, number, icon, the payment sent to the server)
    final options = <(String, String?, IconData, Map<String, dynamic>)>[
      if (methods.contains('wallet')) (GroupLabels.method('wallet').tr, null, Icons.account_balance_wallet_outlined, FinanceGroupService.paymentOf('wallet')),
      for (final m in saved)
        if (methods.contains(m.type))
          (m.title.tr, m.number, Icons.phone_iphone_rounded, FinanceGroupService.paymentOf(m.type, operator: m.operator, number: m.number)),
    ];
    if (!context.mounted) return;
    int? selected = options.isEmpty ? null : 0;
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
                  DsInlineAlert(tone: DsTone.warning, message: "Add a Mobile Money number to pay.".tr)
                else
                  FinSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < options.length; i++) ...[
                          if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
                          _MethodRow(
                            title: options[i].$1,
                            number: options[i].$2,
                            icon: options[i].$3,
                            selected: selected == i,
                            first: i == 0,
                            last: i == options.length - 1,
                            onTap: () => setState(() => selected = i),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (methods.any((m) => m != 'wallet'))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DsButton.ghost(
                      label: "Manage payment numbers".tr,
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
    if (confirmed != true || selected == null) return;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final reply = await submit(options[selected!].$4);
      ShowToastDialog.closeLoader();
      final String status = reply['status']?.toString() ?? '';
      final String instructions = reply['instructions']?.toString() ?? '';
      // Success is shown only when the server says the money arrived.
      final bool received = !payout && status == 'succeeded';
      await finSheet(
        title: (payout ? "Request sent" : (status == 'succeeded' ? "Payment received" : "Payment started")).tr,
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
                      icon: received ? Icons.check_circle_rounded : (payout ? Icons.schedule_send_rounded : Icons.hourglass_top_rounded),
                      tone: received ? DsTone.success : DsTone.info,
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
                                : status == 'succeeded'
                                ? "Your payment was received."
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
    } on FinanceException catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(FinanceErrors.messageKey(e.reason).tr);
    } catch (_) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
    }
  }
}

/// One payment method of the pay sheet: a clear, full-width selectable row.
class _MethodRow extends StatelessWidget {
  final String title;
  final String? number;
  final IconData icon;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  const _MethodRow({required this.title, required this.number, required this.icon, required this.selected, required this.first, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final Color brand = FinColors.brand(context);
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(FinSpace.radius - 1) : Radius.zero,
      bottom: last ? const Radius.circular(FinSpace.radius - 1) : Radius.zero,
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: number == null ? title : '$title, $number',
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
                      if (number != null && number!.isNotEmpty) Text(ltr(number!), style: DsTypography.caption.copyWith(color: c.textSecondary).tabular),
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
    return SizedBox(height: height, child: CustomPaint(painter: _LinePainter(values, c.brand, c.border)));
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

