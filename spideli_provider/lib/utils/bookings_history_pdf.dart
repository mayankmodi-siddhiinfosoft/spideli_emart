import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/utils/booking_receipt_pdf.dart';
import 'package:spideliprovider/utils/bookings_export.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF of the provider's booking history over a period, built with
/// syncfusion_flutter_pdf in the style of [BookingReceiptPdf]: a header
/// (app, provider, period, generation date), a summary (number of bookings,
/// total per currency) and a table that repeats its header on every page.
class BookingsHistoryPdf {
  BookingsHistoryPdf._();

  static const String appName = 'Spideli Provider';

  /// Builds the document and writes it to the temporary directory as
  /// [ExportRange.fileName].
  static Future<File> save({required ExportRange range, required List<BookingExportRow> rows, User? provider, DateTime? generatedAt}) async {
    final List<int> bytes = build(range: range, rows: rows, provider: provider, generatedAt: generatedAt ?? DateTime.now());
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/${range.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the share sheet (save to Files, e-mail, WhatsApp...).
  static Future<void> share(File file, ExportRange range) async {
    final String period = periodLabel(range);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [range.fileName],
        subject: '${'Booking history'.tr} $period',
        text: '$appName - ${'Booking history'.tr} $period',
      ),
    );
  }

  static String periodLabel(ExportRange range) {
    final DateFormat f = DateFormat('dd MMM yyyy');
    return '${f.format(range.from)} - ${f.format(range.to)}';
  }

  static String providerName(User? provider) {
    if ((provider?.companyName ?? '').trim().isNotEmpty) return provider!.companyName!.trim();
    return (provider?.fullName() ?? '').trim();
  }

  /// The PDF bytes.
  static List<int> build({required ExportRange range, required List<BookingExportRow> rows, User? provider, required DateTime generatedAt}) {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36;

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont cellFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont cellBold = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    // Footer on every page: "Page n / total".
    final Size pageSize = document.pageSettings.size;
    final double footerWidth = pageSize.width - document.pageSettings.margins.left - document.pageSettings.margins.right;
    final PdfPageTemplateElement footer = PdfPageTemplateElement(Rect.fromLTWH(0, 0, footerWidth, 18));
    PdfCompositeField(
      font: smallFont,
      brush: muted,
      text: '${_safe('Page'.tr)} {0} / {1}',
      fields: [PdfPageNumberField(font: smallFont, brush: muted), PdfPageCountField(font: smallFont, brush: muted)],
    ).draw(footer.graphics, Offset(0, 4));
    document.template.bottom = footer;

    final PdfPage page = document.pages.add();
    final double width = page.getClientSize().width;
    double y = 0;

    double text(String value, PdfFont font, {PdfBrush? brush, double x = 0, double? w, PdfTextAlignment align = PdfTextAlignment.left}) {
      final String s = _safe(value);
      final double boxW = w ?? width - x;
      final double h = font.measureString(s, layoutArea: Size(boxW, 0)).height;
      page.graphics.drawString(s, font, brush: brush, bounds: Rect.fromLTWH(x, y, boxW, h), format: PdfStringFormat(alignment: align));
      return h;
    }

    void pair(String label, String value) {
      final double labelW = width * 0.32;
      final double h1 = text(label, bodyFont, brush: muted, w: labelW);
      final double h2 = text(value, bodyFont, x: labelW, w: width - labelW);
      y += (h1 > h2 ? h1 : h2) + 3;
    }

    // ---------------- Header ----------------
    y += text(appName, titleFont) + 4;
    y += text('Booking history'.tr, headingFont) + 6;
    final String name = providerName(provider);
    if (name.isNotEmpty) pair('Provider'.tr, name);
    pair('Period'.tr, periodLabel(range));
    pair('Generated on'.tr, DateFormat('dd MMM yyyy, HH:mm').format(generatedAt));
    y += 6;
    page.graphics.drawLine(rulePen, Offset(0, y), Offset(width, y));
    y += 8;

    // ---------------- Summary ----------------
    y += text('Summary'.tr, headingFont) + 4;
    pair('Number of bookings'.tr, '${rows.length}');
    for (final CurrencyTotal total in totalsPerCurrency(rows)) {
      final String label = total.key.isEmpty ? 'Total'.tr : '${'Total'.tr} (${total.key})';
      final String count = '${total.count} ${(total.count == 1 ? 'booking' : 'bookings').tr}';
      final double labelW = width * 0.32;
      final double h1 = text(label, bodyFont, brush: muted, w: labelW);
      final double h2 = text('${BookingReceiptPdf.pdfMoney(total.amount, total.currency)}   ($count)', boldFont, x: labelW, w: width - labelW);
      y += (h1 > h2 ? h1 : h2) + 3;
    }
    y += 10;

    // ---------------- Table ----------------
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 5);
    const List<double> fractions = [0.20, 0.15, 0.31, 0.15, 0.19];
    for (int i = 0; i < fractions.length; i++) {
      grid.columns[i].width = width * fractions[i];
    }
    grid.repeatHeader = true;
    grid.style = PdfGridStyle(font: cellFont, cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3));

    final PdfStringFormat right = PdfStringFormat(alignment: PdfTextAlignment.right, lineAlignment: PdfVerticalAlignment.middle);
    final PdfStringFormat left = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
    final PdfBorders borders = PdfBorders(left: PdfPens.transparent, right: PdfPens.transparent, top: PdfPens.transparent, bottom: rulePen);

    final PdfGridRow header = grid.headers.add(1)[0];
    final List<String> titles = ['Date & Time'.tr, 'Booking ID'.tr, 'Service'.tr, 'Status'.tr, 'Amount'.tr];
    for (int i = 0; i < titles.length; i++) {
      header.cells[i].value = _safe(titles[i]);
      header.cells[i].style = PdfGridCellStyle(
        font: cellBold,
        backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)),
        format: i == titles.length - 1 ? right : left,
        borders: borders,
      );
    }

    final DateFormat dateFormat = DateFormat('dd MMM yyyy HH:mm');
    for (int r = 0; r < rows.length; r++) {
      final BookingExportRow row = rows[r];
      final PdfGridRow gridRow = grid.rows.add();
      final List<String> cells = [
        dateFormat.format(row.createdAt),
        row.shortId,
        row.hourly ? '${row.service} (${'Hourly'.tr})' : row.service,
        row.statusLabel,
        BookingReceiptPdf.pdfMoney(row.amount, row.currency),
      ];
      for (int i = 0; i < cells.length; i++) {
        gridRow.cells[i].value = _safe(cells[i]);
        gridRow.cells[i].style = PdfGridCellStyle(
          font: i == cells.length - 1 ? cellBold : cellFont,
          backgroundBrush: r.isOdd ? PdfSolidBrush(PdfColor(248, 248, 248)) : null,
          format: i == cells.length - 1 ? right : left,
          borders: borders,
        );
      }
    }

    // Paginate: rows flow onto new pages, never split, header repeated.
    grid.allowRowBreakingAcrossPages = false;
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, width, 0),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate, breakType: PdfLayoutBreakType.fitPage),
    );

    final List<int> bytes = document.saveSync();
    document.dispose();
    log('BookingsHistoryPdf: ${rows.length} rows, ${bytes.length} bytes');
    return bytes;
  }

  /// The standard PDF fonts only cover Latin-1: anything else (Arabic...)
  /// would be dropped silently, so it is written as "?" like the receipt does.
  static String _safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));
}
