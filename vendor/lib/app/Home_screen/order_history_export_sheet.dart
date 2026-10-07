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

/// "Export PDF" of the store's order history over a period: pick the period,
/// load every order of the current store created in it (all statuses, as the
/// home tabs list them), build the PDF and open the share sheet.
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
    final OrderExportRange? range = await showModalBottomSheet<OrderExportRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExportPeriodSheet(initial: OrderExportRange.lastDays(DateTime.now()), storeName: store.title ?? ''),
    );
    if (range == null) return;
    await _export(range, store);
  }

  static Future<void> _export(OrderExportRange range, VendorModel shownStore) async {
    final String storeId = (Constant.userModel?.vendorID ?? '').trim();
    if (storeId.isEmpty) return;
    ShowToastDialog.showLoader("Loading orders...".tr);
    final File file;
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
      );
      if (rows.isEmpty) {
        ShowToastDialog.closeLoader();
        await DsDialog.show(
          DsDialog(
            title: "No orders in this period".tr,
            message: "There is no order between @from and @to. Choose another period to export.".trParams({'from': _shownDay(range.from), 'to': _shownDay(range.to)}),
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
        rows: rows,
        summary: OrderExportSummary.of(rows),
        appName: 'spideli Store'.tr,
        storeName: storeName,
        generatedAt: DateTime.now(),
      );
      final Directory dir = await getTemporaryDirectory();
      file = File('${dir.path}/${range.fileName}');
      await file.writeAsBytes(bytes, flush: true);
    } catch (e, s) {
      log("Order history PDF failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the PDF. Please try again.".tr);
      return;
    }
    ShowToastDialog.closeLoader();
    try {
      final String period = '${_shownDay(range.from)} - ${_shownDay(range.to)}';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          fileNameOverrides: [range.fileName],
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

/// Period picker: a range calendar (today at the latest), the chosen period
/// in words, and why it cannot be exported when it cannot.
class _ExportPeriodSheet extends StatefulWidget {
  final OrderExportRange initial;
  final String storeName;

  const _ExportPeriodSheet({required this.initial, required this.storeName});

  @override
  State<_ExportPeriodSheet> createState() => _ExportPeriodSheetState();
}

class _ExportPeriodSheetState extends State<_ExportPeriodSheet> {
  DateTime? _from;
  DateTime? _to;

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
              onPressed: range == null ? null : () => Navigator.of(context).pop(range),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Every order of the store created in the chosen period is included, whatever its status. The period can be up to one year.".tr, style: t.bodySm.withColor(c.textSecondary)),
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
        ],
      ),
    );
  }
}
