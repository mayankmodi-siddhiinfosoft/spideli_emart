import 'dart:ui';

import 'package:driver/constant/constant.dart';
import 'package:driver/models/currency_model.dart';
import 'package:driver/utils/order_history_export.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Texts of the PDF, already translated by the caller (see [pdfLabel]).
class OrderHistoryPdfLabels {
  final String title;
  final String period;
  final String generatedOn;
  final String summary;
  final String numberOfOrders;
  final String totalAmount;
  final String dateTime;
  final String orderId;
  final String type;
  final String status;
  final String deliveryCharge;
  final String tips;
  final String amount;
  final String page;
  final Map<OrderExportType, String> types;

  /// Status as the app shows it (`status.tr`).
  final String Function(String status) statusLabel;

  const OrderHistoryPdfLabels({
    required this.title,
    required this.period,
    required this.generatedOn,
    required this.summary,
    required this.numberOfOrders,
    required this.totalAmount,
    required this.dateTime,
    required this.orderId,
    required this.type,
    required this.status,
    required this.deliveryCharge,
    required this.tips,
    required this.amount,
    required this.page,
    required this.types,
    required this.statusLabel,
  });
}

/// Order-history statement, drawn with syncfusion_flutter_pdf in the style of
/// the receipts (customer / vendor `order_receipt_pdf.dart`): Helvetica, grey
/// header band, thin rules. The table repeats its header on every page and
/// rows never split across pages.
class OrderHistoryPdf {
  OrderHistoryPdf._();

  static final DateFormat _day = DateFormat('dd MMM yyyy');
  static final DateFormat _dayTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _time = DateFormat('hh:mm a');

