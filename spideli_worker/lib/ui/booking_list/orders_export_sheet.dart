import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/currency_model.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/orders_history_export.dart';
import 'package:spideliworker/utils/orders_history_pdf.dart';
import 'package:spideliworker/utils/region_service.dart';

/// "Export PDF" of the booking history (Jobs screen, header action).
///
/// The worker picks a period (default: the last 30 days, at most one year,
/// whole local days); the sheet then reads every booking of that period the
/// Jobs screen lists (Assigned, In progress, Completed), builds the PDF and
/// opens the share sheet. An empty period shows a message and no PDF.
class OrdersExportSheet extends StatefulWidget {
  /// Anchor of the share popover on iPad (the header button).
  final Rect? shareOrigin;

  const OrdersExportSheet({super.key, this.shareOrigin});

  static Future<void> show({Rect? shareOrigin}) {
    return DsBottomSheet.show<void>(
      title: 'Export PDF'.tr,
      subtitle: 'Your bookings of the chosen period, as a PDF to save or share.'.tr,
      child: OrdersExportSheet(shareOrigin: shareOrigin),
    );
  }

  @override
  State<OrdersExportSheet> createState() => _OrdersExportSheetState();
}

class _OrdersExportSheetState extends State<OrdersExportSheet> {
  static final DateFormat _format = DateFormat('dd MMM yyyy');

  late DateTime _from;
  late DateTime _to;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  bool _busy = false;

  /// "No bookings in this period" - shown after a search came back empty.
  bool _empty = false;

  @override
  void initState() {
    super.initState();
    final ExportPeriod period = OrdersHistoryExport.defaultPeriod(DateTime.now());
    _from = period.from;
    _to = period.to;
    _syncText();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _syncText() {
    _fromController.text = _format.format(_from);
    _toController.text = _format.format(_to);
  }

  String? get _error => OrdersHistoryExport.validate(_from, _to);

  Future<void> _pick({required bool from}) async {
    final DateTime today = OrdersHistoryExport.day(DateTime.now());
    final DateTime current = from ? _from : _to;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2015),
      lastDate: today,
      helpText: (from ? 'From' : 'To').tr,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = OrdersHistoryExport.day(picked);
      } else {
        _to = OrdersHistoryExport.day(picked);
      }
      _empty = false;
      _syncText();
    });
  }

  /// Whether the Jobs screen shows this worker its active jobs (documents
  /// approved, or verification off). Waits for the verification state while
  /// it loads; when it cannot be known, treated as not approved (only
  /// completed jobs are exported, as the screen shows).
  Future<bool> _canReceiveJobs() async {
    if (!Get.isRegistered<VerificationController>()) return false;
    final VerificationController verification = Get.find<VerificationController>();
    if (verification.isLoading.value) {
      try {
        await verification.isLoading.stream.firstWhere((loading) => !loading).timeout(const Duration(seconds: 15));
      } catch (e) {
        log('Orders export: verification state not loaded: $e');
        return false;
      }
    }
    return verification.canReceiveJobs;
  }

  Future<void> _export() async {
    if (_busy || _error != null) return;
    final String workerId = MyAppState.currentUser?.id.toString() ?? '';
    if (workerId.isEmpty) {
      ShowToastDialog.showToast('Something went wrong'.tr);
      return;
    }
    final ExportPeriod period = ExportPeriod(_from, _to);
    setState(() {
      _busy = true;
      _empty = false;
    });
    try {
      await RegionService.ensureLoaded();
      final bool canReceiveJobs = await _canReceiveJobs();
      if (!mounted) return;
      final List<OnProviderOrderModel> orders = await FireStoreUtils.getWorkerBookingsInPeriod(
        workerId: workerId,
        statuses: OrdersHistoryExport.statusesFor(canReceiveJobs: canReceiveJobs),
        start: period.start,
        endExclusive: period.endExclusive,
      );
      if (!mounted) return;
      if (orders.isEmpty) {
        setState(() {
          _busy = false;
          _empty = true;
        });
        return;
      }
      final OrdersHistoryPdfData data = OrdersHistoryPdfData(
        appName: 'spideli Worker',
        ownerName: MyAppState.currentUser?.fullName() ?? '',
        period: period,
        generatedAt: DateTime.now(),
        rows: OrdersHistoryExport.buildRows(
          orders,
          currencyFor: RegionService.currencyForRegion,
          fallback: currencyData ?? CurrencyModel(),
        ),
      );
      final File file = await OrdersHistoryPdf.writeFile(data);
      if (!mounted) return;
      // Close the sheet, then hand the file to the share sheet.
      Navigator.of(context).pop();
      try {
        await OrdersHistoryPdf.share(file, data, origin: widget.shareOrigin);
      } catch (e) {
        log('Booking history share failed: $e');
        ShowToastDialog.showToast('Could not share the document.'.tr);
      }
    } catch (e, s) {
      log('Booking history export failed: $e', stackTrace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      ShowToastDialog.showToast('Could not create the PDF. Please try again.'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTextField(
          label: 'From'.tr,
          readOnly: true,
          enabled: !_busy,
          controller: _fromController,
          prefixIcon: Icons.event_outlined,
          suffix: const Icon(Icons.calendar_month),
          onTap: _busy ? null : () => _pick(from: true),
        ),
        DsTextField(
          label: 'To'.tr,
          readOnly: true,
          enabled: !_busy,
          controller: _toController,
          prefixIcon: Icons.event_outlined,
          suffix: const Icon(Icons.calendar_month),
          helper: 'Up to one year, both days included.'.tr,
          errorText: error?.tr,
          onTap: _busy ? null : () => _pick(from: false),
        ),
        if (_empty) ...[
          DsInlineAlert(
            tone: DsTone.info,
            icon: Icons.event_busy_outlined,
            title: 'No bookings in this period'.tr,
            message: 'Choose other dates to export your bookings.'.tr,
          ),
          const DsGap(DsSpace.lg),
        ],
        DsButton.primary(
          label: 'Export PDF'.tr,
          icon: Icons.picture_as_pdf_outlined,
          size: DsButtonSize.lg,
          expand: true,
          loading: _busy,
          onPressed: error == null ? _export : null,
        ),
      ],
    );
  }
}
