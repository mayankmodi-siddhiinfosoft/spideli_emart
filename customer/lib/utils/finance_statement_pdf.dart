import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// The Spideli Finance account statement: header, totals per currency, and a
/// table of the user's ledger transactions for the period (same fonts and
/// greys as the order-history PDF, `order_history_pdf.dart`). [labels] holds
/// the translated texts, so this builder stays free of GetX.
class FinanceStatementPdf {
  FinanceStatementPdf._();

  static final DateFormat _day = DateFormat('MMM dd, yyyy', 'en_US');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

  /// Date & time | Reference | Type | Status | Amount.
  static const List<double> _cols = [0.20, 0.22, 0.22, 0.14, 0.22];

  /// The standard PDF fonts cover Latin-1 only (direction marks are dropped).
  static String _safe(String s) => String.fromCharCodes(s.runes.where((r) => r < 0x2066 || r > 0x2069).map((r) => r <= 0xFF ? r : 0x3F));

  static List<int> build({
    required String customerName,
    required DateTime from,
    required DateTime to,
    required List<StatementRow> rows,
    required String Function(String key) label,
    required String Function(String type) typeLabel,
  }) {
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

    final PdfPageTemplateElement footer = PdfPageTemplateElement(Rect.fromLTWH(0, 0, width, 18));
    PdfCompositeField(
      font: smallFont,
      brush: muted,
      text: '${_safe(label('Spideli Finance'))} - ${_safe(label('Page'))} {0} / {1}',
      fields: <PdfAutomaticField>[PdfPageNumberField(font: smallFont, brush: muted), PdfPageCountField(font: smallFont, brush: muted)],
    ).draw(footer.graphics, const Offset(0, 4));
    document.template.bottom = footer;

    final PdfPage page = document.pages.add();
    final PdfGraphics g = page.graphics;
    double y = 0;

    double text(String value, PdfFont font, double x, double w, {PdfBrush? brush}) {
      final String s = _safe(value);
      final double h = font.measureString(s, layoutArea: Size(w, 0)).height;
      g.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, w, h));
      return h;
    }

    void pair(String l, String v, {PdfFont? font}) {
      final double lw = width * 0.32;
      final double a = text(l, bodyFont, 0, lw, brush: muted);
      final double b = text(v, font ?? bodyFont, lw, width - lw);
      y += (a > b ? a : b) + 3;
    }

    y += text(label('Spideli Finance'), titleFont, 0, width) + 2;
    y += text(label('Account statement'), headingFont, 0, width) + 8;
    if (customerName.trim().isNotEmpty) pair(label('Customer'), customerName.trim());
    pair(label('Period'), '${_day.format(from)} - ${_day.format(to)}');
    pair(label('Generated on'), _dateTime.format(DateTime.now()));
    y += 6;
    g.drawLine(rulePen, Offset(0, y), Offset(width, y));
    y += 8;

    y += text(label('Summary'), headingFont, 0, width) + 4;
    pair(label('Number of transactions'), '${rows.length}');
    final totals = FinanceStatement.totals(rows);
    for (final e in totals.entries) {
      pair('${label('Money in')} (${e.key})', FinanceMoney.format(e.value.moneyIn, e.key), font: boldFont);
      pair('${label('Money out')} (${e.key})', FinanceMoney.format(e.value.moneyOut, e.key), font: boldFont);
    }
    y += text(label('Amounts are as recorded by Spideli Finance. A reversed transaction and its reversal are both listed.'), smallFont, 0, width, brush: muted) + 10;

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
    final PdfPen none = PdfPen(PdfColor(255, 255, 255), width: 0);
    final PdfBorders borders = PdfBorders(left: none, right: none, top: cellPen, bottom: cellPen);

    grid.headers.add(1);
    final titles = [label('Date & time'), label('Reference'), label('Type'), label('Status'), label('Amount')];
    for (int i = 0; i < titles.length; i++) {
      grid.headers[0].cells[i].value = _safe(titles[i]);
      grid.headers[0].cells[i].style = PdfGridCellStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)),
        font: cellBold,
        format: i == titles.length - 1 ? right : left,
        borders: borders,
      );
    }
    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final line = grid.rows.add();
      final values = [
        row.at == null ? '-' : _dateTime.format(row.at!),
        row.reference.isEmpty ? '-' : row.reference,
        typeLabel(row.type),
        label(row.status == 'reversed' ? 'Reversed' : 'Completed'),
        '${row.signedAmount > 0 ? '+' : ''}${FinanceMoney.format(row.signedAmount, row.currency)}',
      ];
      for (int i = 0; i < values.length; i++) {
        line.cells[i].value = _safe(values[i]);
        line.cells[i].style = PdfGridCellStyle(
          backgroundBrush: r.isOdd ? PdfSolidBrush(PdfColor(250, 250, 250)) : null,
          font: i == values.length - 1 ? cellBold : cellFont,
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
