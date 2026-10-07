import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spideliworker/utils/orders_history_export.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// What the booking history PDF shows.
class OrdersHistoryPdfData {
  final String appName;

  /// The worker (signed-in user) the history belongs to.
  final String ownerName;
  final ExportPeriod period;
  final DateTime generatedAt;
  final List<ExportRow> rows;

  const OrdersHistoryPdfData({required this.appName, required this.ownerName, required this.period, required this.generatedAt, required this.rows});
}

/// Booking history PDF (syncfusion_flutter_pdf, same look as the Customer /
/// Store order receipts): header, summary (number of bookings, total per
/// currency) and a paginated table whose header row repeats on every page,
/// with "Page x of y" in the footer.
///
/// The PDF standard fonts only encode Latin-1: a label whose translation is
/// outside it (Arabic) is printed in English, and any other character outside
/// it in a value (a service title, a name) is printed as "?".
class OrdersHistoryPdf {
  OrdersHistoryPdf._();

  static final DateFormat _day = DateFormat('dd MMM yyyy');
  static final DateFormat _dayTime = DateFormat('dd MMM yyyy hh:mm a');

  /// Translation of [key], or [key] itself when the translation cannot be
  /// written with the PDF fonts.
  static String label(String key) {
    final String value = key.tr;
    return OrdersHistoryExport.isLatin1(value) ? value : key;
  }

