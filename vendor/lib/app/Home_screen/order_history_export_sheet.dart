import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/order_history_export.dart';
import 'package:vendor/utils/order_history_pdf.dart';
import 'package:vendor/utils/region_service.dart';

/// "Export PDF" of the store's order history over a period: pick the period
/// and the status (all statuses, or one home tab's), load the orders of the
/// current store created in the period, keep the ones with that status,
/// build the PDF and open the share sheet.
class OrderHistoryExportFlow {
  OrderHistoryExportFlow._();

  /// Same permission as the order tabs.
  static bool get allowed => Constant.getEmployeeRolePermission(module: "Manage Order") == true;

  /// [store] is the store the home screen shows; the export always follows
  /// the currently selected store (`users.vendorID`).
  static Future<void> start(BuildContext context, {required VendorModel store}) async {
    if (!allowed) {
      ShowToastDialog.showToast("You don’t have permission to view orders.".tr);
      return;
    }
    final (OrderExportRange, OrderExportStatus)? choice = await showModalBottomSheet<(OrderExportRange, OrderExportStatus)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExportPeriodSheet(initial: OrderExportRange.lastDays(DateTime.now()), storeName: store.title ?? ''),
    );
    if (choice == null) return;
    await _export(choice.$1, choice.$2, store);
  }

  static Future<void> _export(OrderExportRange range, OrderExportStatus status, VendorModel shownStore) async {
    final String storeId = (Constant.userModel?.vendorID ?? '').trim();
    if (storeId.isEmpty) return;
    ShowToastDialog.showLoader("Loading orders...".tr);
    final File file;
    final String fileName;
    try {
      // Order currencies (one per region) must be known before pricing.
      await RegionService.ensureLoaded();
      final List<OrderModel>? orders = await FireStoreUtils.getStoreOrdersBetween(storeId, range.start, range.endExclusive);
      if (orders == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Could not load the orders. Please check your connection and try again.".tr);
        return;
      }
      final List<OrderExportRow> rows = await OrderHistoryExport.buildRows(
        orders,
        range: range,
        amountOf: OrderHistoryExport.storeTotalOf,
        currencyOf: RegionService.currencyForOrder,
        status: status,
        now: DateTime.now(),
        lead: Constant.scheduleLeadTime,
      );
      if (rows.isEmpty) {
        ShowToastDialog.closeLoader();
        await DsDialog.show(
          DsDialog(
            title: "No orders in this period".tr,
            message: status == OrderExportStatus.all
                ? "There is no order between @from and @to. Choose another period to export.".trParams({'from': _shownDay(range.from), 'to': _shownDay(range.to)})
                : "There is no order with the status @status between @from and @to. Choose another period or status to export.".trParams({
                    'status': status.labelKey.tr,
                    'from': _shownDay(range.from),
                    'to': _shownDay(range.to),
                  }),
            icon: Icons.receipt_long_outlined,
            tone: DsTone.neutral,
            primaryLabel: "OK".tr,
            onPrimary: () => Get.back(),
          ),
        );
        return;
      }
      String storeName = shownStore.title ?? '';
      if (shownStore.id != storeId) storeName = (await FireStoreUtils.getVendorById(storeId))?.title ?? '';
      final List<int> bytes = OrderHistoryPdf.build(
        range: range,
        status: status,
        rows: rows,
        summary: OrderExportSummary.of(rows),
        appName: 'spideli Store'.tr,
        storeName: storeName,
        generatedAt: DateTime.now(),
      );
      final Directory dir = await getTemporaryDirectory();
      fileName = OrderHistoryPdf.fileName(range, status);
      file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
    } catch (e, s) {
      log("Order history PDF failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the PDF. Please try again.".tr);
      return;
    }
    ShowToastDialog.closeLoader();
    try {
      final String period = '${_shownDay(range.from)} - ${_shownDay(range.to)} (${status.labelKey.tr})';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          fileNameOverrides: [fileName],
          subject: "${"Order history".tr} $period",
          text: "${"Order history".tr} $period",
        ),
      );
    } catch (e) {
      log("Order history share failed: $e");
      ShowToastDialog.showToast("Could not share the PDF.".tr);
    }
  }

  static String _shownDay(DateTime day) => DateFormat('dd MMM yyyy').format(day);
}

/// Period and status picker: a range calendar (today at the latest), the
/// chosen period in words (or why it cannot be exported), then the status:
/// "All statuses" (default) or one of the home screen's order tabs.
class _ExportPeriodSheet extends StatefulWidget {
  final OrderExportRange initial;
  final String storeName;

  const _ExportPeriodSheet({required this.initial, required this.storeName});

  @override
  State<_ExportPeriodSheet> createState() => _ExportPeriodSheetState();
}

