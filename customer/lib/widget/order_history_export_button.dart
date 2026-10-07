import 'dart:developer';

import 'package:customer/screen_ui/subscriptions/my_plan_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/order_history_export.dart';
import 'package:customer/utils/order_history_export_service.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Export PDF" of a history screen: choose a period, get the orders of that
/// period as a PDF in the share sheet.
///
/// Customers with an active order-history plan only (client rule). Without
/// one the button is shown with a lock, and tapping it explains why and offers
/// the plans. The lock is only a hint: the plan is re-read when the button is
/// tapped and again when the export starts, so a plan that expired meanwhile
/// never exports.
class OrderHistoryExportButton extends StatefulWidget {
  final OrderHistoryKind kind;

  const OrderHistoryExportButton({super.key, required this.kind});

  @override
  State<OrderHistoryExportButton> createState() => _OrderHistoryExportButtonState();
}

class _OrderHistoryExportButtonState extends State<OrderHistoryExportButton> {
  /// Null while unknown: the button then looks unlocked, and the tap decides.
  bool? _entitled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final bool ok = await OrderHistoryExportService.canExport();
      if (mounted) setState(() => _entitled = ok);
    } catch (e) {
      log("OrderHistoryExportButton: plan not read: $e");
    }
  }

  Future<void> _onTap() async {
    setState(() => _busy = true);
    try {
      final bool ok;
      try {
        ok = await OrderHistoryExportService.canExport();
      } catch (e) {
        log("OrderHistoryExportButton: plan check failed: $e");
        ShowToastDialog.showToast("Could not check your subscription. Please try again.".tr);
        return;
      }
      if (mounted) setState(() => _entitled = ok);
      if (!ok) {
        await OrderHistoryExportFlow.showLocked();
        await _refresh();
        return;
      }
      final ExportPeriod? period = await DsBottomSheet.show<ExportPeriod>(
        title: "Export PDF".tr,
        subtitle: "Your orders of the chosen period, as a PDF you can save or send.".tr,
        child: const ExportPeriodSheet(),
      );
      if (period == null) return;
      final bool exported = await OrderHistoryExportFlow.run(widget.kind, period);
      if (!exported) await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final bool locked = _entitled == false;
    return DsIconButton(
      semanticLabel: locked ? "Export PDF (subscription required)".tr : "Export PDF".tr,
      onPressed: _busy ? null : _onTap,
      child: locked
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.picture_as_pdf_outlined),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                    child: Icon(Icons.lock_rounded, size: 11, color: c.textMuted),
                  ),
                ),
              ],
            )
          : const Icon(Icons.picture_as_pdf_outlined),
    );
  }
}

/// The steps after the period is chosen, and the "locked" explanation.
class OrderHistoryExportFlow {
  OrderHistoryExportFlow._();

  /// Explains that exporting needs an active order-history plan, with a way
  /// to the plans.
  static Future<void> showLocked() async {
    final bool? seePlans = await DsDialog.show<bool>(
      DsDialog(
        title: "Subscription required".tr,
        message: "Exporting your order history as a PDF needs an active order history subscription.".tr,
        icon: Icons.lock_outline_rounded,
        tone: DsTone.brand,
        primaryLabel: "See plans".tr,
        onPrimary: () => Get.back(result: true),
        secondaryLabel: "Close".tr,
        onSecondary: () => Get.back(result: false),
      ),
    );
    if (seePlans == true) await Get.to(() => const MyPlanScreen());
  }

  /// Loads, builds and shares. True when the share sheet was reached.
  static Future<bool> run(OrderHistoryKind kind, ExportPeriod period) async {
    ShowToastDialog.showLoader("Preparing your PDF...".tr);
    bool loaderOpen = true;
    void closeLoader() {
      if (loaderOpen) ShowToastDialog.closeLoader();
      loaderOpen = false;
    }

    try {
      // Re-checked at the moment of export, on fresh data.
      if (!await OrderHistoryExportService.canExport()) {
        closeLoader();
        await showLocked();
        return false;
      }
      final List<OrderExportRow> rows = await OrderHistoryExportService.loadRows(kind, period);
      if (rows.isEmpty) {
        closeLoader();
        ShowToastDialog.showToast("You have no orders in this period.".tr);
        return true;
      }
      final file = await OrderHistoryExportService.writePdf(kind, period, rows);
      closeLoader();
      await OrderHistoryExportService.share(file, period);
      return true;
    } catch (e, s) {
      log("OrderHistoryExport failed: $e", stackTrace: s);
      closeLoader();
      ShowToastDialog.showToast("Could not create the document. Please try again.".tr);
      return false;
    }
  }
}

/// From / To, both days included, last 30 days by default, a year at most.
/// Resolves the bottom sheet with the [ExportPeriod].
class ExportPeriodSheet extends StatefulWidget {
  const ExportPeriodSheet({super.key});

  @override
  State<ExportPeriodSheet> createState() => _ExportPeriodSheetState();
}

class _ExportPeriodSheetState extends State<ExportPeriodSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final ExportPeriod initial = ExportPeriod.lastDays(DateTime.now());
    _from = initial.from;
    _to = initial.to;
  }

  Future<void> _pickDay({required bool start}) async {
    final DateTime today = ExportPeriod.dayOf(DateTime.now());
    final DateTime current = start ? _from : _to;
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2015),
      lastDate: today,
      helpText: start ? "From".tr : "To".tr,
    );
    if (day == null || !mounted) return;
    setState(() {
      if (start) {
        _from = ExportPeriod.dayOf(day);
      } else {
        _to = ExportPeriod.dayOf(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final ExportPeriodError? error = ExportPeriod.validate(_from, _to);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _DayField(label: "From".tr, day: _from, onTap: () => _pickDay(start: true))),
            const DsGap(DsSpace.sm),
            Expanded(child: _DayField(label: "To".tr, day: _to, onTap: () => _pickDay(start: false))),
          ],
        ),
        const DsGap(DsSpace.sm),
        Text("Both days are included. A period can be up to one year.".tr, style: t.caption),
        if (error != null) ...[
          const DsGap(DsSpace.sm),
          Text(ExportPeriod.errorMessage(error), style: t.caption.copyWith(color: c.danger)),
        ],
        const DsGap(DsSpace.md),
        DsButton.primary(
          label: "Export PDF".tr,
          icon: Icons.picture_as_pdf_outlined,
          expand: true,
          onPressed: error != null ? null : () => Get.back<ExportPeriod>(result: ExportPeriod(_from, _to)),
        ),
      ],
    );
  }
}

class _DayField extends StatelessWidget {
  final String label;
  final DateTime day;
  final VoidCallback onTap;

  const _DayField({required this.label, required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DsTypography.overline.copyWith(color: c.textMuted)),
                Text(
                  HistoryPeriod.dayLabel(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
          Icon(Icons.calendar_today_outlined, size: 16, color: c.textMuted),
        ],
      ),
    );
  }
}
