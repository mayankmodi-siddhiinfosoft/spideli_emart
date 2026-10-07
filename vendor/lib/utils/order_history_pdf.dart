import 'dart:ui';

import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:vendor/utils/order_history_export.dart';
import 'package:vendor/utils/order_receipt_pdf.dart';

/// The store's order history over a period, as a PDF (syncfusion_flutter_pdf,
/// same look as [OrderReceiptPdf]): who and when, a summary with one total
/// per currency, then one table row per order. The table repeats its header
/// on every page and never splits a row across two pages.
///
/// The standard PDF fonts only encode Latin-1. A translated label outside it
/// (Arabic, Hindi, Chinese, Japanese, Russian) is printed in English, its
/// key, rather than as "????"; other text outside it (e.g. a store name in
/// Arabic script) is printed with "?" for those letters, as on the receipt.
class OrderHistoryPdf {
  OrderHistoryPdf._();

  // Table columns: date & time | order | type | status | amount.
  static const List<double> _cols = [0.20, 0.17, 0.19, 0.22, 0.22];

  /// [label] translated, or the English key when the translation cannot be
  /// drawn with the standard fonts.
  static String label(String key) {
    final String translated = key.tr;
    return OrderReceiptPdf.isLatin1(translated) ? translated : key;
  }

  /// [label] with `@name` parameters.
  static String labelParams(String key, Map<String, String> params) {
    final String translated = key.trParams(params);
    if (OrderReceiptPdf.isLatin1(translated)) return translated;
    String english = key;
    params.forEach((k, v) => english = english.replaceAll('@$k', v));
    return english;
  }

  static String safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  static String periodText(OrderExportRange range) => '${OrderExportRange.dmy(range.from)} - ${OrderExportRange.dmy(range.to)}';

  static List<int> build({
    required OrderExportRange range,
    required List<OrderExportRow> rows,
    required OrderExportSummary summary,
    required String appName,
    required String storeName,
    required DateTime generatedAt,
  }) {
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.orientation = PdfPageOrientation.portrait;

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont cellFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont cellBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    // Footer on every page: who, period, page x / y.
    final PdfMargins margins = document.pageSettings.margins;
    final double contentWidth = document.pageSettings.size.width - margins.left - margins.right;
    final PdfPageTemplateElement footer = PdfPageTemplateElement(Rect.fromLTWH(0, 0, contentWidth, 18));
    final PdfPageNumberField pageNumber = PdfPageNumberField(font: smallFont, brush: muted);
    final PdfPageCountField pageCount = PdfPageCountField(font: smallFont, brush: muted);
    PdfCompositeField(
      font: smallFont,
      brush: muted,
      text: safe('$storeName - ${periodText(range)}    {0} / {1}'),
      fields: <PdfAutomaticField>[pageNumber, pageCount],
    ).draw(footer.graphics, const Offset(0, 6));
    document.template.bottom = footer;

    final PdfPage page = document.pages.add();
    final double width = page.getClientSize().width;
    double y = 0;

    double text(String value, PdfFont font, {double x = 0, double? w, PdfBrush? brush, PdfTextAlignment align = PdfTextAlignment.left}) {
      final double boxW = w ?? width - x;
      final String s = safe(value);
      final double h = font.measureString(s, layoutArea: Size(boxW, 0)).height;
      page.graphics.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, boxW, h), format: PdfStringFormat(alignment: align));
      return h;
    }

    void pair(String name, String value, {PdfFont? font}) {
      final double labelW = width * 0.42;
      final double h1 = text(name, bodyFont, w: labelW, brush: muted);
      final double h2 = text(value, font ?? bodyFont, x: labelW, w: width - labelW);
      y += (h1 > h2 ? h1 : h2) + 3;
    }

    void rule() {
      page.graphics.drawLine(rulePen, Offset(0, y), Offset(width, y));
    }

    // ---------------- Header ----------------
    y += text(appName, smallFont, brush: muted) + 2;
    if (storeName.trim().isNotEmpty) y += text(storeName, titleFont) + 4;
    y += text(label('Order history'), headingFont) + 6;
    pair(label('Period'), '${periodText(range)} (${labelParams('@count days', {'count': '${range.dayCount}'})})');
    pair(label('Generated on'), OrderExportRange.dmyHm(generatedAt));
    y += 6;
    rule();
    y += 8;

    // ---------------- Summary ----------------
    y += text(label('Summary'), headingFont) + 4;
    pair(label('Orders'), '${summary.orderCount}', font: boldFont);
    if (summary.excludedCount > 0) pair(label('Cancelled or rejected (not in the totals)'), '${summary.excludedCount}');
    if (summary.unpricedCount > 0) pair(label('Amount not available (not in the totals)'), '${summary.unpricedCount}');
    if (summary.totals.isEmpty) {
      pair(label('Total Amount'), '-', font: boldFont);
    } else {
      for (final OrderExportCurrencyTotal total in summary.totals) {
        final String name = summary.totals.length > 1 && total.key.isNotEmpty ? '${label('Total Amount')} (${total.key})' : label('Total Amount');
        pair(name, OrderReceiptPdf.money(total.amount, total.currency), font: boldFont);
      }
    }
    y += 2;
    y += text(label("Each amount is the order's total, in the currency it was charged in."), smallFont, brush: muted) + 10;

    // ---------------- Table ----------------
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: _cols.length);
    for (int i = 0; i < _cols.length; i++) {
      grid.columns[i].width = width * _cols[i];
    }
    grid.repeatHeader = true;
    grid.allowRowBreakingAcrossPages = false;

    final PdfPen none = PdfPens.transparent;
    final PdfBorders cellBorders = PdfBorders(left: none, right: none, top: none, bottom: rulePen);
    final PdfPaddings padding = PdfPaddings(left: 4, right: 4, top: 4, bottom: 4);
    final PdfStringFormat leftFormat = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
    final PdfStringFormat rightFormat = PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle);

    final PdfGridRow header = grid.headers.add(1)[0];
    final List<String> titles = [label('Date & time'), label('Order'), label('Type'), label('Status'), label('Amount')];
    for (int i = 0; i < titles.length; i++) {
      header.cells[i].value = safe(titles[i]);
      header.cells[i].stringFormat = i == titles.length - 1 ? rightFormat : leftFormat;
      header.cells[i].style = PdfGridCellStyle(font: cellBoldFont, backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)), borders: cellBorders, cellPadding: padding);
    }

    final PdfBrush stripe = PdfSolidBrush(PdfColor(250, 250, 250));
    for (int r = 0; r < rows.length; r++) {
      final OrderExportRow row = rows[r];
      final PdfGridRow line = grid.rows.add();
      final List<String> cells = [
        OrderExportRange.dmyHm(row.createdAt),
        row.shortId,
        label(row.takeAway ? 'Takeaway' : 'Deliver to door'),
        row.status.isEmpty ? '-' : label(row.status),
        row.amount == null ? '-' : OrderReceiptPdf.money(row.amount!, row.currency),
      ];
      for (int i = 0; i < cells.length; i++) {
        line.cells[i].value = safe(cells[i]);
        line.cells[i].stringFormat = i == cells.length - 1 ? rightFormat : leftFormat;
        line.cells[i].style = PdfGridCellStyle(
          font: i == cells.length - 1 && row.countsInTotal ? cellBoldFont : cellFont,
          textBrush: row.countsInTotal ? null : muted,
          backgroundBrush: r.isOdd ? stripe : null,
          borders: cellBorders,
          cellPadding: padding,
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
