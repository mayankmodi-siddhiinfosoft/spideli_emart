import 'dart:math' as math;

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

/// Asks for an amount in [currency]; returns minor units or null.
Future<int?> askAmount(BuildContext context, {required String title, required String currency, int? max, String? hint}) {
  final ctrl = TextEditingController();
  return DsBottomSheet.show<int>(
    title: title,
    child: StatefulBuilder(
      builder: (context, setState) {
        final int? value = FinanceAmount.parse(ctrl.text, currency);
        final bool tooMuch = value != null && max != null && value > max;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(
              label: "${"Amount".tr} ($currency)",
              hint: hint,
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              errorText: tooMuch ? "${"At most".tr} ${FinanceMoney.format(max, currency)}" : null,
            ),
            DsButton.primary(
              label: "Continue".tr,
              expand: true,
              onPressed: value == null || tooMuch ? null : () => Get.back(result: value),
            ),
          ],
        );
      },
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
    final options = <(String, Map<String, dynamic>)>[
      if (methods.contains('wallet')) (GroupLabels.method('wallet').tr, FinanceGroupService.paymentOf('wallet')),
      for (final m in saved)
        if (methods.contains(m.type)) ('${m.title.tr} · ${m.number}', FinanceGroupService.paymentOf(m.type, operator: m.operator, number: m.number)),
    ];
    if (!context.mounted) return;
    int? selected = options.isEmpty ? null : 0;
    final confirmed = await DsBottomSheet.show<bool>(
      title: title,
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(FinanceMoney.format(amount, currency), textAlign: TextAlign.center, style: DsTypography.title.tabular),
            const DsGap(DsSpace.md),
            Text((payout ? "Receive the money on" : "Pay with").tr, style: DsTypography.titleSm),
            const DsGap(DsSpace.xs),
            if (options.isEmpty)
              Text("Add a Mobile Money number to pay.".tr, style: DsTypography.body)
            else
              for (int i = 0; i < options.length; i++)
                RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  value: i,
                  groupValue: selected,
                  title: Text(options[i].$1),
                  onChanged: (v) => setState(() => selected = v),
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
            Text((payout ? "Check the amount and where you receive it." : "Check the amount and the payment method. You confirm the payment next.").tr, style: DsTypography.caption),
            const DsGap(DsSpace.sm),
            DsButton.primary(
              label: payout ? "Confirm".tr : "${"Confirm and pay".tr} ${FinanceMoney.format(amount, currency)}",
              icon: payout ? Icons.check_rounded : Icons.lock_outline_rounded,
              expand: true,
              onPressed: selected == null ? null : () => Get.back(result: true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null) return;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final reply = await submit(options[selected!].$2);
      ShowToastDialog.closeLoader();
      final String status = reply['status']?.toString() ?? '';
      final String instructions = reply['instructions']?.toString() ?? '';
      await DsBottomSheet.show(
        title: (payout ? "Request sent" : (status == 'succeeded' ? "Payment received" : "Payment started")).tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              instructions.isNotEmpty
                  ? instructions
                  : (payout
                          ? "The money is sent once your request is processed. You can follow it here."
                          : status == 'succeeded'
                          ? "Your payment was received."
                          : "Approve the payment on your phone if you are asked to. This page updates when the payment is confirmed.")
                      .tr,
              style: DsTypography.body,
            ),
            if ((reply['reference'] ?? '').toString().isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Text("${"Reference".tr}: ${reply['reference']}", style: DsTypography.caption),
            ],
            const DsGap(DsSpace.md),
            DsButton.primary(label: "OK".tr, expand: true, onPressed: () => Get.back()),
          ],
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

