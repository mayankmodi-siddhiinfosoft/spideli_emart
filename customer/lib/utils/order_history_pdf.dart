import 'package:customer/utils/order_history_export.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// What the header of an order-history PDF says.
class OrderHistoryPdfHeader {
  final String appName;
  final String customerName;

  /// "Ride History", "Parcel History" ... (already a printable label).
  final String title;

  /// The section the history belongs to ("Food", "Cab" ...); may be empty.
  final String serviceName;
  final ExportPeriod period;
  final DateTime generatedAt;

  const OrderHistoryPdfHeader({required this.appName, required this.customerName, required this.title, required this.serviceName, required this.period, required this.generatedAt});
}

/// Builds the order-history statement: header, summary (orders, totals per
/// currency) and a table that paginates with its header repeated on every
/// page and no row split across two pages. Same fonts and greys as the
/// receipts (`order_receipt_pdf.dart`).
class OrderHistoryPdf {
  OrderHistoryPdf._();

  static final DateFormat _day = DateFormat('MMM dd, yyyy', 'en_US');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

  /// Date & time | Order | Type | Status | Amount.
  static const List<double> _cols = [0.19, 0.15, 0.30, 0.16, 0.20];

  static String _safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  static String _status(String status) => status.trim().isEmpty ? '-' : OrderHistoryExport.label(status.trim());

  static List<int> build(OrderHistoryPdfHeader h, List<OrderExportRow> rows, OrderExportSummary summary) {
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont cellFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont cellBold = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36;
    final double width = document.pageSettings.size.width - 72;

    // Footer on every page: "Page 2 / 5".
    final PdfPageTemplateElement footer = PdfPageTemplateElement(Rect.fromLTWH(0, 0, width, 18));
    PdfCompositeField(
      font: smallFont,
      brush: muted,
      text: '${_safe(h.appName)} - ${_safe(OrderHistoryExport.label('Page'))} {0} / {1}',
      fields: <PdfAutomaticField>[PdfPageNumberField(font: smallFont, brush: muted), PdfPageCountField(font: smallFont, brush: muted)],
    ).draw(footer.graphics, const Offset(0, 4));
    document.template.bottom = footer;

    final PdfPage page = document.pages.add();
    final PdfGraphics g = page.graphics;
    double y = 0;

    double text(String value, PdfFont font, double x, double w, {PdfBrush? brush, PdfTextAlignment align = PdfTextAlignment.left}) {
      final String s = _safe(value);
      final double hgt = font.measureString(s, layoutArea: Size(w, 0)).height;
      g.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, w, hgt), format: PdfStringFormat(alignment: align));
      return hgt;
    }

    void pair(String label, String value) {
      final double labelW = width * 0.30;
      final double a = text(label, bodyFont, 0, labelW, brush: muted);
      final double b = text(value, bodyFont, labelW, width - labelW);
      y += (a > b ? a : b) + 3;
    }

    void rule() => g.drawLine(rulePen, Offset(0, y), Offset(width, y));

    // ---------------- header ----------------
    y += text(h.appName, titleFont, 0, width) + 2;
    y += text(h.serviceName.isEmpty ? h.title : '${h.title} - ${h.serviceName}', headingFont, 0, width) + 8;
    if (h.customerName.trim().isNotEmpty) pair(OrderHistoryExport.label('Customer'), h.customerName.trim());
    pair(OrderHistoryExport.label('Period'), '${_day.format(h.period.from)} - ${_day.format(h.period.to)}');
    pair(OrderHistoryExport.label('Generated on'), _dateTime.format(h.generatedAt));
    y += 6;
    rule();
    y += 8;

    // ---------------- summary ----------------
    y += text(OrderHistoryExport.label('Summary'), headingFont, 0, width) + 4;
    pair(OrderHistoryExport.label('Number of orders'), '${summary.orderCount}');
    if (summary.totals.isEmpty) {
      pair(OrderHistoryExport.label('Total'), '-');
    }
    for (final CurrencyTotal t in summary.totals) {
      final String code = (t.currency?.code ?? '').trim();
      final String label = code.isEmpty ? OrderHistoryExport.label('Total') : '${OrderHistoryExport.label('Total')} ($code)';
      final double labelW = width * 0.30;
      final double a = text(label, bodyFont, 0, labelW, brush: muted);
      final double b = text(OrderHistoryExport.money(t.amount, t.currency), boldFont, labelW, width - labelW);
      y += (a > b ? a : b) + 3;
    }
    if (summary.voidedCount > 0) {
      y += text('${OrderHistoryExport.label('Cancelled or rejected orders are listed but not included in the totals:')} ${summary.voidedCount}', smallFont, 0, width, brush: muted) + 2;
    }
    if (summary.missingAmountCount > 0) {
      y += text('${OrderHistoryExport.label('Orders whose amount could not be read (shown as -):')} ${summary.missingAmountCount}', smallFont, 0, width, brush: muted) + 2;
    }
    y += 10;

    // ---------------- table ----------------
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: _cols.length);
    for (int i = 0; i < _cols.length; i++) {
      grid.columns[i].width = width * _cols[i];
    }
    grid.repeatHeader = true;
    grid.allowRowBreakingAcrossPages = false;
    grid.style = PdfGridStyle(cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4), font: cellFont);

    final PdfStringFormat right = PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle);
    final PdfStringFormat left = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
    final PdfPen cellPen = PdfPen(PdfColor(225, 225, 225), width: 0.5);
    final PdfBorders borders = PdfBorders(left: PdfPen(PdfColor(255, 255, 255), width: 0), right: PdfPen(PdfColor(255, 255, 255), width: 0), top: cellPen, bottom: cellPen);

    grid.headers.add(1);
    final PdfGridRow header = grid.headers[0];
    final List<String> titles = [
      OrderHistoryExport.label('Date & time'),
      OrderHistoryExport.label('Order'),
      OrderHistoryExport.label('Type'),
      OrderHistoryExport.label('Status'),
      OrderHistoryExport.label('Amount'),
    ];
    for (int i = 0; i < titles.length; i++) {
      header.cells[i].value = _safe(titles[i]);
      header.cells[i].style = PdfGridCellStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)),
        font: cellBold,
        format: i == titles.length - 1 ? right : left,
        borders: borders,
      );
    }

    for (int r = 0; r < rows.length; r++) {
      final OrderExportRow row = rows[r];
      final PdfGridRow line = grid.rows.add();
      final List<String> values = [
        row.createdAt == null ? '-' : _dateTime.format(row.createdAt!),
        OrderHistoryExport.shortId(row.orderId),
        row.type.trim().isEmpty ? '-' : row.type.trim(),
        _status(row.status),
        OrderHistoryExport.money(row.amount, row.currency),
      ];
      for (int i = 0; i < values.length; i++) {
        line.cells[i].value = _safe(values[i]);
        line.cells[i].style = PdfGridCellStyle(
          backgroundBrush: r.isOdd ? PdfSolidBrush(PdfColor(250, 250, 250)) : null,
          font: i == values.length - 1 && !row.isVoided ? cellBold : cellFont,
          textBrush: row.isVoided ? muted : null,
          format: i == values.length - 1 ? right : left,
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
}