  /// Latin-1 only; anything else becomes "?".
  static String safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  /// The PDF bytes.
  static List<int> build(OrdersHistoryPdfData d) {
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 36;

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont tableFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont tableBold = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    // Footer on every page: app name left, "Page x of y" right.
    final double clientWidth = document.pageSettings.size.width - document.pageSettings.margins.left - document.pageSettings.margins.right;
    final PdfPageTemplateElement footer = PdfPageTemplateElement(Rect.fromLTWH(0, 0, clientWidth, 22));
    footer.graphics.drawLine(rulePen, const Offset(0, 4), Offset(clientWidth, 4));
    footer.graphics.drawString(safe(d.appName), smallFont, brush: muted, bounds: Rect.fromLTWH(0, 8, clientWidth / 2, 12));
    final String pageText = label('Page {0} of {1}');
    final PdfCompositeField pages = PdfCompositeField(
      font: smallFont,
      brush: muted,
      text: pageText.contains('{0}') && pageText.contains('{1}') ? safe(pageText) : 'Page {0} of {1}',
      fields: <PdfAutomaticField>[PdfPageNumberField(font: smallFont, brush: muted), PdfPageCountField(font: smallFont, brush: muted)],
    );
    pages.stringFormat = PdfStringFormat(alignment: PdfTextAlignment.right);
    pages.bounds = Rect.fromLTWH(clientWidth / 2, 8, clientWidth / 2, 12);
    pages.draw(footer.graphics);
    document.template.bottom = footer;

    final PdfPage page = document.pages.add();
    final double width = page.getClientSize().width;
    double y = 0;

    double text(String value, PdfFont font, {PdfBrush? brush, double x = 0, double? w}) {
      final String s = safe(value);
      final double boxW = w ?? width - x;
      final double h = font.measureString(s, layoutArea: Size(boxW, 0)).height;
      page.graphics.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, boxW, h));
      return h;
    }

    void pair(String name, String value) {
      final double labelW = width * 0.30;
      final double h1 = text(name, bodyFont, brush: muted, w: labelW);
      final double h2 = text(value, bodyFont, x: labelW, w: width - labelW);
      y += (h1 > h2 ? h1 : h2) + 3;
    }

    // Header.
    y += text(d.appName, titleFont) + 4;
    y += text(label('Booking history'), headingFont) + 6;
    if (d.ownerName.trim().isNotEmpty) pair(label('Worker'), d.ownerName.trim());
    pair(label('Period'), '${_day.format(d.period.from)} - ${_day.format(d.period.to)}');
    pair(label('Generated on'), _dayTime.format(d.generatedAt));
    y += 6;
    page.graphics.drawLine(rulePen, Offset(0, y), Offset(width, y));
    y += 8;

    // Summary.
    y += text(label('Summary'), headingFont) + 4;
    pair(label('Number of bookings'), '${d.rows.length}');
    for (final CurrencyTotal t in OrdersHistoryExport.totalsPerCurrency(d.rows)) {
      final String code = OrdersHistoryExport.currencyKey(t.currency);
      final String name = code.isEmpty ? label('Total') : '${label('Total')} ($code)';
      final String value = '${OrdersHistoryExport.money(t.total, t.currency)}   (${t.count} ${label(t.count == 1 ? 'booking' : 'bookings')})';
      final double labelW = width * 0.30;
      final double h1 = text(name, bodyFont, brush: muted, w: labelW);
      final double h2 = text(value, boldFont, x: labelW, w: width - labelW);
      y += (h1 > h2 ? h1 : h2) + 3;
    }
    y += 10;

    // Table.
    const List<double> cols = [0.21, 0.15, 0.31, 0.14, 0.19];
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: cols.length);
    for (int i = 0; i < cols.length; i++) {
      grid.columns[i].width = width * cols[i];
    }
    grid.style = PdfGridStyle(font: tableFont, cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4));
    grid.repeatHeader = true;
    grid.allowRowBreakingAcrossPages = false;

    final PdfStringFormat leftFmt = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
    final PdfStringFormat rightFmt = PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle);
    final PdfBorders borders = PdfBorders(left: PdfPens.transparent, right: PdfPens.transparent, top: rulePen, bottom: rulePen);

    final PdfGridRow header = grid.headers.add(1)[0];
    final List<String> titles = [label('Date & Time'), label('Booking ID'), label('Service'), label('Status'), label('Amount')];
    for (int i = 0; i < titles.length; i++) {
      header.cells[i].value = safe(titles[i]);
      header.cells[i].style = PdfGridCellStyle(
        font: tableBold,
        backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)),
        format: i == titles.length - 1 ? rightFmt : leftFmt,
        borders: borders,
      );
    }

    for (int r = 0; r < d.rows.length; r++) {
      final ExportRow row = d.rows[r];
      final PdfGridRow gridRow = grid.rows.add();
      final List<String> cells = [
        _dayTime.format(row.date),
        row.shortId,
        row.service,
        label(row.statusLabel),
        OrdersHistoryExport.money(row.amount, row.currency),
      ];
      for (int i = 0; i < cells.length; i++) {
        gridRow.cells[i].value = safe(cells[i]);
        gridRow.cells[i].style = PdfGridCellStyle(
          font: i == cells.length - 1 ? tableBold : tableFont,
          backgroundBrush: r.isOdd ? PdfSolidBrush(PdfColor(248, 248, 248)) : null,
          format: i == cells.length - 1 ? rightFmt : leftFmt,
          borders: borders,
        );
      }
    }

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, width, 0),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate, breakType: PdfLayoutBreakType.fitPage),
    );

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  /// Builds the PDF and writes it to a temporary file named
  /// [OrdersHistoryExport.fileName] (`orders_<from>_<to>.pdf`).
  static Future<File> writeFile(OrdersHistoryPdfData data) async {
    final List<int> bytes = build(data);
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/${OrdersHistoryExport.fileName(data.period)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the share sheet on [file] so the worker can save it (Files,
  /// Drive, ...) or send it (mail, WhatsApp, ...). [origin] anchors the
  /// share popover on iPad.
  static Future<void> share(File file, OrdersHistoryPdfData data, {Rect? origin}) async {
    final String name = OrdersHistoryExport.fileName(data.period);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
        subject: '${label('Booking history')} ${_day.format(data.period.from)} - ${_day.format(data.period.to)}',
        sharePositionOrigin: origin,
      ),
    );
  }
}
