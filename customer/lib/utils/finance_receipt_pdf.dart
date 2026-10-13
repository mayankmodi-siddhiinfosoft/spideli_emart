import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A one-page Spideli Finance receipt (transfers, bill payments): title,
/// then label / value lines, as the server recorded them. Same fonts and
/// greys as the statement (`finance_statement_pdf.dart`). [label] holds the
/// translated texts, so this builder stays free of GetX.
class FinanceReceiptPdf {
  FinanceReceiptPdf._();

  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

  /// The standard PDF fonts cover Latin-1 only (direction marks are dropped).
  static String _safe(String s) => String.fromCharCodes(s.runes.where((r) => r < 0x2066 || r > 0x2069).map((r) => r <= 0xFF ? r : 0x3F));

  static List<int> build({
    required String title,
    required List<(String, String)> lines,
    String? highlight,
    required String Function(String key) label,
  }) {
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10.5);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold);
    final PdfFont bigFont = PdfStandardFont(PdfFontFamily.courier, 16, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 40;
    final double width = document.pageSettings.size.width - 80;
    final PdfGraphics g = document.pages.add().graphics;
    double y = 0;

    double text(String value, PdfFont font, double x, double w, {PdfBrush? brush}) {
      final String s = _safe(value);
      final double h = font.measureString(s, layoutArea: Size(w, 0)).height;
      g.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, w, h));
      return h;
    }

    y += text(label('Spideli Finance'), titleFont, 0, width) + 2;
    y += text(title, headingFont, 0, width) + 10;
    g.drawLine(rulePen, Offset(0, y), Offset(width, y));
    y += 10;
    if (highlight != null && highlight.isNotEmpty) {
      y += text(highlight, bigFont, 0, width) + 12;
    }
    for (final (l, v) in lines) {
      final double lw = width * 0.36;
      final double a = text(l, bodyFont, 0, lw, brush: muted);
      final double b = text(v, boldFont, lw, width - lw);
      y += (a > b ? a : b) + 6;
    }
    y += 8;
    g.drawLine(rulePen, Offset(0, y), Offset(width, y));
    y += 8;
    text('${label('Generated on')} ${_dateTime.format(DateTime.now())}. ${label('This receipt reflects the transaction as recorded by Spideli Finance.')}', smallFont, 0, width,
        brush: muted);

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }
}