class _ExportPeriodSheetState extends State<_ExportPeriodSheet> {
  /// What the chosen status covers, in words.
  static String _statusHint(OrderExportStatus status) => switch (status) {
    OrderExportStatus.all => "Orders in every status.".tr,
    OrderExportStatus.newOrders => "Placed orders the store can accept or reject now.".tr,
    OrderExportStatus.scheduled => "Placed orders waiting for their scheduled time.".tr,
    _ => "Includes: @statuses".trParams({'statuses': status.statuses.map((s) => s.tr).join(', ')}),
  };

  DateTime? _from;
  DateTime? _to;
  OrderExportStatus _status = OrderExportStatus.all;

  @override
  void initState() {
    super.initState();
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final OrderExportRangeError? error = OrderExportRange.check(_from, _to);
    final OrderExportRange? range = error == null ? OrderExportRange(_from!, _to!) : null;

    return DsSheet(
      title: "Export PDF".tr,
      subtitle: widget.storeName.trim().isEmpty ? null : widget.storeName,
      showClose: true,
      actions: Row(
        children: [
          Expanded(
            child: DsButton.secondary(label: "Cancel".tr, expand: true, onPressed: () => Navigator.of(context).pop()),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: DsButton.primary(
              label: "Export".tr,
              icon: Icons.picture_as_pdf_outlined,
              expand: true,
              onPressed: range == null ? null : () => Navigator.of(context).pop((range, _status)),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Every order of the store created in the chosen period with the chosen status is included. The period can be up to one year.".tr, style: t.bodySm.withColor(c.textSecondary)),
          const DsGap(DsSpace.md),
          SizedBox(
            height: 330,
            child: SfDateRangePicker(
              backgroundColor: c.surfaceRaised,
              headerStyle: DateRangePickerHeaderStyle(backgroundColor: c.surfaceRaised, textStyle: DsTypography.titleSm.copyWith(color: c.textPrimary)),
              monthViewSettings: DateRangePickerMonthViewSettings(viewHeaderStyle: DateRangePickerViewHeaderStyle(textStyle: DsTypography.labelSm.copyWith(color: c.textMuted))),
              monthCellStyle: DateRangePickerMonthCellStyle(
                textStyle: DsTypography.body.copyWith(color: c.textPrimary),
                disabledDatesTextStyle: DsTypography.body.copyWith(color: c.textDisabled),
                todayTextStyle: DsTypography.label.copyWith(color: c.brandStrong),
              ),
              selectionColor: c.brand,
              startRangeSelectionColor: c.brand,
              endRangeSelectionColor: c.brand,
              rangeSelectionColor: c.brandSoft,
              todayHighlightColor: c.brand,
              selectionTextStyle: DsTypography.label.copyWith(color: c.onBrand),
              rangeTextStyle: DsTypography.body.copyWith(color: c.textPrimary),
              selectionMode: DateRangePickerSelectionMode.range,
              maxDate: today,
              initialDisplayDate: widget.initial.to,
              initialSelectedRange: PickerDateRange(widget.initial.from, widget.initial.to),
              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                  final PickerDateRange value = args.value;
                  setState(() {
                    _from = value.startDate;
                    // One day tapped so far: the period is that day until
                    // the second tap.
                    _to = value.endDate ?? value.startDate;
                  });
                }
              },
            ),
          ),
          const DsGap(DsSpace.md),
          if (range != null)
            Row(
              children: [
                Icon(Icons.date_range_rounded, size: 18, color: c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(
                    "@from - @to (@count days)".trParams({
                      'from': OrderHistoryExportFlow._shownDay(range.from),
                      'to': OrderHistoryExportFlow._shownDay(range.to),
                      'count': '${range.dayCount}',
                    }),
                    style: t.label.withColor(c.textPrimary),
                  ),
                ),
              ],
            )
          else
            DsInlineAlert(tone: DsTone.warning, message: OrderExportRange.messageOf(error!).tr),
          const DsGap(DsSpace.lg),
          DsFieldLabel("Status".tr),
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: [
              for (final OrderExportStatus status in OrderExportStatus.values)
                ChoiceChip(
                  label: Text(status.labelKey.tr),
                  selected: _status == status,
                  showCheckmark: false,
                  selectedColor: c.brand,
                  backgroundColor: c.surfaceRaised,
                  side: BorderSide(color: _status == status ? c.brand : c.divider),
                  labelStyle: (_status == status ? DsTypography.label : DsTypography.body).copyWith(color: _status == status ? c.onBrand : c.textPrimary),
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const DsGap(DsSpace.sm),
          Text(_statusHint(_status), style: t.bodySm.withColor(c.textMuted)),
        ],
      ),
    );
  }
}
