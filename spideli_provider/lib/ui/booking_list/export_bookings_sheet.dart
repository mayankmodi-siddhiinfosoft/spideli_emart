import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/bookings_export.dart';
import 'package:spideliprovider/utils/bookings_history_pdf.dart';

/// "Export PDF" of the booking history: pick a period (default: the last 30
/// days, at most one year), load the provider's bookings created in it, and
/// share them as a PDF.
abstract final class ExportBookingsSheet {
  static Future<void> show() {
    return DsBottomSheet.show<void>(
      title: 'Export PDF'.tr,
      subtitle: 'Choose the period to export'.tr,
      child: const _ExportBookingsBody(),
    );
  }
}

class _ExportBookingsBody extends StatefulWidget {
  const _ExportBookingsBody();

  @override
  State<_ExportBookingsBody> createState() => _ExportBookingsBodyState();
}

class _ExportBookingsBodyState extends State<_ExportBookingsBody> {
  late ExportRange _range = ExportRange.lastDays(DateTime.now());
  bool _loading = false;

  /// Message shown under the dates: nothing to export, or a failure.
  String? _notice;
  DsTone _noticeTone = DsTone.info;

  static final DateTime _firstDay = DateTime(2015);

  Future<void> _pick({required bool from}) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime current = from ? _range.from : _range.to;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: _firstDay,
      lastDate: today,
      helpText: (from ? 'From' : 'To').tr,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = from ? ExportRange(picked, _range.to) : ExportRange(_range.from, picked);
      _notice = null;
    });
  }

  Future<void> _export() async {
    final ExportRange range = _range;
    if (range.validate() != null || _loading) return;
    final String? providerId = MyAppState.currentUser?.id;
    if (providerId == null || providerId.isEmpty) return;

    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final List<OnProviderOrderModel> bookings = await FireStoreUtils.getProviderBookingsCreatedBetween(
        providerId: providerId,
        statuses: exportedBookingStatuses,
        start: range.start,
        endExclusive: range.endExclusive,
      );
      final List<BookingExportRow> rows = buildBookingExportRows(bookings, range, currencyFor: RegionService.currencyForBooking);
      if (rows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _noticeTone = DsTone.info;
          _notice = 'No bookings in this period.'.tr;
        });
        return;
      }
      final File file = await BookingsHistoryPdf.save(range: range, rows: rows, provider: MyAppState.currentUser);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop();
      try {
        await BookingsHistoryPdf.share(file, range);
      } catch (e) {
        log('Booking history share failed: $e');
        ShowToastDialog.showToast('Could not export the booking history. Please try again.'.tr);
      }
    } catch (e, s) {
      log('Booking history export failed: $e', stackTrace: s);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _noticeTone = DsTone.danger;
        _notice = 'Could not export the booking history. Please try again.'.tr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExportRangeError? error = _range.validate();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateField(label: 'From'.tr, date: _range.from, enabled: !_loading, onTap: () => _pick(from: true)),
        const DsGap(DsSpace.sm),
        _DateField(label: 'To'.tr, date: _range.to, enabled: !_loading, onTap: () => _pick(from: false)),
        if (error != null) ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.danger, message: ExportRange.message(error)),
        ] else if (_notice != null) ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: _noticeTone, message: _notice!),
        ],
        const DsGap(DsSpace.lg),
        DsButton.primary(
          label: 'Export PDF'.tr,
          icon: Icons.picture_as_pdf_outlined,
          expand: true,
          loading: _loading,
          onPressed: error == null && !_loading ? _export : null,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.date, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
      semanticLabel: label,
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, color: c.iconDefault, size: 22),
          const DsGap(DsSpace.md),
          Expanded(child: Text(label, style: t.bodySm.withColor(c.textSecondary))),
          Text(DateFormat('dd MMM yyyy').format(date), style: t.bodyStrong.tabular),
          const DsGap(DsSpace.xs),
          Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