  /// Builds the document and returns its bytes.
  ///
  /// [headerLines] are printed under the title (app, driver or company,
  /// selected driver...). [showEarnings] adds the delivery charge and tip
  /// columns the delivery history card shows.
  static List<int> build({
    required OrderHistoryPdfLabels labels,
    required List<String> headerLines,
    required ExportDateRange range,
    required DateTime generatedAt,
    required List<OrderExportRow> rows,
    required bool showEarnings,
  }) {
    final OrderExportSummary summary = OrderExportSummary.of(rows);
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    final _Writer w = _Writer(document);

    // ---------------- Header ----------------
    w.line(labels.title, w.titleFont);
    for (final String line in headerLines.where((l) => l.trim().isNotEmpty)) {
      w.line(line, w.headingFont);
    }
    w.gap(2);
    w.pair(labels.period, '${_day.format(range.from)} - ${_day.format(range.to)}');
    w.pair(labels.generatedOn, _dayTime.format(generatedAt));
    w.gap(8);
    w.rule();
    w.gap(8);

    // ---------------- Summary ----------------
    w.line(labels.summary, w.headingFont);
    w.pair(labels.numberOfOrders, '${summary.orderCount}');
    for (final CurrencyTotals t in summary.perCurrency) {
      final String code = currencyKey(t.currency);
      final String suffix = code.isEmpty ? '' : ' ($code)';
      // Several currencies (orders of different regions): each one's count too.
      if (summary.perCurrency.length > 1) w.pair('${labels.numberOfOrders}$suffix', '${t.orders}');
      w.pair('${labels.totalAmount}$suffix', money(t.amount, t.currency));
      if (showEarnings && (t.deliveryCharge > 0 || t.tips > 0)) {
        w.pair('${labels.deliveryCharge}$suffix', money(t.deliveryCharge, t.currency));
        w.pair('${labels.tips}$suffix', money(t.tips, t.currency));
      }
    }
    w.gap(12);

    // ---------------- Table ----------------
    final List<_Column> columns = [
      _Column(labels.dateTime, showEarnings ? 0.17 : 0.21),
      _Column(labels.orderId, showEarnings ? 0.13 : 0.15),
      _Column(labels.type, showEarnings ? 0.17 : 0.22),
      _Column(labels.status, showEarnings ? 0.15 : 0.20),
      if (showEarnings) _Column(labels.deliveryCharge, 0.12, right: true),
      if (showEarnings) _Column(labels.tips, 0.10, right: true),
      _Column(labels.amount, showEarnings ? 0.16 : 0.22, right: true),
    ];
    w.table(columns, [
      for (final OrderExportRow row in rows)
        [
          '${_day.format(row.createdAt.toLocal())}\n${_time.format(row.createdAt.toLocal())}',
          shortOrderId(row.orderId),
          [labels.types[row.type] ?? row.type.name, if (row.section.trim().isNotEmpty) row.section.trim()].join('\n'),
          labels.statusLabel(row.status),
          if (showEarnings) row.type == OrderExportType.delivery && row.deliveryCharge != null ? money(row.deliveryCharge!, row.currency) : '-',
          if (showEarnings) row.type == OrderExportType.delivery && (row.tip ?? 0) > 0 ? money(row.tip!, row.currency) : '-',
          row.amount == null ? '-' : money(row.amount!, row.currency),
        ],
    ]);

    // ---------------- Page numbers ----------------
    final int count = document.pages.count;
    for (int i = 0; i < count; i++) {
      final PdfPage page = document.pages[i];
      final Size size = page.getClientSize();
      page.graphics.drawString(
        _Writer.safe('${labels.page} ${i + 1} / $count'),
        w.smallFont,
        brush: w.muted,
        bounds: Rect.fromLTWH(0, size.height - _Writer.footerHeight + 6, size.width, _Writer.footerHeight - 6),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  /// [Constant.amountShow] in the order's currency. A symbol the PDF font
  /// cannot draw (e.g. the rupee sign) is replaced by the currency code, as
  /// the receipts do.
  static String money(double value, CurrencyModel? currency) {
    final String shown = Constant.amountShow(currency: currency, amount: value.toString());
    if (!isLatin1(shown) && currency != null && (currency.code ?? '').isNotEmpty) {
      return shown.replaceAll(currency.symbol ?? '', currency.code!).trim();
    }
    return shown;
  }
}

class _Column {
  final String title;
  final double share;
  final bool right;

  const _Column(this.title, this.share, {this.right = false});
}

/// Top-to-bottom writer with automatic page breaks (as in the receipts).
class _Writer {
  final PdfDocument document;
  late PdfPage page;
  double y = 0;

  /// Room kept at the bottom of every page for the page number.
  static const double footerHeight = 18;

  final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
  final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
  final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final PdfFont cellFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
  final PdfFont cellBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
  final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
  final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
  final PdfBrush headerFill = PdfSolidBrush(PdfColor(240, 240, 240));
  final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);
  final PdfPen rowPen = PdfPen(PdfColor(225, 225, 225), width: 0.5);

  _Writer(this.document) {
    page = document.pages.add();
  }

  double get width => page.getClientSize().width;
  double get height => page.getClientSize().height - footerHeight;

  /// Starts a new page when [needed] does not fit; returns true if it did.
  bool ensure(double needed) {
    if (y + needed > height) {
      page = document.pages.add();
      y = 0;
      return true;
    }
    return false;
  }

  void gap(double value) => y += value;

  /// Standard fonts only encode Latin-1; anything else becomes "?".
  static String safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  double measure(String text, PdfFont font, double w) => text.isEmpty ? 0 : font.measureString(safe(text), layoutArea: Size(w, 0)).height;

  double textAt(String text, PdfFont font, double x, double top, double w, {PdfTextAlignment align = PdfTextAlignment.left, PdfBrush? brush}) {
    if (text.isEmpty) return 0;
    final double h = measure(text, font, w);
    page.graphics.drawString(safe(text), font, brush: brush, bounds: Rect.fromLTWH(x, top, w, h), format: PdfStringFormat(alignment: align));
    return h;
  }

  void line(String text, PdfFont font) {
    final double h = measure(text, font, width);
    ensure(h);
    textAt(text, font, 0, y, width);
    y += h + 3;
  }

  void pair(String label, String value) {
    final double labelW = width * 0.38;
    final double valueW = width - labelW;
    final double h = [measure(label, bodyFont, labelW), measure(value, bodyFont, valueW)].reduce((a, b) => a > b ? a : b);
    ensure(h);
    textAt(label, bodyFont, 0, y, labelW, brush: muted);
    textAt(value, bodyFont, labelW, y, valueW);
    y += h + 3;
  }

  void rule() {
    ensure(2);
    page.graphics.drawLine(rulePen, Offset(0, y), Offset(width, y));
  }

  static const double _pad = 3;

  void table(List<_Column> columns, List<List<String>> rows) {
    final List<double> xs = [];
    double x = 0;
    for (final _Column c in columns) {
      xs.add(x);
      x += width * c.share;
    }
    double cellW(int i) => width * columns[i].share - 2 * _pad;

    double headerHeight() {
      double h = 0;
      for (int i = 0; i < columns.length; i++) {
        final double ch = measure(columns[i].title, cellBoldFont, cellW(i));
        if (ch > h) h = ch;
      }
      return h + 2 * _pad;
    }

    void header() {
      final double h = headerHeight();
      page.graphics.drawRectangle(brush: headerFill, bounds: Rect.fromLTWH(0, y, width, h));
      for (int i = 0; i < columns.length; i++) {
        textAt(columns[i].title, cellBoldFont, xs[i] + _pad, y + _pad, cellW(i), align: columns[i].right ? PdfTextAlignment.right : PdfTextAlignment.left);
      }
      y += h;
    }

    // The header and at least the first row stay together.
    final double firstRow = rows.isEmpty ? 0 : _rowHeight(columns, rows.first, cellW);
    ensure(headerHeight() + firstRow);
    header();
    for (final List<String> cells in rows) {
      final double h = _rowHeight(columns, cells, cellW);
      if (ensure(h)) header();
      for (int i = 0; i < columns.length; i++) {
        final bool last = i == columns.length - 1;
        textAt(cells[i], last ? cellBoldFont : cellFont, xs[i] + _pad, y + _pad, cellW(i), align: columns[i].right ? PdfTextAlignment.right : PdfTextAlignment.left);
      }
      y += h;
      page.graphics.drawLine(rowPen, Offset(0, y), Offset(width, y));
    }
  }

  double _rowHeight(List<_Column> columns, List<String> cells, double Function(int) cellW) {
    double h = 0;
    for (int i = 0; i < columns.length; i++) {
      final double ch = measure(cells[i], i == columns.length - 1 ? cellBoldFont : cellFont, cellW(i));
      if (ch > h) h = ch;
    }
    return h + 2 * _pad;
  }
}
