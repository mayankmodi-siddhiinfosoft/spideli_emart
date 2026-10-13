import 'dart:developer';

import 'package:customer/screen_ui/subscriptions/my_plan_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/order_history_export.dart';
import 'package:customer/utils/order_history_export_service.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Export PDF" of a history screen: choose a period and a status ("All
/// statuses" or one of the screen's tabs), get those orders as a PDF in the
/// share sheet.
///
/// Customers with an active order-history plan only (client rule). Without
/// one the button is shown with a lock, and tapping it explains why and offers
/// the plans. The lock is only a hint: the plan is re-read when the button is
/// tapped and again when the export starts, so a plan that expired meanwhile
/// never exports - and the export service itself refuses every step to a
/// customer without one ([OrderHistoryExportService.ensureEntitled]).
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
      final OrderHistoryExportRequest? request = await DsBottomSheet.show<OrderHistoryExportRequest>(
        title: "Export PDF".tr,
        subtitle: "Your orders of the chosen period, as a PDF you can save or send.".tr,
        child: ExportPeriodSheet(kind: widget.kind),
      );
      if (request == null) return;
      final bool exported = await OrderHistoryExportFlow.run(widget.kind, request);
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

  /// Loads, filters by status, builds and shares. True when the share sheet
  /// was reached or there was nothing to export.
  static Future<bool> run(OrderHistoryKind kind, OrderHistoryExportRequest request) async {
    ShowToastDialog.showLoader("Preparing your PDF...".tr);
    bool loaderOpen = true;
    void closeLoader() {
      if (loaderOpen) ShowToastDialog.closeLoader();
      loaderOpen = false;
    }

    try {
      // The service re-checks the plan at the moment of export, on fresh data.
      final file = await OrderHistoryExportService.exportPdf(kind, request);
      closeLoader();
      if (file == null) {
        ShowToastDialog.showToast(OrderHistoryExport.noOrdersMessage(request.status));
        return true;
      }
      await OrderHistoryExportService.share(file);
      return true;
    } on OrderHistoryExportLocked {
      closeLoader();
      await showLocked();
      return false;
    } catch (e, s) {
      log("OrderHistoryExport failed: $e", stackTrace: s);
      closeLoader();
      ShowToastDialog.showToast("Could not create the document. Please try again.".tr);
      return false;
    }
  }
}

/// From / To, both days included, last 30 days by default, a year at most;
/// then the status: "All statuses" (default) or one of the history screen's
/// tabs that has orders in the period (with their count). Resolves the bottom
/// sheet with the [OrderHistoryExportRequest].
class ExportPeriodSheet extends StatefulWidget {
  final OrderHistoryKind kind;

  const ExportPeriodSheet({super.key, required this.kind});

  @override
  State<ExportPeriodSheet> createState() => _ExportPeriodSheetState();
}

class _ExportPeriodSheetState extends State<ExportPeriodSheet> {
  late DateTime _from;
  late DateTime _to;
  ExportStatusFilter _status = ExportStatusFilter.all;

  /// The rows of [_rowsPeriod] (all statuses), read to offer the statuses.
  List<OrderExportRow>? _rows;
  ExportPeriod? _rowsPeriod;
  bool _loading = false;

  /// The period's orders could not be read: every tab is offered.
  bool _loadFailed = false;

  /// Ignores a read that finished after the period changed again.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final ExportPeriod initial = ExportPeriod.lastDays(DateTime.now());
    _from = initial.from;
    _to = initial.to;
    _loading = true;
    _fetch(initial, ++_generation);
  }

  /// After a day was picked: reads the statuses of the new period.
  void _reload() {
    final int generation = ++_generation;
    final bool valid = ExportPeriod.validate(_from, _to) == null;
    setState(() {
      _rows = null;
      _rowsPeriod = null;
      _loadFailed = false;
      _loading = valid;
    });
    if (valid) _fetch(ExportPeriod(_from, _to), generation);
  }

  Future<void> _fetch(ExportPeriod period, int generation) async {
    List<OrderExportRow>? rows;
    try {
      rows = await OrderHistoryExportService.loadRows(widget.kind, period);
    } catch (e) {
      // Locked or unreadable: the export itself re-checks and explains.
      log("ExportPeriodSheet: statuses not read: $e");
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _loadFailed = rows == null;
      _rows = rows;
      _rowsPeriod = rows == null ? null : period;
      if (!_options.contains(_status)) _status = ExportStatusFilter.all;
    });
  }

  List<ExportStatusFilter> get _options {
    if (_loadFailed) return OrderHistoryExport.statusOptions(widget.kind, null);
    if (_rows == null) return const [ExportStatusFilter.all];
    return OrderHistoryExport.statusOptions(widget.kind, _rows);
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
    _reload();
  }

  void _export() {
    final ExportPeriod period = ExportPeriod(_from, _to);
    Get.back<OrderHistoryExportRequest>(
      result: OrderHistoryExportRequest(period: period, status: _status, rows: _rowsPeriod == period ? _rows : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final ExportPeriodError? error = ExportPeriod.validate(_from, _to);
    final List<ExportStatusFilter> options = _options;
    final int selected = options.indexOf(_status);
    final List<OrderExportRow>? rows = _rows;
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
        if (error == null) ...[
          const DsGap(DsSpace.md),
          DsFieldLabel("Status".tr),
          if (_loading)
            Row(
              children: [
                const DsSpinner(size: 16, strokeWidth: 2),
                const DsGap(DsSpace.sm),
                Expanded(child: Text("Checking your orders in this period...".tr, style: t.caption)),
              ],
            )
          else ...[
            DsSegmentedTabs(
              scrollable: true,
              index: selected < 0 ? 0 : selected,
              onChanged: (i) => setState(() => _status = options[i]),
              segments: [
                for (final ExportStatusFilter o in options)
                  DsSegment(o.label, count: rows == null ? null : OrderHistoryExport.filterByStatus(rows, o).length),
              ],
            ),
            if (rows != null && rows.isEmpty) ...[
              const DsGap(DsSpace.sm),
              Text("You have no orders in this period.".tr, style: t.caption),
            ],
          ],
        ],
        const DsGap(DsSpace.md),
        DsButton.primary(
          label: "Export PDF".tr,
          icon: Icons.picture_as_pdf_outlined,
          expand: true,
          onPressed: error != null || _loading ? null : _export,
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
